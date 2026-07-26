require "rails_helper"

RSpec.describe Backend, type: :model do
  describe "validations" do
    it "requires a host" do
      backend = Backend.new(host: nil)
      expect(backend).not_to be_valid
      expect(backend.errors[:host]).to be_present
    end

    it "requires a unique host" do
      Backend.create!(host: "web-1")
      duplicate = Backend.new(host: "web-1")
      expect(duplicate).not_to be_valid
    end

    it "requires a positive weight" do
      backend = Backend.new(host: "web-1", weight: 0)
      expect(backend).not_to be_valid
    end
  end

  describe "defaults" do
    it "defaults weight to 1, healthy to true, and counters to 0" do
      backend = Backend.create!(host: "web-1")
      expect(backend.weight).to eq(1)
      expect(backend.healthy).to eq(true)
      expect(backend.active_connections).to eq(0)
      expect(backend.times_selected).to eq(0)
    end
  end

  describe ".healthy" do
    it "only returns backends marked healthy" do
      healthy = Backend.create!(host: "web-1", healthy: true)
      Backend.create!(host: "web-2", healthy: false)

      expect(Backend.healthy).to contain_exactly(healthy)
    end
  end

  describe "#acquire!" do
    it "increments times_selected and active_connections" do
      backend = Backend.create!(host: "web-1")

      expect { backend.acquire! }
        .to change { backend.reload.times_selected }.by(1)
        .and change { backend.reload.active_connections }.by(1)
    end
  end

  describe "#release!" do
    it "decrements active_connections" do
      backend = Backend.create!(host: "web-1", active_connections: 2)

      expect { backend.release! }.to change { backend.reload.active_connections }.by(-1)
    end

    it "does not go below zero" do
      backend = Backend.create!(host: "web-1", active_connections: 0)

      expect { backend.release! }.not_to(change { backend.reload.active_connections })
    end
  end

  describe "#mark_unhealthy! and #mark_healthy!" do
    it "toggles the healthy flag" do
      backend = Backend.create!(host: "web-1", healthy: true)

      backend.mark_unhealthy!
      expect(backend.reload.healthy).to eq(false)

      backend.mark_healthy!
      expect(backend.reload.healthy).to eq(true)
    end
  end
end
