require 'faraday'
require 'json'

module LLMChain
  module Clients
    # Mistral client for Ollama
    # 
    # Provides access to Mistral models through Ollama with support for
    # streaming and non-streaming responses.
    #
    # @example Basic usage
    #   client = LLMChain::Clients::Mistral.new
    #   response = client.chat("Hello, how are you?")
    #
    # @example Using specific model variant
    #   client = LLMChain::Clients::Mistral.new(model: "mixtral:8x7b")
    #   response = client.chat("Explain quantum computing")
    #
    class Mistral < OllamaBase
      DEFAULT_MODEL = "mistral:latest".freeze
      
      # Optimized settings for Mistral models
      # @return [Hash] Default options for Mistral models
      DEFAULT_OPTIONS = {
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
        num_ctx: 8192,
        stop: ["<|im_end|>", "<|endoftext|>", "<|user|>", "<|assistant|>"]
      }.freeze

      # Initialize the Mistral client
      # @param model [String] Model to use (defaults to mistral:latest)
      # @param base_url [String] Custom base URL for API calls
      # @param options [Hash] Additional options to merge with defaults
      def initialize(model: DEFAULT_MODEL, base_url: nil, **options)
        super(model: model, base_url: base_url, default_options: DEFAULT_OPTIONS.merge(options))
      end
    end
  end
end 