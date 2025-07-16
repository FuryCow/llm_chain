# frozen_string_literal: true

require_relative '../interfaces/builders/prompt_builder'

module LLMChain
  module Builders
    # Production implementation of prompt builder for LLMChain.
    # Assembles the final prompt from memory, tools, RAG, and user prompt.
    class Prompt < Interfaces::Builders::Prompt
      # Build the final prompt for the LLM.
      # @param memory_context [String]
      # @param tool_responses [String]
      # @param rag_documents [String]
      # @param prompt [String]
      # @return [String] final prompt for LLM
      def build(memory_context:, tool_responses:, rag_documents:, prompt:)
        parts = []
        parts << memory_context if memory_context && !memory_context.empty?
        parts << rag_documents if rag_documents && !rag_documents.empty?
        parts << tool_responses if tool_responses && !tool_responses.empty?
        parts << "Current question: #{prompt}"
        parts.join("\n\n")
      end
    end
  end
end 