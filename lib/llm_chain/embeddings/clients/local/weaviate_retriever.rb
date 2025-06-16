module LLMChain
  module Embeddings
    module Clients
      module Local
        class WeaviateRetriever
          def initialize(embedder: nil)
            @vector_store = WeaviateVectorStore.new(
              embedder: embedder
            )
          end

          def search(query, limit: 3)
            @vector_store.semantic_search(query, limit: limit)
          end
        end
      end
    end
  end
end