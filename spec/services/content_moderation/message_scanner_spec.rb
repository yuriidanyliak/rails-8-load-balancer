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
