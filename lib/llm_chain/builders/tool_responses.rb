# frozen_string_literal: true

require_relative '../interfaces/builders/tool_responses_builder'

module LLMChain
  module Builders
    # Production implementation of tool responses builder for LLMChain.
    # Formats tool results for inclusion in the prompt.
    class ToolResponses < Interfaces::Builders::ToolResponses
      # Build the tool responses string for the prompt.
      # @param tool_results [Hash] tool name => result
      # @return [String] formatted tool responses
      def build(tool_results)
        return "" if tool_results.nil? || tool_results.empty?
        parts = ["Tool results:"]
        tool_results.each do |name, response|
          if response.is_a?(Hash) && response[:formatted]
            parts << "#{name}: #{response[:formatted]}"
          else
            parts << "#{name}: #{response}"
          end
        end
        parts.join("\n")
      end
    end
  end
end 