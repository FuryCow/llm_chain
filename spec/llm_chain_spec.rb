require 'spec_helper'
require 'llm_chain'

RSpec.describe LLMChain do
  describe 'Configuration' do
    let(:config) { described_class::Configuration.new }
    it 'has default values' do
      expect(config.default_model).to eq('qwen3:1.7b')
      expect(config.timeout).to eq(30)
      expect(config.memory_size).to eq(100)
      expect(config.search_engine).to eq(:google)
    end
    it 'can be changed and reset' do
      config.default_model = 'foo'
      config.timeout = 1
      config.memory_size = 2
      config.search_engine = :bing
      config.reset_to_defaults
      expect(config.default_model).to eq('qwen3:1.7b')
      expect(config.timeout).to eq(30)
      expect(config.memory_size).to eq(100)
      expect(config.search_engine).to eq(:google)
    end
    it 'is valid if all required fields are set' do
      expect(config.valid?).to be true
      config.timeout = 0
      expect(config.valid?).to be false
    end
  end

  describe '.configuration' do
    it 'returns a singleton configuration' do
      expect(described_class.configuration).to be_a(described_class::Configuration)
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe '.configure' do
    it 'yields and updates configuration' do
      described_class.configure { |c| c.default_model = 'bar' }
      expect(described_class.configuration.default_model).to eq('bar')
    end
  end

  describe '.reset_configuration' do
    it 'resets configuration to default' do
      described_class.configure { |c| c.default_model = 'baz' }
      described_class.reset_configuration
      expect(described_class.configuration.default_model).to eq('qwen3:1.7b')
    end
  end

  describe '.quick_chain' do
    before do
      stub_const('LLMChain::Chain', Class.new)
      allow(LLMChain::Chain).to receive(:new)
      allow(described_class).to receive(:build_chain_options).and_call_original
      allow(described_class).to receive(:build_tools).and_call_original
      allow(described_class).to receive(:build_memory).and_call_original
    end
    it 'calls Chain.new with correct options' do
      described_class.quick_chain(model: 'foo', tools: false, memory: false, validate_config: false, extra: 1)
      expect(described_class).to have_received(:build_chain_options).with('foo', false, false, false, extra: 1)
      expect(LLMChain::Chain).to have_received(:new)
    end
  end

  describe '.diagnose_system' do
    it 'calls SystemDiagnostics.run' do
      stub_const('LLMChain::SystemDiagnostics', Class.new)
      expect(LLMChain::SystemDiagnostics).to receive(:run)
      described_class.diagnose_system
    end
  end

  describe 'private build_tools' do
    before do
      stub_const('LLMChain::Tools::ToolManagerFactory', Class.new)
      allow(LLMChain::Tools::ToolManagerFactory).to receive(:create_default_toolset).and_return(:default_tools)
    end
    it 'returns default toolset if tools is true' do
      expect(described_class.send(:build_tools, true)).to eq(:default_tools)
    end
    it 'returns nil if tools is false' do
      expect(described_class.send(:build_tools, false)).to be_nil
    end
    it 'returns tools if tools is an object' do
      expect(described_class.send(:build_tools, :custom)).to eq(:custom)
    end
  end

  describe 'private build_memory' do
    before do
      stub_const('LLMChain::Memory::Array', Class.new)
      allow(LLMChain::Memory::Array).to receive(:new).and_return(:array_memory)
      allow(described_class).to receive(:configuration).and_return(double(memory_size: 123))
    end
    it 'returns Array memory if memory is true' do
      expect(described_class.send(:build_memory, true)).to eq(:array_memory)
    end
    it 'returns nil if memory is false' do
      expect(described_class.send(:build_memory, false)).to be_nil
    end
    it 'returns memory if memory is an object' do
      expect(described_class.send(:build_memory, :custom)).to eq(:custom)
    end
  end
end 