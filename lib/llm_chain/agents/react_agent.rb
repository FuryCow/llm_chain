# frozen_string_literal: true

require_relative '../interfaces/agent'
require_relative '../client_registry'

module LLMChain
  module Agents
    # ReAct Agent implements the Reasoning + Acting paradigm
    # 
    # The agent follows this cycle:
    # 1. **Reasoning**: Analyze the task and plan steps
    # 2. **Acting**: Execute tools based on the plan
    # 3. **Observing**: Evaluate results and adjust plan
    # 4. **Repeating**: Continue until task completion
    #
    # @example Basic usage
    #   agent = ReActAgent.new(
    #     model: "qwen3:1.7b",
    #     tools: ToolManagerFactory.create_default_toolset,
    #     max_iterations: 5
    #   )
    #   
    #   result = agent.run("Find the weather in Moscow and calculate the average temperature for the week")
    class ReActAgent < LLMChain::Interfaces::Agent

      attr_reader :model, :tools, :memory, :max_iterations, :client

      # Initialize ReAct agent
      # @param model [String] LLM model identifier
      # @param tools [LLMChain::Interfaces::ToolManager] tool manager
      # @param memory [LLMChain::Interfaces::Memory] memory backend
      # @param max_iterations [Integer] maximum reasoning iterations
      # @param client_options [Hash] additional client options
      def initialize(model:, tools:, memory: nil, max_iterations: 3, **client_options)
        @model = model
        @tools = tools
        @memory = memory || LLMChain::Memory::Array.new
        @max_iterations = max_iterations
        @client = LLMChain::ClientRegistry.client_for(@model, **client_options)
      end

      # Execute a task using ReAct methodology
      # @param task [String] the task to accomplish
      # @param stream [Boolean] whether to stream reasoning steps
      # @yield [Hash] reasoning step information
      # @return [Hash] final result with reasoning trace
      def run(task, stream: false, &block)
        # Special case: if asking about available tools, return immediately
        if task.downcase.include?("tools") && (task.downcase.include?("available") || task.downcase.include?("which"))
          return {
            task: task,
            final_answer: "Available tools: #{@tools.list_tools.map(&:name).join(', ')}",
            reasoning_trace: [],
            iterations: 0,
            success: true
          }
        end
        
        reasoning_trace = []
        current_state = { task: task, observations: [] }
        failed_actions = {}  # Track failed actions to avoid repetition
        
        @max_iterations.times do |iteration|
          # Step 1: Reasoning - Analyze current state and plan next action
          reasoning_step = reason(current_state, reasoning_trace, failed_actions)
          reasoning_trace << reasoning_step
          
          yield reasoning_step if block_given? && stream
          
          # Step 2: Acting - Execute planned action
          action_result = act(reasoning_step)
          reasoning_trace.last[:action_result] = action_result
          
          # Step 3: Observing - Update state with results
          current_state[:observations] << action_result
          
          # Track failed actions
          if !action_result[:success] || action_result[:formatted].include?("error")
            action_key = "#{reasoning_step[:action]}:#{reasoning_step[:action_input]}"
            failed_actions[action_key] = (failed_actions[action_key] || 0) + 1
          end
          
          # Step 4: Check if task is complete
          if reasoning_step[:thought].include?("FINAL ANSWER") || 
             reasoning_step[:thought].include?("Task completed") ||
             (action_result[:success] && !action_result[:formatted].include?("error") && 
              action_result[:formatted].length > 100 && !action_result[:formatted].include?("timezone"))
            break
          end
          
          # Stop if too many failures
          if failed_actions.values.any? { |count| count >= 3 }
            break
          end
        end
        
        # Extract final answer from reasoning trace
        final_answer = extract_final_answer(reasoning_trace)
        
        {
          task: task,
          final_answer: final_answer,
          reasoning_trace: reasoning_trace,
          iterations: reasoning_trace.length,
          success: !final_answer.nil? && !final_answer.empty? && !final_answer.include?("error")
        }
      end

      # Check if this agent can handle the given task
      # @param task [String] task description
      # @return [Boolean] whether this agent can handle the task
      def can_handle?(task)
        # ReAct agent can handle complex multi-step tasks
        task.include?("analyze") || 
        task.include?("find") && task.include?("and") ||
        task.include?("calculate") && task.include?("and") ||
        task.length > 50  # Long tasks likely need reasoning
      end

      # Get description of agent capabilities
      # @return [String] agent description
      def description
        "ReAct agent with reasoning and acting capabilities for complex multi-step tasks"
      end

      private

      # Generate reasoning step based on current state
      # @param state [Hash] current state including task and observations
      # @param trace [Array] previous reasoning steps
      # @param failed_actions [Hash] tracking of failed actions
      # @return [Hash] reasoning step with thought and action
      def reason(state, trace, failed_actions)
        prompt = build_reasoning_prompt(state, trace, failed_actions)
        response = @client.chat(prompt)
        parsed = parse_reasoning_response(response)
        
        {
          iteration: trace.length + 1,
          thought: parsed[:thought],
          action: parsed[:action],
          action_input: parsed[:action_input],
          timestamp: Time.now
        }
      end

      # Execute the planned action using available tools
      # @param reasoning_step [Hash] the reasoning step with action details
      # @return [Hash] action execution result
      def act(reasoning_step)
        action = reasoning_step[:action]
        action_input = reasoning_step[:action_input]
        
        return { success: false, error: "No action specified" } unless action
        
        tool = @tools.get_tool(action)
        return { success: false, error: "Tool '#{action}' not found" } unless tool
        
        begin
          result = tool.call(action_input)
          {
            success: true,
            tool: action,
            input: action_input,
            result: result,
            formatted: tool.format_result(result)
          }
        rescue => e
          {
            success: false,
            tool: action,
            input: action_input,
            error: e.message
          }
        end
      end

      # Build prompt for reasoning step
      # @param state [Hash] current state
      # @param trace [Array] reasoning trace
      # @param failed_actions [Hash] tracking of failed actions
      # @return [String] formatted prompt
      def build_reasoning_prompt(state, trace, failed_actions)
        tools_description = @tools.tools_description
        observations = state[:observations].map { |obs| obs[:formatted] }.join("\n")
        
        failed_actions_info = if failed_actions.any?
          "Failed actions (avoid repeating):\n" + 
          failed_actions.map { |action, count| "  #{action} (failed #{count} times)" }.join("\n")
        else
          "No failed actions yet"
        end
        
        <<~PROMPT
          You are a ReAct agent. Your task is: #{state[:task]}

          Available tools:
          #{tools_description}

          Previous observations:
          #{observations.empty? ? "None" : observations}

          #{failed_actions_info}

          Instructions:
          - For calculations: Use calculator tool, then provide FINAL ANSWER
          - For web searches: Use web_search tool, maximize requests as much as possible to get the most relevant information
          - For dates and time: Use date_time tool with empty input or timezone name (e.g., "Moscow", "New York")
          - For multiple timezones: Use date_time tool multiple times, once for each timezone
          - For current information searches: ALWAYS first use date_time tool to get current date, then use web_search with current year
          - For questions about current subjects, or recent events: First get current date with date_time, then search
          - If you need to pass a date to web_search, use date_time tool to get the date in the correct format
          - For code: Use code_interpreter tool
          - For multi-step tasks (with "and"): Complete ALL steps before FINAL ANSWER
          - After getting a good result, provide FINAL ANSWER
          - Don't repeat failed actions
          - Summarize the result in a few words
          
          IMPORTANT: When searching for current information (recent events), 
          you MUST first use date_time tool to get the current year, then include that year in your web_search query.

          Format:
          Thought: [brief reasoning]
          Action: [tool_name]
          Action Input: [input]

          Or when done:
          Thought: [reasoning]
          FINAL ANSWER: [answer]
        PROMPT
      end

      # Format reasoning trace for prompt
      # @param trace [Array] reasoning trace
      # @return [String] formatted trace
      def format_reasoning_trace(trace)
        return "None" if trace.empty?
        
        trace.map do |step|
          "Step #{step[:iteration]}: #{step[:thought]}"
        end.join("\n")
      end

      # Parse LLM response to extract reasoning components
      # @param response [String] LLM response
      # @return [Hash] parsed thought, action, and action_input
      def parse_reasoning_response(response)
        # Try to extract structured response
        if response.include?("Thought:") && response.include?("Action:")
          thought_match = response.match(/Thought:\s*(.*?)(?=Action:|$)/m)
          action_match = response.match(/Action:\s*(\w+)/)
          input_match = response.match(/Action Input:\s*(.*?)(?=\n|$)/m)
          
          action_input = input_match&.[](1)&.strip
          
          # Clean up action input - remove markdown code blocks if present
          if action_input&.start_with?("```")
            action_input = action_input.gsub(/^```\w*\n/, "").gsub(/\n```$/, "")
          end
          
          {
            thought: thought_match&.[](1)&.strip || response,
            action: action_match&.[](1),
            action_input: action_input
          }
        else
          # Fallback: treat entire response as thought
          {
            thought: response,
            action: nil,
            action_input: nil
          }
        end
      end

      # Extract final answer from reasoning trace
      # @param trace [Array] reasoning trace
      # @return [String] final answer
      def extract_final_answer(trace)
        # Look for FINAL ANSWER in the last reasoning step
        last_step = trace.last
        return nil unless last_step
        
        thought = last_step[:thought]
        if thought.include?("FINAL ANSWER:")
          thought.match(/FINAL ANSWER:\s*(.*)/m)&.[](1)&.strip
        elsif last_step[:action_result]&.[](:success)
          result = last_step[:action_result][:formatted]
          # If result is JSON with error, try to get a better answer
          if result.include?("error")
            # Look for successful results in previous steps
            trace.reverse.each do |step|
              if step[:action_result]&.[](:success) && !step[:action_result][:formatted].include?("error")
                return step[:action_result][:formatted]
              end
            end
            return "Unable to complete task after #{trace.length} attempts"
          else
            result
          end
        else
          thought
        end
      end
    end
  end
end 