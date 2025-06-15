require 'faraday'
require 'json'

module LLMChain
  module Clients
    class OpenAI < Base
      BASE_URL = "https://api.openai.com/v1".freeze
      DEFAULT_MODEL = "gpt-3.5-turbo".freeze

      def initialize(api_key: nil, model: nil, organization_id: nil)
        @api_key = api_key || ENV.fetch('OPENAI_API_KEY') { raise "OPENAI_API_KEY is required" }
        @model = model || DEFAULT_MODEL
        @organization_id = organization_id || ENV['OPENAI_ORGANIZATION_ID']
      end

      def chat(prompt, temperature: 0.7, max_tokens: 1000)
        response = connection.post("chat/completions") do |req|
          req.headers = headers
          req.body = {
            model: @model,
            messages: [{ role: "user", content: prompt }],
            temperature: temperature,
            max_tokens: max_tokens
          }.to_json
        end

        handle_response(response)
      rescue Faraday::Error => e
        raise LLMChain::Error, "OpenAI API request failed: #{e.message}"
      end

      private

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@api_key}",
          'OpenAI-Organization' => @organization_id.to_s
        }.compact
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |f|
          f.adapter :net_http
        end
      end

      def handle_response(response)
        data = JSON.parse(response.body)
        data.dig("choices", 0, "message", "content") || 
          raise(LLMChain::Error, "Unexpected API response: #{data}")
      end
    end
  end
end