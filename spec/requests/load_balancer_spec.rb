require "rails_helper"

RSpec.describe "LoadBalancer", type: :request do
  describe "GET /backends" do
    it "returns all backends with their current state" do
      Backend.create!(host: "web-1", weight: 2)

      get "/backends"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first).to include("host" => "web-1", "weight" => 2)
    end
  end

  describe "POST /route" do
    it "acquires and returns a backend, defaulting to round_robin" do
      Backend.create!(host: "web-1")

      post "/route"

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["host"]).to eq("web-1")
      expect(body["active_connections"]).to eq(1)
    end

    it "accepts a strategy param and skips unhealthy backends" do
      Backend.create!(host: "down", healthy: false)
      Backend.create!(host: "up", healthy: true)

      post "/route", params: { strategy: "least_connections" }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["host"]).to eq("up")
    end

    it "returns 422 for an unknown strategy" do
      Backend.create!(host: "web-1")

      post "/route", params: { strategy: "fastest" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 503 when there are no healthy backends" do
      Backend.create!(host: "web-1", healthy: false)

      post "/route"

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe "DELETE /route" do
    it "releases a connection on the given backend" do
      backend = Backend.create!(host: "web-1", active_connections: 1)

      delete "/route", params: { host: "web-1" }

      expect(response).to have_http_status(:ok)
      expect(backend.reload.active_connections).to eq(0)
    end

    it "returns a JSON 404 for an unknown host" do
      delete "/route", params: { host: "does-not-exist" }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to have_key("error")
    end
  end
end
