require 'rails_helper'

RSpec.describe BannedWord, type: :model do
  it "is valid with a phrase" do
    expect(BannedWord.new(phrase: "badword")).to be_valid
  end

  it "requires a phrase" do
    expect(BannedWord.new(phrase: nil)).not_to be_valid
  end

  it "is invalid when the phrase is a case-insensitive duplicate" do
    allow(ContentModeration::BannedWordIndexer).to receive(:call)

    BannedWord.create!(phrase: "badword")
    expect(BannedWord.new(phrase: "BadWord")).not_to be_valid
  end

  it "defaults to active" do
    expect(BannedWord.new(phrase: "badword").active).to eq(true)
  end

  it "syncs to the search index after commit" do
    allow(ContentModeration::BannedWordIndexer).to receive(:call)

    banned_word = BannedWord.create!(phrase: "badword")

    expect(ContentModeration::BannedWordIndexer).to have_received(:call).with(banned_word)
  end

  it "does not raise if the search index sync fails" do
    allow(ContentModeration::BannedWordIndexer).to receive(:call).and_raise(StandardError, "boom")

    expect { BannedWord.create!(phrase: "badword") }.not_to raise_error
  end
end
