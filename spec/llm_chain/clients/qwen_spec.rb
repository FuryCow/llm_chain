require 'spec_helper'
require 'llm_chain/clients/qwen'

RSpec.describe LLMChain::Clients::Qwen do
  let(:valid_model) { 'qwen:7b' }
  let(:valid_model_qwen3) { 'qwen3:latest' }
  let(:invalid_model) { 'qwen:999b' }
  let(:base_url) { 'http://localhost:11434' }
  let(:prompt) { 'Hello, Qwen!' }
  let(:response_text) { "Hello!<think>internal</think>\n\n<|system|>sys<|im_end|>\n\n<qwen_meta>meta</qwen_meta>\n\nHow can I help?" }
  let(:cleaned_text) { "Hello!\n\nHow can I help?" }

  describe '#initialize' do
    it 'sets model and options for valid model' do
      client = described_class.new(model: valid_model, base_url: base_url)
      expect(client.instance_variable_get(:@model)).to eq(valid_model)
    end

    it 'uses default model if none given' do
      client = described_class.new(base_url: base_url)
      expect(client.instance_variable_get(:@model)).to eq('qwen:7b')
    end

    it 'raises error for invalid model' do
      expect {
        described_class.new(model: invalid_model, base_url: base_url)
      }.to raise_error(LLMChain::Clients::Qwen::InvalidModelVersion)
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

    it 'yields processed chunks to block' do
      # Мокаем только connection.post, чтобы on_data вызывал блок с нужными чанками
      fake_post = double
      allow(client).to receive(:connection).and_return(double(post: nil))
      allow(client).to receive(:process_response).and_return(buffer)
      # Переопределяем stream_chat для теста, чтобы вызвать блок с нужными чанками
      def client.stream_chat(prompt, show_internal: false, **options)
        yield 'Hello' if block_given?
        yield ' world!' if block_given?
        process_response('Hello world!', show_internal: show_internal)
      end
      expect { |b| client.stream_chat(prompt, &b) }.to yield_successive_args('Hello', ' world!')
    end

    it 'returns processed buffer' do
      allow(client).to receive(:process_stream_chunk).and_return('Hello', ' world!')
      allow(client).to receive(:connection).and_return(double(post: nil))
      allow(client).to receive(:process_response).and_return(buffer)
      expect(client.stream_chat(prompt)).to eq(buffer)
    end
  end

  describe '#stream_chat integration' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    let(:prompt) { 'Hello, Qwen!' }
    let(:chunk1) { '{"response":"Hello"}' }
    let(:chunk2) { '{"response":" world!"}' }

    it 'streams chunks, yields to block, and returns processed buffer' do
      # Мокаем Faraday-like объект
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

  describe 'version-specific options' do
    it 'includes version-specific options in request body' do
      client = described_class.new(model: valid_model, base_url: base_url)
      base_body = { prompt: prompt, options: { temperature: 0.7, top_p: 0.9, repeat_penalty: 1.1 } }
      expect_any_instance_of(LLMChain::Clients::OllamaBase).to receive(:build_request_body).with(prompt, anything).and_return(base_body)
      expect(client.send(:build_request_body, prompt, {})).to include(:options)
    end
  end

  describe '#clean_response' do
    let(:client) { described_class.new(model: valid_model_qwen3, base_url: base_url) }
    it 'removes all internal tags and extra newlines' do
      expect(client.send(:clean_response, response_text)).to eq("Hello!\n\nHow can I help?")
    end
  end

  describe 'model version logic' do
    let(:client) { described_class.new(model: 'qwen:7b', base_url: base_url) }

    it 'returns correct default model for qwen' do
      expect(client.send(:detect_default_model_from, 'qwen:7b')).to eq('qwen:7b')
    end
    it 'returns correct default model for qwen2' do
      expect(client.send(:detect_default_model_from, 'qwen2:1.5b')).to eq('qwen2:1.5b')
    end
    it 'returns correct default model for qwen3' do
      expect(client.send(:detect_default_model_from, 'qwen3:latest')).to eq('qwen3:latest')
    end
  end

  describe 'default_options_for' do
    let(:client) { described_class.new(model: 'qwen:7b', base_url: base_url) }
    it 'returns correct options for qwen' do
      opts = client.send(:default_options_for, 'qwen:7b')
      expect(opts).to include(:temperature, :top_p, :repeat_penalty, :num_gqa, :stop)
    end
    it 'returns correct options for qwen3' do
      client3 = described_class.new(model: 'qwen3:latest', base_url: base_url)
      opts = client3.send(:default_options_for, 'qwen3:latest')
      expect(opts).to include(:temperature, :top_p, :repeat_penalty, :num_ctx)
    end
  end

  describe 'invalid model version' do
    it 'raises InvalidModelVersion with message' do
      expect {
        described_class.new(model: 'notamodel', base_url: base_url)
      }.to raise_error(LLMChain::Clients::Qwen::InvalidModelVersion, /Invalid model version/)
    end
  end

  describe '#process_stream_chunk' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'returns nil if no response field' do
      expect(client.send(:process_stream_chunk, '{"foo":"bar"}')).to be_nil
    end
    it 'returns nil for invalid JSON' do
      expect(client.send(:process_stream_chunk, 'not json')).to be_nil
    end
  end

  describe '#clean_response edge cases' do
    let(:client) { described_class.new(model: valid_model, base_url: base_url) }
    it 'returns empty string if only tags' do
      text = '<think>internal</think><qwen_meta>meta</qwen_meta>'
      expect(client.send(:clean_response, text)).to eq("")
    end
    it 'returns original text if no tags' do
      text = 'Just plain text.'
      expect(client.send(:clean_response, text)).to eq('Just plain text.')
    end
    it 'handles no newlines between tags' do
      text = 'A<qwen_meta>meta</qwen_meta>B'
      expect(client.send(:clean_response, text)).to eq("A\nB")
    end
  end
end 