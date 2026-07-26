class LoadBalancer
  class UnknownStrategyError < StandardError; end
  class NoHealthyBackendsError < StandardError; end

  STRATEGIES = {
    round_robin: Strategies::RoundRobin,
    weighted_round_robin: Strategies::WeightedRoundRobin,
    least_connections: Strategies::LeastConnections
  }.freeze

  def initialize(strategy: :round_robin, backends: Backend.healthy)
    @strategy = STRATEGIES.fetch(strategy.to_sym) {
      raise UnknownStrategyError, "unknown strategy: #{strategy.inspect}"
    }.new
    @backends = backends
  end

  # Pure selection: does not mutate any backend's state.
  def next_backend
    healthy_backends = @backends.select(&:healthy?)
    raise NoHealthyBackendsError, "no healthy backends available" if healthy_backends.empty?

    @strategy.select(healthy_backends)
  end

  # Selects and acquires a backend. With a block, the connection is
  # automatically released after the block runs (self-contained one-shot,
  # handy in specs). Without a block, the caller owns the connection's
  # lifecycle and must release! it explicitly (used by the controller, so
  # least-connections stays observable across separate requests).
  def route
    backend = next_backend
    backend.acquire!
    return backend unless block_given?

    begin
      yield backend
    ensure
      backend.release!
    end
  end
end
