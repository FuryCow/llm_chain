module LLMChain
  module Tools
    class BaseTool
      attr_reader :name, :description, :parameters

      def initialize(name:, description:, parameters: {})
        @name = name
        @description = description
        @parameters = parameters
      end

      # Проверяет, подходит ли инструмент для данного промпта
      # @param prompt [String] Входной промпт от пользователя
      # @return [Boolean] true если инструмент должен быть вызван
      def match?(prompt)
        raise NotImplementedError, "Subclasses must implement #match?"
      end

      # Выполняет инструмент
      # @param prompt [String] Входной промпт от пользователя
      # @param context [Hash] Дополнительный контекст
      # @return [String, Hash] Результат выполнения инструмента
      def call(prompt, context: {})
        raise NotImplementedError, "Subclasses must implement #call"
      end

      # Возвращает JSON-схему для LLM
      def to_schema
        {
          name: @name,
          description: @description,
          parameters: {
            type: "object",
            properties: @parameters,
            required: required_parameters
          }
        }
      end

      # Извлекает параметры из промпта (для автоматического парсинга)
      # @param prompt [String] Входной промпт
      # @return [Hash] Извлеченные параметры
      def extract_parameters(prompt)
        {}
      end

      # Форматирует результат для включения в промпт
      # @param result [Object] Результат выполнения инструмента
      # @return [String] Форматированный результат
      def format_result(result)
        case result
        when String then result
        when Hash, Array then JSON.pretty_generate(result)
        else result.to_s
        end
      end

      protected

      # Список обязательных параметров
      def required_parameters
        []
      end

      # Помощник для проверки ключевых слов в промпте
      def contains_keywords?(prompt, keywords)
        keywords.any? { |keyword| prompt.downcase.include?(keyword.downcase) }
      end

      # Помощник для извлечения числовых значений
      def extract_numbers(text)
        text.scan(/-?\d+\.?\d*/).map(&:to_f)
      end

      # Помощник для извлечения URL
      def extract_urls(text)
        text.scan(%r{https?://[^\s]+})
      end
    end
  end
end 