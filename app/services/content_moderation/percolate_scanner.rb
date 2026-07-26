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
