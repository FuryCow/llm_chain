# frozen_string_literal: true

require_relative '../interfaces/builders/retriever_context_builder'

module LLMChain
  module Builders
    # Production implementation of retriever context builder for LLMChain.
    # Retrieves and formats RAG context documents.
    class RetrieverContext < Interfaces::Builders::RetrieverContext
      # Retrieve and format RAG context documents.
      # @param retriever [Object] retriever instance (must respond to #search)
      # @param query [String] user query
      # @param options [Hash]
      # @return [Array<Hash>] list of retrieved documents
      def retrieve(retriever, query, options = {})
        return [] unless retriever && retriever.respond_to?(:search)
        limit = options[:limit] || 3
        retriever.search(query, limit: limit)
      rescue => e
        warn "[RetrieverContext] Error retrieving context: #{e.message}"
        []
      end
    end
  end
end 