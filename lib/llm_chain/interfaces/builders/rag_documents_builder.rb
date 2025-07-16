# frozen_string_literal: true

module LLMChain
  module Interfaces
    module Builders
      # Abstract interface for building RAG documents context in LLMChain.
      # Implementations must provide a method to format retrieved documents for the prompt.
      #
      # @abstract
      class RagDocuments
        # Build the RAG documents string for the prompt.
        # @param rag_documents [Array<Hash>] list of retrieved documents
        # @return [String] formatted RAG context
        def build(rag_documents)
          raise NotImplementedError, "Implement in subclass"
        end
      end
    end
  end
end 