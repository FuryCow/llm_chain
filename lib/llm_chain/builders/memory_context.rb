# frozen_string_literal: true

require_relative '../interfaces/builders/memory_context_builder'

module LLMChain
  module Builders
    # Production implementation of memory context builder for LLMChain.
    # Formats conversation history for inclusion in the prompt.
    class MemoryContext < Interfaces::Builders::MemoryContext
      # Build the memory context string for the prompt.
      # @param memory_history [Array<Hash>] conversation history
      # @return [String] formatted memory context
      def build(memory_history)
        return "" if memory_history.nil? || memory_history.empty?
        parts = ["Dialogue history:"]
        memory_history.each do |item|
          parts << "User: #{item[:prompt]}"
          parts << "Assistant: #{item[:response]}"
        end
        parts.join("\n")
      end
    end
  end
end 