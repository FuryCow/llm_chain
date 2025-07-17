require 'spec_helper'
require 'llm_chain/embeddings/clients/local/weaviate_vector_store'

RSpec.describe LLMChain::Embeddings::Clients::Local::WeaviateVectorStore do
  let(:client_double) { double('Weaviate::Client', objects: double, query: double, schema: double) }
  let(:embedder_double) { double('Embedder') }
  let(:embedding) { [0.1, 0.2, 0.3] }
  let(:class_name) { 'Document' }

  before do
    stub_const('Weaviate::Client', Class.new)
    allow(Weaviate::Client).to receive(:new).and_return(client_double)
    allow(embedder_double).to receive(:embed).and_return(embedding)
    allow(client_double.schema).to receive(:get)
  end

  describe '#initialize' do
    it 'sets default params and calls create_schema_if_not_exists' do
      expect_any_instance_of(described_class).to receive(:create_schema_if_not_exists)
      store = described_class.new
      expect(store.instance_variable_get(:@class_name)).to eq('Document')
      expect(store.instance_variable_get(:@embedder)).to be_a(LLMChain::Embeddings::Clients::Local::OllamaClient)
      expect(store.instance_variable_get(:@client)).to eq(client_double)
    end
    it 'sets custom params and embedder' do
      expect_any_instance_of(described_class).to receive(:create_schema_if_not_exists)
      store = described_class.new(class_name: 'Foo', embedder: embedder_double)
      expect(store.instance_variable_get(:@class_name)).to eq('Foo')
      expect(store.instance_variable_get(:@embedder)).to eq(embedder_double)
    end
  end

  describe '#add_document' do
    let(:store) { described_class.new(embedder: embedder_double) }
    it 'calls embed and objects.create with correct params' do
      expect(embedder_double).to receive(:embed).with('text').and_return(embedding)
      expect(client_double.objects).to receive(:create).with(hash_including(
        class_name: class_name,
        properties: hash_including(content: 'text', text: 'text', metadata: '{}'),
        vector: embedding
      ))
      store.add_document(text: 'text')
    end
    it 'serializes metadata to JSON' do
      expect(client_double.objects).to receive(:create).with(hash_including(properties: hash_including(metadata: '{"foo":1}')))
      store.add_document(text: 'text', metadata: { foo: 1 })
    end
  end

  describe '#semantic_search' do
    let(:store) { described_class.new(embedder: embedder_double) }
    it 'calls embed and query.get with correct params' do
      expect(embedder_double).to receive(:embed).with('query').and_return(embedding)
      expect(client_double.query).to receive(:get).with(hash_including(
        class_name: class_name,
        fields: 'content metadata text',
        limit: '3',
        offset: '1',
        near_vector: /vector: \[0.1, 0.2, 0.3\]/
      ))
      store.semantic_search('query')
    end
    it 'passes custom limit and certainty' do
      expect(client_double.query).to receive(:get).with(hash_including(limit: '1', offset: '1', near_vector: /certainty: 0.9/))
      allow(embedder_double).to receive(:embed).and_return(embedding)
      store.semantic_search('query', limit: 1, certainty: 0.9)
    end
  end

  describe '#create_schema_if_not_exists (private)' do
    let(:store) { described_class.allocate }
    before do
      store.instance_variable_set(:@client, client_double)
      store.instance_variable_set(:@class_name, class_name)
    end
    it 'does nothing if schema exists' do
      expect(client_double.schema).to receive(:get).with(class_name: class_name)
      expect(client_double.schema).not_to receive(:create)
      store.send(:create_schema_if_not_exists)
    end
    it 'creates schema if not exists' do
      allow(client_double.schema).to receive(:get).and_raise(Faraday::ResourceNotFound)
      expect(client_double.schema).to receive(:create).with(hash_including(
        class_name: class_name,
        properties: array_including(hash_including(name: 'content'), hash_including(name: 'metadata'))
      ))
      store.send(:create_schema_if_not_exists)
    end
  end
end 