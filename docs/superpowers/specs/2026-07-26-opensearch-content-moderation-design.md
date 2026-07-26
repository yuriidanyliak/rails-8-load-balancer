# OpenSearch Content Moderation — Design

Date: 2026-07-26

## Goal

Let operators maintain a list of banned words/phrases, and periodically scan
`Message` and `Image` content in the background for matches, flagging hits
for follow-up review. The core requirement is an *efficient* search function
— one that doesn't degrade as the banned-word list grows — invoked from a
Sidekiq job.

## Data model

### `BannedWord`

```ruby
create_table :banned_words do |t|
  t.string  :phrase, null: false
  t.boolean :active, null: false, default: true
  t.timestamps
end
add_index :banned_words, "lower(phrase)", unique: true, name: "index_banned_words_on_lower_phrase"
```

### `Message`

```ruby
create_table :messages do |t|
  t.text     :body, null: false
  t.boolean  :flagged, null: false, default: false
  t.datetime :flagged_at
  t.jsonb    :matched_terms, null: false, default: []
  t.datetime :last_scanned_at
  t.timestamps
end
add_index :messages, :last_scanned_at
add_index :messages, :flagged
```

### `Image`

```ruby
create_table :images do |t|
  t.string   :filename
  t.string   :caption
  t.jsonb    :tags, null: false, default: []
  t.boolean  :flagged, null: false, default: false
  t.datetime :flagged_at
  t.jsonb    :matched_terms, null: false, default: []
  t.datetime :last_scanned_at
  t.timestamps
end
add_index :images, :last_scanned_at
add_index :images, :flagged
```

`Image` also gets `has_one_attached :file` (Active Storage — `image_processing`
is already in the Gemfile) for a real persisted file. The *searchable*
surface for moderation purposes is metadata only: `filename` + `caption` +
`tags`. Actual pixel-content classification (computer vision) is out of scope.

## OpenSearch integration

Gem: `opensearch-ruby`. Client: `ContentModeration::OpensearchClient`, a thin
singleton around `OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"))`.

### Percolator index (the efficiency mechanism)

One shared index, `banned_content_queries_#{Rails.env}`:

```json
{ "properties": {
    "content": { "type": "text", "analyzer": "standard" },
    "query":   { "type": "percolator" }
}}
```

Created idempotently by a rake task (`content_moderation:setup_index`), not
on every boot.

Rationale: a naive design runs one query per document with one clause per
banned word — cost grows as O(documents × words). The percolator approach
indexes each banned word once as a stored query; scanning becomes "percolate
a batch of documents against all stored queries in one request," which is
O(batches) and stays flat as the word list grows. This is the standard
OpenSearch/Elasticsearch pattern for "many rules vs. many documents"
matching (content moderation, alerting).

### Syncing the dictionary

`BannedWord` has an `after_commit` callback delegating to
`ContentModeration::BannedWordIndexer.call(banned_word)`:
- create/update (while `active: true`): index `{ query: { match_phrase: { content: phrase } } }` under `_id: banned_word.id`.
- destroy, or `active: false`: delete that doc.

Low volume, real-time is fine — no batching needed here.

### Scanning (high volume — the core function)

`ContentModeration::PercolateScanner`, parameterized by model class + a block
building the searchable text, shared by both scanners:

```ruby
module ContentModeration
  class PercolateScanner
    BATCH_SIZE = 500

    def initialize(model_class, client: OpensearchClient.instance, &content_builder)
      @model_class = model_class
      @client = client
      @content_builder = content_builder
    end

    def call
      unscanned.find_in_batches(batch_size: BATCH_SIZE) { |batch| scan_batch(batch) }
    end

    private

    def unscanned
      @model_class.where(last_scanned_at: nil).or(@model_class.where("last_scanned_at < updated_at"))
    end

    def scan_batch(batch)
      response = @client.search(
        index: PERCOLATOR_INDEX,
        body: {
          query: { percolate: {
            field: "query",
            documents: batch.map { |record| { content: @content_builder.call(record) } }
          } }
        }
      )
      apply_results(batch, matches_by_slot(response))
    end

    def apply_results(batch, matches_by_slot)
      now = Time.current
      batch.each_with_index do |record, slot|
        matched = matches_by_slot[slot] || []
        if matched.any?
          record.update_columns(flagged: true, flagged_at: now, matched_terms: matched, last_scanned_at: now)
        else
          record.update_columns(last_scanned_at: now)
        end
      end
    end
  end
end
```

```ruby
# app/services/content_moderation/message_scanner.rb
ContentModeration::PercolateScanner.new(Message) { |m| m.body }.call

# app/services/content_moderation/image_scanner.rb
ContentModeration::PercolateScanner.new(Image) { |i| [i.filename, i.caption, Array(i.tags).join(" ")].compact.join(" ") }.call
```

## Controller

`app/controllers/banned_words_controller.rb`, full CRUD JSON:

```ruby
resources :banned_words, only: %i[index create update destroy]
```

Stays thin — no OpenSearch calls in the controller; syncing happens via the
model's `after_commit` hook.

## Sidekiq job & scheduling

```ruby
class ContentModerationSweepJob < ApplicationJob
  queue_as :default

  def perform
    ContentModeration::MessageScanner.call
    ContentModeration::ImageScanner.call
  end
end
```

Scheduled via `sidekiq-cron`, `config/schedule.yml`:

```yaml
content_moderation_sweep:
  cron: "*/5 * * * *"
  class: "ContentModerationSweepJob"
```

Loaded from `config/initializers/sidekiq.rb`, guarded by `Sidekiq.server?`.

## Local infra

New `docker-compose.yml`: single-node OpenSearch (`discovery.type=single-node`,
security plugin disabled for dev), port `9200`. `OPENSEARCH_URL` documented
in README/`.env`.

## Testing

- `OpensearchClient` is injected (constructor param, defaulting to the
  singleton) into `PercolateScanner` and `BannedWordIndexer`, so specs stub a
  double instead of requiring a live OpenSearch instance.
- Unit specs: `PercolateScanner` (stub `client.search`, assert per-slot
  `update_columns` behavior), `BannedWordIndexer` (stub `client.index` /
  `client.delete`).
- Request specs: `BannedWordsController` CRUD, indexer stubbed.
- One `:integration`-tagged spec (excluded from the default run) exercises a
  real percolate round-trip against the docker-compose OpenSearch instance.

## Out of scope

- Actual image computer-vision/content classification.
- Admin UI (views) for banned words — JSON API only.
- Multi-tenant or namespaced banned-word lists.
