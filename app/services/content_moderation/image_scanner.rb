module ContentModeration
  class ImageScanner
    def self.call
      PercolateScanner.new(Image) { |image| [ image.filename, image.caption, Array(image.tags).join(" ") ].compact.join(" ") }.call
    end
  end
end
