# frozen_string_literal: true

module LLMChain
  module Interfaces
    module Builders
      # Abstract interface for building memory context in LLMChain.
      # Implementations must provide a method to format conversation history for the prompt.
      #
      # @abstract
      class MemoryContext
        # Build the memory context string for the prompt.
        # @param memory_history [Array<Hash>] conversation history
        # @return [String] formatted memory context
        def build(memory_history)
          raise NotImplementedError, "Implement in subclass"
        end
      end
    end
  end
end 