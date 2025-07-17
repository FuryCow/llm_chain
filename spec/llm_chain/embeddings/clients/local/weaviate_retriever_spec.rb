require 'spec_helper'
require 'llm_chain/embeddings/clients/local/weaviate_retriever'

RSpec.describe LLMChain::Embeddings::Clients::Local::WeaviateRetriever do
  let(:embedder) { double('Embedder') }
  let(:vector_store) { double('WeaviateVectorStore') }
  let(:results) { [{ content: 'foo' }] }

  before do
    stub_const('LLMChain::Embeddings::Clients::Local::WeaviateVectorStore', Class.new)
    allow(LLMChain::Embeddings::Clients::Local::WeaviateVectorStore).to receive(:new).and_return(vector_store)
  end

  describe '#initialize' do
    it 'creates WeaviateVectorStore with embedder' do
      expect(LLMChain::Embeddings::Clients::Local::WeaviateVectorStore).to receive(:new).with(embedder: embedder)
      described_class.new(embedder: embedder)
    end
  end

  describe '#search' do
    let(:retriever) { described_class.new(embedder: embedder) }
    it 'calls semantic_search on vector_store with query and limit' do
      expect(vector_store).to receive(:semantic_search).with('q', limit: 5).and_return(results)
      expect(retriever.search('q', limit: 5)).to eq(results)
    end
    it 'defaults limit to 3' do
      expect(vector_store).to receive(:semantic_search).with('foo', limit: 3).and_return(results)
      expect(retriever.search('foo')).to eq(results)
    end
  end
end 