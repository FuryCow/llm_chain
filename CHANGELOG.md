# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2025-07-24

### Added
* **Smart CompositeAgent** - Intelligent planning and execution capabilities:
  * Automatic detection of simple vs complex tasks (math, time queries vs multi-step tasks)
  * Direct execution for simple tasks (no unnecessary planning overhead)
  * Smart result validation and quality scoring (0-10 scale)
  * Intelligent result aggregation with structured summaries
  * Better error handling and graceful degradation
  * Meaningful information extraction from tool responses
* **Enhanced DateTime Tool** - Improved timezone handling and parsing:
  * Support for multi-word timezone names (e.g., "New York", "Europe/Moscow")
  * IANA timezone mapping and validation
  * Better JSON input parsing
  * Improved timezone abbreviation display
  * Fallback handling for invalid timezones
* **Improved ReActAgent** - Better tool usage and reasoning:
  * Enhanced prompt instructions for DateTime tool integration
  * Improved termination logic to prevent premature stopping
  * Better guidance for current information queries (uses DateTime before WebSearch)
  * Support for multiple timezone queries

### Changed
* **CompositeAgent Architecture** - Major refactoring for better performance:
  * Split execution into `run_with_planning` and `execute_directly` methods
  * Introduced `should_use_planner?` for intelligent task classification
  * Enhanced result processing with `validate_and_process_result`
  * Improved success validation with `validate_overall_success`
  * Better streaming support with proper step tracking
* **Example Files Cleanup** - Streamlined and improved examples:
  * Removed redundant and temporary example files
  * Cleaned up all comments for better readability
  * Consolidated planner agent examples
  * Improved composite agent demonstration
* **Test Suite Improvements** - Better test coverage and reliability:
  * Updated CompositeAgent specs to match new behavior
  * Fixed DateTime tool specs with proper mocking
  * Improved test isolation and dependency handling

### Fixed
* **DateTime Tool Parsing** - Fixed "Invalid identifier" errors for multi-word timezones
* **ReActAgent Termination** - Prevented premature stopping after DateTime tool usage
* **CompositeAgent Streaming** - Fixed keyword argument passing for stream parameter
* **Test Reliability** - Resolved TZInfo dependency issues in test environment

## [0.5.5] - 2025-07-17

### Changed
* **Major refactor:**
  * Core classes have been extensively refactored for improved modularity, clarity, and maintainability:
    * Adopted SOLID principles throughout the codebase.
    * Extracted interfaces for memory, tool management, and all builder components, now located in a dedicated `interfaces` namespace.
    * Introduced a `builders` folder and builder pattern for prompt, memory context, tool responses, RAG documents, and retriever context.
    * Improved dependency injection and separation of concerns, making the codebase easier to extend and test.
    * Centralized error handling and configuration validation.
    * Enhanced documentation and type signatures for all major classes.
    * The public API remains minimal and idiomatic, with extensibility via interfaces and factories.
  * `Chain#ask` method rewritten following Ruby best practices: now declarative, each pipeline stage is a private method, code is cleaner and easier to extend.
  * All ToolManager creation and configuration is now done via a dedicated factory: `ToolManagerFactory`. Old calls (`ToolManager.create_default_toolset`, `ToolManager.from_config`) have been replaced with factory methods.

## [0.5.4] - 2025-07-08

### Added
* **Deepseek-Coder-V2 Client** - Support for Deepseek-Coder-V2 models via Ollama
  * Available variants: `deepseek-coder-v2:latest`, `deepseek-coder-v2:16b`, `deepseek-coder-v2:236b`
  * Optimized settings for code generation tasks (low temperature, large context)
  * Integrated with existing tool ecosystem (CodeInterpreter, WebSearch, Calculator)
  * Full compatibility with Chain, ClientRegistry, and CLI

### Changed
* Updated model support table in README with Deepseek-Coder-V2 information

## [0.5.3] - 2025-07-05

### Added
* **CLI Executable** (`llm-chain`) with commands:
  * `chat` – one-off prompt
  * `diagnose` – system diagnostics
  * `tools list` – list default tools
  * `repl` – interactive Read-Eval-Print Loop with in-memory history and helper slash-commands

### Changed
* CLI autodetects Bundler only in development repo to avoid gem conflicts.

### Fixed
* Version conflicts when running CLI inside unrelated Bundler projects.

## [0.5.2] - 2025-01-XX

### Added
- **Configuration Validator** - Comprehensive system validation before chain initialization
- **System Diagnostics** - `LLMChain.diagnose_system` method for health checks
- **Retry Logic** - Exponential backoff for HTTP requests with configurable max retries
- **Enhanced Logging** - Structured logging with debug mode support
- **Internet Connectivity Detection** - Automatic offline mode detection
- **Code Extraction Improvements** - Better parsing of code blocks and inline commands

### Changed
- **Improved Error Handling** - Better error messages with suggested solutions
- **Enhanced WebSearch** - More robust fallback mechanisms and timeout handling
- **CodeInterpreter Enhancements** - Improved code extraction from various formats
- **Better Validation** - Early detection of configuration issues with helpful warnings

### Fixed
- **WebSearch Stability** - Fixed timeout and connection issues with retry logic
- **Code Block Parsing** - Resolved issues with multiline regex and Windows line endings
- **Graceful Degradation** - Better handling of offline scenarios and API failures
- **Memory Leaks** - Improved cleanup of temporary files and resources

## [0.5.1] - 2025-06-26

### Added
- Quick chain creation method `LLMChain.quick_chain` for rapid setup
- Global configuration system with `LLMChain.configure`
- Google Search integration for accurate, up-to-date search results
- Fallback search data for common queries (Ruby versions, etc.)
- Production-ready output without debug noise

### Changed  
- **BREAKING**: Replaced DuckDuckGo with Google as default search engine
- Web search now returns accurate results instead of outdated information
- Removed all debug output functionality for cleaner user experience
- Improved calculator expression parsing for better math evaluation
- Enhanced code interpreter to handle inline code prompts (e.g., "Execute code: puts ...")

### Fixed
- Calculator now correctly parses expressions like "50 / 2" instead of extracting just "2"
- Code interpreter properly extracts code from "Execute code: ..." format
- Web search HTTP 202 responses no longer treated as errors
- Removed excessive debug console output

## [0.5.0] - 2025-06-25

### Added
- Core tool system with automatic tool selection
- Calculator tool for mathematical expressions
- Web search tool with DuckDuckGo integration  
- Code interpreter tool for Ruby code execution
- Multi-LLM support (OpenAI, Qwen, LLaMA2, Gemma)
- Memory system with Array and Redis backends
- RAG support with vector databases
- Streaming output support
- Comprehensive error handling
- Tool manager for organizing and managing tools

### Changed
- Initial stable release with core functionality

[Unreleased]: https://github.com/FuryCow/llm_chain/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/FuryCow/llm_chain/compare/v0.5.5...v0.6.0
[0.5.5]: https://github.com/FuryCow/llm_chain/compare/v0.5.4...v0.5.5
[0.5.3]: https://github.com/FuryCow/llm_chain/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/FuryCow/llm_chain/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/FuryCow/llm_chain/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/FuryCow/llm_chain/releases/tag/v0.5.0 
