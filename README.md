# LLMChain

A Ruby gem for interacting with Large Language Models (LLMs) through a unified interface, with native Ollama and local model support.

[![Gem Version](https://badge.fury.io/rb/llm_chain.svg)](https://badge.fury.io/rb/llm_chain)
[![Tests](https://github.com/your_username/llm_chain/actions/workflows/tests.yml/badge.svg)](https://github.com/your_username/llm_chain/actions)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## Features

- Unified interface for multiple LLMs (Qwen, Llama2, Mistral, etc.)
- Native [Ollama](https://ollama.ai/) integration for local models
- Prompt templating system
- Streaming response support
- RAG-ready with vector database integration
- Automatic model verification

## Installation

Add to your Gemfile:

```ruby
gem 'llm_chain'
```
Or install directly:

```
gem install llm_chain
```

## Prerequisites
Install [Ollama](https://ollama.ai/)

Pull desired models:

```bash
ollama pull qwen:7b
ollama pull llama2:13b
```

## Usage

basic example:

```ruby
require 'llm_chain'

memory = LLMChain::Memory::Array.new(max_size: 1)
chain = LLMChain::Chain.new(model: "qwen3:1.7b", memory: memory)
```

Model-specific Clients:

```ruby
# Qwen with custom options
qwen = LLMChain::Clients::Qwen.new(
  model: "qwen3:1.7b",
  temperature: 0.8,
  top_p: 0.95
)
puts qwen.chat("Write Ruby code for Fibonacci sequence")
```

Streaming Responses:

```ruby
LLMChain::Chain.new(model: "qwen3:1.7b").ask('How are you?', stream: true) do |chunk|
  print chunk
end
```

Chain pattern:

```ruby
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  memory: LLMChain::Memory::Array.new
)

# Conversation with context
chain.ask("What's 2^10?")
chain.ask("Now multiply that by 5")
```

## Supported models

OpenAI - Web\n
LLama2 - ollama\n
Qwen/Qwen3 - ollama\n

## Error handling

```ruby
begin
  chain.ask("Explain DNS")
rescue LLMChain::Error => e
  puts "Error: #{e.message}"
  # Auto-fallback logic can be implemented here
end
```

## Contributing
Bug reports and pull requests are welcome on GitHub at:
https://github.com/FuryCow/llm_chain

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).