require 'rails_helper'

RSpec.describe Message, type: :model do
  it "requires a body" do
    expect(Message.new(body: nil)).not_to be_valid
  end

  it "is not flagged by default" do
    expect(Message.new(body: "hello").flagged).to eq(false)
  end

  it "defaults matched_terms to an empty array" do
    expect(Message.new(body: "hello").matched_terms).to eq([])
  end
end
