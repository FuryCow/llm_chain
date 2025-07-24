#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🤖 LLMChain ReAct Agent Example"
puts "=" * 50

agent = LLMChain::Agents::AgentFactory.create(
  type: :react,
  model: "deepseek-coder-v2:16b",
  max_iterations: 10
)

puts "Agent created: #{agent.description}"
puts "Available tools: #{agent.tools.list_tools.map(&:name).join(', ')}"
puts

task = "Calculate 15 * 7 + 32"
puts "🎯 Task: #{task}"
puts "Processing..."

result = agent.run(task, stream: true) do |step|
  puts "  Step #{step[:iteration]}: #{step[:thought]}"
  if step[:action]
    puts "    Action: #{step[:action]} (#{step[:action_input]})"
  end
end

puts
puts "✅ Final Answer: #{result[:final_answer]}"
puts "📊 Iterations: #{result[:iterations]}"
puts "🎯 Success: #{result[:success]}"
puts

task2 = "Who is the president of the United States? and who was the president before him?"
puts "🎯 Complex Task: #{task2}"
puts "Processing..."

result2 = agent.run(task2, stream: true) do |step|
  puts "  Step #{step[:iteration]}: #{step[:thought][0..100]}..."
  if step[:action]
    puts "    Action: #{step[:action]} (#{step[:action_input]})"
  end
end

puts
puts "✅ Final Answer: #{result2[:final_answer]}"
puts "📊 Iterations: #{result2[:iterations]}"
puts "🎯 Success: #{result2[:success]}" 

task3 = "Which tools are available to me?"
puts "🎯 Task: #{task3}"
puts "Processing..."

result3 = agent.run(task3, stream: true) do |step|
  puts "  Step #{step[:iteration]}: #{step[:thought]}"
  if step[:action]
    puts "    Action: #{step[:action]} (#{step[:action_input]})"
  end
end

puts "✅ Final Answer: #{result3[:final_answer]}"
puts "📊 Iterations: #{result3[:iterations]}"
puts "🎯 Success: #{result3[:success]}" 