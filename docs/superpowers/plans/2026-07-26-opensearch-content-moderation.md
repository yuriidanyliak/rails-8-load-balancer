# OpenSearch Content Moderation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let operators maintain a banned-word list via a JSON API, and have a Sidekiq job periodically scan `Message` and `Image` records for matches using an OpenSearch percolator index, so search cost stays flat as the word list grows.

**Architecture:** Banned words are stored in Postgres and mirrored 1:1 into a single OpenSearch percolator index (`banned_content_queries_<env>`) via an `after_commit` hook. A shared `ContentModeration::PercolateScanner` batches unscanned `Message`/`Image` rows (500 at a time), sends them in one `_search` percolate request, and writes flag results back to Postgres with `update_columns`. `ContentModerationSweepJob`, scheduled via `sidekiq-cron`, calls the two scanner wrappers every 5 minutes.

**Tech Stack:** Rails 8.1, RSpec, PostgreSQL (Postgres jsonb columns), `opensearch-ruby`, Sidekiq + `sidekiq-cron`, OpenSearch (Docker for local dev).

Spec this plan implements: `docs/superpowers/specs/2026-07-26-opensearch-content-moderation-design.md`

---

### Task 1: Add gems

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add the gems**

Add these two lines to `Gemfile`, right after the `gem "sidekiq"` line:

```ruby
gem "sidekiq"

# OpenSearch client for content-moderation search
gem "opensearch-ruby"

# Cron-style recurring Sidekiq jobs
gem "sidekiq-cron"
```

- [ ] **Step 2: Install**

Run: `bundle install`
Expected: `Bundle complete!` with `opensearch-ruby` and `sidekiq-cron` (and their dependencies) listed as newly installed.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add opensearch-ruby and sidekiq-cron gems"
```

---

### Task 2: BannedWord model

**Files:**
- Create: `db/migrate/20260726100000_create_banned_words.rb`
- Create: `app/models/banned_word.rb`
- Test: `spec/models/banned_word_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/banned_word_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe BannedWord, type: :model do
  it "is valid with a phrase" do
    expect(BannedWord.new(phrase: "badword")).to be_valid
  end

  it "requires a phrase" do
    expect(BannedWord.new(phrase: nil)).not_to be_valid
  end

  it "is invalid when the phrase is a case-insensitive duplicate" do
    BannedWord.create!(phrase: "badword")
    expect(BannedWord.new(phrase: "BadWord")).not_to be_valid
  end

  it "defaults to active" do
    expect(BannedWord.new(phrase: "badword").active).to eq(true)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/banned_word_spec.rb`
Expected: FAIL with `uninitialized constant BannedWord`

- [ ] **Step 3: Write the migration**

Create `db/migrate/20260726100000_create_banned_words.rb`:

```ruby
class CreateBannedWords < ActiveRecord::Migration[8.1]
  def change
    create_table :banned_words do |t|
      t.string  :phrase, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :banned_words, "lower(phrase)", unique: true, name: "index_banned_words_on_lower_phrase"
  end
end
```

- [ ] **Step 4: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260726100000 CreateBannedWords: migrated`

- [ ] **Step 5: Write the model**

Create `app/models/banned_word.rb`:

```ruby
class BannedWord < ApplicationRecord
  validates :phrase, presence: true, uniqueness: { case_sensitive: false }
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/banned_word_spec.rb`
Expected: PASS (4 examples, 0 failures)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260726100000_create_banned_words.rb db/schema.rb app/models/banned_word.rb spec/models/banned_word_spec.rb
git commit -m "Add BannedWord model"
```

---

### Task 3: Message model

**Files:**
- Create: `db/migrate/20260726100010_create_messages.rb`
- Create: `app/models/message.rb`
- Test: `spec/models/message_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/message_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Message, type: :model do
  it "requires a body" do
    expect(Message.new(body: nil)).not_to be_valid
  end

  it "is not flagged by default" do
    expect(Message.new(body: "hello").flagged).to eq(false)
  end

  it "defaults matched_terms to an empty array" do
    expect(Message.new(body: "hello").matched_terms).to eq([])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/message_spec.rb`
Expected: FAIL with `uninitialized constant Message`

- [ ] **Step 3: Write the migration**

Create `db/migrate/20260726100010_create_messages.rb`:

```ruby
class CreateMessages < ActiveRecord::Migration[8.1]
  def change
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
  end
end
```

- [ ] **Step 4: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260726100010 CreateMessages: migrated`

