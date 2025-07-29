require 'spec_helper'
require 'llm_chain/clients/mistral'

RSpec.describe LLMChain::Clients::Mistral do
  let(:valid_model) { 'mistral:latest' }
  let(:base_url) { 'http://localhost:11434' }
  let(:prompt) { 'Hello, Mistral!' }
  let(:response_text) { "Hello! How can I help?" }

  describe '#initialize' do
    it 'sets default model and options' do
      client = described_class.new
      expect(client.instance_variable_get(:@model)).to eq('mistral:latest')
      expect(client.instance_variable_get(:@default_options)).to include(
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
        num_ctx: 8192
      )
    end

    it 'allows overriding model and base_url' do
      client = described_class.new(model: 'mixtral:8x7b', base_url: base_url)
      expect(client.instance_variable_get(:@model)).to eq('mixtral:8x7b')
      expect(client.instance_variable_get(:@base_url)).to eq(base_url)
    end

    it 'merges custom options with defaults' do
      custom_options = { temperature: 0.3, top_p: 0.8 }
      client = described_class.new(**custom_options)
      expect(client.instance_variable_get(:@default_options)[:temperature]).to eq(0.3)
      expect(client.instance_variable_get(:@default_options)[:top_p]).to eq(0.8)
    end
  end

  describe '#chat' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }

    it 'calls super with correct arguments' do
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:chat).with(prompt).and_return(response_text)
      expect(client.chat(prompt)).to eq(response_text)
    end
  end

  describe 'inheritance' do
    it 'inherits from OllamaBase' do
      expect(described_class.superclass).to eq(LLMChain::Clients::OllamaBase)
    end
  end

  describe 'default constants' do
    it 'has correct default model' do
      expect(described_class::DEFAULT_MODEL).to eq('mistral:latest')
    end

    it 'has optimized default options' do
      expect(described_class::DEFAULT_OPTIONS).to include(
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
        num_ctx: 8192,
        stop: ["<|im_end|>", "<|endoftext|>", "<|user|>", "<|assistant|>"]
      )
    end
  end
end 