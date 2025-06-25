# frozen_string_literal: true

require_relative "llm_chain/version"
require_relative "llm_chain/chain"
require_relative "llm_chain/client_registry"
require_relative "llm_chain/clients/base"
require_relative "llm_chain/clients/openai"
require_relative "llm_chain/clients/ollama_base"
require_relative "llm_chain/clients/qwen"
require_relative "llm_chain/clients/llama2"
require_relative "llm_chain/clients/gemma3"
require_relative "llm_chain/memory/array"
require_relative "llm_chain/memory/redis"
require_relative "llm_chain/tools/base_tool"
require_relative "llm_chain/tools/calculator"
require_relative "llm_chain/tools/web_search"
require_relative "llm_chain/tools/code_interpreter"
require_relative "llm_chain/tools/tool_manager"
require_relative "llm_chain/embeddings/clients/local/weaviate_vector_store"
require_relative "llm_chain/embeddings/clients/local/weaviate_retriever"
require_relative "llm_chain/embeddings/clients/local/ollama_client"

module LLMChain
  class Error < StandardError; end
  class UnknownModelError < Error; end
  class InvalidModelVersion < Error; end
  class ClientError < Error; end
  class ServerError < Error; end
  class TimeoutError < Error; end
  class MemoryError < Error; end

  # Простая система конфигурации
  class Configuration
    attr_accessor :default_model, :timeout, :memory_size, :search_engine

    def initialize
      @default_model = "qwen3:1.7b"
      @timeout = 30
      @memory_size = 100
      @search_engine = :google
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Быстрое создание цепочки с настройками по умолчанию
    def quick_chain(model: nil, tools: true, memory: true, **options)
      model ||= configuration.default_model
      
      chain_options = {
        model: model,
        retriever: false,
        **options
      }
      
      if tools
        tool_manager = Tools::ToolManager.create_default_toolset
        chain_options[:tools] = tool_manager
      end
      
      if memory
        chain_options[:memory] = Memory::Array.new(max_size: configuration.memory_size)
      end
      
      Chain.new(**chain_options)
    end
  end
end