- [ ] **Step 5: Write the model**

Create `app/models/message.rb`:

```ruby
class Message < ApplicationRecord
  validates :body, presence: true
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/message_spec.rb`
Expected: PASS (3 examples, 0 failures)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260726100010_create_messages.rb db/schema.rb app/models/message.rb spec/models/message_spec.rb
git commit -m "Add Message model"
```

---

### Task 4: Image model

**Files:**
- Create: `db/migrate/20260726100020_create_images.rb`
- Create: `app/models/image.rb`
- Test: `spec/models/image_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/models/image_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Image, type: :model do
  it "is valid with just metadata" do
    expect(Image.new(filename: "meme.png", caption: "a caption", tags: [ "fun" ])).to be_valid
  end

  it "defaults tags to an empty array" do
    expect(Image.new.tags).to eq([])
  end

  it "can have a file attached" do
    expect(Image.new).to respond_to(:file)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/image_spec.rb`
Expected: FAIL with `uninitialized constant Image`

- [ ] **Step 3: Write the migration**

Create `db/migrate/20260726100020_create_images.rb`:

```ruby
class CreateImages < ActiveRecord::Migration[8.1]
  def change
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
  end
end
```

- [ ] **Step 4: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260726100020 CreateImages: migrated`

- [ ] **Step 5: Write the model**

Create `app/models/image.rb`:

```ruby
class Image < ApplicationRecord
  has_one_attached :file
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/image_spec.rb`
Expected: PASS (3 examples, 0 failures)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260726100020_create_images.rb db/schema.rb app/models/image.rb spec/models/image_spec.rb
git commit -m "Add Image model"
```

---

### Task 5: OpenSearch client wrapper

**Files:**
- Create: `app/services/content_moderation/opensearch_client.rb`
- Test: `spec/services/content_moderation/opensearch_client_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/services/content_moderation/opensearch_client_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModeration::OpensearchClient do
  it "memoizes a single OpenSearch::Client instance" do
    expect(described_class.instance).to be_a(OpenSearch::Client)
    expect(described_class.instance).to equal(described_class.instance)
  end

  it "exposes the percolator index name for the current environment" do
    expect(described_class::PERCOLATOR_INDEX).to eq("banned_content_queries_test")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/content_moderation/opensearch_client_spec.rb`
Expected: FAIL with `uninitialized constant ContentModeration`

- [ ] **Step 3: Write the implementation**

Create `app/services/content_moderation/opensearch_client.rb`:

```ruby
module ContentModeration
  class OpensearchClient
    PERCOLATOR_INDEX = "banned_content_queries_#{Rails.env}".freeze

    def self.instance
      @instance ||= OpenSearch::Client.new(
        url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"),
        log: false
      )
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/content_moderation/opensearch_client_spec.rb`
Expected: PASS (2 examples, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/services/content_moderation/opensearch_client.rb spec/services/content_moderation/opensearch_client_spec.rb
git commit -m "Add OpenSearch client wrapper"
```

---

### Task 6: BannedWord search-index sync

**Files:**
- Create: `app/services/content_moderation/banned_word_indexer.rb`
- Modify: `app/models/banned_word.rb`
- Test: `spec/services/content_moderation/banned_word_indexer_spec.rb`
- Test: `spec/models/banned_word_spec.rb`

- [ ] **Step 1: Write the failing indexer test**

Create `spec/services/content_moderation/banned_word_indexer_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModeration::BannedWordIndexer do
  let(:client) { instance_double(OpenSearch::Client, index: nil, delete: nil) }

  it "indexes an active banned word as a percolator query" do
    banned_word = BannedWord.new(id: 42, phrase: "badword", active: true)

    described_class.new(banned_word, client: client).call

    expect(client).to have_received(:index).with(
      index: ContentModeration::OpensearchClient::PERCOLATOR_INDEX,
      id: 42,
      body: { query: { match_phrase: { content: "badword" } }, phrase: "badword" },
      refresh: true
    )
  end

  it "removes the percolator doc when the banned word is inactive" do
    banned_word = BannedWord.new(id: 42, phrase: "badword", active: false)

    described_class.new(banned_word, client: client).call

    expect(client).to have_received(:delete).with(
      index: ContentModeration::OpensearchClient::PERCOLATOR_INDEX,
      id: 42,
      ignore: [ 404 ]
    )
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/content_moderation/banned_word_indexer_spec.rb`
Expected: FAIL with `uninitialized constant ContentModeration::BannedWordIndexer`

