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
chain = LLMChain::Chain.new(model: "qwen3:1.7b", memory: memory, retriever: false)
# retriever: false is required when you don't use a vector database to store context or external data
# reitriever: - is set to WeaviateRetriever.new as default  so you need to pass an external params to set Weaviate host
puts chain.ask("What is 2+2?")
```

Using redis as redistributed memory store:

```ruby
# redis_url: 'redis://localhost:6379' is default or either set REDIS_URL env var
# max_size: 10 is default
# namespace: 'llm_chain' is default
memory = LLMChain::Memory::Redis.new(redis_url: 'redis://localhost:6379', max_size: 10, namespace: 'my_app')

chain = LLMChain::Chain.new(model: "qwen3:1.7b", memory: memory)
puts chain.ask("What is 2+2?")
```

Model-specific Clients:

```ruby
# Qwen with custom options (Without RAG support)
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

## Supported Models

| Model Family | Backend/Service | Notes |
|-------------|----------------|-------|
| OpenAI (GPT-3.5, GPT-4) | Web API | Supports all OpenAI API models (Not tested) |
| LLaMA2 (7B, 13B, 70B) | Ollama | Local inference via Ollama |
| Qwen/Qwen3 (0.5B-72B) | Ollama | Supports all Qwen model sizes |
| Mistral/Mixtral | Ollama | Including Mistral 7B and Mixtral 8x7B (In progress) |
| Gemma (2B, 7B) | Ollama | Google's lightweight models (In progress) |
| Claude (Haiku, Sonnet, Opus) | Anthropic API | Web API access (In progress) |
| Command R+ | Cohere API | Optimized for RAG (In progress) |

## Retrieval-Augmented Generation (RAG) 

```ruby
# Initialize components
embedder = LLMChain::Embeddings::Clients::Local::OllamaClient.new(model: "nomic-embed-text")
rag_store = LLMChain::Embeddings::Clients::Local::WeaviateVectorStore.new(embedder: embedder, weaviate_url: 'http://localhost:8080') # Replace with your Weaviate URL if needed
retriever = LLMChain::Embeddings::Clients::Local::WeaviateRetriever.new(embedder: embedder)
memory = LLMChain::Memory::Array.new
tools = []

# Create chain
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  memory: memory, # LLMChain::Memory::Array.new is default
  tools: tools, # There is no tools supported yet
  retriever: retriever # LLMChain::Embeddings::Clients::Local::WeaviateRetriever.new is default
)

# simple Chain definition, with default settings

simple_chain = LLMChain::Chain.new(model: "qwen3:1.7b")

# Example of adding documents to vector database
documents = [
  {
    text: "Ruby supports four OOP principles: encapsulation, inheritance, polymorphism and abstraction",
    metadata: { source: "ruby-docs", page: 42 }
  },
  {
    text: "Modules in Ruby are used for namespaces and mixins",
    metadata: { source: "ruby-guides", author: "John Doe" }
  },
  {
    text: "2 + 2 is equals to 4",
    matadata: { source: 'mad_brain', author: 'John Doe' }
  }
]

# Ingest documents into Weaviate
documents.each do |doc|
  rag_store.add_document(
    text: doc[:text],
    metadata: doc[:metadata]
  )
end

# Simple query without RAG
response = chain.ask("What is 2+2?", rag_context: false) # rag_context: false is default
puts response

# Query with RAG context
response = chain.ask(
  "What OOP principles does Ruby support?",
  rag_context: true,
  rag_options: { limit: 3 }
)
puts response

# Streamed response with RAG
chain.ask("Explain Ruby modules", stream: true, rag_context: true) do |chunk|
  print chunk
end
```

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