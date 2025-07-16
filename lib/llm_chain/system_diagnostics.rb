# frozen_string_literal: true

module LLMChain
  # System diagnostics utility for checking LLMChain environment
  class SystemDiagnostics
    DIAGNOSTICS_HEADER = "🔍 LLMChain System Diagnostics"
    SEPARATOR = "=" * 50

    def self.run
      new.run
    end

    def run
      puts_header
      results = ConfigurationValidator.validate_environment
      display_results(results)
      display_recommendations(results)
      puts_footer
      results
    end

    private

    def puts_header
      puts DIAGNOSTICS_HEADER
      puts SEPARATOR
    end

    def puts_footer
      puts SEPARATOR
    end

    def display_results(results)
      display_system_components(results)
      display_api_keys(results)
      display_warnings(results)
    end

    def display_system_components(results)
      puts "\n📋 System Components:"
      puts "  Ruby: #{status_icon(results[:ruby])} (#{RUBY_VERSION})"
      puts "  Python: #{status_icon(results[:python])}"
      puts "  Node.js: #{status_icon(results[:node])}"
      puts "  Internet: #{status_icon(results[:internet])}"
      puts "  Ollama: #{status_icon(results[:ollama])}"
    end

    def display_api_keys(results)
      puts "\n🔑 API Keys:"
      results[:apis].each do |api, available|
        puts "  #{api.to_s.capitalize}: #{status_icon(available)}"
      end
    end

    def display_warnings(results)
      return unless results[:warnings].any?

      puts "\n⚠️  Warnings:"
      results[:warnings].each { |warning| puts "  • #{warning}" }
    end

    def display_recommendations(results)
      puts "\n💡 Recommendations:"
      puts "  • Install missing components for full functionality"
      puts "  • Configure API keys for enhanced features"
      puts "  • Start Ollama server: ollama serve" unless results[:ollama]
    end

    def status_icon(status)
      status ? '✅' : '❌'
    end
  end
end 