module LLMChain
  module Clients
    class Llama2 < OllamaBase
      DEFAULT_MODEL = "llama2:13b".freeze
      DEFAULT_OPTIONS = {
        temperature: 0.7,
        top_k: 40,
        num_ctx: 4096
      }.freeze

      def initialize(model: DEFAULT_MODEL, base_url: nil, **options)
        super(model: model, base_url: base_url, default_options: DEFAULT_OPTIONS.merge(options))
      end
    end
  end
end