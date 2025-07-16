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
require_relative "llm_chain/clients/deepseek_coder_v2"
require_relative "llm_chain/memory/array"
require_relative "llm_chain/memory/redis"
require_relative "llm_chain/tools/base"
require_relative "llm_chain/tools/calculator"
require_relative "llm_chain/tools/web_search"
require_relative "llm_chain/tools/code_interpreter"
require_relative "llm_chain/tools/tool_manager"
require_relative "llm_chain/tools/date_time"
require_relative "llm_chain/embeddings/clients/local/weaviate_vector_store"
require_relative "llm_chain/embeddings/clients/local/weaviate_retriever"
require_relative "llm_chain/embeddings/clients/local/ollama_client"

module LLMChain
  # Exception classes
  class Error < StandardError; end
  class UnknownModelError < Error; end
  class InvalidModelVersion < Error; end
  class ClientError < Error; end
  class ServerError < Error; end
  class TimeoutError < Error; end
  class MemoryError < Error; end
end

# Load validator and diagnostics after base classes are defined
require_relative "llm_chain/configuration_validator"
require_relative "llm_chain/system_diagnostics"

module LLMChain
  # Simple configuration system for LLMChain
  class Configuration
    # Configuration constants
    DEFAULT_MODEL = "qwen3:1.7b"
    DEFAULT_TIMEOUT = 30
    DEFAULT_MEMORY_SIZE = 100
    DEFAULT_SEARCH_ENGINE = :google

    attr_accessor :default_model, :timeout, :memory_size, :search_engine

    def initialize
      @default_model = DEFAULT_MODEL
      @timeout = DEFAULT_TIMEOUT
      @memory_size = DEFAULT_MEMORY_SIZE
      @search_engine = DEFAULT_SEARCH_ENGINE
    end

    def reset_to_defaults
      initialize
    end

    def valid?
      default_model && timeout.positive? && memory_size.positive?
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

    def reset_configuration
      @configuration = nil
    end

    # Quick chain creation with default settings
    def quick_chain(model: nil, tools: true, memory: true, validate_config: true, **options)
      chain_options = build_chain_options(model, tools, memory, validate_config, **options)
      Chain.new(**chain_options)
    end

    # System diagnostics
    def diagnose_system
      SystemDiagnostics.run
    end

    private

    def build_chain_options(model, tools, memory, validate_config, **options)
      {
        model: model || configuration.default_model,
        tools: build_tools(tools),
        memory: build_memory(memory),
        retriever: false,
        validate_config: validate_config,
        **options
      }
    end

    def build_tools(tools)
      return Tools::ToolManagerFactory.create_default_toolset if tools == true
      return nil if tools == false

      tools
    end

    def build_memory(memory)
      return Memory::Array.new(max_size: configuration.memory_size) if memory == true
      return nil if memory == false

      memory
    end
  end
end