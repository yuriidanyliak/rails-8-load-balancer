class LoadBalancer
  module Strategies
    class Base
      # backends: an Enumerable of healthy Backend records. Returns one Backend.
      def select(backends)
        raise NotImplementedError
      end
    end
  end
end
