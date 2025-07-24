#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🚀 Improved CompositeAgent Final Demo"
puts "=" * 50

agent = LLMChain::Agents::AgentFactory.create(
  type: :composite,
  model: "qwen3:1.7b",
  max_iterations: 3
)

puts "✅ Improved agent created successfully"
puts "Model: #{agent.model}"
puts "Description: #{agent.description}"
puts

puts "🎯 Test 1: Simple Math Task (Direct Execution)"
task1 = "Calculate 2 + 2"
puts "Task: #{task1}"

begin
  result1 = agent.run(task1)
  puts "✅ Result: #{result1[:final_answer]}"
  puts "✅ Success: #{result1[:success]}"
  puts "✅ Iterations: #{result1[:iterations]}"
  puts "✅ Approach: #{result1[:approach]}"
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n" + "=" * 60

puts "🎯 Test 2: Simple Time Task (Direct Execution)"
task2 = "What time is it?"
puts "Task: #{task2}"

begin
  result2 = agent.run(task2)
  puts "✅ Result: #{result2[:final_answer]}"
  puts "✅ Success: #{result2[:success]}"
  puts "✅ Iterations: #{result2[:iterations]}"
  puts "✅ Approach: #{result2[:approach]}"
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n" + "=" * 60

puts "🎯 Test 3: Complex Task (Planning)"
task3 = "Find the current president of the United States and the capital of France"
puts "Task: #{task3}"

begin
  result3 = agent.run(task3, stream: true) do |step|
    if step[:type] == "step_completion"
      puts "  📋 Step #{step[:step]}/#{step[:total_steps]}: #{step[:current_step]}"
      if step[:validated_answer]
        puts "    ✅ Validated: #{step[:validated_answer][:processed_answer][0..80]}..."
        puts "    📊 Quality Score: #{step[:validated_answer][:quality_score]}/10"
      end
    end
  end

  puts "\n📊 Final Result:"
  puts "✅ Answer: #{result3[:final_answer][0..200]}..."
  puts "✅ Success: #{result3[:success]}"
  puts "✅ Total iterations: #{result3[:iterations]}"
  puts "✅ Planning steps: #{result3[:planning_result][:steps].length}"
  puts "✅ Validated answers: #{result3[:validated_answers]&.length || 0}"
  
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n" + "=" * 60

puts "🎯 Test 4: Performance Comparison"
task4 = "Calculate 15 * 7 + 32"

react_agent = LLMChain::Agents::AgentFactory.create(
  type: :react,
  model: "qwen3:1.7b",
  max_iterations: 3
)

puts "Task: #{task4}"

puts "\n📋 ReAct Agent:"
begin
  react_result = react_agent.run(task4)
  puts "✅ Result: #{react_result[:final_answer]}"
  puts "✅ Success: #{react_result[:success]}"
  puts "✅ Iterations: #{react_result[:iterations]}"
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n📋 Improved Composite Agent:"
begin
  composite_result = agent.run(task4)
  puts "✅ Result: #{composite_result[:final_answer]}"
  puts "✅ Success: #{composite_result[:success]}"
  puts "✅ Iterations: #{composite_result[:iterations]}"
  puts "✅ Approach: #{composite_result[:approach]}"
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n🎉 Demo completed!"
puts
puts "📋 Key Improvements Achieved:"
puts "1. ✅ Smart planning detection - simple tasks use direct execution"
puts "2. ✅ Result validation - filters out error responses"
puts "3. ✅ Quality scoring - rates answer quality (0-10)"
puts "4. ✅ Smart aggregation - structures multi-part responses"
puts "5. ✅ Better success validation - checks completeness of complex tasks"
puts "6. ✅ Meaningful info extraction - extracts relevant data from responses"
puts "7. ✅ Efficient execution - no unnecessary planning for simple tasks"
puts "8. ✅ Better error handling - graceful handling of failed steps" 