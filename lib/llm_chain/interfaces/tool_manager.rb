# frozen_string_literal: true

module LLMChain
  module Interfaces
    # Abstract interface for tool management in LLMChain.
    # Implementations must provide methods for registering, finding, and executing tools.
    #
    # @abstract
    class ToolManager
      # Register a new tool instance.
      # @param tool [LLMChain::Tools::Base]
      # @return [void]
      def register_tool(tool)
        raise NotImplementedError, "Implement in subclass"
      end

      # Unregister a tool by name.
      # @param name [String]
      # @return [void]
      def unregister_tool(name)
        raise NotImplementedError, "Implement in subclass"
      end

      # Fetch a tool by its name.
      # @param name [String]
      # @return [LLMChain::Tools::Base, nil]
      def get_tool(name)
        raise NotImplementedError, "Implement in subclass"
      end

      # List all registered tools.
      # @return [Array<LLMChain::Tools::Base>]
      def list_tools
        raise NotImplementedError, "Implement in subclass"
      end

      # Find tools whose #match? returns true for the prompt.
      # @param prompt [String]
      # @return [Array<LLMChain::Tools::Base>]
      def find_matching_tools(prompt)
        raise NotImplementedError, "Implement in subclass"
      end

      # Execute every matching tool and collect results.
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash] mapping tool name → result hash
      def execute_tools(prompt, context: {})
        raise NotImplementedError, "Implement in subclass"
      end

      # Format tool execution results for inclusion into an LLM prompt.
      # @param results [Hash]
      # @return [String]
      def format_tool_results(results)
        raise NotImplementedError, "Implement in subclass"
      end

      # Human-readable list of available tools.
      # @return [String]
      def tools_description
        raise NotImplementedError, "Implement in subclass"
      end

      # Determine if prompt likely needs tool usage.
      # @param prompt [String]
      # @return [Boolean]
      def needs_tools?(prompt)
        raise NotImplementedError, "Implement in subclass"
      end

      # Auto-select and execute best tools for prompt.
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash]
      def auto_execute(prompt, context: {})
        raise NotImplementedError, "Implement in subclass"
      end

      # Build JSON schemas for all registered tools.
      # @return [Array<Hash>]
      def get_tools_schema
        raise NotImplementedError, "Implement in subclass"
      end
    end
  end
end 