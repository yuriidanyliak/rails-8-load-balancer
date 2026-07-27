class ContentModerationSweepJob < ApplicationJob
  queue_as :default

  def perform
    ContentModeration::MessageScanner.call
    ContentModeration::ImageScanner.call
  end
end
