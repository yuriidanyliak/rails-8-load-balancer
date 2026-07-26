require 'rails_helper'

RSpec.describe ContentModeration::BannedWordIndexer do
  let(:client) { instance_double(OpenSearch::Client, index: nil, delete: nil) }

  it "indexes an active banned word as a percolator query" do
    banned_word = BannedWord.new(id: 42, phrase: "badword", active: true)

    described_class.new(banned_word, client: client).call

    expect(client).to have_received(:index).with(
      index: ContentModeration::OpensearchClient::PERCOLATOR_INDEX,
      id: 42,
      body: { query: { match_phrase: { content: "badword" } }, phrase: "badword" },
      refresh: true
    )
  end

  it "removes the percolator doc when the banned word is inactive" do
    banned_word = BannedWord.new(id: 42, phrase: "badword", active: false)

    described_class.new(banned_word, client: client).call

    expect(client).to have_received(:delete).with(
      index: ContentModeration::OpensearchClient::PERCOLATOR_INDEX,
      id: 42,
      ignore: [ 404 ]
    )
  end
end
