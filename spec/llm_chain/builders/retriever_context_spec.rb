require 'spec_helper'
require 'llm_chain/builders/retriever_context'

RSpec.describe LLMChain::Builders::RetrieverContext do
  let(:builder) { described_class.new }
  let(:query) { 'foo' }
  let(:docs) { [{ content: 'a' }, { content: 'b' }] }

  it 'returns [] if retriever is nil' do
    expect(builder.retrieve(nil, query)).to eq([])
  end

  it 'returns [] if retriever does not respond to search' do
    retriever = double('Retriever', search: nil)
    expect(builder.retrieve(Object.new, query)).to eq([])
  end

  it 'calls search with query and default limit' do
    retriever = double('Retriever')
    expect(retriever).to receive(:search).with(query, limit: 3).and_return(docs)
    expect(builder.retrieve(retriever, query)).to eq(docs)
  end

  it 'calls search with query and custom limit' do
    retriever = double('Retriever')
    expect(retriever).to receive(:search).with(query, limit: 5).and_return(docs)
    expect(builder.retrieve(retriever, query, limit: 5)).to eq(docs)
  end

  it 'returns [] and warns if search raises error' do
    retriever = double('Retriever')
    allow(retriever).to receive(:search).and_raise(StandardError, 'fail')
    expect(builder).to receive(:warn).with(/fail/)
    expect(builder.retrieve(retriever, query)).to eq([])
  end
end 