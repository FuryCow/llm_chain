# frozen_string_literal: true

require_relative '../interfaces/agent'
require_relative '../client_registry'

module LLMChain
  module Agents
    # Agent that decomposes a complex user request into a sequence of atomic steps.
    #
    # The agent uses the same model system as other agents in the framework.
    # It creates a client through the ClientRegistry based on the provided model.
    #
    # @example Basic usage
    #   planner = LLMChain::Agents::PlannerAgent.new(model: "qwen3:1.7b")
    #   steps = planner.plan("Find the president of the US and the capital of France")
    #   # => ["Find the president of the US", "Find the capital of France"]
    class PlannerAgent < LLMChain::Interfaces::Agent
      attr_reader :model, :client

      # Initialize the planner agent with a model identifier.
      # @param model [String] LLM model identifier
      # @param client_options [Hash] additional client options
      def initialize(model:, **client_options)
        @model = model
        @client = LLMChain::ClientRegistry.client_for(@model, **client_options)
      end

      # Decompose a complex user task into a sequence of atomic steps.
      # @param task [String] The complex user request to decompose.
      # @return [Array<String>] The list of atomic steps (one per string).
      # @example
      #   planner = PlannerAgent.new(client: my_llm_client)
      #   steps = planner.plan("Find the president of the US and the capital of France")
      #   # => ["Find the president of the US", "Find the capital of France"]
      def plan(task)
        prompt = <<~PROMPT
          Decompose the following user request into a minimal sequence of atomic steps.
          Return only the steps, one per line, no explanations, *no numbering*.

          User request:
          #{task}

          Steps:
        PROMPT

        response = @client.chat(prompt)
        response.lines.map(&:strip).reject(&:empty?)
      end

      # Check if this agent can handle the given task
      # @param task [String] The user request
      # @return [Boolean] Whether this agent can handle the task
      def can_handle?(task)
        !task.nil? && !task.strip.empty?
      end

      # Execute a task using the agent's capabilities
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information (when streaming)
      # @return [Hash] execution result with reasoning trace
      def run(task, stream: false, &block)
        steps = plan(task)
        
        result = {
          task: task,
          steps: steps,
          result: steps.join("\n\n"),
          reasoning_trace: [
            {
              step: 1,
              action: "plan",
              action_input: task,
              observation: "Decomposed into #{steps.length} steps: #{steps.join(', ')}"
            }
          ]
        }
        
        yield(result) if block_given? && stream
        result
      end

      # Get the model identifier used by this agent
      # @return [String] model name
      def model
        @model
      end

      # Get the tool manager available to this agent
      # @return [LLMChain::Interfaces::ToolManager] tool manager
      def tools
        nil # Planner doesn't use tools directly
      end

      # Get the memory system used by this agent
      # @return [LLMChain::Interfaces::Memory] memory backend
      def memory
        nil # Planner doesn't use memory
      end

      # Get description of agent capabilities
      # @return [String] Agent description
      def description
        "Planner agent that decomposes complex tasks into atomic steps."
      end
    end
  end
end 