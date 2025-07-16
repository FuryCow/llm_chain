# frozen_string_literal: true

require_relative '../interfaces/tool_manager'

module LLMChain
  module Tools
    # ToolManager manages registration, selection, and execution of tools in LLMChain.
    # Implements the LLMChain::Interfaces::ToolManager interface.
    class ToolManager < Interfaces::ToolManager
      attr_reader :tools

      def initialize(tools: [])
        @tools = {}
        tools.each { |tool| register_tool(tool) }
      end

      # Register a new tool instance.
      # @param tool [LLMChain::Tools::Base]
      # @return [void]
      def register_tool(tool)
        unless tool.is_a?(Base)
          raise ArgumentError, "Tool must inherit from LLMChain::Tools::Base"
        end
        @tools[tool.name] = tool
      end

      # Unregister a tool by name.
      # @param name [String]
      # @return [void]
      def unregister_tool(name)
        @tools.delete(name.to_s)
      end

      # Fetch a tool by its name.
      # @param name [String]
      # @return [LLMChain::Tools::Base, nil]
      def get_tool(name)
        @tools[name.to_s]
      end

      # List all registered tools.
      # @return [Array<LLMChain::Tools::Base>]
      def list_tools
        @tools.values
      end

      # Find tools whose #match? returns true for the prompt.
      # @param prompt [String]
      # @return [Array<LLMChain::Tools::Base>]
      def find_matching_tools(prompt)
        @tools.values.select { |tool| tool.match?(prompt) }
      end

      # Execute every matching tool and collect results.
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

      # Format tool execution results for inclusion into an LLM prompt.
      # @param results [Hash]
      # @return [String]
      def format_tool_results(results)
        return "" if results.empty?
        formatted_results = results.map do |tool_name, result|
          "#{tool_name}: #{result[:formatted]}"
        end
        "Tool Results:\n#{formatted_results.join("\n\n")}"
      end

      # Human-readable list of available tools.
      # @return [String]
      def tools_description
        descriptions = @tools.values.map do |tool|
          "- #{tool.name}: #{tool.description}"
        end
        "Available tools:\n#{descriptions.join("\n")}"
      end

      # Determine if prompt likely needs tool usage.
      # @param prompt [String]
      # @return [Boolean]
      def needs_tools?(prompt)
        return true if prompt.match?(/\b(use tool|call tool|execute|calculate|search|run code)\b/i)
        find_matching_tools(prompt).any?
      end

      # Auto-select and execute best tools for prompt.
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash]
      def auto_execute(prompt, context: {})
        return {} unless needs_tools?(prompt)
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

      # Build JSON schemas for all registered tools.
      # @return [Array<Hash>]
      def get_tools_schema
        @tools.values.map(&:to_schema)
      end

      private

      # Simple heuristic to rank matching tools.
      def select_best_tools(tools, prompt, limit: 3)
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