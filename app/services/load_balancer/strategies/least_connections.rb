class LoadBalancer
  module Strategies
    class LeastConnections < Base
      def select(backends)
        backends.min_by { |backend| [ backend.active_connections, backend.id ] }
      end
    end
  end
end
