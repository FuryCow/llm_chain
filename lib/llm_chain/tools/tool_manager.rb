module LLMChain
  module Tools
    class ToolManager
      attr_reader :tools

      def initialize(tools: [])
        @tools = {}
        tools.each { |tool| register_tool(tool) }
      end

      # Регистрирует новый инструмент
      def register_tool(tool)
        unless tool.is_a?(BaseTool)
          raise ArgumentError, "Tool must inherit from BaseTool"
        end
        @tools[tool.name] = tool
      end

      # Удаляет инструмент
      def unregister_tool(name)
        @tools.delete(name.to_s)
      end

      # Получает инструмент по имени
      def get_tool(name)
        @tools[name.to_s]
      end

      # Возвращает список всех инструментов
      def list_tools
        @tools.values
      end

      # Получает схемы всех инструментов для LLM
      def get_tools_schema
        @tools.values.map(&:to_schema)
      end

      # Находит подходящие инструменты для промпта
      def find_matching_tools(prompt)
        @tools.values.select { |tool| tool.match?(prompt) }
      end

      # Выполняет все подходящие инструменты
      def execute_tools(prompt, context: {})
        matching_tools = find_matching_tools(prompt)
        
        results = {}
        matching_tools.each do |tool|
          begin
            result = tool.call(prompt, context: context)
            results[tool.name] = {
              success: true,
              result: result,
              formatted: tool.format_result(result)
            }
          rescue => e
            results[tool.name] = {
              success: false,
              error: e.message,
              formatted: "Error in #{tool.name}: #{e.message}"
            }
          end
        end

        results
      end

      # Выполняет конкретный инструмент по имени
      def execute_tool(name, prompt, context: {})
        tool = get_tool(name)
        raise ArgumentError, "Tool '#{name}' not found" unless tool

        begin
          result = tool.call(prompt, context: context)
          {
            success: true,
            result: result,
            formatted: tool.format_result(result)
          }
        rescue => e
          {
            success: false,
            error: e.message,
            formatted: "Error in #{name}: #{e.message}"
          }
        end
      end

      # Создает стандартный набор инструментов
      def self.create_default_toolset
        tools = [
          Calculator.new,
          WebSearch.new,
          CodeInterpreter.new
        ]
        
        new(tools: tools)
      end

      # Создает набор инструментов из конфигурации
      def self.from_config(config)
        tools = []
        
        config.each do |tool_config|
          tool_class = tool_config[:class] || tool_config['class']
          tool_options = tool_config[:options] || tool_config['options'] || {}
          
          case tool_class.to_s.downcase
          when 'calculator'
            tools << Calculator.new
          when 'web_search', 'websearch'
            tools << WebSearch.new(**tool_options)
          when 'code_interpreter', 'codeinterpreter'
            tools << CodeInterpreter.new(**tool_options)
          else
            raise ArgumentError, "Unknown tool class: #{tool_class}"
          end
        end
        
        new(tools: tools)
      end

      # Форматирует результаты выполнения для включения в промпт
      def format_tool_results(results)
        return "" if results.empty?

        formatted_results = results.map do |tool_name, result|
          "#{tool_name}: #{result[:formatted]}"
        end

        "Tool Results:\n#{formatted_results.join("\n\n")}"
      end

      # Получает краткое описание доступных инструментов
      def tools_description
        descriptions = @tools.values.map do |tool|
          "- #{tool.name}: #{tool.description}"
        end

        "Available tools:\n#{descriptions.join("\n")}"
      end

      # Проверяет, содержит ли промпт запрос на использование инструментов
      def needs_tools?(prompt)
        # Проверяем явные запросы на использование инструментов
        return true if prompt.match?(/\b(use tool|call tool|execute|calculate|search|run code)\b/i)
        
        # Проверяем, есть ли подходящие инструменты
        find_matching_tools(prompt).any?
      end

      # Автоматически решает, какие инструменты использовать
      def auto_execute(prompt, context: {})
        return {} unless needs_tools?(prompt)
        
        # Ограничиваем количество одновременно выполняемых инструментов
        matching_tools = find_matching_tools(prompt)
        selected_tools = select_best_tools(matching_tools, prompt)
        
        results = {}
        selected_tools.each do |tool|
          begin
            result = tool.call(prompt, context: context)
            results[tool.name] = {
              success: true,
              result: result,
              formatted: tool.format_result(result)
            }
          rescue => e
            results[tool.name] = {
              success: false,
              error: e.message,
              formatted: "Error in #{tool.name}: #{e.message}"
            }
          end
        end

        results
      end

      private

      # Выбирает лучшие инструменты для выполнения (ограничение по количеству)
      def select_best_tools(tools, prompt, limit: 3)
        # Простая логика приоритизации
        prioritized = tools.sort_by do |tool|
          case tool.name
          when 'calculator'
            prompt.include?('calculate') || prompt.match?(/\d+\s*[+\-*\/]\s*\d+/) ? 0 : 2
          when 'web_search'
            prompt.include?('search') || prompt.match?(/\b(what|who|where|when)\b/i) ? 0 : 2
          when 'code_interpreter'
            prompt.include?('```') || prompt.include?('code') ? 0 : 2
          else
            1
          end
        end

        prioritized.first(limit)
      end
    end
  end
end 