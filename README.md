# 🦾 LLMChain

[![Gem Version](https://badge.fury.io/rb/llm_chain.svg)](https://badge.fury.io/rb/llm_chain)
[![RSpec](https://github.com/FuryCow/llm_chain/actions/workflows/rspec.yml/badge.svg?branch=master)](https://github.com/FuryCow/llm_chain/actions/workflows/rspec.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

**A powerful Ruby library for working with Large Language Models (LLMs) with intelligent tool system**

**LLMChain** is a powerful Ruby library that brings the magic of Large Language Models to your applications. Think of it as your AI Swiss Army knife - whether you need to chat with models, execute code, search the web, or build intelligent agents, LLMChain has you covered.

Built with Ruby's elegance and designed for developers who want to harness AI capabilities without the complexity, LLMChain provides a unified interface for OpenAI, Ollama, Qwen, and other leading LLMs. It comes packed with intelligent tools, smart agents, and RAG capabilities out of the box.

* 🔄 **Bundler-aware loading** – CLI detects if it’s executed inside the gem repo and avoids version clashes with external Gemfiles.

That’s all you need to start talking to LLMs straight from the terminal. See the **Command-line Interface** section below for usage examples.

## ✨ Key Features

- 🤖 **Unified API** for multiple LLMs (OpenAI, Ollama, Qwen, LLaMA2, Gemma)
- 🧠 **Smart Agents** - CompositeAgent, ReActAgent, PlannerAgent for complex reasoning
- 🛠️ **Intelligent tool system** with automatic selection
- 🧮 **Built-in tools**: Calculator, web search, code interpreter, DateTime
- 🔍 **RAG-ready** with vector database integration
- 💾 **Flexible memory system** (Array, Redis)
- 🌊 **Streaming output** for real-time responses
- 🏠 **Local models** via Ollama
- 🔧 **Extensible architecture** for custom tools

## 🚀 Quick Start

### Installation

```bash
gem install llm_chain
```

Or add to Gemfile:

```ruby
gem 'llm_chain'
```

### Prerequisites

1. **Install Ollama** for local models:
   ```bash
   # macOS/Linux
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Download models
   ollama pull qwen3:1.7b
   ollama pull llama2:7b
   ```

2. **Optional**: API keys for enhanced features
   ```bash
   # For OpenAI models
   export OPENAI_API_KEY="your-openai-key"
   
   # For Google Search (get at console.developers.google.com)
   export GOOGLE_API_KEY="your-google-key"
   export GOOGLE_SEARCH_ENGINE_ID="your-search-engine-id"
   ```

### Simple Example

```ruby
require 'llm_chain'

# Quick start with default tools (v0.5.1+)
chain = LLMChain.quick_chain
response = chain.ask("Hello! How are you?")
puts response

# Or traditional setup
chain = LLMChain::Chain.new(model: "qwen3:1.7b")
response = chain.ask("Hello! How are you?")
puts response
```

## 🖥️ Command-line Interface (v0.5.3+)

Alongside the Ruby API, LLMChain ships with a convenient CLI executable `llm-chain`.

### Basic commands

```bash
# One-off question
llm-chain chat "Hello! How are you?"

# Interactive REPL with conversation memory (/help in session)
llm-chain repl

# System diagnostics (same as LLMChain.diagnose_system)
llm-chain diagnose

# List default tools
llm-chain tools list

# Show gem version
llm-chain -v
```

The CLI is installed automatically with the gem. If your shell doesn’t find the command, make sure RubyGems’ bindir is in your `$PATH` or use Bundler-aware launch:

```bash
bundle exec llm-chain chat "…"
```

Set `LLM_CHAIN_DEBUG=true` to print extra logs.

## 🔍 System Diagnostics (v0.5.2+)

Before diving into development, it's recommended to check your system configuration:

```ruby
require 'llm_chain'

# Run comprehensive system diagnostics
LLMChain.diagnose_system
# 🔍 LLMChain System Diagnostics
# ==================================================
# 📋 System Components:
#   Ruby: ✅ (3.2.2)
#   Python: ✅
#   Node.js: ✅
#   Internet: ✅
#   Ollama: ✅
# 🔑 API Keys:
#   Openai: ❌
#   Google_search: ❌
# 💡 Recommendations:
#   • Configure API keys for enhanced features
#   • Start Ollama server: ollama serve
```

### Configuration Validation

Chains now validate their configuration on startup:

```ruby
# Automatic validation (v0.5.2+)
begin
  chain = LLMChain.quick_chain(model: "qwen3:1.7b")
rescue LLMChain::Error => e
  puts "Configuration issue: #{e.message}"
end

# Disable validation if needed
chain = LLMChain.quick_chain(
  model: "qwen3:1.7b",
  validate_config: false
)

# Manual validation
LLMChain::ConfigurationValidator.validate_chain_config!(
  model: "qwen3:1.7b",
  tools: LLMChain::Tools::ToolManagerFactory.create_default_toolset
)
```

## 🛠️ Tool System

### Automatic Tool Usage

```ruby
# Quick setup (v0.5.1+)
chain = LLMChain.quick_chain

# Tools are selected automatically
chain.ask("Calculate 15 * 7 + 32")
# 🧮 Result: 137

chain.ask("Which is the latest version of Ruby?")
# 🔍 Result: Ruby 3.3.6 (via Google search)

chain.ask("Execute code: puts (1..10).sum")
# 💻 Result: 55

# Traditional setup
tool_manager = LLMChain::Tools::ToolManagerFactory.create_default_toolset
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  tools: tool_manager
)
```

### Built-in Tools

#### 🧮 Calculator
```ruby
calculator = LLMChain::Tools::Calculator.new
result = calculator.call("Find square root of 144")
puts result[:formatted]
# Output: sqrt(144) = 12.0
```

#### 🕐 DateTime (Enhanced in v0.6.0)
```ruby
datetime = LLMChain::Tools::DateTime.new

# Current time
result = datetime.call("What time is it?")
puts result[:formatted]
# Output: 2025-07-24 15:30:45 UTC

# Time in specific timezone
result = datetime.call("What time is it in New York?")
puts result[:formatted]
# Output: 2025-07-24 11:30:45 EDT

# Time in Europe
result = datetime.call("What time is it in Europe/Moscow?")
puts result[:formatted]
# Output: 2025-07-24 18:30:45 MSK

# JSON input support
result = datetime.call('{"timezone": "Asia/Tokyo"}')
puts result[:formatted]
# Output: 2025-07-25 00:30:45 JST
```

#### 🌐 Web Search
```ruby
# Google search for accurate results (v0.5.1+)
search = LLMChain::Tools::WebSearch.new
results = search.call("Latest Ruby version")
puts results[:formatted]
# Output: Ruby 3.3.6 is the current stable version...

# Fallback data available without API keys
search = LLMChain::Tools::WebSearch.new
results = search.call("Which is the latest version of Ruby?")
# Works even without Google API configured
```

#### 💻 Code Interpreter (Enhanced in v0.5.2)
```ruby
interpreter = LLMChain::Tools::CodeInterpreter.new

# Standard markdown blocks
result = interpreter.call(<<~CODE)
  ```ruby
  def factorial(n)
    n <= 1 ? 1 : n * factorial(n - 1)
  end
  puts factorial(5)
  ```
CODE

# Inline code commands (v0.5.2+)
result = interpreter.call("Execute code: puts 'Hello World!'")

# Code without language specification
result = interpreter.call(<<~CODE)
  ```
  numbers = [1, 2, 3, 4, 5]
  puts numbers.sum
  ```
CODE

# Windows line endings support (v0.5.2+)
result = interpreter.call("```ruby\r\nputs 'Windows compatible'\r\n```")

puts result[:formatted]
```

## ⚙️ Configuration (v0.5.2+)

```ruby
# Global configuration
LLMChain.configure do |config|
  config.default_model = "qwen3:1.7b"          # Default LLM model
  config.search_engine = :google               # Google for accurate results
  config.memory_size = 100                     # Memory buffer size
  config.timeout = 30                          # Request timeout (seconds)
end

# Quick chain with default settings
chain = LLMChain.quick_chain

# Override settings per chain (v0.5.2+)
chain = LLMChain.quick_chain(
  model: "gpt-4",
  tools: false,                               # Disable tools
  memory: false,                              # Disable memory
  validate_config: false                      # Skip validation
)
```

### Debug Mode (v0.5.2+)

Enable detailed logging for troubleshooting:

```bash
# Enable debug logging
export LLM_CHAIN_DEBUG=true

# Or in Ruby
ENV['LLM_CHAIN_DEBUG'] = 'true'
```

### Validation and Error Handling (v0.5.2+)

```ruby
# Comprehensive environment check
results = LLMChain::ConfigurationValidator.validate_environment
puts "Ollama available: #{results[:ollama]}"
puts "Internet: #{results[:internet]}"
puts "Warnings: #{results[:warnings]}"

# Chain validation with custom settings
begin
  LLMChain::ConfigurationValidator.validate_chain_config!(
    model: "gpt-4",
    tools: [LLMChain::Tools::Calculator.new, LLMChain::Tools::WebSearch.new]
  )
rescue LLMChain::ConfigurationValidator::ValidationError => e
  puts "Setup issue: #{e.message}"
  # Handle configuration problems
end
```

### Creating Custom Tools

```ruby
class WeatherTool < LLMChain::Tools::BaseTool
  def initialize(api_key:)
    @api_key = api_key
    super(
      name: "weather",
      description: "Gets weather information",
      parameters: {
        location: { 
          type: "string", 
          description: "City name" 
        }
      }
    )
  end

  def match?(prompt)
    contains_keywords?(prompt, ['weather', 'temperature', 'forecast'])
  end

  def call(prompt, context: {})
    location = extract_location(prompt)
    # Your weather API integration
    {
      location: location,
      temperature: "22°C",
      condition: "Sunny",
      formatted: "Weather in #{location}: 22°C, Sunny"
    }
  end

  private

  def extract_location(prompt)
    prompt.scan(/in\s+(\w+)/i).flatten.first || "Unknown"
  end
end

# Usage
weather = WeatherTool.new(api_key: "your-key")
tool_manager = LLMChain::Tools::ToolManagerFactory.create_default_toolset
tool_manager.register_tool(weather)
```

## 🤖 Supported Models

| Model Family | Backend | Status | Notes |
|--------------|---------|--------|-------|
| **OpenAI** | Web API | ✅ Supported | GPT-3.5, GPT-4, GPT-4 Turbo |
| **Qwen/Qwen2** | Ollama | ✅ Supported | 0.5B - 72B parameters |
| **LLaMA2/3** | Ollama | ✅ Supported | 7B, 13B, 70B |
| **Gemma** | Ollama | ✅ Supported | 2B, 7B, 9B, 27B |
| **Deepseek-Coder-V2** | Ollama | ✅ Supported | 16B, 236B - Code specialist |
| **Mistral/Mixtral** | Ollama | ✅ Supported | 7B, 8x7B, Tiny, Small, Medium, Large |
| **Claude** | Anthropic | 🔄 Planned | Haiku, Sonnet, Opus |
| **Command R+** | Cohere | 🔄 Planned | Optimized for RAG |

### Model Usage Examples

```ruby
# OpenAI
openai_chain = LLMChain::Chain.new(
  model: "gpt-4",
  api_key: ENV['OPENAI_API_KEY']
)

# Qwen via Ollama
qwen_chain = LLMChain::Chain.new(model: "qwen3:1.7b")

# LLaMA via Ollama with settings
llama_chain = LLMChain::Chain.new(
  model: "llama2:7b",
  temperature: 0.8,
  top_p: 0.95
)

# Deepseek-Coder-V2 for code tasks
deepseek_chain = LLMChain::Chain.new(model: "deepseek-coder-v2:16b")

# Mistral via Ollama
mistral_chain = LLMChain::Chain.new(model: "mistral:7b")

# Mixtral for complex tasks
mixtral_chain = LLMChain::Chain.new(model: "mixtral:8x7b")

# Direct client usage
deepseek_client = LLMChain::Clients::DeepseekCoderV2.new(model: "deepseek-coder-v2:16b")
response = deepseek_client.chat("Create a Ruby method to sort an array")

mistral_client = LLMChain::Clients::Mistral.new
response = mistral_client.chat("Explain quantum computing in simple terms")
```

## 💾 Memory System

### Array Memory (default)
```ruby
memory = LLMChain::Memory::Array.new(max_size: 10)
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  memory: memory
)

chain.ask("My name is Alex")
chain.ask("What's my name?") # Remembers previous context
```

### Redis Memory (for production)
```ruby
memory = LLMChain::Memory::Redis.new(
  redis_url: 'redis://localhost:6379',
  max_size: 100,
  namespace: 'my_app'
)

chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  memory: memory
)
```

## 🔍 RAG (Retrieval-Augmented Generation)

### Setting up RAG with Weaviate

```ruby
# Initialize components
embedder = LLMChain::Embeddings::Clients::Local::OllamaClient.new(
  model: "nomic-embed-text"
)

vector_store = LLMChain::Embeddings::Clients::Local::WeaviateVectorStore.new(
  embedder: embedder,
  weaviate_url: 'http://localhost:8080'
)

retriever = LLMChain::Embeddings::Clients::Local::WeaviateRetriever.new(
  embedder: embedder
)

# Create chain with RAG
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b",
  retriever: retriever
)
```

### Adding Documents

```ruby
documents = [
  {
    text: "Ruby supports OOP principles: encapsulation, inheritance, polymorphism",
    metadata: { source: "ruby-guide", page: 15 }
  },
  {
    text: "Modules in Ruby are used for namespaces and mixins",
    metadata: { source: "ruby-book", author: "Matz" }
  }
]

# Add to vector database
documents.each do |doc|
  vector_store.add_document(
    text: doc[:text],
    metadata: doc[:metadata]
  )
end
```

### RAG Queries

```ruby
# Regular query
response = chain.ask("What is Ruby?")

# Query with RAG
response = chain.ask(
  "What OOP principles does Ruby support?",
  rag_context: true,
  rag_options: { limit: 3 }
)
```

## 🌊 Streaming Output

```ruby
chain = LLMChain::Chain.new(model: "qwen3:1.7b")

# Streaming with block
chain.ask("Tell me about Ruby history", stream: true) do |chunk|
  print chunk
  $stdout.flush
end

# Streaming with tools
tool_manager = LLMChain::Tools::ToolManagerFactory.create_default_toolset
chain = LLMChain::Chain.new(
  model: "qwen3:1.7b", 
  tools: tool_manager
)

chain.ask("Calculate 15! and explain the process", stream: true) do |chunk|
  print chunk
end
```

## ⚙️ Configuration

### Environment Variables

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."
export OPENAI_ORGANIZATION_ID="org-..."

# Search
export SEARCH_API_KEY="your-search-api-key"
export GOOGLE_SEARCH_ENGINE_ID="your-cse-id"

# Redis
export REDIS_URL="redis://localhost:6379"

# Weaviate
export WEAVIATE_URL="http://localhost:8080"
```

### Tool Configuration

```ruby
# From configuration
tools_config = [
  { 
    class: 'calculator' 
  },
  { 
    class: 'web_search', 
    options: { 
      search_engine: :duckduckgo,
      api_key: ENV['SEARCH_API_KEY']
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

tool_manager = LLMChain::Tools::ToolManagerFactory.from_config(tools_config)
```

### Client Settings

```ruby
# Qwen with custom parameters
qwen = LLMChain::Clients::Qwen.new(
  model: "qwen2:7b",
  temperature: 0.7,
  top_p: 0.9,
  base_url: "http://localhost:11434"
)

# OpenAI with settings
openai = LLMChain::Clients::OpenAI.new(
  model: "gpt-4",
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.8,
  max_tokens: 2000
)
```

## 🔧 Error Handling (Enhanced in v0.5.2)

```ruby
begin
  chain = LLMChain::Chain.new(model: "qwen3:1.7b")
  response = chain.ask("Complex query")
rescue LLMChain::ConfigurationValidator::ValidationError => e
  puts "Configuration issue: #{e.message}"
  # Use LLMChain.diagnose_system to check setup
rescue LLMChain::UnknownModelError => e
  puts "Unknown model: #{e.message}"
  # Check available models with ollama list
rescue LLMChain::ClientError => e
  puts "Client error: #{e.message}"
  # Network or API issues
rescue LLMChain::TimeoutError => e
  puts "Timeout exceeded: #{e.message}"
  # Increase timeout or use faster model
rescue LLMChain::Error => e
  puts "General LLMChain error: #{e.message}"
end
```

### Automatic Retry Logic (v0.5.2+)

WebSearch and other tools now include automatic retry with exponential backoff:

```ruby
# Retry configuration is automatic, but you can observe it:
ENV['LLM_CHAIN_DEBUG'] = 'true'

search = LLMChain::Tools::WebSearch.new
result = search.call("search query")
# [WebSearch] Retrying search (1/3) after 0.5s: Net::TimeoutError
# [WebSearch] Retrying search (2/3) after 1.0s: Net::TimeoutError
# [WebSearch] Search failed after 3 attempts: Net::TimeoutError

# Tools gracefully degrade to fallback methods when possible
puts result[:formatted] # Still provides useful response
```

### Graceful Degradation

```ruby
# Tools handle failures gracefully
calculator = LLMChain::Tools::Calculator.new
web_search = LLMChain::Tools::WebSearch.new
code_runner = LLMChain::Tools::CodeInterpreter.new

# Even with network issues, you get useful responses:
search_result = web_search.call("latest Ruby version")
# Falls back to hardcoded data for common queries

# Safe code execution with timeout protection:
code_result = code_runner.call("puts 'Hello World!'")
# Executes safely with proper sandboxing
```

## 📚 Usage Examples

### Smart Agents (v0.6.0+)

#### CompositeAgent - Intelligent Planning and Execution

```ruby
require 'llm_chain'

# Create a smart composite agent
agent = LLMChain::Agents::AgentFactory.create(
  type: :composite,
  model: "qwen3:1.7b",
  max_iterations: 3
)

# Simple task - direct execution (no planning overhead)
result = agent.run("Calculate 15 * 7 + 32")
puts result[:final_answer]  # "137"
puts result[:approach]      # "direct"

# Complex task - intelligent planning
result = agent.run("Find the current president of the United States and the capital of France", stream: true) do |step|
  if step[:type] == "step_completion"
    puts "Step #{step[:step]}/#{step[:total_steps]}: #{step[:current_step]}"
    puts "Quality: #{step[:validated_answer][:quality_score]}/10"
  end
end

puts result[:final_answer]
# "Joe Biden\n\nParis\n\nSummary: The current president of the United States is Joe Biden, and the capital of France is Paris."
```

#### ReActAgent - Reasoning and Acting

```ruby
# Create a ReAct agent for complex reasoning tasks
react_agent = LLMChain::Agents::AgentFactory.create(
  type: :react,
  model: "qwen3:1.7b",
  max_iterations: 5
)

# Agent will use tools intelligently
result = react_agent.run("What time is it in New York and what's the weather like?")
puts result[:final_answer]
# Uses DateTime tool first, then WebSearch for weather
```

#### PlannerAgent - Task Decomposition

```ruby
# Create a planner agent for complex task breakdown
planner_agent = LLMChain::Agents::AgentFactory.create(
  type: :planner,
  model: "qwen3:1.7b"
)

# Decompose complex task into steps
result = planner_agent.run("Plan a vacation to Japan")
puts result[:planning_result][:steps]
# ["Research popular destinations in Japan", "Check visa requirements", "Find flights", "Book accommodations", "Plan itinerary"]
```

### Chatbot with Tools

```ruby
require 'llm_chain'

class ChatBot
  def initialize
    @tool_manager = LLMChain::Tools::ToolManagerFactory.create_default_toolset
    @memory = LLMChain::Memory::Array.new(max_size: 20)
    @chain = LLMChain::Chain.new(
      model: "qwen3:1.7b",
      memory: @memory,
      tools: @tool_manager
    )
  end

  def chat_loop
    puts "🤖 Hello! I'm an AI assistant with tools. Ask me anything!"
    
    loop do
      print "\n👤 You: "
      input = gets.chomp
      break if input.downcase.in?(['exit', 'quit', 'bye'])

      response = @chain.ask(input, stream: true) do |chunk|
        print chunk
      end
      puts "\n"
    end
  end
end

# Run
bot = ChatBot.new
bot.chat_loop
```

### Data Analysis with Code

```ruby
data_chain = LLMChain::Chain.new(
  model: "qwen3:7b",
  tools: LLMChain::Tools::ToolManagerFactory.create_default_toolset
)

# Analyze CSV data
response = data_chain.ask(<<~PROMPT)
  Analyze this code and execute it:
  
  ```ruby
  data = [
    { name: "Alice", age: 25, salary: 50000 },
    { name: "Bob", age: 30, salary: 60000 },
    { name: "Charlie", age: 35, salary: 70000 }
  ]
  
  average_age = data.sum { |person| person[:age] } / data.size.to_f
  total_salary = data.sum { |person| person[:salary] }
  
  puts "Average age: #{average_age}"
  puts "Total salary: #{total_salary}"
  puts "Average salary: #{total_salary / data.size}"
  ```
PROMPT

puts response
```

## 🧪 Testing

```bash
# Run tests
bundle exec rspec

# Run demo
ruby -I lib examples/tools_example.rb

# Interactive console
bundle exec bin/console
```

## 📖 API Documentation

### Main Classes

- `LLMChain::Chain` - Main class for creating chains
- `LLMChain::Agents::AgentFactory` - Factory for creating smart agents
- `LLMChain::Agents::CompositeAgent` - Intelligent planning and execution
- `LLMChain::Agents::ReActAgent` - Reasoning and acting agent
- `LLMChain::Agents::PlannerAgent` - Task decomposition agent
- `LLMChain::Tools::ToolManager` - Tool management
- `LLMChain::Memory::Array/Redis` - Memory systems
- `LLMChain::Clients::*` - Clients for various LLMs

### Chain Methods

```ruby
chain = LLMChain::Chain.new(options)

# Main method
chain.ask(prompt, stream: false, rag_context: false, rag_options: {})

# Initialization parameters
# - model: model name
# - memory: memory object
# - tools: array of tools or ToolManager
# - retriever: RAG retriever
# - client_options: additional client parameters
```

## 🛣️ Roadmap

### v0.5.2 ✅ Completed
- [x] System diagnostics and health checks
- [x] Configuration validation
- [x] Enhanced error handling with retry logic
- [x] Improved code extraction and tool stability

### v0.6.0 ✅ Completed
- [x] Smart CompositeAgent with intelligent planning
- [x] Enhanced ReActAgent with better tool integration
- [x] Improved DateTime tool with timezone support
- [x] Better error handling and result validation
- [x] Streamlined examples and improved test coverage

### v0.7.0 (Next)
- [ ] More tools (file system, database queries)
- [ ] Claude integration
- [ ] Advanced logging and metrics
- [ ] Multi-agent systems
- [ ] Task planning and workflows
- [ ] Web interface for testing

### v1.0.0
- [ ] Stable API with semantic versioning
- [ ] Complete documentation coverage
- [ ] Production-grade performance

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development

```bash
git clone https://github.com/FuryCow/llm_chain.git
cd llm_chain
bundle install
bundle exec rspec
```

## 📄 License

This project is distributed under the [MIT License](LICENSE.txt).

## 🙏 Acknowledgments

- [Ollama](https://ollama.ai/) team for excellent local LLM platform
- [LangChain](https://langchain.com/) developers for inspiration
- Ruby community for support

---

**Made with ❤️ for Ruby community**

[Documentation](https://github.com/FuryCow/llm_chain/wiki) | 
[Examples](https://github.com/FuryCow/llm_chain/tree/main/examples) | 
[Changelog](CHANGELOG.md) |
[Issues](https://github.com/FuryCow/llm_chain/issues) | 
[Discussions](https://github.com/FuryCow/llm_chain/discussions)