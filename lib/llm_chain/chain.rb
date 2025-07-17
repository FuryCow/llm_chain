require "json"
require_relative "memory/array"
require_relative "tools/tool_manager_factory"
require_relative "builders/prompt"
require_relative "builders/memory_context"
require_relative "builders/tool_responses"
require_relative "builders/rag_documents"
require_relative "builders/retriever_context"

module LLMChain
  # High-level interface that ties together an LLM client, optional memory,
  # tool system and RAG retriever. Use {LLMChain.quick_chain} for the common
  # defaults or build manually via this class.
  class Chain
    # @return [String] selected model identifier
    # @return [Object] memory backend
    # @return [Array, Tools::ToolManager, nil] tools collection
    # @return [Object, nil] RAG retriever
    attr_reader :model, :memory, :tools, :retriever

    # Create a new chain.
    #
    # @param model [String] model name, e.g. "gpt-4" or "qwen3:1.7b"
    # @param memory [LLMChain::Interfaces::Memory] conversation memory backend
    # @param tools [LLMChain::Interfaces::ToolManager, Array, true, false, nil]
    # @param retriever [#search, false, nil] document retriever for RAG
    # @param prompt_builder [LLMChain::Interfaces::Builders::Prompt]
    # @param memory_context_builder [LLMChain::Interfaces::Builders::MemoryContext]
    # @param tool_responses_builder [LLMChain::Interfaces::Builders::ToolResponses]
    # @param rag_documents_builder [LLMChain::Interfaces::Builders::RagDocuments]
    # @param retriever_context_builder [LLMChain::Interfaces::Builders::RetrieverContext]
    # @param validate_config [Boolean] run {ConfigurationValidator}
    # @param client_options [Hash] extra LLM-client options (api_key etc.)
    def initialize(
      model: nil,
      memory: nil,
      tools: true,
      retriever: false,
      validate_config: true,
      **client_options
    )
      if validate_config
        begin
          ConfigurationValidator.validate_chain_config!(
            model: model,
            tools: tools,
            memory: memory,
            retriever: retriever,
            **client_options
          )
        rescue ConfigurationValidator::ValidationError => e
          raise Error, "Configuration validation failed: #{e.message}"
        end
      end

      @model = model
      @memory = memory || Memory::Array.new
      @tools =
        if tools == true
          Tools::ToolManagerFactory.create_default_toolset
        elsif tools.is_a?(Array)
          Tools::ToolManager.new(tools: tools)
        elsif tools.is_a?(Tools::ToolManager)
          tools
        elsif tools.is_a?(Hash) && tools[:config]
          Tools::ToolManagerFactory.from_config(tools[:config])
        else
          nil
        end
      @retriever = if retriever.nil?
                     Embeddings::Clients::Local::WeaviateRetriever.new
                   elsif retriever == false
                     nil
                   else
                     retriever
                  end
      @client = ClientRegistry.client_for(model, **client_options)

      # Always use default builders
      @prompt_builder = Builders::Prompt.new
      @memory_context_builder = Builders::MemoryContext.new
      @tool_responses_builder = Builders::ToolResponses.new
      @rag_documents_builder = Builders::RagDocuments.new
      @retriever_context_builder = Builders::RetrieverContext.new
    end

    # Main inference entrypoint.
    #
    # @param prompt [String] user prompt
    # @param stream [Boolean] if `true` yields chunks and returns full string
    # @param rag_context [Boolean] whether to include retriever context
    # @param rag_options [Hash] options passed to retriever (eg. :limit)
    # @yield [String] chunk — called when `stream` is true
    # @return [String] assistant response
    def ask(prompt, stream: false, rag_context: false, rag_options: {}, &block)
      memory_context = build_memory_context(prompt)
      tool_responses = build_tool_responses(prompt)
      rag_documents  = build_rag_documents(prompt, rag_context, rag_options)
      full_prompt    = build_full_prompt(prompt, memory_context, tool_responses, rag_documents)

      response = generate_response(full_prompt, stream: stream, &block)
      store_memory(prompt, response)
      response
    end

    private

    def build_memory_context(prompt)
      history = @memory&.recall(prompt)
      @memory_context_builder.build(history)
    end

    def build_tool_responses(prompt)
      results = @tools&.execute_tools(prompt) || {}
      @tool_responses_builder.build(results)
    end

    def build_rag_documents(prompt, rag_context, rag_options)
      return "" unless rag_context && @retriever

      docs = @retriever_context_builder.retrieve(@retriever, prompt, rag_options)
      @rag_documents_builder.build(docs)
    end

    def build_full_prompt(prompt, memory_context, tool_responses, rag_documents)
      @prompt_builder.build(
        memory_context: memory_context,
        tool_responses: tool_responses,
        rag_documents: rag_documents,
        prompt: prompt
      )
    end

    def store_memory(prompt, response)
      @memory&.store(prompt, response)
    end

    def generate_response(prompt, stream: false, &block)
      if stream
        stream_response(prompt, &block)
      else
        @client.chat(prompt)
      end
    end

    def stream_response(prompt)
      buffer = ""
      @client.stream_chat(prompt) do |chunk|
        buffer << chunk
        yield chunk if block_given?
      end
      buffer
    end
  end
end
