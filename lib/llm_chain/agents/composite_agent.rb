# frozen_string_literal: true

require_relative '../interfaces/agent'
require_relative 'agent_factory'
require_relative 'planner_agent'
require_relative 'react_agent'

module LLMChain
  module Agents
    # Composite agent that combines planning and execution capabilities.
    #
    # This agent uses a PlannerAgent to decompose complex tasks into atomic steps,
    # then uses a ReActAgent to execute each step. This provides better handling
    # of multi-step tasks compared to using ReActAgent alone.
    #
    # @example Basic usage
    #   agent = LLMChain::Agents::CompositeAgent.new(
    #     model: "qwen3:1.7b",
    #     tools: tool_manager
    #   )
    #   result = agent.run("Find the president of the US and the capital of France")
    class CompositeAgent < LLMChain::Interfaces::Agent
      attr_reader :model, :tools, :memory, :planner, :executor

      # Initialize the composite agent with planning and execution capabilities.
      # @param model [String] LLM model identifier
      # @param tools [LLMChain::Interfaces::ToolManager] tool manager
      # @param memory [LLMChain::Interfaces::Memory] memory backend
      # @param max_iterations [Integer] maximum reasoning iterations for executor
      # @param client_options [Hash] additional client options
      def initialize(model:, tools:, memory: nil, max_iterations: 3, **client_options)
        @model = model
        @tools = tools
        @memory = memory || LLMChain::Memory::Array.new
        @max_iterations = max_iterations
        
        # Create planner and executor agents through factory
        @planner = AgentFactory.create(
          type: :planner,
          model: @model,
          **client_options
        )
        @executor = AgentFactory.create(
          type: :react,
          model: @model,
          tools: @tools,
          memory: @memory,
          max_iterations: @max_iterations,
          **client_options
        )
      end

      # Execute a task using planning and execution methodology.
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information
      # @return [Hash] final result with reasoning trace
      def run(task, stream: false, &block)
        # Step 1: Determine if task needs planning
        use_planner = should_use_planner?(task)
        
        if use_planner
          # Use planning approach for complex tasks
          run_with_planning(task, stream: stream, &block)
        else
          # Use direct execution for simple tasks
          execute_directly(task, stream: stream, &block)
        end
      end

      # Check if this agent can handle the given task.
      # @param task [String] task description
      # @return [Boolean] whether this agent can handle the task
      def can_handle?(task)
        # Composite agent can handle any task that the planner or executor can handle
        @planner.can_handle?(task) || @executor.can_handle?(task)
      end

      # Get description of agent capabilities.
      # @return [String] agent description
      def description
        "Composite agent with intelligent planning and execution capabilities for complex multi-step tasks"
      end

      private

      # Determine if task should use planning approach
      # @param task [String] the task to analyze
      # @return [Boolean] whether to use planning
      def should_use_planner?(task)
        # Simple tasks that don't need planning
        simple_patterns = [
          /\bcalculate\s+\d+\s*[\+\-\*\/]\s*\d+\b/i,
          /\bwhat\s+is\s+\d+\s*[\+\-\*\/]\s*\d+\b/i,
          /\b\d+\s*[\+\-\*\/]\s*\d+\b/,
          /\bwhat\s+time\s+is\s+it\b/i,
          /\bcurrent\s+time\b/i,
          /\bwhat\s+year\s+is\s+it\b/i,
          /\bcurrent\s+date\b/i,
          /\bwhat\s+time\b/i,
          /\bcurrent\s+date\b/i
        ]
        
        # Complex patterns that need planning
        complex_patterns = [
          /\band\b/i,
          /\bthen\b/i,
          /\bnext\b/i,
          /\bfind\b.*\band\b/i,
          /\bsearch\b.*\band\b/i,
          /\bget\b.*\band\b/i,
          /\bcalculate\b.*\band\b/i,
          /\bwhat\s+is\b.*\band\b/i
        ]
        
        # Check if task matches simple patterns
        return false if simple_patterns.any? { |pattern| task.match?(pattern) }
        
        # Check if task matches complex patterns
        return true if complex_patterns.any? { |pattern| task.match?(pattern) }
        
        # Default to planning for tasks longer than 50 characters
        task.length > 50
      end

      # Run task with planning approach
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information
      # @return [Hash] final result with reasoning trace
      def run_with_planning(task, stream: false, &block)
        # Step 1: Plan - Decompose the task into atomic steps
        planning_result = @planner.run(task, stream: stream, &block)
        steps = planning_result[:steps] || [task]
        
        # Step 2: Execute - Run each step with the executor
        execution_results = []
        validated_answers = []
        
        steps.each_with_index do |step, index|
          step_result = @executor.run(step, stream: stream, &block)
          execution_results << step_result
          
          # Validate and process the result
          validated_answer = validate_and_process_result(step_result, step, index + 1)
          validated_answers << validated_answer if validated_answer
          
          # Yield step completion if streaming
          if block_given? && stream
            yield({
              step: index + 1,
              total_steps: steps.length,
              current_step: step,
              step_result: step_result,
              validated_answer: validated_answer,
              type: "step_completion"
            })
          end
        end
        
        # Step 3: Compile final result with smart aggregation
        final_answer = smart_aggregate_results(validated_answers, task)
        
        {
          task: task,
          final_answer: final_answer,
          reasoning_trace: [
            {
              step: 1,
              action: "plan",
              action_input: task,
              observation: "Decomposed into #{steps.length} steps: #{steps.join(', ')}"
            },
            *execution_results.flat_map { |result| result[:reasoning_trace] }
          ],
          iterations: execution_results.sum { |result| result[:iterations] || 0 },
          success: validate_overall_success(execution_results, validated_answers, task),
          planning_result: planning_result,
          execution_results: execution_results,
          validated_answers: validated_answers
        }
      end

      # Execute task directly without planning
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information
      # @return [Hash] final result with reasoning trace
      def execute_directly(task, stream: false, &block)
        result = @executor.run(task, stream: stream, &block)
        
        {
          task: task,
          final_answer: result[:final_answer],
          reasoning_trace: result[:reasoning_trace],
          iterations: result[:iterations],
          success: result[:success],
          planning_result: { steps: [task] },
          execution_results: [result],
          validated_answers: [],
          approach: "direct"
        }
      end

      # Validate and process execution result
      # @param result [Hash] execution result
      # @param step [String] step description
      # @param step_number [Integer] step number
      # @return [Hash, nil] validated and processed result
      def validate_and_process_result(result, step, step_number)
        return nil unless result[:success] && result[:final_answer]
        
        answer = result[:final_answer]
        
        # Check for error indicators
        error_indicators = [
          "unable to complete",
          "insufficient data",
          "error",
          "failed",
          "please provide",
          "no results found"
        ]
        
        return nil if error_indicators.any? { |indicator| answer.downcase.include?(indicator) }
        
        # Extract meaningful information based on step type
        processed_answer = extract_meaningful_info(answer, step)
        
        {
          step_number: step_number,
          step: step,
          original_answer: answer,
          processed_answer: processed_answer,
          quality_score: calculate_quality_score(answer, step)
        }
      end

      # Extract meaningful information from answer
      # @param answer [String] original answer
      # @param step [String] step description
      # @return [String] processed answer
      def extract_meaningful_info(answer, step)
        # For mathematical calculations, extract the result
        if step.match?(/\b(calculate|add|multiply|divide|subtract)\b/i)
          # Look for numbers in the answer
          numbers = answer.scan(/\d+/).map(&:to_i)
          return numbers.last.to_s if numbers.any?
        end
        
        # For time/date queries, extract the formatted time
        if step.match?(/\b(time|date|year)\b/i) && answer.include?("formatted")
          # Extract the formatted time from JSON
          if match = answer.match(/"formatted":\s*"([^"]+)"/)
            return match[1]
          end
        end
        
        # For web search results, extract the most relevant snippet
        if answer.include?("Search results") && answer.include?("snippet")
          # Extract first meaningful snippet
          if match = answer.match(/"snippet":\s*"([^"]+)"/)
            return match[1].gsub(/\.\.\./, '').strip
          end
        end
        
        # Default: return first 100 characters
        answer.length > 100 ? answer[0..100] + "..." : answer
      end

      # Calculate quality score for answer
      # @param answer [String] answer to score
      # @param step [String] step description
      # @return [Integer] quality score (0-10)
      def calculate_quality_score(answer, step)
        score = 5 # Base score
        
        # Penalize error indicators
        error_indicators = ["unable to complete", "insufficient data", "error", "failed"]
        score -= 3 if error_indicators.any? { |indicator| answer.downcase.include?(indicator) }
        
        # Reward meaningful content
        score += 2 if answer.length > 20
        score += 1 if answer.match?(/\d+/)
        score += 1 if answer.match?(/[A-Za-z]+/)
        
        # Reward specific content types
        score += 2 if step.match?(/\b(calculate|add|multiply)\b/i) && answer.match?(/\d+/)
        score += 2 if step.match?(/\b(time|date)\b/i) && answer.include?("formatted")
        score += 2 if step.match?(/\b(search|find)\b/i) && answer.include?("results")
        
        [score, 10].min # Cap at 10
      end

      # Smart aggregation of results
      # @param validated_answers [Array] validated answers
      # @param original_task [String] original task
      # @return [String] aggregated result
      def smart_aggregate_results(validated_answers, original_task)
        return "Task could not be completed successfully." if validated_answers.empty?
        
        # For single answer, return it directly
        if validated_answers.length == 1
          return validated_answers.first[:processed_answer]
        end
        
        # For multiple answers, create a structured response
        parts = []
        validated_answers.each_with_index do |answer, index|
          parts << "Part #{index + 1}: #{answer[:processed_answer]}"
        end
        
        # Add summary if it's a complex task
        if original_task.match?(/\band\b/i)
          parts << "\nSummary: All requested information has been gathered."
        end
        
        parts.join("\n\n")
      end

      # Validate overall success
      # @param execution_results [Array] execution results
      # @param validated_answers [Array] validated answers
      # @param task [String] original task
      # @return [Boolean] overall success
      def validate_overall_success(execution_results, validated_answers, task)
        # Check if we have any valid answers
        return false if validated_answers.empty?
        
        # For simple tasks, one good answer is enough
        return true unless task.match?(/\band\b/i)
        
        # For complex tasks, we need at least 50% of expected parts
        expected_parts = task.scan(/\band\b/i).length + 1
        actual_parts = validated_answers.length
        
        actual_parts >= (expected_parts * 0.5).ceil
      end
    end
  end
end 