require 'spec_helper'
require 'llm_chain/clients/gemma3'

RSpec.describe LLMChain::Clients::Gemma3 do
  let(:valid_model) { 'gemma3:2b' }
  let(:invalid_model) { 'gemma3:999b' }
  let(:base_url) { 'http://localhost:11434' }
  let(:prompt) { 'Hello, Gemma3!' }
  let(:response_text) { "Hello!<think>internal</think>\n\n<|system|>sys<|im_end|>\n\n<|user|>user<|im_end|>\n\n<|assistant|>asst<|im_end|>\n\nHow can I help?" }
  let(:cleaned_text) { "Hello!\n\nHow can I help?" }

  describe '#initialize' do
    it 'sets model and options for valid model' do
      client = described_class.new(model: valid_model, base_url: base_url)
      expect(client.instance_variable_get(:@model)).to eq(valid_model)
    end
    it 'uses default model if none given' do
      client = described_class.new(base_url: base_url)
      expect(client.instance_variable_get(:@model)).to eq('gemma3:2b')
    end
    it 'raises error for invalid model' do
      expect {
        described_class.new(model: invalid_model, base_url: base_url)
      }.to raise_error(described_class::InvalidModelVersion)
    end
  end

  describe '#chat' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'calls super for non-stream' do
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:chat).with(prompt).and_return(response_text)
      expect(client.chat(prompt)).to eq(cleaned_text)
    end
    it 'calls stream_chat for stream: true' do
      expect(client).to receive(:stream_chat).with(prompt, show_internal: false).and_return(cleaned_text)
      client.chat(prompt, stream: true)
    end
    it 'returns raw response if show_internal: true' do
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:chat).and_return(response_text)
      expect(client.chat(prompt, show_internal: true)).to eq(response_text)
    end
  end

  describe '#stream_chat' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    let(:chunk1) { '{"response":"Hello"}' }
    let(:chunk2) { '{"response":" world!"}' }
    let(:buffer) { 'Hello world!' }
    it 'yields processed chunks to block and returns processed buffer' do
      fake_req = double
      allow(fake_req).to receive(:headers).and_return({})
      allow(fake_req).to receive(:body=)
      fake_options = double
      allow(fake_req).to receive(:options).and_return(fake_options)
      allow(fake_options).to receive(:on_data=) do |proc|
        proc.call(chunk1, nil, nil)
        proc.call(chunk2, nil, nil)
      end
      fake_connection = double
      allow(fake_connection).to receive(:post) do |_, &block|
        block.call(fake_req)
      end
      allow(client).to receive(:connection).and_return(fake_connection)
      allow(client).to receive(:process_stream_chunk).and_return('Hello', ' world!')
      expect(client).to receive(:process_response).with('Hello world!', show_internal: false).and_return('Hello world!')
      yielded = []
      result = client.stream_chat(prompt) { |chunk| yielded << chunk }
      expect(yielded).to eq(['Hello', ' world!'])
      expect(result).to eq('Hello world!')
    end
  end

  describe 'build_request_body' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'includes version-specific options in request body' do
      base_body = { prompt: prompt, options: { temperature: 0.7, top_p: 0.9, top_k: 40, repeat_penalty: 1.1, num_ctx: 8192 } }
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:build_request_body).with(prompt, anything).and_return(base_body)
      expect(client.send(:build_request_body, prompt, {})).to include(:options)
    end
  end

  describe '#process_stream_chunk' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'returns response field from valid JSON' do
      expect(client.send(:process_stream_chunk, '{"response":"hi"}')).to eq('hi')
    end
    it 'returns nil for invalid JSON' do
      expect(client.send(:process_stream_chunk, 'not json')).to be_nil
    end
    it 'returns nil if no response field' do
      expect(client.send(:process_stream_chunk, '{"foo":"bar"}')).to be_nil
    end
  end

  describe '#process_response' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }

    it 'returns response as-is if not a String' do
      expect(client.send(:process_response, 123)).to eq(123)
    end

    it 'returns response as-is if show_internal: true' do
      expect(client.send(:process_response, "foo", show_internal: true)).to eq("foo")
    end

    it 'returns cleaned response if show_internal: false' do
      expect(client.send(:process_response, response_text, show_internal: false)).to eq(cleaned_text)
    end
  end

  describe '#clean_response' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }

    it 'returns empty string if only tags' do
      text = '<think>internal</think><|system|>sys<|im_end|>'
      expect(client.send(:clean_response, text)).to eq("")
    end

    it 'returns original text if no tags' do
      text = 'Just plain text.'
      expect(client.send(:clean_response, text)).to eq('Just plain text.')
    end

    it 'handles no newlines between tags' do
      text = 'A<|system|>sys<|im_end|>B'
      expect(client.send(:clean_response, text)).to eq("A\nB")
    end
  end

  describe '#build_request_body' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }

    it 'does not fail if version_specific_options is nil' do
      allow(client).to receive(:model_version).and_return(:unknown)
      body = { options: {} }
      allow_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:build_request_body).and_return(body)
      expect { client.send(:build_request_body, "prompt", {}) }.not_to raise_error
    end
  end

  describe '#process_stream_chunk' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }

    it 'returns nil if parsed is not a Hash' do
      allow(JSON).to receive(:parse).and_return(["not", "a", "hash"])
      expect(client.send(:process_stream_chunk, '{"foo":"bar"}')).to be_nil
    end
  end

  describe '#default_options_for' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'returns correct options' do
      opts = client.send(:default_options_for, valid_model)
      expect(opts).to include(:temperature, :top_p, :repeat_penalty, :num_ctx, :top_k, :stop)
    end
  end
end 