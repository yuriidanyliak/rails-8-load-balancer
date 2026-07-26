require 'rails_helper'

RSpec.describe BannedWord, type: :model do
  it "is valid with a phrase" do
    expect(BannedWord.new(phrase: "badword")).to be_valid
  end

  it "requires a phrase" do
    expect(BannedWord.new(phrase: nil)).not_to be_valid
  end

  it "is invalid when the phrase is a case-insensitive duplicate" do
    BannedWord.create!(phrase: "badword")
    expect(BannedWord.new(phrase: "BadWord")).not_to be_valid
  end

  it "defaults to active" do
    expect(BannedWord.new(phrase: "badword").active).to eq(true)
  end
end
