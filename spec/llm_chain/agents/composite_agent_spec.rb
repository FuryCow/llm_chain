# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LLMChain::Agents::CompositeAgent do
  let(:model) { "qwen3:1.7b" }
  let(:tools) { LLMChain::Tools::ToolManager.new(tools: []) }
  let(:memory) { LLMChain::Memory::Array.new }
  let(:max_iterations) { 3 }

  describe "#initialize" do
    it "creates planner and executor agents through factory" do
      # Мокаем фабрику агентов
      planner_agent = instance_double(LLMChain::Agents::PlannerAgent)
      react_agent = instance_double(LLMChain::Agents::ReActAgent)
      
      expect(LLMChain::Agents::AgentFactory).to receive(:create)
        .with(type: :planner, model: model)
        .and_return(planner_agent)
      
      expect(LLMChain::Agents::AgentFactory).to receive(:create)
        .with(type: :react, model: model, tools: tools, memory: memory, max_iterations: max_iterations)
        .and_return(react_agent)
      
      agent = described_class.new(
        model: model,
        tools: tools,
        memory: memory,
        max_iterations: max_iterations
      )
      
      expect(agent.planner).to eq(planner_agent)
      expect(agent.executor).to eq(react_agent)
    end
  end

  describe "#run" do
    let(:agent) { described_class.new(model: model, tools: tools, memory: memory, max_iterations: max_iterations) }
    let(:planner_agent) { instance_double(LLMChain::Agents::PlannerAgent) }
    let(:react_agent) { instance_double(LLMChain::Agents::ReActAgent) }
    
    before do
      agent.instance_variable_set(:@planner, planner_agent)
      agent.instance_variable_set(:@executor, react_agent)
    end

    it "decomposes task and executes each step" do
      task = "Find the president of the US and the capital of France"
      steps = ["Find the president of the US", "Find the capital of France"]
      
      # Мокаем планировщик
      planning_result = {
        task: task,
        steps: steps,
        result: steps.join("\n\n"),
        reasoning_trace: []
      }
      
      expect(planner_agent).to receive(:run)
        .with(task, stream: false)
        .and_return(planning_result)
      
      # Мокаем исполнителя для каждого шага
      step1_result = {
        task: steps[0],
        final_answer: "Joe Biden",
        reasoning_trace: [],
        iterations: 1,
        success: true
      }
      
      step2_result = {
        task: steps[1],
        final_answer: "Paris",
        reasoning_trace: [],
        iterations: 1,
        success: true
      }
      
      expect(react_agent).to receive(:run)
        .with(steps[0], stream: false)
        .and_return(step1_result)
      
      expect(react_agent).to receive(:run)
        .with(steps[1], stream: false)
        .and_return(step2_result)
      
      result = agent.run(task)
      
      expect(result[:task]).to eq(task)
      expect(result[:final_answer]).to include("Joe Biden")
      expect(result[:final_answer]).to include("Paris")
      expect(result[:success]).to be true
      expect(result[:iterations]).to eq(2)
      expect(result[:planning_result]).to eq(planning_result)
      expect(result[:execution_results]).to eq([step1_result, step2_result])
    end

    it "handles streaming" do
      task = "Find the president and the capital"
      steps = ["Find the president", "Find the capital"]
      
      planning_result = {
        task: task,
        steps: steps,
        result: steps.join("\n\n"),
        reasoning_trace: []
      }
      
      step1_result = {
        task: "Find the president",
        final_answer: "Joe Biden",
        reasoning_trace: [],
        iterations: 1,
        success: true
      }
      
      step2_result = {
        task: "Find the capital",
        final_answer: "Paris",
        reasoning_trace: [],
        iterations: 1,
        success: true
      }
      
      expect(planner_agent).to receive(:run)
        .with(task, stream: true)
        .and_return(planning_result)
      
      expect(react_agent).to receive(:run)
        .with("Find the president", stream: true)
        .and_return(step1_result)
      
      expect(react_agent).to receive(:run)
        .with("Find the capital", stream: true)
        .and_return(step2_result)
      
      yielded_data = []
      agent.run(task, stream: true) { |data| yielded_data << data }
      
      expect(yielded_data).to include(
        hash_including(
          step: 1,
          total_steps: 2,
          current_step: "Find the president",
          step_result: step1_result,
          type: "step_completion"
        )
      )
    end
  end

  describe "#can_handle?" do
    let(:agent) { described_class.new(model: model, tools: tools, memory: memory) }
    let(:planner_agent) { instance_double(LLMChain::Agents::PlannerAgent) }
    let(:react_agent) { instance_double(LLMChain::Agents::ReActAgent) }
    
    before do
      agent.instance_variable_set(:@planner, planner_agent)
      agent.instance_variable_set(:@executor, react_agent)
    end

    it "returns true if planner can handle the task" do
      expect(planner_agent).to receive(:can_handle?).with("test task").and_return(true)
      expect(react_agent).not_to receive(:can_handle?)
      
      expect(agent.can_handle?("test task")).to be true
    end

    it "returns true if executor can handle the task" do
      expect(planner_agent).to receive(:can_handle?).with("test task").and_return(false)
      expect(react_agent).to receive(:can_handle?).with("test task").and_return(true)
      
      expect(agent.can_handle?("test task")).to be true
    end

    it "returns false if neither can handle the task" do
      expect(planner_agent).to receive(:can_handle?).with("test task").and_return(false)
      expect(react_agent).to receive(:can_handle?).with("test task").and_return(false)
      
      expect(agent.can_handle?("test task")).to be false
    end
  end

  describe "#description" do
    it "returns agent description" do
      agent = described_class.new(model: model, tools: tools, memory: memory)
      expect(agent.description).to eq("Composite agent with intelligent planning and execution capabilities for complex multi-step tasks")
    end
  end
end 