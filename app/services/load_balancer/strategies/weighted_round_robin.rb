class LoadBalancer
  module Strategies
    # Picks the backend minimizing times_selected/weight, so higher-weight
    # backends accumulate selections proportionally faster. A ratio-based
    # simplification of smooth weighted round-robin (e.g. nginx's algorithm) —
    # converges to the same proportional distribution over many picks.
    class WeightedRoundRobin < Base
      def select(backends)
        backends.min_by { |backend| [ backend.times_selected.to_f / backend.weight, backend.id ] }
      end
    end
  end
end
