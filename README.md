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

# Initialize client
client = LLMChain::Clients::Qwen.new

# Simple chat
response = client.chat("Explain quantum entanglement")
puts response
```

Model-specific Clients:

```ruby
# Qwen with custom options
qwen = LLMChain::Clients::Qwen.new(
  model: "qwen:14b",
  temperature: 0.8,
  top_p: 0.95
)
puts qwen.chat("Write Ruby code for Fibonacci sequence")

# Llama2 with context length
llama = LLMChain::Clients::Llama2.new(num_ctx: 4096)
llama.chat("Explain the CAP theorem")
```

Streaming Responses:

```ruby
LLMChain::Clients::Mistral.new.stream_chat("Describe UNIX architecture") do |chunk|
  print chunk
end
```

Chain pattern:

```ruby
chain = LLMChain::Chain.new(
  model: "llama2:70b",
  memory: LLMChain::Memory::Redis.new,
  tools: [CalculatorTool, WebSearchTool]
)

# Conversation with context
chain.ask("What's 2^10?")
chain.ask("Now multiply that by 5")
```

## Supported models

OpenAI - Web
LLama2 - ollama
Qwen - ollama

## Error handling

```ruby
begin
  client.chat("Explain DNS")
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