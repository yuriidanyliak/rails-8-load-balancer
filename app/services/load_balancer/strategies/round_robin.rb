class LoadBalancer
  module Strategies
    # Picks the backend with the fewest prior selections. Starting all
    # backends at times_selected=0 and incrementing after each pick
    # reproduces the exact cyclic order (1,2,3,1,2,3,...) — this is
    # classic round-robin, not an approximation, under sequential selection.
    class RoundRobin < Base
      def select(backends)
        backends.min_by { |backend| [ backend.times_selected, backend.id ] }
      end
    end
  end
end
