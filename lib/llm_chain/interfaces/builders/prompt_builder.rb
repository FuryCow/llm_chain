# frozen_string_literal: true

module LLMChain
  module Interfaces
    module Builders
      # Abstract interface for prompt building in LLMChain.
      # Implementations must provide a method to assemble the final prompt for the LLM.
      #
      # @abstract
      class Prompt
        # Build the final prompt for the LLM.
        # @param memory_context [String]
        # @param tool_responses [String]
        # @param rag_documents [String]
        # @param prompt [String]
        # @return [String] final prompt for LLM
        def build(memory_context:, tool_responses:, rag_documents:, prompt:)
          raise NotImplementedError, "Implement in subclass"
        end
      end
    end
  end
end 