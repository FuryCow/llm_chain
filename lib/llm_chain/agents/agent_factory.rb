# frozen_string_literal: true

require_relative '../interfaces/agent'

module LLMChain
  module Agents
    # Factory for creating different types of agents
    # 
    # Provides a centralized way to instantiate agents with proper configuration.
    # Supports dependency injection and easy extension for new agent types.
    #
    # @example Basic usage
    #   agent = AgentFactory.create(type: :react, model: "qwen3:1.7b")
    #   result = agent.run("Analyze this data")
    #
    # @example With custom tools and memory
    #   agent = AgentFactory.create(
    #     type: :react,
    #     model: "gpt-4",
    #     tools: custom_tool_manager,
    #     memory: redis_memory
    #   )
    #
    # @example Registering custom agent
    #   class MyCustomAgent < LLMChain::Interfaces::Agent
    #     # implementation
    #   end
    #   
    #   AgentFactory.register(:my_custom, MyCustomAgent)
    #   agent = AgentFactory.create(type: :my_custom)
    class AgentFactory
      @registry = {}
      @descriptions = {}

      # Register a custom agent class
      # @param type [Symbol] agent type identifier
      # @param agent_class [Class] agent class that implements LLMChain::Interfaces::Agent
      # @param description [String] human-readable description of the agent
      # @return [void]
      def self.register(type, agent_class, description: nil)
        unless agent_class.ancestors.include?(LLMChain::Interfaces::Agent)
          raise ArgumentError, "Agent class must implement LLMChain::Interfaces::Agent"
        end
        
        @registry[type.to_sym] = agent_class
        @descriptions[type.to_sym] = description || "Custom agent: #{agent_class.name}"
      end

      # Create an agent instance by type
      # @param type [Symbol] the type of agent to create
      # @param model [String] LLM model identifier
      # @param tools [LLMChain::Interfaces::ToolManager] tool manager
      # @param memory [LLMChain::Interfaces::Memory] memory backend
      # @param max_iterations [Integer] maximum reasoning iterations (for ReAct)
      # @param client_options [Hash] additional client options
      # @return [LLMChain::Interfaces::Agent] agent instance
      # @raise [ArgumentError] when agent type is unknown
      def self.create(
        type:,
        model: nil,
        tools: nil,
        memory: nil,
        max_iterations: 5,
        **client_options
      )
        type_sym = type.to_sym
        
        # Get registered agent class
        agent_class = @registry[type_sym]
        unless agent_class
          raise ArgumentError, "Unknown agent type: #{type}. Supported types: #{supported_types.join(', ')}"
        end

        # Create agent instance with standard parameters
        agent_class.new(
          model: model || LLMChain.configuration.default_model,
          tools: tools || LLMChain::Tools::ToolManagerFactory.create_default_toolset,
          memory: memory || LLMChain::Memory::Array.new,
          max_iterations: max_iterations,
          **client_options
        )
      end

      # Get list of supported agent types
      # @return [Array<Symbol>] supported agent types
      def self.supported_types
        @registry.keys
      end

      # Check if agent type is supported
      # @param type [Symbol] agent type to check
      # @return [Boolean] whether the type is supported
      def self.supported?(type)
        supported_types.include?(type.to_sym)
      end

      # Get description of available agent types
      # @return [Hash<Symbol, String>] agent type descriptions
      def self.agent_descriptions
        @descriptions
      end

      # Unregister a custom agent
      # @param type [Symbol] agent type to unregister
      # @return [void]
      def self.unregister(type)
        type_sym = type.to_sym
        @registry.delete(type_sym)
        @descriptions.delete(type_sym)
      end

      # Get registered agent class
      # @param type [Symbol] agent type
      # @return [Class, nil] agent class or nil if not registered
      def self.get_registered_agent(type)
        @registry[type.to_sym]
      end
    end
  end
end 