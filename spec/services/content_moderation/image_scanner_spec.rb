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
