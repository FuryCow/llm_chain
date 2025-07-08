module LLMChain
  module Tools
    class ToolManager
      attr_reader :tools

      def initialize(tools: [])
        @tools = {}
        tools.each { |tool| register_tool(tool) }
      end

      # Register a new tool instance.
      #
      # @param tool [LLMChain::Tools::Base]
      # @raise [ArgumentError] if object does not inherit from Tools::Base
      def register_tool(tool)
        unless tool.is_a?(Base)
          raise ArgumentError, "Tool must inherit from LLMChain::Tools::Base"
        end
        @tools[tool.name] = tool
      end

      # Unregister a tool by name.
      def unregister_tool(name)
        @tools.delete(name.to_s)
      end

      # Fetch a tool by its name.
      def get_tool(name)
        @tools[name.to_s]
      end

      # @return [Array<LLMChain::Tools::Base>] list of registered tools
      def list_tools
        @tools.values
      end

      # Build JSON schemas for all registered tools.
      def get_tools_schema
        @tools.values.map(&:to_schema)
      end

      # Find tools whose {Tools::Base#match?} returns `true` for the prompt.
      def find_matching_tools(prompt)
        @tools.values.select { |tool| tool.match?(prompt) }
      end

      # Execute every matching tool and collect results.
      #
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash] mapping tool name → result hash
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

      # Execute a single tool by name.
      #
      # @param name [String]
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash] result wrapper
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

      # Create default toolset (Calculator, WebSearch, CodeInterpreter, DateTime).
      def self.create_default_toolset
        tools = [
          Calculator.new,
          WebSearch.new,
          CodeInterpreter.new,
          DateTime.new
        ]
        
        new(tools: tools)
      end

      # Build toolset from a config array.
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

      # Format tool execution results for inclusion into an LLM prompt.
      def format_tool_results(results)
        return "" if results.empty?

        formatted_results = results.map do |tool_name, result|
          "#{tool_name}: #{result[:formatted]}"
        end

        "Tool Results:\n#{formatted_results.join("\n\n")}"
      end

      # Human-readable list of available tools.
      def tools_description
        descriptions = @tools.values.map do |tool|
          "- #{tool.name}: #{tool.description}"
        end

        "Available tools:\n#{descriptions.join("\n")}"
      end

      # Determine if prompt likely needs tool usage.
      def needs_tools?(prompt)
        # Check for explicit tool usage requests
        return true if prompt.match?(/\b(use tool|call tool|execute|calculate|search|run code)\b/i)
        
        # Check if there are any matching tools
        find_matching_tools(prompt).any?
      end

      # Auto-select and execute best tools for prompt.
      def auto_execute(prompt, context: {})
        return {} unless needs_tools?(prompt)
        
        # Limit the number of tools executed at once
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

      # Simple heuristic to rank matching tools.
        def select_best_tools(tools, prompt, limit: 3)
          # Simple prioritization logic
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