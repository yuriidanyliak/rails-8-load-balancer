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
