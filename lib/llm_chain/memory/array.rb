# frozen_string_literal: true

require_relative '../interfaces/memory'

module LLMChain
  module Memory
    # In-memory array-based memory adapter for LLMChain.
    # Stores conversation history in a simple Ruby array.
    class Array < Interfaces::Memory
      def initialize(max_size: 10)
        @storage = []
        @max_size = max_size
      end

      # Store a prompt/response pair in memory.
      # @param prompt [String]
      # @param response [String]
      # @return [void]
      def store(prompt, response)
        @storage << { prompt: prompt, response: response }
        @storage.shift if @storage.size > @max_size
      end

      # Recall conversation history (optionally filtered by prompt).
      # @param prompt [String, nil]
      # @return [Array<Hash>]
      def recall(_ = nil)
        @storage.dup
      end

      # Clear all memory.
      # @return [void]
      def clear
        @storage.clear
      end

      # Return number of stored items.
      # @return [Integer]
      def size
        @storage.size
      end
    end
  end
end