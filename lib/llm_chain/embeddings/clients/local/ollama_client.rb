require 'net/http'
require 'json'

module LLMChain
  module Embeddings
    module Clients
      module Local
        class OllamaClient
          DEFAULT_MODEL = "nomic-embed-text"
          OLLAMA_API_URL = "http://localhost:11434"

          def initialize(model: DEFAULT_MODEL, ollama_url: nil)
            @model = model
            @ollama_url = (ollama_url || OLLAMA_API_URL) + "/api/embeddings"
          end

          # Генерация эмбеддинга для текста
          def embed(text)
            response = send_ollama_request(text)
            validate_response(response)
            parse_response(response)
          rescue => e
            raise EmbeddingError, "Failed to generate embedding: #{e.message}"
          end

          # Пакетная обработка
          def embed_batch(texts, batch_size: 5)
            texts.each_slice(batch_size).flat_map do |batch|
              batch.map { |text| embed(text) }
            end
          end

          private

          def send_ollama_request(text)
            uri = URI(@ollama_url)
            http = Net::HTTP.new(uri.host, uri.port)
            request = Net::HTTP::Post.new(uri)
            request['Content-Type'] = 'application/json'
            request.body = {
              model: @model,
              prompt: text
            }.to_json

            http.request(request)
          end

          def validate_response(response)
            unless response.is_a?(Net::HTTPSuccess)
              error = JSON.parse(response.body) rescue {}
              raise EmbeddingError, "API error: #{response.code} - #{error['error'] || response.message}"
            end
          end

          def parse_response(response)
            data = JSON.parse(response.body)
            data['embedding'] or raise EmbeddingError, "No embedding in response"
          rescue JSON::ParserError => e
            raise EmbeddingError, "Invalid JSON: #{e.message}"
          end

          class EmbeddingError < StandardError; end
        end
      end
    end
  end
end