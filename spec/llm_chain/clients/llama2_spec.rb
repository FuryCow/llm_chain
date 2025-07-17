require 'spec_helper'
require 'llm_chain/clients/llama2'

RSpec.describe LLMChain::Clients::Llama2 do
  let(:default_model) { described_class::DEFAULT_MODEL }
  let(:default_options) { described_class::DEFAULT_OPTIONS }

  describe '#initialize' do
    it 'sets default model and options' do
      client = described_class.new
      expect(client.instance_variable_get(:@model)).to eq(default_model)
      expect(client.instance_variable_get(:@default_options)).to include(default_options)
    end

    it 'allows overriding model and base_url' do
      client = described_class.new(model: 'llama2:70b', base_url: 'http://foo')
      expect(client.instance_variable_get(:@model)).to eq('llama2:70b')
      expect(client.instance_variable_get(:@base_url)).to eq('http://foo')
    end

    it 'merges custom options with defaults' do
      client = described_class.new(temperature: 0.5, foo: 1)
      opts = client.instance_variable_get(:@default_options)
      expect(opts[:temperature]).to eq(0.5)
      expect(opts[:foo]).to eq(1)
      expect(opts[:top_k]).to eq(40)
    end

    it 'calls super with correct arguments' do
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:initialize).with(hash_including(model: default_model, default_options: hash_including(temperature: 0.7)))
      described_class.new
    end
  end
end 