- [ ] **Step 3: Write the indexer**

Create `app/services/content_moderation/banned_word_indexer.rb`:

```ruby
module ContentModeration
  class BannedWordIndexer
    def self.call(banned_word, client: OpensearchClient.instance)
      new(banned_word, client: client).call
    end

    def initialize(banned_word, client: OpensearchClient.instance)
      @banned_word = banned_word
      @client = client
    end

    def call
      if @banned_word.destroyed? || !@banned_word.active?
        remove
      else
        upsert
      end
    end

    private

    def upsert
      @client.index(
        index: OpensearchClient::PERCOLATOR_INDEX,
        id: @banned_word.id,
        body: { query: { match_phrase: { content: @banned_word.phrase } }, phrase: @banned_word.phrase },
        refresh: true
      )
    end

    def remove
      @client.delete(index: OpensearchClient::PERCOLATOR_INDEX, id: @banned_word.id, ignore: [ 404 ])
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/content_moderation/banned_word_indexer_spec.rb`
Expected: PASS (2 examples, 0 failures)

- [ ] **Step 5: Write the failing model test for the sync callback**

Add to `spec/models/banned_word_spec.rb` (inside the existing `RSpec.describe BannedWord` block, after the last `it`):

```ruby
  it "syncs to the search index after commit" do
    allow(ContentModeration::BannedWordIndexer).to receive(:call)

    banned_word = BannedWord.create!(phrase: "badword")

    expect(ContentModeration::BannedWordIndexer).to have_received(:call).with(banned_word)
  end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bundle exec rspec spec/models/banned_word_spec.rb`
Expected: FAIL — "syncs to the search index after commit" fails because `ContentModeration::BannedWordIndexer` is never called (BannedWord has no callback yet)

- [ ] **Step 7: Wire up the callback**

Modify `app/models/banned_word.rb`:

```ruby
class BannedWord < ApplicationRecord
  validates :phrase, presence: true, uniqueness: { case_sensitive: false }

  after_commit :sync_search_index

  private

  def sync_search_index
    ContentModeration::BannedWordIndexer.call(self)
  end
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bundle exec rspec spec/models/banned_word_spec.rb`
Expected: PASS (5 examples, 0 failures)

- [ ] **Step 9: Commit**

```bash
git add app/services/content_moderation/banned_word_indexer.rb app/models/banned_word.rb spec/services/content_moderation/banned_word_indexer_spec.rb spec/models/banned_word_spec.rb
git commit -m "Sync BannedWord changes to the OpenSearch percolator index"
```

---

### Task 7: PercolateScanner — the core efficient search function

**Files:**
- Create: `app/services/content_moderation/percolate_scanner.rb`
- Test: `spec/services/content_moderation/percolate_scanner_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/services/content_moderation/percolate_scanner_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModeration::PercolateScanner do
  let(:client) { instance_double(OpenSearch::Client) }

  it "flags records that matched a percolator query and stamps last_scanned_at on all of them" do
    matching = Message.create!(body: "this contains badword")
    clean = Message.create!(body: "this is fine")

    allow(client).to receive(:search).and_return(
      "hits" => { "hits" => [
        { "_source" => { "phrase" => "badword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } }
      ] }
    )

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(matching.reload).to have_attributes(flagged: true, matched_terms: [ "badword" ])
    expect(clean.reload).to have_attributes(flagged: false, matched_terms: [])
    expect(matching.last_scanned_at).to be_present
    expect(clean.last_scanned_at).to be_present
  end

  it "sends one percolate request for the whole batch, not one per record" do
    Message.create!(body: "one")
    Message.create!(body: "two")
    allow(client).to receive(:search).and_return("hits" => { "hits" => [] })

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(client).to have_received(:search).once
  end

  it "does not rescan a record that was already scanned since its last update" do
    Message.create!(body: "old", last_scanned_at: 1.hour.from_now)
    allow(client).to receive(:search).and_return("hits" => { "hits" => [] })

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(client).not_to have_received(:search)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/content_moderation/percolate_scanner_spec.rb`
Expected: FAIL with `uninitialized constant ContentModeration::PercolateScanner`

- [ ] **Step 3: Write the implementation**

