require 'faraday'
require 'json'

module LLMChain
  module Clients
    class Qwen < OllamaBase
      # Доступные версии моделей
      MODEL_VERSIONS = {
        qwen: {
          default: "qwen:7b",
          versions: ["qwen:7b", "qwen:14b", "qwen:72b", "qwen:0.5b"]
        },
        qwen2: {
          default: "qwen2:1.5b",
          versions: [
            "qwen2:0.5b", "qwen2:1.5b", "qwen2:7b", "qwen2:72b"
          ]
        },
        qwen3: {
          default: "qwen3:latest",
          versions: [
            "qwen3:latest", "qwen3:0.6b", "qwen3:1.7b", "qwen3:4b",
            "qwen3:8b", "qwen3:14b", "qwen3:30b", "qwen3:32b", "qwen3:235b"
          ]
        }
      }.freeze

      COMMON_DEFAULT_OPTIONS = {
        temperature: 0.7,
        top_p: 0.9,
        repeat_penalty: 1.1
      }.freeze

      VERSION_SPECIFIC_OPTIONS = {
        qwen: {
          num_gqa: 8,
          stop: ["<|im_end|>", "<|endoftext|>"]
        },
        qwen3: {
          num_ctx: 4096
        }
      }.freeze

      INTERNAL_TAGS = {
        common: {
          think: /<think>.*?<\/think>\s*/mi,
          reasoning: /<reasoning>.*?<\/reasoning>\s*/mi
        },
        qwen: {
          system: /<\|system\|>.*?<\|im_end\|>\s*/mi
        },
        qwen3: {
          qwen_meta: /<qwen_meta>.*?<\/qwen_meta>\s*/mi
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
        if @model.start_with?('qwen3:')
          :qwen3
        elsif @model.start_with?('qwen2:')
          :qwen2
        else
          :qwen
        end
      end

      def detect_default_model
        MODEL_VERSIONS[model_version][:default]
      end

      def validate_model_version(model)
        valid_models = MODEL_VERSIONS.values.flat_map { |v| v[:versions] }
        unless valid_models.include?(model)
          raise InvalidModelVersion, "Invalid model version. Available: #{valid_models.join(', ')}"
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