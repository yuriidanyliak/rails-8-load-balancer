namespace :content_moderation do
  desc "Create the OpenSearch percolator index used for banned-word matching"
  task setup_index: :environment do
    client = ContentModeration::OpensearchClient.instance
    index = ContentModeration::OpensearchClient::PERCOLATOR_INDEX

    if client.indices.exists?(index: index)
      puts "Index #{index} already exists"
    else
      client.indices.create(
        index: index,
        body: {
          mappings: {
            properties: {
              content: { type: "text", analyzer: "standard" },
              query: { type: "percolator" }
            }
          }
        }
      )
      puts "Created index #{index}"
    end
  end
end
