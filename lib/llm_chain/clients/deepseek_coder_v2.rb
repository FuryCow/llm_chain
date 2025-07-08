module LLMChain
  module Clients
    # Deepseek-Coder-V2 client for Ollama
    # 
    # An open-source Mixture-of-Experts (MoE) code language model that achieves 
    # performance comparable to GPT4-Turbo in code-specific tasks.
    #
    # @example Using default model
    #   client = LLMChain::Clients::DeepseekCoderV2.new
    #   response = client.chat("Write a Python function to sort a list")
    #
    # @example Using specific model variant
    #   client = LLMChain::Clients::DeepseekCoderV2.new(model: "deepseek-coder-v2:16b")
    #   response = client.chat("Explain this algorithm")
    #
    class DeepseekCoderV2 < OllamaBase
      DEFAULT_MODEL = "deepseek-coder-v2:latest".freeze
      
      # Optimized settings for code generation tasks
      DEFAULT_OPTIONS = {
        temperature: 0.1,     # Lower temperature for more precise code
        top_p: 0.95,         # High top_p for diverse but relevant responses
        num_ctx: 8192,       # Large context for complex code analysis
        stop: ["User:", "Assistant:"]  # Stop tokens for chat format
      }.freeze

      def initialize(model: DEFAULT_MODEL, base_url: nil, **options)
        super(model: model, base_url: base_url, default_options: DEFAULT_OPTIONS.merge(options))
      end
    end
  end
end 