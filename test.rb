# test.rb
require 'bundler/setup'
require 'llm_chain'

memory = LLMChain::Memory::Array.new(max_size: 1)
chain = LLMChain::Chain.new(model: "qwen3:1.7b", memory: memory)

# Первый запрос
puts chain.ask("Привет!") # => "Привет! Как я могу помочь?"

puts chain.ask("Как дела?")

puts chain.ask("расскажи про компьютеры")

puts chain.ask("расскажи про руби")

# chain = LLMChain::Chain.new(model: "qwen:0.5b")
# puts chain.ask("Привет!")
