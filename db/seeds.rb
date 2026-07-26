# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

[
  { host: "web-1", weight: 5, healthy: true },
  { host: "web-2", weight: 3, healthy: true },
  { host: "web-3", weight: 1, healthy: true },
  { host: "web-4", weight: 1, healthy: false }
].each do |attrs|
  Backend.find_or_create_by!(host: attrs[:host]) do |backend|
    backend.weight = attrs[:weight]
    backend.healthy = attrs[:healthy]
  end
end
