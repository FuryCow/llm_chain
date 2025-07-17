require 'faraday'
require 'json'

module LLMChain
  module Clients
    class OpenAI < Base
      BASE_URL = "https://api.openai.com/v1".freeze
      DEFAULT_MODEL = "gpt-3.5-turbo".freeze
      DEFAULT_OPTIONS = {
        temperature: 0.7,
        max_tokens: 1000,
        top_p: 1.0,
        frequency_penalty: 0,
        presence_penalty: 0
      }.freeze

      def initialize(api_key: nil, model: nil, organization_id: nil, **options)
        @api_key = api_key || ENV.fetch('OPENAI_API_KEY') { raise LLMChain::Error, "OPENAI_API_KEY is required" }
        @model = model || DEFAULT_MODEL
        @organization_id = organization_id || ENV['OPENAI_ORGANIZATION_ID']
        @default_options = DEFAULT_OPTIONS.merge(options)
      end

      def chat(messages, stream: false, **options, &block)
        params = build_request_params(messages, stream: stream, **options)

        if stream
          stream_chat(params, &block)
        else
          response = connection.post("chat/completions") do |req|
            req.headers = headers
            req.body = params.to_json
          end
          handle_response(response)
        end
      rescue Faraday::Error => e
        raise LLMChain::Error, "OpenAI API request failed: #{e.message}"
      end

      def stream_chat(params, &block)
        buffer = ""
        connection.post("chat/completions") do |req|
          req.headers = headers
          req.body = params.to_json
          
          req.options.on_data = Proc.new do |chunk, _bytes, _env|
            processed = process_stream_chunk(chunk)
            next unless processed
            
            buffer << processed
            block.call(processed) if block_given?
          end
        end
        buffer
      end

      private

      def build_request_params(messages, stream: false, **options)
        {
          model: @model,
          messages: prepare_messages(messages),
          stream: stream,
          **@default_options.merge(options)
        }.compact
      end

      def prepare_messages(input)
        case input
        when String then [{ role: "user", content: input }]
        when Array then input
        else raise ArgumentError, "Messages should be String or Array"
        end
      end

      def process_stream_chunk(chunk)
        return if chunk.strip.empty?
        
        data = JSON.parse(chunk.gsub(/^data: /, ''))
        data.dig("choices", 0, "delta", "content").to_s
      rescue JSON::ParserError
        nil
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@api_key}",
          'OpenAI-Organization' => @organization_id.to_s
        }.compact
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |f|
          f.request :json
          f.response :raise_error
          f.adapter :net_http
        end
      end

      def handle_response(response)
        data = JSON.parse(response.body)
        content = data.dig("choices", 0, "message", "content")
        
        content || raise(LLMChain::Error, "Unexpected API response: #{data.to_json}")
      end
    end
  end
end