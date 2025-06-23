require 'faraday'
require 'json'

module LLMChain
  module Clients
    class Gemma3 < OllamaBase
      # Доступные версии моделей Gemma3
      MODEL_VERSIONS = {
        gemma3: {
          default: "gemma3:2b",
          versions: [
            "gemma3:2b", "gemma3:8b", "gemma3:27b",
            "gemma3:2b-instruct", "gemma3:8b-instruct", "gemma3:27b-instruct", "gemma3:4b"
          ]
        }
      }.freeze

      # Общие настройки по умолчанию для Gemma3
      COMMON_DEFAULT_OPTIONS = {
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
        num_ctx: 8192
      }.freeze

      # Специфичные настройки для разных версий
      VERSION_SPECIFIC_OPTIONS = {
        gemma3: {
          stop: ["<|im_end|>", "<|endoftext|>", "<|user|>", "<|assistant|>"]
        }
      }.freeze

      # Внутренние теги для очистки ответов
      INTERNAL_TAGS = {
        common: {
          think: /<think>.*?<\/think>\s*/mi,
          reasoning: /<reasoning>.*?<\/reasoning>\s*/mi
        },
        gemma3: {
          system: /<\|system\|>.*?<\|im_end\|>\s*/mi,
          user: /<\|user\|>.*?<\|im_end\|>\s*/mi,
          assistant: /<\|assistant\|>.*?<\|im_end\|>\s*/mi
        }
      }.freeze

      def initialize(model: nil, base_url: nil, **options)
        model ||= detect_default_model

        @model = model
        validate_model_version(@model)

        super(
          model: @model,
          base_url: base_url,
          default_options: default_options_for(@model).merge(options)
        )
      end

      def chat(prompt, show_internal: false, stream: false, **options, &block)
        if stream
          stream_chat(prompt, show_internal: show_internal, **options, &block)
        else
          response = super(prompt, **options)
          process_response(response, show_internal: show_internal)
        end
      end

      def stream_chat(prompt, show_internal: false, **options, &block)
        buffer = ""
        connection.post(API_ENDPOINT) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = build_request_body(prompt, options.merge(stream: true))
          
          req.options.on_data = Proc.new do |chunk, _bytes, _env|
            processed = process_stream_chunk(chunk)
            next unless processed

            buffer << processed
            block.call(processed) if block_given?
          end
        end

        process_response(buffer, show_internal: show_internal)
      end

      protected

      def build_request_body(prompt, options)
        body = super
        version_specific_options = VERSION_SPECIFIC_OPTIONS[model_version]
        body[:options].merge!(version_specific_options) if version_specific_options
        body
      end

      private

      def model_version
        :gemma3
      end

      def detect_default_model
        MODEL_VERSIONS[model_version][:default]
      end

      def validate_model_version(model)
        valid_models = MODEL_VERSIONS.values.flat_map { |v| v[:versions] }
        unless valid_models.include?(model)
          raise InvalidModelVersion, "Invalid Gemma3 model version. Available: #{valid_models.join(', ')}"
        end
      end

      def default_options_for(model)
        COMMON_DEFAULT_OPTIONS.merge(
          VERSION_SPECIFIC_OPTIONS[model_version] || {}
        )
      end

      def process_stream_chunk(chunk)
        parsed = JSON.parse(chunk)
        parsed["response"] if parsed.is_a?(Hash) && parsed["response"]
      rescue JSON::ParserError
        nil
      end

      def process_response(response, show_internal: false)
        return response unless response.is_a?(String)
        
        if show_internal
          response
        else
          clean_response(response)
        end
      end

      def clean_response(text)
        tags = INTERNAL_TAGS[:common].merge(INTERNAL_TAGS[model_version] || {})
        tags.values.reduce(text) do |processed, regex|
          processed.gsub(regex, '')
        end.gsub(/\n{3,}/, "\n\n").strip
      end
    end
  end
end 