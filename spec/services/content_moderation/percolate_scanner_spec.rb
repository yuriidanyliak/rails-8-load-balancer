require 'rails_helper'

RSpec.describe ContentModeration::PercolateScanner do
  let(:client) { instance_double(OpenSearch::Client) }

  it "flags records that matched a percolator query and stamps last_scanned_at on all of them" do
    matching = Message.create!(body: "this contains badword")
    clean = Message.create!(body: "this is fine")

    allow(client).to receive(:search).and_return(
      "hits" => { "hits" => [
        { "_source" => { "phrase" => "badword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } }
      ] }
    )

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(matching.reload).to have_attributes(flagged: true, matched_terms: [ "badword" ])
    expect(clean.reload).to have_attributes(flagged: false, matched_terms: [])
    expect(matching.last_scanned_at).to be_present
    expect(clean.last_scanned_at).to be_present
  end

  it "sends one percolate request for the whole batch, not one per record" do
    Message.create!(body: "one")
    Message.create!(body: "two")
    allow(client).to receive(:search).and_return("hits" => { "hits" => [] })

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(client).to have_received(:search).once
  end

  it "does not rescan a record that was already scanned since its last update" do
    Message.create!(body: "old", last_scanned_at: 1.hour.from_now)
    allow(client).to receive(:search).and_return("hits" => { "hits" => [] })

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(client).not_to have_received(:search)
  end

  it "collects matched_terms from multiple banned-word hits on the same record" do
    message = Message.create!(body: "this contains both badword and worseword")

    allow(client).to receive(:search).and_return(
      "hits" => { "hits" => [
        { "_source" => { "phrase" => "badword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } },
        { "_source" => { "phrase" => "worseword" }, "fields" => { "_percolator_document_slot" => [ 0 ] } }
      ] }
    )

    described_class.new(Message, client: client) { |m| m.body }.call

    expect(message.reload.matched_terms).to contain_exactly("badword", "worseword")
  end
end
