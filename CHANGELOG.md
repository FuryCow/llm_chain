# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/FuryCow/llm_chain/compare/v0.5.2...HEAD
[0.5.2]: https://github.com/FuryCow/llm_chain/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/FuryCow/llm_chain/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/FuryCow/llm_chain/releases/tag/v0.5.0 