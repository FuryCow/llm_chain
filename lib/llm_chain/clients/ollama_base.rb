require 'faraday'
require 'json'

module LLMChain
  module Clients
    class OllamaBase
      DEFAULT_BASE_URL = "http://localhost:11434".freeze
      API_ENDPOINT = "/api/generate".freeze

      def initialize(model:, base_url: nil, default_options: {})
        @base_url = base_url || DEFAULT_BASE_URL
        @model = model
        @default_options = {
          temperature: 0.7,
          top_p: 0.9,
          num_ctx: 2048
        }.merge(default_options)
      end

      def chat(prompt, **options)
        response = connection.post(API_ENDPOINT) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = build_request_body(prompt, options)
        end

        handle_response(response)
      rescue Faraday::Error => e
        handle_error(e)
      end

      protected

      def build_request_body(prompt, options)
        {
          model: @model,
          prompt: prompt,
          stream: false,
          options: @default_options.merge(options)
        }
      end

      private

      def connection
        @connection ||= Faraday.new(url: @base_url) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
          f.options.timeout = 300 # 5 минут для больших моделей
        end
      end

      def handle_response(response)
        if response.success?
          response.body["response"] || raise(LLMChain::Error, "Empty response from Ollama")
        else
          raise LLMChain::Error, "Ollama API error: #{response.body['error'] || response.body}"
        end
      end

      def handle_error(error)
        case error
        when Faraday::ResourceNotFound
          raise LLMChain::Error, <<~ERROR
            Ollama API error (404). Possible reasons:
            1. Model '#{@model}' not found
            2. API endpoint not available
            
            Solutions:
            1. Check available models: `ollama list`
            2. Pull the model: `ollama pull #{@model}`
            3. Verify server: `curl #{@base_url}/api/tags`
          ERROR
        when Faraday::ConnectionFailed
          raise LLMChain::Error, "Cannot connect to Ollama at #{@base_url}"
        when Faraday::TimeoutError
          raise LLMChain::Error, "Ollama request timed out. Try smaller prompt or faster model."
        else
          raise LLMChain::Error, "Ollama communication error: #{error.message}"
        end
      end
    end
  end
end