Create `app/services/content_moderation/percolate_scanner.rb`:

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
        index: OpensearchClient::PERCOLATOR_INDEX,
        body: {
          query: {
            percolate: {
              field: "query",
              documents: batch.map { |record| { content: @content_builder.call(record) } }
            }
          }
        }
      )
      apply_results(batch, matches_by_slot(response))
    end

    def matches_by_slot(response)
      hits = response.dig("hits", "hits") || []
      result = Hash.new { |hash, key| hash[key] = [] }
      hits.each do |hit|
        phrase = hit.dig("_source", "phrase")
        slots = hit.dig("fields", "_percolator_document_slot") || []
        slots.each { |slot| result[slot] << phrase }
      end
      result
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

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/content_moderation/percolate_scanner_spec.rb`
Expected: PASS (3 examples, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/services/content_moderation/percolate_scanner.rb spec/services/content_moderation/percolate_scanner_spec.rb
git commit -m "Add PercolateScanner for batch content-moderation search"
```

---

### Task 8: MessageScanner and ImageScanner

**Files:**
- Create: `app/services/content_moderation/message_scanner.rb`
- Create: `app/services/content_moderation/image_scanner.rb`
- Test: `spec/services/content_moderation/message_scanner_spec.rb`
- Test: `spec/services/content_moderation/image_scanner_spec.rb`

- [ ] **Step 1: Write the failing test for MessageScanner**

Create `spec/services/content_moderation/message_scanner_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModeration::MessageScanner do
  it "flags a message whose body matches a stored percolator query" do
    client = instance_double(OpenSearch::Client)
    message = Message.create!(body: "you are a badword")
    allow(client).to receive(:search).and_return(
      "hits" => { "hits" => [
        { "_source" => { "phrase" => "badword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } }
      ] }
    )
    allow(ContentModeration::OpensearchClient).to receive(:instance).and_return(client)

    described_class.call

    expect(message.reload).to be_flagged
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/content_moderation/message_scanner_spec.rb`
Expected: FAIL with `uninitialized constant ContentModeration::MessageScanner`

- [ ] **Step 3: Write MessageScanner**

Create `app/services/content_moderation/message_scanner.rb`:

```ruby
module ContentModeration
  class MessageScanner
    def self.call
      PercolateScanner.new(Message) { |message| message.body.to_s }.call
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/content_moderation/message_scanner_spec.rb`
Expected: PASS (1 example, 0 failures)

- [ ] **Step 5: Write the failing test for ImageScanner**

Create `spec/services/content_moderation/image_scanner_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModeration::ImageScanner do
  it "flags an image whose metadata matches a stored percolator query" do
    client = instance_double(OpenSearch::Client)
    image = Image.create!(filename: "meme.png", caption: "totally a badword", tags: [ "fun" ])
    allow(client).to receive(:search).and_return(
      "hits" => { "hits" => [
        { "_source" => { "phrase" => "badword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } }
      ] }
    )
    allow(ContentModeration::OpensearchClient).to receive(:instance).and_return(client)

    described_class.call

    expect(image.reload).to be_flagged
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bundle exec rspec spec/services/content_moderation/image_scanner_spec.rb`
Expected: FAIL with `uninitialized constant ContentModeration::ImageScanner`

- [ ] **Step 7: Write ImageScanner**

Create `app/services/content_moderation/image_scanner.rb`:

```ruby
module ContentModeration
  class ImageScanner
    def self.call
      PercolateScanner.new(Image) { |image| [ image.filename, image.caption, Array(image.tags).join(" ") ].compact.join(" ") }.call
    end
  end
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bundle exec rspec spec/services/content_moderation/image_scanner_spec.rb`
Expected: PASS (1 example, 0 failures)

- [ ] **Step 9: Commit**

```bash
git add app/services/content_moderation/message_scanner.rb app/services/content_moderation/image_scanner.rb spec/services/content_moderation/message_scanner_spec.rb spec/services/content_moderation/image_scanner_spec.rb
git commit -m "Add MessageScanner and ImageScanner"
```

---

### Task 9: BannedWords controller and routes

