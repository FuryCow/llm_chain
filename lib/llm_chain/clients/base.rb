module LLMChain
  module Clients
    # Abstract base class for an LLM client adapter.
    #
    # Concrete clients **must** implement two methods:
    #   * `#chat(prompt, **options)` – single-shot request
    #   * `#stream_chat(prompt, **options)` – streaming request yielding chunks
    #
    # Constructor should accept `model:` plus any client-specific options
    # (`api_key`, `base_url`, …).
    #
    # @abstract
    class Base
      # @param model [String]
      def initialize(model)
        @model = model
      end

      # Send a non-streaming chat request.
      #
      # @param prompt [String]
      # @param options [Hash]
      # @return [String] assistant response
      def chat(prompt, **options)
        raise NotImplementedError
      end

      # Send a streaming chat request.
      #
      # @param prompt [String]
      # @param options [Hash]
      # @yieldparam chunk [String] partial response chunk
      # @return [String] full concatenated response
      def stream_chat(prompt, **options, &block)
        raise NotImplementedError
      end
    end
  end
end