#!/usr/bin/env ruby

require_relative '../lib/llm_chain'

puts "🛠️  LLMChain Tools Demo"
puts "=" * 40

puts "\n1. 🧮 Calculator Tool"
calculator = LLMChain::Tools::Calculator.new

examples = [
  "15 * 7 + 3",
  "sqrt(144)",
  "2 * 2 * 2"
]

examples.each do |expr|
  result = calculator.call("Calculate: #{expr}")
  puts "📊 #{result[:formatted]}"
end

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

puts "\n3. 💻 Code Interpreter Tool"
interpreter = LLMChain::Tools::CodeInterpreter.new

ruby_examples = [
  <<~RUBY,
    ```ruby
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