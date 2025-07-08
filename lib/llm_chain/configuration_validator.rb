require 'net/http'
require 'uri'
require 'json'

module LLMChain
  class ConfigurationValidator
    class ValidationError < Error; end
    class ValidationWarning < StandardError; end

    def self.validate_chain_config!(model: nil, **options)
      new.validate_chain_config!(model: model, **options)
    end

    def validate_chain_config!(model: nil, **options)
      @warnings = []
      
      begin
        validate_model!(model) if model
        validate_client_availability!(model) if model
        validate_tools!(options[:tools]) if options[:tools]
        validate_memory!(options[:memory]) if options[:memory]
        validate_retriever!(options[:retriever]) if options[:retriever]
        
        # Выводим предупреждения, если есть
        @warnings.each { |warning| warn_user(warning) } if @warnings.any?
        
        true
      rescue => e
        raise ValidationError, "Configuration validation failed: #{e.message}"
      end
    end

    def self.validate_environment
      new.validate_environment
    end

    def validate_environment
      @warnings = []
      results = {}
      
      results[:ollama] = check_ollama_availability
      results[:ruby] = check_ruby_version
      results[:python] = check_python_availability
      results[:node] = check_node_availability
      results[:internet] = check_internet_connectivity
      results[:apis] = check_api_keys
      
      results[:warnings] = @warnings
      results
    end

    private

    def validate_model!(model)
      return if model.nil?
      
      case model.to_s
      when /^gpt/
        validate_openai_requirements!(model)
      when /qwen|llama|gemma|deepseek-coder-v2/
        validate_ollama_requirements!(model)
      else
        add_warning("Unknown model type: #{model}. Proceeding with default settings.")
      end
    end

    def validate_openai_requirements!(model)
      api_key = ENV['OPENAI_API_KEY']
      unless api_key
        raise ValidationError, "OpenAI API key required for model '#{model}'. Set OPENAI_API_KEY environment variable."
      end
      
      if api_key.length < 20
        raise ValidationError, "OpenAI API key appears to be invalid (too short)."
      end
      
      # Проверяем доступность OpenAI API
      begin
        uri = URI('https://api.openai.com/v1/models')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5
        
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{api_key}"
        
        response = http.request(request)
        
        case response.code
        when '200'
          # OK
        when '401'
          raise ValidationError, "OpenAI API key is invalid or expired."
        when '429'
          add_warning("OpenAI API rate limit reached. Service may be temporarily unavailable.")
        else
          add_warning("OpenAI API returned status #{response.code}. Service may be temporarily unavailable.")
        end
      rescue => e
        add_warning("Cannot verify OpenAI API availability: #{e.message}")
      end
    end

    def validate_ollama_requirements!(model)
      unless check_ollama_availability
        raise ValidationError, "Ollama is not running. Please start Ollama server with: ollama serve"
      end
      
      unless model_available_in_ollama?(model)
        raise ValidationError, "Model '#{model}' not found in Ollama. Available models: #{list_ollama_models.join(', ')}"
      end
    end

    def validate_client_availability!(model)
      case model.to_s
      when /qwen|llama|gemma/
        unless check_ollama_availability
          raise ValidationError, "Ollama server is not running for model '#{model}'"
        end
      end
    end

    def validate_tools!(tools)
      return unless tools
      
      if tools.respond_to?(:tools) # ToolManager
        tools.tools.each { |tool| validate_single_tool!(tool) }
      elsif tools.is_a?(Array)
        tools.each { |tool| validate_single_tool!(tool) }
      else
        validate_single_tool!(tools)
      end
    end

    def validate_single_tool!(tool)
      case tool.class.name
      when /WebSearch/
        validate_web_search_tool!(tool)
      when /CodeInterpreter/
        validate_code_interpreter_tool!(tool)
      when /Calculator/
        # Calculator не требует дополнительной валидации
      end
    end

    def validate_web_search_tool!(tool)
      # Проверяем доступность Google Search API
      if ENV['GOOGLE_API_KEY'] && ENV['GOOGLE_SEARCH_ENGINE_ID']
        # Есть API ключи, но проверим их валидность
        begin
          # Простая проверка доступности
          uri = URI('https://www.googleapis.com/customsearch/v1')
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 3
          http.read_timeout = 3
          
          response = http.get('/')
          # Если получили любой ответ, значит API доступен
        rescue => e
          add_warning("Google Search API may be unavailable: #{e.message}")
        end
      else
        add_warning("Google Search API not configured. Search will use fallback methods.")
      end
      
      # Проверяем доступность интернета для fallback поиска
      unless check_internet_connectivity
        add_warning("No internet connection detected. Search functionality will be limited.")
      end
    end

    def validate_code_interpreter_tool!(tool)
      # Проверяем доступность языков программирования
      languages = tool.instance_variable_get(:@allowed_languages) || ['ruby']
      
      languages.each do |lang|
        case lang
        when 'ruby'
          unless check_ruby_version
            add_warning("Ruby interpreter not found or outdated.")
          end
        when 'python'
          unless check_python_availability
            add_warning("Python interpreter not found.")
          end
        when 'javascript'
          unless check_node_availability
            add_warning("Node.js interpreter not found.")
          end
        end
      end
    end

    def validate_memory!(memory)
      return unless memory
      
      case memory.class.name
      when /Redis/
        validate_redis_memory!(memory)
      when /Array/
        # Array memory не требует дополнительной валидации
      end
    end

    def validate_redis_memory!(memory)
      begin
        # Проверяем подключение к Redis
        redis_client = memory.instance_variable_get(:@redis) || memory.redis
        if redis_client.respond_to?(:ping)
          redis_client.ping
        end
      rescue => e
        raise ValidationError, "Redis connection failed: #{e.message}"
      end
    end

    def validate_retriever!(retriever)
      return unless retriever
      return if retriever == false
      
      case retriever.class.name
      when /Weaviate/
        validate_weaviate_retriever!(retriever)
      end
    end

    def validate_weaviate_retriever!(retriever)
      # Проверяем доступность Weaviate
      begin
        # Попытка подключения к Weaviate
        uri = URI('http://localhost:8080/v1/.well-known/ready')
        response = Net::HTTP.get_response(uri)
        
        unless response.code == '200'
          raise ValidationError, "Weaviate server is not ready. Please start Weaviate."
        end
      rescue => e
        raise ValidationError, "Cannot connect to Weaviate: #{e.message}"
      end
    end

    # Вспомогательные методы для проверки системы

    def check_ollama_availability
      begin
        uri = URI('http://localhost:11434/api/tags')
        response = Net::HTTP.get_response(uri)
        response.code == '200'
      rescue
        false
      end
    end

    def model_available_in_ollama?(model)
      begin
        uri = URI('http://localhost:11434/api/tags')
        response = Net::HTTP.get_response(uri)
        return false unless response.code == '200'
        
        data = JSON.parse(response.body)
        models = data['models'] || []
        models.any? { |m| m['name'].include?(model.to_s.split(':').first) }
      rescue
        false
      end
    end

    def list_ollama_models
      begin
        uri = URI('http://localhost:11434/api/tags')
        response = Net::HTTP.get_response(uri)
        return [] unless response.code == '200'
        
        data = JSON.parse(response.body)
        models = data['models'] || []
        models.map { |m| m['name'] }
      rescue
        []
      end
    end

    def check_ruby_version
      begin
        version = RUBY_VERSION
        major, minor, patch = version.split('.').map(&:to_i)
        
        # Требуем Ruby >= 3.1.0
        if major > 3 || (major == 3 && minor >= 1)
          true
        else
          add_warning("Ruby version #{version} detected. Minimum required: 3.1.0")
          false
        end
      rescue
        false
      end
    end

    def check_python_availability
      begin
        output = `python3 --version 2>&1`
        $?.success? && output.include?('Python')
      rescue
        false
      end
    end

    def check_node_availability
      begin
        output = `node --version 2>&1`
        $?.success? && output.include?('v')
      rescue
        false
      end
    end

    def check_internet_connectivity
      begin
        require 'socket'
        Socket.tcp("8.8.8.8", 53, connect_timeout: 3) {}
        true
      rescue
        false
      end
    end

    def check_api_keys
      keys = {}
      keys[:openai] = !ENV['OPENAI_API_KEY'].nil?
      keys[:google_search] = !ENV['GOOGLE_API_KEY'].nil? && !ENV['GOOGLE_SEARCH_ENGINE_ID'].nil?
      keys[:bing_search] = !ENV['BING_API_KEY'].nil?
      keys
    end

    def add_warning(message)
      @warnings << message
    end

    def warn_user(message)
      if defined?(Rails) && Rails.logger
        Rails.logger.warn "[LLMChain] #{message}"
      else
        warn "[LLMChain] Warning: #{message}"
      end
    end
  end
end 