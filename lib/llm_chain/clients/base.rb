module LLMChain
  module Clients
    class Base
      def initialize(model)
        @model = model
      end

      def chat(_prompt)
        raise NotImplementedError
      end

      def stream_chat(_prompt)
        raise NotImplementedError
      end
    end
  end
end