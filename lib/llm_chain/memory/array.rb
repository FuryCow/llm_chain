module LLMChain
  module Memory
    class Array
      def initialize
        @storage = []
      end

      def store(prompt, response)
        @storage << { prompt => response }
      end

      def recall(prompt)
        @storage.reverse.find { |item| item.key?(prompt) }&.values&.first
      end
    end
  end
end