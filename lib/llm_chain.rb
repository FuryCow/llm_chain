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
end

# Загружаем валидатор после определения базовых классов
require_relative "llm_chain/configuration_validator"

module LLMChain

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
    def quick_chain(model: nil, tools: true, memory: true, validate_config: true, **options)
      model ||= configuration.default_model
      
      chain_options = {
        model: model,
        retriever: false,
        validate_config: validate_config,
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

    # Диагностика системы
    def diagnose_system
      puts "🔍 LLMChain System Diagnostics"
      puts "=" * 50
      
      results = ConfigurationValidator.validate_environment
      
      puts "\n📋 System Components:"
      puts "  Ruby: #{results[:ruby] ? '✅' : '❌'} (#{RUBY_VERSION})"
      puts "  Python: #{results[:python] ? '✅' : '❌'}"
      puts "  Node.js: #{results[:node] ? '✅' : '❌'}"
      puts "  Internet: #{results[:internet] ? '✅' : '❌'}"
      puts "  Ollama: #{results[:ollama] ? '✅' : '❌'}"
      
      puts "\n🔑 API Keys:"
      results[:apis].each do |api, available|
        puts "  #{api.to_s.capitalize}: #{available ? '✅' : '❌'}"
      end
      
      if results[:warnings].any?
        puts "\n⚠️  Warnings:"
        results[:warnings].each { |warning| puts "  • #{warning}" }
      end
      
      puts "\n💡 Recommendations:"
      puts "  • Install missing components for full functionality"
      puts "  • Configure API keys for enhanced features"
      puts "  • Start Ollama server: ollama serve" unless results[:ollama]
      
      puts "\n" + "=" * 50
      
      results
    end
  end
end