require 'weaviate'

module LLMChain
  module Embeddings
    module Clients
      module Local
        class WeaviateVectorStore
          def initialize(
            weaviate_url: ENV['WEAVIATE_URL'] || 'http://localhost:8080',
            class_name: 'Document',
            embedder: nil
          )
            @client = Weaviate::Client.new(
              url: weaviate_url,
              model_service: :ollama
            )
            @embedder = embedder || OllamaClient.new
            @class_name = class_name
            create_schema_if_not_exists
          end

          def add_document(text:, metadata: {})
            embedding = @embedder.embed(text)
            
            @client.objects.create(
              class_name: @class_name,
              properties: {
                content: text,
                metadata: metadata.to_json,
                text: text
              },
              vector: embedding
            )
          end

          # Поиск по семантическому сходству
          def semantic_search(query, limit: 3, certainty: 0.7)
            near_vector = "{ vector: #{@embedder.embed(query)}, certainty: #{certainty} }"

            @client.query.get(
                class_name: @class_name,
                fields: "content metadata text",
                limit: limit.to_s,
                offset: "1",
                near_vector: near_vector,
            )
          end

          private

          def create_schema_if_not_exists
            begin
              @client.schema.get(class_name: @class_name)
            rescue Faraday::ResourceNotFound
              @client.schema.create(
                class_name: @class_name,
                properties: [
                  { name: 'content', dataType: ['text'] },
                  { name: 'metadata', dataType: ['text'] }
                ]
              )
            end
          end
        end
      end
    end
  end
end