module LLMChain
  module Memory
    class Array
      def initialize(max_size: 10)
        @storage = []
        @max_size = max_size
      end

      def store(prompt, response)
        @storage << { prompt: prompt, response: response }
        @storage.shift if @storage.size > @max_size
      end

      def recall(_ = nil)
        @storage.dup
      end

      def clear
        @storage.clear
      end

      def size
        @storage.size
      end
    end
  end
end