require 'spec_helper'
require 'llm_chain/clients/ollama_base'
require 'faraday'

RSpec.describe LLMChain::Clients::OllamaBase do
  let(:model) { 'test-model' }
  let(:base_url) { 'http://localhost:1234' }
  let(:default_options) { { temperature: 0.5, foo: 1 } }
  let(:prompt) { 'Hello' }
  let(:response_body) { { 'response' => 'hi' } }
  let(:success_response) { double('Faraday::Response', success?: true, body: response_body) }
  let(:fail_response) { double('Faraday::Response', success?: false, body: { 'error' => 'fail' }) }

  describe '#initialize' do
    it 'sets default base_url and options' do
      client = described_class.new(model: model)
      expect(client.instance_variable_get(:@base_url)).to eq('http://localhost:11434')
      expect(client.instance_variable_get(:@model)).to eq(model)
      expect(client.instance_variable_get(:@default_options)).to include(temperature: 0.7, top_p: 0.9, num_ctx: 2048)
    end
    it 'sets custom base_url and options' do
      client = described_class.new(model: model, base_url: base_url, default_options: default_options)
      expect(client.instance_variable_get(:@base_url)).to eq(base_url)
      expect(client.instance_variable_get(:@default_options)).to include(default_options)
    end
  end

  describe '#chat' do
    let(:client) { described_class.new(model: model, base_url: base_url, default_options: default_options) }
    let(:conn_double) { double('Faraday::Connection') }

    before do
      allow(client).to receive(:connection).and_return(conn_double)
    end

    it 'returns response.body["response"] for success' do
      expect(conn_double).to receive(:post).and_return(success_response)
      expect(client.chat(prompt)).to eq('hi')
    end
    it 'raises error if response.body["response"] is nil' do
      resp = double('Faraday::Response', success?: true, body: {})
      expect(conn_double).to receive(:post).and_return(resp)
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /Empty response/)
    end
    it 'raises error if response is not success' do
      expect(conn_double).to receive(:post).and_return(fail_response)
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /fail/)
    end
    it 'raises error for Faraday::ResourceNotFound' do
      expect(conn_double).to receive(:post).and_raise(Faraday::ResourceNotFound.new('not found'))
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /Ollama API error \(404\)/)
    end
    it 'raises error for Faraday::ConnectionFailed' do
      expect(conn_double).to receive(:post).and_raise(Faraday::ConnectionFailed.new('fail'))
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /Cannot connect/)
    end
    it 'raises error for Faraday::TimeoutError' do
      expect(conn_double).to receive(:post).and_raise(Faraday::TimeoutError.new('timeout'))
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /timed out/)
    end
    it 'raises error for other Faraday::Error' do
      expect(conn_double).to receive(:post).and_raise(Faraday::ClientError.new('fail'))
      expect { client.chat(prompt) }.to raise_error(LLMChain::Error, /communication error/)
    end
  end

  describe '#build_request_body' do
    let(:client) { described_class.new(model: model, default_options: default_options) }
    it 'builds correct request body' do
      body = client.send(:build_request_body, 'foo', { bar: 2, stream: true })
      expect(body).to eq({
        model: model,
        prompt: 'foo',
        stream: true,
        options: client.instance_variable_get(:@default_options).merge(bar: 2, stream: true)
      })
    end
  end

  describe '#connection' do
    let(:client) { described_class.new(model: model, base_url: base_url) }
    it 'returns a Faraday connection with correct url' do
      conn = client.send(:connection)
      expect(conn).to be_a(Faraday::Connection)
      expect(conn.url_prefix.to_s).to include(base_url)
    end
  end
end 