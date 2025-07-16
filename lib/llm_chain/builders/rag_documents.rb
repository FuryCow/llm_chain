# frozen_string_literal: true

require_relative '../interfaces/builders/rag_documents_builder'

module LLMChain
  module Builders
    # Production implementation of RAG documents builder for LLMChain.
    # Formats retrieved documents for inclusion in the prompt.
    class RagDocuments < Interfaces::Builders::RagDocuments
      # Build the RAG documents string for the prompt.
      # @param rag_documents [Array<Hash>] list of retrieved documents
      # @return [String] formatted RAG context
      def build(rag_documents)
        return "" if rag_documents.nil? || rag_documents.empty?
        parts = ["Relevant documents:"]
        rag_documents.each_with_index do |doc, i|
          parts << "Document #{i + 1}: #{doc['content'] || doc[:content]}"
          meta = doc['metadata'] || doc[:metadata]
          parts << "Metadata: #{meta.to_json}" if meta
        end
        parts.join("\n")
      end
    end
  end
end 