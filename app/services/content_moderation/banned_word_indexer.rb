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
      # `phrase` is duplicated here (outside `query`) so scan results can read back
      # which phrase matched without a round-trip to Postgres.
      @client.index(
        index: OpensearchClient::PERCOLATOR_INDEX,
        id: @banned_word.id,
        body: { query: { match_phrase: { content: @banned_word.phrase } }, phrase: @banned_word.phrase },
        refresh: true
      )
    end

    def remove
      @client.delete(index: OpensearchClient::PERCOLATOR_INDEX, id: @banned_word.id, ignore: [ 404 ], refresh: true)
    end
  end
end
