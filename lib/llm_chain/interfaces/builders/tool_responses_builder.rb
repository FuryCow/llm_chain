# frozen_string_literal: true

module LLMChain
  module Interfaces
    module Builders
      # Abstract interface for building tool responses context in LLMChain.
      # Implementations must provide a method to format tool results for the prompt.
      #
      # @abstract
      class ToolResponses
        # Build the tool responses string for the prompt.
        # @param tool_results [Hash] tool name => result
        # @return [String] formatted tool responses
        def build(tool_results)
          raise NotImplementedError, "Implement in subclass"
        end
      end
    end
  end
end 