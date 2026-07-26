require "rails_helper"

RSpec.describe LoadBalancer do
  describe "#initialize" do
    it "raises UnknownStrategyError for an unrecognized strategy" do
      expect { described_class.new(strategy: :fastest) }
        .to raise_error(described_class::UnknownStrategyError)
    end
  end

  describe "#next_backend" do
    it "raises NoHealthyBackendsError when the pool is empty" do
      lb = described_class.new(strategy: :round_robin, backends: Backend.none)

      expect { lb.next_backend }.to raise_error(described_class::NoHealthyBackendsError)
    end

    it "skips unhealthy backends even if passed in explicitly" do
      healthy = Backend.create!(host: "web-1", healthy: true)
      Backend.create!(host: "web-2", healthy: false)

      lb = described_class.new(strategy: :round_robin, backends: Backend.all)

      expect(lb.next_backend).to eq(healthy)
    end

    it "does not mutate backend state" do
      backend = Backend.create!(host: "web-1")
      lb = described_class.new(strategy: :round_robin, backends: Backend.healthy)

      lb.next_backend

      expect(backend.reload.times_selected).to eq(0)
    end
  end

  describe "round_robin strategy" do
    it "cycles through healthy backends in order of fewest prior selections" do
      a = Backend.create!(host: "a")
      b = Backend.create!(host: "b")
      c = Backend.create!(host: "c")
      lb = described_class.new(strategy: :round_robin)

      picks = 6.times.map { lb.route.host }

      expect(picks).to eq(%w[a b c a b c])
      expect([ a, b, c ].map { |backend| backend.reload.times_selected }).to eq([ 2, 2, 2 ])
    end
  end

  describe "weighted_round_robin strategy" do
    it "picks higher-weight backends proportionally more often" do
      Backend.create!(host: "heavy", weight: 3)
      Backend.create!(host: "light", weight: 1)
      lb = described_class.new(strategy: :weighted_round_robin)

      picks = 8.times.map { lb.route.host }

      expect(picks.count("heavy")).to be > picks.count("light")
    end
  end

  describe "least_connections strategy" do
    it "picks the backend with the fewest active connections" do
      busy = Backend.create!(host: "busy", active_connections: 5)
      idle = Backend.create!(host: "idle", active_connections: 0)
      lb = described_class.new(strategy: :least_connections)

      expect(lb.next_backend).to eq(idle)
    end

    it "reacts to connections being released" do
      a = Backend.create!(host: "a")
      b = Backend.create!(host: "b")
      lb = described_class.new(strategy: :least_connections)

      first_pick = lb.route # acquires whichever of a/b (tie -> lowest id -> a)
      second_pick = lb.route # a now has 1 connection, b has 0 -> picks b
      expect(second_pick).not_to eq(first_pick)

      first_pick.release!
      third_pick = lb.route # a and b now tied at... first_pick back to 0, other at 1 -> picks first_pick again
      expect(third_pick).to eq(first_pick)
    end
  end

  describe "#route" do
    it "acquires the backend and leaves the connection open when no block is given" do
      Backend.create!(host: "web-1")
      lb = described_class.new(strategy: :round_robin)

      backend = lb.route

      expect(backend.reload.active_connections).to eq(1)
    end

    it "acquires then releases automatically when given a block" do
      Backend.create!(host: "web-1")
      lb = described_class.new(strategy: :round_robin)

      result = lb.route { |backend| backend.host.upcase }

      expect(result).to eq("WEB-1")
      expect(Backend.find_by(host: "web-1").active_connections).to eq(0)
    end

    it "still releases when the block raises" do
      Backend.create!(host: "web-1")
      lb = described_class.new(strategy: :round_robin)

      expect { lb.route { raise "boom" } }.to raise_error("boom")
      expect(Backend.find_by(host: "web-1").active_connections).to eq(0)
    end
  end
end
