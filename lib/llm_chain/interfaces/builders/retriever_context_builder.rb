# frozen_string_literal: true

module LLMChain
  module Interfaces
    module Builders
      # Abstract interface for retrieving and formatting RAG context in LLMChain.
      # Implementations must provide a method to retrieve and format context documents.
      #
      # @abstract
      class RetrieverContext
        # Retrieve and format RAG context documents.
        # @param retriever [Object] retriever instance
        # @param query [String] user query
        # @param options [Hash]
        # @return [Array<Hash>] list of retrieved documents
        def retrieve(retriever, query, options = {})
          raise NotImplementedError, "Implement in subclass"
        end
      end
    end
  end
end 