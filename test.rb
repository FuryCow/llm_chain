# test.rb
require 'bundler/setup'
require 'llm_chain'

chain = LLMChain::Chain.new(model: "qwen:0.5b")
puts chain.ask("Как работает yield в Ruby?")
llama = LLMChain::Clients::Llama2.new(model: "llama2:70b")
response = llama.chat("Write Python code for quicksort", temperature: 0.5)