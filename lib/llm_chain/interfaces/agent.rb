# frozen_string_literal: true

module LLMChain
  module Interfaces
    # Abstract interface for all LLMChain agents
    # 
    # All agents must implement the run method and provide access to their
    # model, tools, and memory. The constructor is left to individual implementations
    # to allow for flexibility in parameter requirements.
    #
    # @abstract
    class Agent
      # Execute a task using the agent's capabilities
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information (when streaming)
      # @return [Hash] execution result with reasoning trace
      def run(task, stream: false, &block)
        raise NotImplementedError, "Implement in subclass"
      end

      # Get the model identifier used by this agent
      # @return [String] model name
      def model
        raise NotImplementedError, "Implement in subclass"
      end

      # Get the tool manager available to this agent
      # @return [LLMChain::Interfaces::ToolManager] tool manager
      def tools
        raise NotImplementedError, "Implement in subclass"
      end

      # Get the memory system used by this agent
      # @return [LLMChain::Interfaces::Memory] memory backend
      def memory
        raise NotImplementedError, "Implement in subclass"
      end

      # Check if the agent can handle the given task
      # @param task [String] task description
      # @return [Boolean] whether the agent can handle this task
      def can_handle?(task)
        raise NotImplementedError, "Implement in subclass"
      end

      # Get a description of the agent's capabilities
      # @return [String] agent description
      def description
        raise NotImplementedError, "Implement in subclass"
      end
    end
  end
end 