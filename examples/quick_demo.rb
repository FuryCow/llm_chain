#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🦾 LLMChain v#{LlmChain::VERSION} - Quick Demo"
puts "=" * 50

# 1. Simple chain without tools
puts "\n1. 💬 Simple conversation"
begin
  simple_chain = LLMChain::Chain.new(
    model: "qwen3:1.7b",
    retriever: false
  )
  
  response = simple_chain.ask("Hello! Tell me briefly about yourself.")
  puts "🤖 #{response}"
rescue => e
  puts "❌ Error: #{e.message}"
  puts "💡 Make sure Ollama is running and qwen3:1.7b model is downloaded"
end

# 2. Calculator
puts "\n2. 🧮 Built-in calculator"
calculator = LLMChain::Tools::Calculator.new
result = calculator.call("Calculate 25 * 8 + 15")
puts "📊 #{result[:formatted]}"

# 3. Code interpreter
puts "\n3. 💻 Code interpreter"
begin
  interpreter = LLMChain::Tools::CodeInterpreter.new
  ruby_code = <<~RUBY_CODE
    ```ruby
    # Simple program
    data = [1, 2, 3, 4, 5]
    total = data.sum
    puts "Sum of numbers: \#{total}"
    puts "Average: \#{total / data.size.to_f}"
    ```
  RUBY_CODE
  
  code_result = interpreter.call(ruby_code)

  if code_result.is_a?(Hash) && code_result[:result]
    puts "✅ Execution result:"
    puts code_result[:result]
  elsif code_result.is_a?(Hash) && code_result[:error]
    puts "❌ #{code_result[:error]}"
  else
    puts "📝 #{code_result}"
  end
rescue => e
  puts "❌ Interpreter error: #{e.message}"
end

# 4. Web search (may not work without internet)
puts "\n4. 🔍 Web search"
search = LLMChain::Tools::WebSearch.new
search_result = search.call("Ruby programming language")

if search_result.is_a?(Hash) && search_result[:results] && !search_result[:results].empty?
  puts "🌐 Found #{search_result[:count]} results:"
  search_result[:results].first(2).each_with_index do |result, i|
    puts "  #{i+1}. #{result[:title]}"
  end
else
  puts "❌ Search failed or no results found"
end

# 5. Chain with tools
puts "\n5. 🛠️ Chain with automatic tools"
begin
  tool_manager = LLMChain::Tools::ToolManagerFactory.create_default_toolset
  smart_chain = LLMChain::Chain.new(
    model: "qwen3:1.7b",
    tools: tool_manager,
    retriever: false
  )
  
  puts "\n🧮 Math test:"
  math_response = smart_chain.ask("How much is 12 * 15?")
  puts "🤖 #{math_response}"
  
rescue => e
  puts "❌ Tools error: #{e.message}"
end

puts "\n" + "=" * 50
puts "✨ Demo completed!"
puts "\n📖 More examples:"
puts "   - ruby -I lib examples/tools_example.rb"
puts "   - See README.md for complete documentation" 