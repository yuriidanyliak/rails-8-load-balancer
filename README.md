# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Content moderation search (OpenSearch)

Banned words are matched against `Message` and `Image` content via an
OpenSearch percolator index, scanned periodically by
`ContentModerationSweepJob` (every 5 minutes via `sidekiq-cron`).

1. Start OpenSearch locally: `docker compose up -d opensearch`
2. Set `OPENSEARCH_URL` if not using the default (`http://localhost:9200`)
3. Create the percolator index (once per environment): `bin/rails content_moderation:setup_index`
4. Add banned words via `POST /banned_words` (`{ "banned_word": { "phrase": "..." } }`)
