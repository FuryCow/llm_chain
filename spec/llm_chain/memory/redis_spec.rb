require 'spec_helper'
require 'llm_chain/memory/redis'
require 'json'

RSpec.describe LLMChain::Memory::Redis do
  let(:redis_double) { double('Redis') }
  let(:namespace) { 'llm_chain' }
  let(:session_key) { "#{namespace}:session" }

  before do
    allow(::Redis).to receive(:new).and_return(redis_double)
  end

  describe '#initialize' do
    it 'sets default params and session_key' do
      client = described_class.new
      expect(client.instance_variable_get(:@namespace)).to eq('llm_chain')
      expect(client.instance_variable_get(:@session_key)).to eq('llm_chain:session')
      expect(client.instance_variable_get(:@max_size)).to eq(10)
      expect(client.instance_variable_get(:@redis)).to eq(redis_double)
    end
    it 'sets custom params' do
      client = described_class.new(max_size: 5, redis_url: 'redis://foo', namespace: 'bar')
      expect(client.instance_variable_get(:@namespace)).to eq('bar')
      expect(client.instance_variable_get(:@session_key)).to eq('bar:session')
      expect(client.instance_variable_get(:@max_size)).to eq(5)
    end
  end

  describe '#store' do
    let(:client) { described_class.new }
    it 'pushes and trims in multi block' do
      expect(redis_double).to receive(:multi).and_yield
      expect(redis_double).to receive(:rpush).with(session_key, kind_of(String))
      expect(redis_double).to receive(:ltrim).with(session_key, -10, -1)
      client.store('prompt', 'response')
    end
  end

  describe '#recall' do
    let(:client) { described_class.new }
    it 'returns array of hashes with symbol keys' do
      entry = { 'prompt' => 'p', 'response' => 'r', 'timestamp' => 1 }.to_json
      allow(redis_double).to receive(:lrange).with(session_key, 0, -1).and_return([entry])
      result = client.recall
      expect(result).to eq([{ prompt: 'p', response: 'r', timestamp: 1 }])
    end
    it 'returns [] for invalid JSON' do
      allow(redis_double).to receive(:lrange).and_return(['not json'])
      expect(client.recall).to eq([])
    end
    it 'raises Error for Redis connection error' do
      allow(redis_double).to receive(:lrange).and_raise(::Redis::CannotConnectError)
      expect { client.recall }.to raise_error(described_class::Error, /Cannot connect/)
    end
  end

  describe '#clear' do
    let(:client) { described_class.new }
    it 'calls del on session_key' do
      expect(redis_double).to receive(:del).with(session_key)
      client.clear
    end
  end

  describe '#size' do
    let(:client) { described_class.new }
    it 'calls llen on session_key' do
      expect(redis_double).to receive(:llen).with(session_key)
      client.size
    end
  end

  describe '#symbolize_keys (private)' do
    let(:client) { described_class.new }
    it 'converts all keys to symbols' do
      hash = { 'foo' => 1, 'bar' => 2 }
      expect(client.send(:symbolize_keys, hash)).to eq(foo: 1, bar: 2)
    end
  end
end 