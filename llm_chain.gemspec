# frozen_string_literal: true

require_relative "lib/llm_chain/version"

Gem::Specification.new do |spec|
  spec.name = "llm_chain"
  spec.version = LlmChain::VERSION
  spec.authors = ["FuryCow"]
  spec.email = ["dreamweaver0408@gmail.com"]

  spec.summary = "A comprehensive Ruby framework for building LLM-powered applications with chains, memory, and vector storage"
  spec.description = <<~DESCRIPTION
    LLM Chain is a powerful Ruby framework that provides tools for building sophisticated 
    LLM-powered applications. It includes support for prompt management, conversation chains, 
    memory systems, vector storage integration, and seamless LLM provider connections.
    
    Key features:
    • Chain-based conversation flows
    • Memory management with Redis
    • Vector storage with Weaviate
    • Multiple LLM provider support
    • Prompt templating and management
    • Easy integration with existing Ruby applications
  DESCRIPTION
  spec.homepage = "https://github.com/FuryCow/llm_chain"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/FuryCow/llm_chain"
  spec.metadata["changelog_uri"] = "https://github.com/FuryCow/llm_chain/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/FuryCow/llm_chain#readme"
  spec.metadata["bug_tracker_uri"] = "https://github.com/FuryCow/llm_chain/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # HTTP client for API requests
  spec.add_dependency "httparty", "~> 0.21"
  
  # Memory storage backend
  spec.add_dependency "redis", "~> 5.0"
  
  # HTTP client framework
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-net_http", "~> 3.0"
  
  # JSON processing
  spec.add_dependency "json", "~> 2.6"
  
  # Vector database integration
  spec.add_dependency "weaviate-ruby", "~> 0.9.1"

  # Testing framework
  spec.add_development_dependency "rspec", "~> 3.12"
  
  # Code quality and linting
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 2.20"
  
  # Documentation generation
  spec.add_development_dependency "yard", "~> 0.9"
  
  # Development server and debugging
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "pry-byebug", "~> 3.10"
end
