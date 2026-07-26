require 'rails_helper'

RSpec.describe ContentModeration::OpensearchClient do
  it "memoizes a single OpenSearch::Client instance" do
    expect(described_class.instance).to be_a(OpenSearch::Client)
    expect(described_class.instance).to equal(described_class.instance)
  end

  it "exposes the percolator index name for the current environment" do
    expect(described_class::PERCOLATOR_INDEX).to eq("banned_content_queries_test")
  end
end
