# frozen_string_literal: true

module LLMChain
  module Tools
    # Factory for creating ToolManager instances with default or custom toolsets.
    module ToolManagerFactory
      # Create a ToolManager with the default set of tools.
      # @return [ToolManager]
      def self.create_default_toolset
        tools = [
          Calculator.new,
          WebSearch.new,
          CodeInterpreter.new,
          DateTime.new
        ]
        ToolManager.new(tools: tools)
      end

      # Create a ToolManager from a config array.
      # @param config [Array<Hash>] tool config hashes
      # @return [ToolManager]
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
          when 'date_time', 'datetime'
            tools << DateTime.new
          else
            raise ArgumentError, "Unknown tool class: #{tool_class}"
          end
        end
        ToolManager.new(tools: tools)
      end
    end
  end
end 