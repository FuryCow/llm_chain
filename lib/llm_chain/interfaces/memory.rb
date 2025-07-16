# frozen_string_literal: true

module LLMChain
  module Interfaces
    # Abstract interface for memory adapters in LLMChain.
    # Implementations must provide methods for storing and recalling conversation history.
    #
    # @abstract
    class Memory
      # Store a prompt/response pair in memory.
      # @param prompt [String]
      # @param response [String]
      # @return [void]
      def store(prompt, response)
        raise NotImplementedError, "Implement in subclass"
      end

      # Recall conversation history (optionally filtered by prompt).
      # @param prompt [String, nil]
      # @return [Array<Hash>] [{ prompt: ..., response: ... }, ...]
      def recall(prompt = nil)
        raise NotImplementedError, "Implement in subclass"
      end

      # Clear all memory.
      # @return [void]
      def clear
        raise NotImplementedError, "Implement in subclass"
      end

      # Return number of stored items.
      # @return [Integer]
      def size
        raise NotImplementedError, "Implement in subclass"
      end
    end
  end
end 