require 'spec_helper'
require 'llm_chain/embeddings/clients/local/ollama_client'
require 'json'

RSpec.describe LLMChain::Embeddings::Clients::Local::OllamaClient do
  let(:embedding) { [0.1, 0.2, 0.3] }
  let(:success_response) { double('Net::HTTPSuccess', is_a?: true, body: { embedding: embedding }.to_json) }
  let(:fail_response) { double('Net::HTTPServerError', is_a?: false, code: '500', message: 'Internal Error', body: { error: 'fail' }.to_json) }
  let(:no_embedding_response) { double('Net::HTTPSuccess', is_a?: true, body: { foo: 'bar' }.to_json) }
  let(:bad_json_response) { double('Net::HTTPSuccess', is_a?: true, body: 'not json') }

  describe '#initialize' do
    it 'sets default model and url' do
      client = described_class.new
      expect(client.instance_variable_get(:@model)).to eq('nomic-embed-text')
      expect(client.instance_variable_get(:@ollama_url)).to include('/api/embeddings')
    end
    it 'sets custom model and url' do
      client = described_class.new(model: 'foo', ollama_url: 'http://bar')
      expect(client.instance_variable_get(:@model)).to eq('foo')
      expect(client.instance_variable_get(:@ollama_url)).to eq('http://bar/api/embeddings')
    end
  end

  describe '#embed' do
    let(:client) { described_class.new }
    it 'returns embedding for successful response' do
      allow(client).to receive(:send_ollama_request).and_return(success_response)
      expect(client.embed('text')).to eq(embedding)
    end
    it 'raises EmbeddingError for API error' do
      allow(client).to receive(:send_ollama_request).and_return(fail_response)
      expect { client.embed('text') }.to raise_error(described_class::EmbeddingError, /API error/)
    end
    it 'raises EmbeddingError if no embedding in response' do
      allow(client).to receive(:send_ollama_request).and_return(no_embedding_response)
      expect { client.embed('text') }.to raise_error(described_class::EmbeddingError, /No embedding/)
    end
    it 'raises EmbeddingError for invalid JSON' do
      allow(client).to receive(:send_ollama_request).and_return(bad_json_response)
      expect { client.embed('text') }.to raise_error(described_class::EmbeddingError)
    end
    it 'raises EmbeddingError if send_ollama_request raises' do
      allow(client).to receive(:send_ollama_request).and_raise(StandardError, 'fail')
      expect { client.embed('text') }.to raise_error(described_class::EmbeddingError, /fail/)
    end
    it 'returns [] if embedding is empty array' do
      resp = double('Net::HTTPSuccess', is_a?: true, body: { embedding: [] }.to_json)
      allow(client).to receive(:send_ollama_request).and_return(resp)
      expect(client.embed('text')).to eq([])
    end
    it 'raises EmbeddingError if embedding is nil' do
      resp = double('Net::HTTPSuccess', is_a?: true, body: { embedding: nil }.to_json)
      allow(client).to receive(:send_ollama_request).and_return(resp)
      expect { client.embed('text') }.to raise_error(described_class::EmbeddingError, /No embedding/)
    end
  end

  describe '#embed_batch' do
    let(:client) { described_class.new }
    it 'calls embed for each text and returns embeddings' do
      allow(client).to receive(:embed).and_return([1], [2], [3])
      result = client.embed_batch(%w[a b c], batch_size: 2)
      expect(result).to eq([[1], [2], [3]])
    end
    it 'respects batch_size' do
      expect(client).to receive(:embed).exactly(3).times.and_return([1])
      client.embed_batch(%w[a b c], batch_size: 2)
    end
    it 'returns empty array for empty input' do
      expect(client.embed_batch([], batch_size: 2)).to eq([])
    end
  end

  describe '#validate_response' do
    let(:client) { described_class.new }
    it 'does nothing for HTTPSuccess' do
      expect { client.send(:validate_response, success_response) }.not_to raise_error
    end
    it 'raises EmbeddingError for non-success' do
      expect {
        client.send(:validate_response, fail_response)
      }.to raise_error(described_class::EmbeddingError, /API error/)
    end
    it 'raises EmbeddingError with message if response body is not JSON' do
      resp = double('Net::HTTPServerError', is_a?: false, code: '500', message: 'Internal Error', body: 'not json')
      expect {
        client.send(:validate_response, resp)
      }.to raise_error(described_class::EmbeddingError, /Internal Error/)
    end
  end

  describe '#parse_response' do
    let(:client) { described_class.new }
    it 'returns embedding if present' do
      expect(client.send(:parse_response, success_response)).to eq(embedding)
    end
    it 'raises EmbeddingError if no embedding' do
      expect { client.send(:parse_response, no_embedding_response) }.to raise_error(described_class::EmbeddingError, /No embedding/)
    end
    it 'raises EmbeddingError for invalid JSON' do
      expect { client.send(:parse_response, bad_json_response) }.to raise_error(described_class::EmbeddingError)
    end
    it 'returns [] if embedding is empty array' do
      resp = double('Net::HTTPSuccess', is_a?: true, body: { embedding: [] }.to_json)
      expect(client.send(:parse_response, resp)).to eq([])
    end
    it 'raises EmbeddingError if embedding is nil' do
      resp = double('Net::HTTPSuccess', is_a?: true, body: { embedding: nil }.to_json)
      expect { client.send(:parse_response, resp) }.to raise_error(described_class::EmbeddingError, /No embedding/)
    end
  end

  describe '#send_ollama_request (private)' do
    let(:client) { described_class.new(model: 'test-model', ollama_url: 'http://localhost:1234') }
    let(:fake_response) { double('Net::HTTPResponse') }

    it 'sends a POST request with correct payload and headers' do
      uri = URI('http://localhost:1234/api/embeddings')
      fake_http = double('Net::HTTP')
      fake_request = double('Net::HTTP::Post')
      expect(URI).to receive(:parse).with('http://localhost:1234/api/embeddings').and_return(uri)
      expect(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(fake_http)
      expect(Net::HTTP::Post).to receive(:new).with(uri).and_return(fake_request)
      expect(fake_request).to receive(:[]=).with('Content-Type', 'application/json')
      expect(fake_request).to receive(:body=).with({ model: 'test-model', prompt: 'foo' }.to_json)
      expect(fake_http).to receive(:request).with(fake_request).and_return(fake_response)

      result = client.send(:send_ollama_request, 'foo')
      expect(result).to eq(fake_response)
    end
  end
end 