require 'spec_helper'
require 'llm_chain/clients/openai'

RSpec.describe LLMChain::Clients::OpenAI do
  let(:api_key) { 'test-key' }
  let(:client) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    it 'sets api_key and model' do
      expect(client.instance_variable_get(:@api_key)).to eq(api_key)
      expect(client.instance_variable_get(:@model)).to eq('gpt-3.5-turbo')
    end
    it 'raises if no api_key' do
      expect { described_class.new(api_key: nil) }.to raise_error(LLMChain::Error)
    end
    it 'sets organization_id from ENV' do
      stub_const('ENV', ENV.to_hash.merge('OPENAI_ORGANIZATION_ID' => 'org'))
      c = described_class.new(api_key: api_key)
      expect(c.instance_variable_get(:@organization_id)).to eq('org')
    end
  end

  describe '#build_request_params' do
    it 'builds params with defaults' do
      params = client.send(:build_request_params, 'hi')
      expect(params[:model]).to eq('gpt-3.5-turbo')
      expect(params[:messages]).to be_a(Array)
      expect(params[:stream]).to eq(false)
    end
    it 'merges options' do
      params = client.send(:build_request_params, 'hi', temperature: 0.1)
      expect(params[:temperature]).to eq(0.1)
    end
  end

  describe '#prepare_messages' do
    it 'wraps string in user message' do
      expect(client.send(:prepare_messages, 'hi')).to eq([{ role: 'user', content: 'hi' }])
    end
    it 'returns array as is' do
      arr = [{ role: 'user', content: 'hi' }]
      expect(client.send(:prepare_messages, arr)).to eq(arr)
    end
    it 'raises on invalid input' do
      expect { client.send(:prepare_messages, 123) }.to raise_error(ArgumentError)
    end
  end

  describe '#process_stream_chunk' do
    it 'returns nil for empty chunk' do
      expect(client.send(:process_stream_chunk, '   ')).to be_nil
    end
    it 'returns content from valid chunk' do
      chunk = 'data: {"choices":[{"delta":{"content":"hello"}}]}'
      expect(client.send(:process_stream_chunk, chunk)).to eq('hello')
    end
    it 'returns nil for invalid JSON' do
      expect(client.send(:process_stream_chunk, 'data: notjson')).to be_nil
    end
  end

  describe '#handle_response' do
    it 'returns content from valid response' do
      resp = double('response', body: { choices: [ { message: { content: 'hi' } } ] }.to_json)
      expect(client.send(:handle_response, resp)).to eq('hi')
    end
    it 'raises if no content' do
      resp = double('response', body: { choices: [ { message: {} } ] }.to_json)
      expect { client.send(:handle_response, resp) }.to raise_error(LLMChain::Error)
    end
  end

  describe '#chat' do
    let(:messages) { 'hi' }
    let(:response_double) { double('response', body: { choices: [ { message: { content: 'hello' } } ] }.to_json) }
    let(:conn) { double('conn') }

    before do
      allow(client).to receive(:connection).and_return(conn)
      allow(client).to receive(:headers).and_return({})
    end

    it 'sends a POST request and returns content' do
      req = double('req', headers: nil, body: nil)
      allow(req).to receive(:headers=)
      allow(req).to receive(:body=)
      expect(conn).to receive(:post).with("chat/completions").and_yield(req).and_return(response_double)
      expect(client).to receive(:handle_response).with(response_double).and_call_original
      expect(client.chat(messages)).to eq('hello')
    end

    it 'raises LLMChain::Error on Faraday error' do
      expect(conn).to receive(:post).and_raise(Faraday::Error.new('fail'))
      expect { client.chat(messages) }.to raise_error(LLMChain::Error, /OpenAI API request failed/)
    end

    it 'calls stream_chat if stream: true' do
      expect(client).to receive(:build_request_params).with(messages, stream: true).and_return({})
      expect(client).to receive(:stream_chat).with({})
      client.chat(messages, stream: true)
    end
  end

  describe '#stream_chat' do
    let(:params) { { model: 'gpt-3.5-turbo', messages: [{ role: 'user', content: 'hi' }], stream: true } }
    let(:conn) { double('conn') }
    let(:req) do
      r = double('req', headers: nil, body: nil, options: double('options', on_data: nil))
      allow(r).to receive(:headers=)
      allow(r).to receive(:body=)
      r
    end
    let(:chunk) { 'data: {"choices":[{"delta":{"content":"hello"}}]}' }

    before do
      allow(client).to receive(:connection).and_return(conn)
      allow(client).to receive(:headers).and_return({})
    end

    it 'yields processed chunk to block and returns buffer' do
      expect(conn).to receive(:post).with("chat/completions").and_yield(req)
      allow(req.options).to receive(:on_data=) { |proc| proc.call(chunk, nil, nil) }
      buffer = ""
      result = client.stream_chat(params) { |data| buffer << data }
      expect(buffer).to include('hello')
      expect(result).to include('hello')
    end

    it 'returns buffer even if no block given' do
      expect(conn).to receive(:post).with("chat/completions").and_yield(req)
      allow(req.options).to receive(:on_data=) { |proc| proc.call(chunk, nil, nil) }
      result = client.stream_chat(params)
      expect(result).to include('hello')
    end

    it 'skips empty/invalid chunks' do
      expect(conn).to receive(:post).with("chat/completions").and_yield(req)
      allow(req.options).to receive(:on_data=) do |proc|
        proc.call('   ', nil, nil)
        proc.call('data: notjson', nil, nil)
        proc.call(chunk, nil, nil)
      end
      result = client.stream_chat(params)
      expect(result).to include('hello')
    end
  end
end 