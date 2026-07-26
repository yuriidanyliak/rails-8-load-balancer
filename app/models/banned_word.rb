class BannedWord < ApplicationRecord
  validates :phrase, presence: true, uniqueness: { case_sensitive: false }

  after_commit :sync_search_index

  private

  def sync_search_index
    ContentModeration::BannedWordIndexer.call(self)
  rescue StandardError => e
    Rails.logger.error("[BannedWord##{id}] failed to sync OpenSearch index: #{e.class}: #{e.message}")
  end
end
