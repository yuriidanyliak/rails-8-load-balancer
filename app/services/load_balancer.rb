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

  # Pure selection: does not mutate any backend's state. Not locked by
  # default -- safe to call standalone outside a transaction, but that also
  # means two concurrent callers can read the same snapshot. #route uses
  # lock: true internally to close that race; see there for why.
  def next_backend(lock: false)
    scope = lock ? @backends.lock : @backends
    healthy_backends = scope.select(&:healthy?)
    raise NoHealthyBackendsError, "no healthy backends available" if healthy_backends.empty?

    @strategy.select(healthy_backends)
  end

  # Selects and acquires a backend. Selection + acquisition run inside a
  # transaction with the healthy candidates row-locked (SELECT ... FOR
  # UPDATE), so concurrent callers can't both read the same stale counters
  # and pick the same backend -- without this, two requests hitting /route
  # at once (this app's Puma runs multi-threaded) could both see "0 active
  # connections" and both choose the same backend, defeating the point of
  # a load balancer. Each route call is serialized against the others
  # instead. The transaction also makes acquire!'s two increments atomic
  # as a pair.
  #
  # With a block, the connection is automatically released after the block
  # runs (self-contained one-shot, handy in specs). Without a block, the
  # caller owns the connection's lifecycle and must release! it explicitly
  # (used by the controller, so least-connections stays observable across
  # separate requests).
  def route
    backend = Backend.transaction do
      chosen = next_backend(lock: true)
      chosen.acquire!
      chosen
    end
    return backend unless block_given?

    begin
      yield backend
    ensure
      backend.release!
    end
  end
end
