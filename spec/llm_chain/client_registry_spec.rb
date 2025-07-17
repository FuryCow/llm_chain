require 'spec_helper'
require 'llm_chain/client_registry'

RSpec.describe LLMChain::ClientRegistry do
  before do
    described_class.instance_variable_set(:@clients, {})
  end

  describe '.register_client' do
    it 'registers a client class by name' do
      dummy = Class.new
      described_class.register_client('foo', dummy)
      clients = described_class.instance_variable_get(:@clients)
      expect(clients['foo']).to eq(dummy)
    end

    it 'overwrites client with same name' do
      dummy1 = Class.new
      dummy2 = Class.new
      described_class.register_client('bar', dummy1)
      described_class.register_client('bar', dummy2)
      clients = described_class.instance_variable_get(:@clients)
      expect(clients['bar']).to eq(dummy2)
    end
  end

  describe '.client_for' do
    let(:options) { {foo: 'bar'} }

    before do
      stub_const('LLMChain::Clients::OpenAI', Class.new do
        def initialize(**opts); @opts = opts; end
        attr_reader :opts
      end)
      stub_const('LLMChain::Clients::Qwen', Class.new do
        def initialize(**opts); @opts = opts; end
        attr_reader :opts
      end)
      stub_const('LLMChain::Clients::Llama2', Class.new do
        def initialize(**opts); @opts = opts; end
        attr_reader :opts
      end)
      stub_const('LLMChain::Clients::Gemma3', Class.new do
        def initialize(**opts); @opts = opts; end
        attr_reader :opts
      end)
      stub_const('LLMChain::Clients::DeepseekCoderV2', Class.new do
        def initialize(**opts); @opts = opts; end
        attr_reader :opts
      end)
      stub_const('LLMChain::UnknownModelError', Class.new(StandardError))
    end

    it 'returns OpenAI client for gpt model' do
      client = described_class.client_for('gpt-3.5-turbo', **options)
      expect(client).to be_a(LLMChain::Clients::OpenAI)
      expect(client.opts[:model]).to eq('gpt-3.5-turbo')
      expect(client.opts[:foo]).to eq('bar')
    end

    it 'returns Qwen client for qwen model' do
      client = described_class.client_for('qwen:7b', **options)
      expect(client).to be_a(LLMChain::Clients::Qwen)
    end

    it 'returns Llama2 client for llama2 model' do
      client = described_class.client_for('llama2:13b', **options)
      expect(client).to be_a(LLMChain::Clients::Llama2)
    end

    it 'returns Gemma3 client for gemma3 model' do
      client = described_class.client_for('gemma3:2b', **options)
      expect(client).to be_a(LLMChain::Clients::Gemma3)
    end

    it 'returns DeepseekCoderV2 client for deepseek-coder-v2 model' do
      client = described_class.client_for('deepseek-coder-v2:6b', **options)
      expect(client).to be_a(LLMChain::Clients::DeepseekCoderV2)
    end

    it 'raises UnknownModelError for unknown model' do
      expect {
        described_class.client_for('foobar', **options)
      }.to raise_error(LLMChain::UnknownModelError)
    end
  end
end 