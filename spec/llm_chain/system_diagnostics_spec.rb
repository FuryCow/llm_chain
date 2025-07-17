require 'spec_helper'
require 'llm_chain/system_diagnostics'

RSpec.describe LLMChain::SystemDiagnostics do
  let(:results_all_ok) do
    {
      ruby: true,
      python: true,
      node: true,
      internet: true,
      ollama: true,
      apis: { openai: true, google_search: true, bing_search: true },
      warnings: []
    }
  end

  let(:results_some_missing) do
    {
      ruby: false,
      python: true,
      node: false,
      internet: false,
      ollama: false,
      apis: { openai: false, google_search: true, bing_search: false },
      warnings: ["Ruby outdated", "No internet"]
    }
  end

  before do
    allow($stdout).to receive(:puts) # suppress output
  end

  describe '.run' do
    it 'calls ConfigurationValidator.validate_environment and returns results' do
      allow(LLMChain::ConfigurationValidator).to receive(:validate_environment).and_return(results_all_ok)
      expect(LLMChain::ConfigurationValidator).to receive(:validate_environment)
      expect(described_class.run).to eq(results_all_ok)
    end

    it 'prints all system components and API keys as present' do
      allow(LLMChain::ConfigurationValidator).to receive(:validate_environment).and_return(results_all_ok)
      expect { described_class.run }.to output(/Ruby: ✅/).to_stdout
      expect { described_class.run }.to output(/Python: ✅/).to_stdout
      expect { described_class.run }.to output(/Node\.js: ✅/).to_stdout
      expect { described_class.run }.to output(/Internet: ✅/).to_stdout
      expect { described_class.run }.to output(/Ollama: ✅/).to_stdout
      expect { described_class.run }.to output(/Openai: ✅/i).to_stdout
      expect { described_class.run }.to output(/Google_search: ✅/i).to_stdout
      expect { described_class.run }.to output(/Bing_search: ✅/i).to_stdout
    end

    it 'prints missing components, API keys, warnings, and recommendations' do
      allow(LLMChain::ConfigurationValidator).to receive(:validate_environment).and_return(results_some_missing)
      expect { described_class.run }.to output(/Ruby: ❌/).to_stdout
      expect { described_class.run }.to output(/Node\.js: ❌/).to_stdout
      expect { described_class.run }.to output(/Internet: ❌/).to_stdout
      expect { described_class.run }.to output(/Ollama: ❌/).to_stdout
      expect { described_class.run }.to output(/Openai: ❌/i).to_stdout
      expect { described_class.run }.to output(/Bing_search: ❌/i).to_stdout
      expect { described_class.run }.to output(/⚠️  Warnings:/).to_stdout
      expect { described_class.run }.to output(/Ruby outdated/).to_stdout
      expect { described_class.run }.to output(/No internet/).to_stdout
      expect { described_class.run }.to output(/Start Ollama server: ollama serve/).to_stdout
    end

    it 'does not print recommendations to start Ollama if it is present' do
      allow(LLMChain::ConfigurationValidator).to receive(:validate_environment).and_return(results_all_ok)
      expect { described_class.run }.not_to output(/Start Ollama server/).to_stdout
    end

    it 'prints recommendations section always' do
      allow(LLMChain::ConfigurationValidator).to receive(:validate_environment).and_return(results_all_ok)
      expect { described_class.run }.to output(/Recommendations:/).to_stdout
    end
  end
end 