**Files:**
- Create: `app/controllers/banned_words_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/banned_words_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/banned_words_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "/banned_words", type: :request do
  before do
    allow(ContentModeration::BannedWordIndexer).to receive(:call)
  end

  describe "GET /index" do
    it "returns all banned words" do
      BannedWord.create!(phrase: "badword")
      get banned_words_url
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    it "creates a new banned word" do
      expect {
        post banned_words_url, params: { banned_word: { phrase: "badword" } }
      }.to change(BannedWord, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "rejects a blank phrase" do
      expect {
        post banned_words_url, params: { banned_word: { phrase: "" } }
      }.not_to change(BannedWord, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /update" do
    it "updates the phrase" do
      banned_word = BannedWord.create!(phrase: "badword")
      patch banned_word_url(banned_word), params: { banned_word: { phrase: "worseword" } }
      expect(banned_word.reload.phrase).to eq("worseword")
    end
  end

  describe "DELETE /destroy" do
    it "destroys the banned word" do
      banned_word = BannedWord.create!(phrase: "badword")
      expect {
        delete banned_word_url(banned_word)
      }.to change(BannedWord, :count).by(-1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/banned_words_spec.rb`
Expected: FAIL with a routing error (`undefined method 'banned_words_url'`)

- [ ] **Step 3: Add the route**

Modify `config/routes.rb` — add this line right after `resources :tasks`:

```ruby
  resources :tasks
  resources :banned_words, only: %i[index create update destroy]
```

- [ ] **Step 4: Write the controller**

Create `app/controllers/banned_words_controller.rb`:

```ruby
class BannedWordsController < ApplicationController
  before_action :set_banned_word, only: %i[update destroy]

  def index
    render json: BannedWord.all
  end

  def create
    banned_word = BannedWord.new(banned_word_params)

    if banned_word.save
      render json: banned_word, status: :created
    else
      render json: { errors: banned_word.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @banned_word.update(banned_word_params)
      render json: @banned_word
    else
      render json: { errors: @banned_word.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @banned_word.destroy!
    head :no_content
  end

  private

  def set_banned_word
    @banned_word = BannedWord.find(params.expect(:id))
  end

  def banned_word_params
    params.expect(banned_word: [ :phrase, :active ])
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/banned_words_spec.rb`
Expected: PASS (5 examples, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/banned_words_controller.rb config/routes.rb spec/requests/banned_words_spec.rb
git commit -m "Add BannedWords JSON API"
```

---

### Task 10: Sidekiq sweep job and cron schedule

**Files:**
- Create: `app/jobs/content_moderation_sweep_job.rb`
- Create: `config/schedule.yml`
- Modify: `config/initializers/sidekiq.rb`
- Test: `spec/jobs/content_moderation_sweep_job_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/jobs/content_moderation_sweep_job_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ContentModerationSweepJob, type: :job do
  it "runs the message and image scanners" do
    allow(ContentModeration::MessageScanner).to receive(:call)
    allow(ContentModeration::ImageScanner).to receive(:call)

    described_class.perform_now

    expect(ContentModeration::MessageScanner).to have_received(:call)
    expect(ContentModeration::ImageScanner).to have_received(:call)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/content_moderation_sweep_job_spec.rb`
Expected: FAIL with `uninitialized constant ContentModerationSweepJob`

- [ ] **Step 3: Write the job**

Create `app/jobs/content_moderation_sweep_job.rb`:

```ruby
class ContentModerationSweepJob < ApplicationJob
  queue_as :default

  def perform
    ContentModeration::MessageScanner.call
    ContentModeration::ImageScanner.call
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/jobs/content_moderation_sweep_job_spec.rb`
Expected: PASS (1 example, 0 failures)

- [ ] **Step 5: Add the cron schedule**

Create `config/schedule.yml`:

```yaml
content_moderation_sweep:
  cron: "*/5 * * * *"
  class: "ContentModerationSweepJob"
```

- [ ] **Step 6: Load the schedule on the Sidekiq server**

Modify `config/initializers/sidekiq.rb` to:

```ruby
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  schedule_file = Rails.root.join("config/schedule.yml")
  Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file)) if File.exist?(schedule_file)
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
```

- [ ] **Step 7: Commit**

```bash
git add app/jobs/content_moderation_sweep_job.rb config/schedule.yml config/initializers/sidekiq.rb spec/jobs/content_moderation_sweep_job_spec.rb
git commit -m "Schedule ContentModerationSweepJob every 5 minutes via sidekiq-cron"
```

---

### Task 11: Percolator index setup rake task

**Files:**
- Create: `lib/tasks/content_moderation.rake`

- [ ] **Step 1: Write the rake task**

Create `lib/tasks/content_moderation.rake`:

```ruby
namespace :content_moderation do
  desc "Create the OpenSearch percolator index used for banned-word matching"
  task setup_index: :environment do
    client = ContentModeration::OpensearchClient.instance
    index = ContentModeration::OpensearchClient::PERCOLATOR_INDEX

    if client.indices.exists?(index: index)
      puts "Index #{index} already exists"
    else
      client.indices.create(
        index: index,
        body: {
          mappings: {
            properties: {
              content: { type: "text", analyzer: "standard" },
              query: { type: "percolator" }
            }
          }
        }
      )
      puts "Created index #{index}"
    end
  end
