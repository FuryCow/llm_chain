module LLMChain
  module Clients
    class Qwen < OllamaBase
      DEFAULT_MODEL = "qwen:7b".freeze
      DEFAULT_OPTIONS = {
        temperature: 0.8,
        repeat_penalty: 1.1,
        num_gqa: 8  # Специфичный параметр для Qwen
      }.freeze

      def initialize(model: DEFAULT_MODEL, base_url: nil, **options)
        super(model: model, base_url: base_url, default_options: DEFAULT_OPTIONS.merge(options))
      end

      protected

      def build_request_body(prompt, options)
        # Qwen-specific adjustments
        body = super
        body[:options][:stop] = ["<|im_end|>"]  # Специфичный стоп-токен для Qwen
        body
      end
    end
  end
end