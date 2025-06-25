#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🛠️  LLMChain Tools Demo"
puts "=" * 40

# 1. Individual Tool Usage
puts "\n1. 🧮 Calculator Tool"
calculator = LLMChain::Tools::Calculator.new

# Test mathematical expressions
examples = [
  "15 * 7 + 3",
  "sqrt(144)",
  "2 * 2 * 2"
]

examples.each do |expr|
  result = calculator.call("Calculate: #{expr}")
  puts "📊 #{result[:formatted]}"
end

# 2. Web Search Tool
puts "\n2. 🔍 Web Search Tool"
search = LLMChain::Tools::WebSearch.new

search_queries = [
  "Ruby programming language",
  "Machine learning basics"
]

search_queries.each do |query|
  puts "\n🔍 Searching: #{query}"
  result = search.call(query)
  
  if result[:results] && result[:results].any?
    puts "Found #{result[:count]} results:"
    result[:results].first(2).each_with_index do |item, i|
      puts "  #{i+1}. #{item[:title]}"
      puts "     #{item[:url]}" if item[:url]
    end
  else
    puts "No results found"
  end
end

# 3. Code Interpreter Tool
puts "\n3. 💻 Code Interpreter Tool"
interpreter = LLMChain::Tools::CodeInterpreter.new

# Test Ruby code execution
ruby_examples = [
  <<~RUBY,
    ```ruby
    # Simple Fibonacci calculation
    a, b = 0, 1
    result = [a, b]
    8.times do
      c = a + b
      result << c
      a, b = b, c
    end
    
    puts "Fibonacci sequence (first 10 numbers):"
    puts result.join(" ")
    ```
  RUBY
  
  <<~RUBY
    ```ruby
    # Data analysis example
    numbers = [23, 45, 67, 89, 12, 34, 56, 78]
    
    puts "Dataset: \#{numbers}"
    puts "Sum: \#{numbers.sum}"
    puts "Average: \#{numbers.sum.to_f / numbers.size}"
    puts "Max: \#{numbers.max}"
    puts "Min: \#{numbers.min}"
    ```
  RUBY
]

ruby_examples.each_with_index do |code, i|
  puts "\n💻 Ruby Example #{i+1}:"
  begin
    result = interpreter.call(code)
    
    if result.is_a?(Hash) && result[:result]
      puts "✅ Output:"
      puts result[:result]
    elsif result.is_a?(Hash) && result[:error]
      puts "❌ Error: #{result[:error]}"
    else
      puts "📝 #{result}"
    end
  rescue => e
    puts "❌ Execution error: #{e.message}"
  end
end

# 4. Tool Manager Usage
puts "\n4. 🎯 Tool Manager"
tool_manager = LLMChain::Tools::ToolManager.create_default_toolset

puts "Registered tools: #{tool_manager.list_tools.map(&:name).join(', ')}"

# Test tool matching
test_prompts = [
  "What is 25 squared?",
  "Find information about Ruby gems",
  "Run this code: puts 'Hello World'"
]

test_prompts.each do |prompt|
  puts "\n🎯 Testing: \"#{prompt}\""
  matched_tools = tool_manager.list_tools.select { |tool| tool.match?(prompt) }
  
  if matched_tools.any?
    puts "   Matched tools: #{matched_tools.map(&:name).join(', ')}"
    
    # Execute with first matched tool
    tool = matched_tools.first
    result = tool.call(prompt)
    puts "   Result: #{result[:formatted] || result.inspect}"
  else
    puts "   No tools matched"
  end
end

# 5. LLM Chain with Tools
puts "\n5. 🤖 LLM Chain with Tools"

begin
  # Create chain with tools (but without retriever for local testing)
  chain = LLMChain::Chain.new(
    model: "qwen3:1.7b",
    tools: tool_manager,
    retriever: false  # Disable RAG for this example
  )
  
  # Test queries that should trigger tools
  test_queries = [
    "Calculate the area of a circle with radius 5 (use pi = 3.14159)",
    "What's the latest news about Ruby programming?",
    "Execute this Ruby code: puts (1..100).select(&:even?).sum"
  ]
  
  test_queries.each_with_index do |query, i|
    puts "\n🤖 Query #{i+1}: #{query}"
    puts "🔄 Processing..."
    
    response = chain.ask(query)
    puts "📝 Response: #{response}"
    puts "-" * 40
  end
  
rescue => e
  puts "❌ Error with LLM Chain: #{e.message}"
  puts "💡 Make sure Ollama is running with qwen3:1.7b model"
end

# 6. Custom Tool Example
puts "\n6. 🔧 Custom Tool Example"

# Create a simple DateTime tool
class DateTimeTool < LLMChain::Tools::BaseTool
  def initialize
    super(
      name: "datetime",
      description: "Gets current date and time information",
      parameters: {
        format: { 
          type: "string", 
          description: "Date format (optional)" 
        }
      }
    )
  end

  def match?(prompt)
    contains_keywords?(prompt, ['time', 'date', 'now', 'current', 'today'])
  end

  def call(prompt, context: {})
    now = Time.now
    
    # Try to detect desired format from prompt
    format = if prompt.match?(/iso|standard/i)
               now.iso8601
             elsif prompt.match?(/human|readable/i)
               now.strftime("%B %d, %Y at %I:%M %p")
             else
               now.to_s
             end
    
    {
      timestamp: now.to_i,
      formatted_time: format,
      timezone: now.zone,
      formatted: "Current time: #{format} (#{now.zone})"
    }
  end
end

# Test custom tool
datetime_tool = DateTimeTool.new
time_queries = [
  "What time is it now?",
  "Give me current date in human readable format",
  "Show me the current time in ISO format"
]

time_queries.each do |query|
  puts "\n🕐 Query: #{query}"
  if datetime_tool.match?(query)
    result = datetime_tool.call(query)
    puts "   #{result[:formatted]}"
  else
    puts "   Query didn't match datetime tool"
  end
end

# 7. Configuration-based Tool Setup
puts "\n7. ⚙️  Configuration-based Tools"

tools_config = [
  { 
    class: 'calculator' 
  },
  { 
    class: 'web_search',
    options: { 
      search_engine: :duckduckgo 
    }
  },
  { 
    class: 'code_interpreter',
    options: { 
      timeout: 30,
      allowed_languages: ['ruby', 'python'] 
    }
  }
]

config_tool_manager = LLMChain::Tools::ToolManager.from_config(tools_config)
puts "Tools from config: #{config_tool_manager.list_tools.map(&:name).join(', ')}"

# Test configuration-based setup
config_result = config_tool_manager.execute_tool('calculator', 'What is 99 * 99?')
puts "Config test result: #{config_result[:formatted]}" if config_result

puts "\n" + "=" * 40
puts "✨ Tools demo completed!"
puts "\nTry running the chain with: ruby -I lib examples/quick_demo.rb" 