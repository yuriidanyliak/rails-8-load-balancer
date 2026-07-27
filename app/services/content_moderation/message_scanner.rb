module ContentModeration
  class MessageScanner
    def self.call
      PercolateScanner.new(Message) { |message| message.body.to_s }.call
    end
  end
end
