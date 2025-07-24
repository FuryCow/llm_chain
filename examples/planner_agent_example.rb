#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🧠 Simple PlannerAgent Example"
puts "=" * 40

planner = LLMChain::Agents::AgentFactory.create(
  type: :planner,
  model: "qwen3:1.7b"
)

puts "✅ Planner agent created successfully"
puts "Model: #{planner.model}"
puts "Description: #{planner.description}"
puts

puts "🎯 Example 1: Simple Task"
task1 = "What is 2 + 2?"
puts "Task: #{task1}"

steps1 = planner.plan(task1)
puts "Steps:"
steps1.each_with_index do |step, index|
  puts "  #{index + 1}. #{step}"
end

puts

puts "🎯 Example 2: Multi-Part Task"
task2 = "Find the current president of the United States and the capital of France"
puts "Task: #{task2}"

steps2 = planner.plan(task2)
puts "Steps:"
steps2.each_with_index do |step, index|
  puts "  #{index + 1}. #{step}"
end

puts

puts "🎯 Example 3: Complex Task"
task3 = "Calculate 15 * 7 + 32, find the current time in Moscow, and get the population of Tokyo"
puts "Task: #{task3}"

steps3 = planner.plan(task3)
puts "Steps:"
steps3.each_with_index do |step, index|
  puts "  #{index + 1}. #{step}"
end

puts

puts "🎯 Example 4: Using run() method"
task4 = "What is the current time and what year is it?"
puts "Task: #{task4}"

result4 = planner.run(task4)
puts "Result:"
puts "  Task: #{result4[:task]}"
puts "  Steps: #{result4[:steps].length}"
result4[:steps].each_with_index do |step, index|
  puts "  #{index + 1}. #{step}"
end
puts "  Full result: #{result4[:result]}"

puts

puts "🎯 Example 5: Comparison with ReAct Agent"
puts "Note: PlannerAgent only plans, ReActAgent executes"

react_agent = LLMChain::Agents::AgentFactory.create(
  type: :react,
  model: "qwen3:1.7b",
  max_iterations: 3
)

comparison_task = "What is the current time?"
puts "Task: #{comparison_task}"

puts "\nPlannerAgent result:"
planner_steps = planner.plan(comparison_task)
planner_steps.each_with_index do |step, index|
  puts "  #{index + 1}. #{step}"
end

puts "\nReActAgent result:"
begin
  react_result = react_agent.run(comparison_task)
  puts "  Final answer: #{react_result[:final_answer]}"
  puts "  Iterations: #{react_result[:iterations]}"
  puts "  Success: #{react_result[:success]}"
rescue => e
  puts "  Error: #{e.message}"
end

puts "\n🎉 Example completed!"
puts
puts "📋 Key Points:"
puts "1. PlannerAgent breaks down complex tasks into steps"
puts "2. It doesn't execute tasks, only plans them"
puts "3. Use plan() for just steps, run() for full result"
puts "4. Combine with ReActAgent for execution" 