end
```

- [ ] **Step 2: Verify the task loads**

Run: `bin/rails -T content_moderation`
Expected: lists `rails content_moderation:setup_index` with its description

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/content_moderation.rake
git commit -m "Add rake task to create the percolator index"
```

---

### Task 12: Local OpenSearch via Docker Compose + docs

**Files:**
- Create: `docker-compose.yml`
- Modify: `README.md`

- [ ] **Step 1: Add docker-compose.yml**

Create `docker-compose.yml`:

```yaml
services:
  opensearch:
    image: opensearchproject/opensearch:2.19.1
    container_name: opensearch-content-moderation
    environment:
      - discovery.type=single-node
      - plugins.security.disabled=true
      - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
      - "9600:9600"
```

- [ ] **Step 2: Document setup in the README**

Add this section to `README.md`, replacing the "Services (job queues, cache servers, search engines, etc.)" bullet point:

```markdown
## Content moderation search (OpenSearch)

Banned words are matched against `Message` and `Image` content via an
OpenSearch percolator index, scanned periodically by
`ContentModerationSweepJob` (every 5 minutes via `sidekiq-cron`).

1. Start OpenSearch locally: `docker compose up -d opensearch`
2. Set `OPENSEARCH_URL` if not using the default (`http://localhost:9200`)
3. Create the percolator index (once per environment): `bin/rails content_moderation:setup_index`
4. Add banned words via `POST /banned_words` (`{ "banned_word": { "phrase": "..." } }`)
```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml README.md
git commit -m "Add local OpenSearch via Docker Compose and setup docs"
```

---

### Task 13: End-to-end integration spec and full suite verification

**Files:**
- Create: `spec/integration/content_moderation_spec.rb`
- Modify: `spec/rails_helper.rb`

- [ ] **Step 1: Exclude integration specs from the default run**

Modify `spec/rails_helper.rb` — inside the `RSpec.configure do |config|` block, add:

```ruby
  config.filter_run_excluding integration: true
```

- [ ] **Step 2: Write the integration spec**

Create `spec/integration/content_moderation_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Content moderation end-to-end", :integration do
  # Run manually against a real OpenSearch instance:
  #   docker compose up -d opensearch
  #   bin/rails content_moderation:setup_index RAILS_ENV=test
  #   bundle exec rspec spec/integration/content_moderation_spec.rb --tag integration
  it "flags a message containing a real banned word via a real percolate round-trip" do
    banned_word = BannedWord.create!(phrase: "forbiddenphrase")
    sleep 1 # allow the refresh: true index write to settle
    message = Message.create!(body: "this message has a forbiddenphrase in it")

    ContentModeration::MessageScanner.call

    expect(message.reload).to be_flagged
    expect(message.matched_terms).to include(banned_word.phrase)
  end
end
```

- [ ] **Step 3: Run the default suite (integration spec excluded)**

Run: `bundle exec rspec`
Expected: All examples pass; the integration spec is skipped/filtered out; the one pre-existing `tasks/index` scaffold failure noted at worktree setup is the only known failure (unrelated to this feature).

- [ ] **Step 4: Commit**

```bash
git add spec/integration/content_moderation_spec.rb spec/rails_helper.rb
git commit -m "Add end-to-end integration spec for content moderation (excluded by default)"
```

---

## Self-review notes

- **Spec coverage:** every section of the design doc (BannedWord/Message/Image models, OpenSearch client, percolator index + rationale, dictionary sync, PercolateScanner, MessageScanner/ImageScanner, controller, job + cron schedule, rake task, docker-compose, testing strategy including the `:integration` tag) maps to a task above.
- **Type/name consistency checked:** `ContentModeration::OpensearchClient::PERCOLATOR_INDEX`, `ContentModeration::BannedWordIndexer.call`, `ContentModeration::PercolateScanner.new(model_class, client:, &block).call`, `ContentModeration::MessageScanner.call` / `ContentModeration::ImageScanner.call`, `ContentModerationSweepJob` — used identically across all tasks that reference them.
- **Out of scope (per design doc):** image computer-vision classification, an admin UI (views) for banned words, multi-tenant word lists.
