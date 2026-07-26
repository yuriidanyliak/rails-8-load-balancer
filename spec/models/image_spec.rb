require 'rails_helper'

RSpec.describe Image, type: :model do
  it "is valid with just metadata" do
    expect(Image.new(filename: "meme.png", caption: "a caption", tags: [ "fun" ])).to be_valid
  end

  it "defaults tags to an empty array" do
    expect(Image.new.tags).to eq([])
  end

  it "can have a file attached" do
    expect(Image.new).to respond_to(:file)
  end
end
