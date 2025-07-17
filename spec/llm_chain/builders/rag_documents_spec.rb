require 'spec_helper'
require 'llm_chain/builders/rag_documents'
require 'json'

RSpec.describe LLMChain::Builders::RagDocuments do
  let(:builder) { described_class.new }

  it 'returns empty string for nil' do
    expect(builder.build(nil)).to eq("")
  end

  it 'returns empty string for empty array' do
    expect(builder.build([])).to eq("")
  end

  it 'formats single document without metadata (symbol keys)' do
    docs = [{ content: 'foo' }]
    expect(builder.build(docs)).to eq("Relevant documents:\nDocument 1: foo")
  end

  it 'formats single document with metadata (symbol keys)' do
    docs = [{ content: 'foo', metadata: { source: 'bar' } }]
    expect(builder.build(docs)).to eq("Relevant documents:\nDocument 1: foo\nMetadata: {\"source\":\"bar\"}")
  end

  it 'formats single document with string keys' do
    docs = [{ 'content' => 'foo', 'metadata' => { 'source' => 'bar' } }]
    expect(builder.build(docs)).to eq("Relevant documents:\nDocument 1: foo\nMetadata: {\"source\":\"bar\"}")
  end

  it 'formats multiple documents with and without metadata' do
    docs = [
      { content: 'foo', metadata: { source: 'bar' } },
      { content: 'baz' }
    ]
    expect(builder.build(docs)).to eq(
      "Relevant documents:\nDocument 1: foo\nMetadata: {\"source\":\"bar\"}\nDocument 2: baz"
    )
  end

  it 'handles mixed string/symbol keys' do
    docs = [
      { 'content' => 'foo', :metadata => { source: 'bar' } },
      { :content => 'baz', 'metadata' => { 'source' => 'qux' } }
    ]
    expect(builder.build(docs)).to eq(
      "Relevant documents:\nDocument 1: foo\nMetadata: {\"source\":\"bar\"}\nDocument 2: baz\nMetadata: {\"source\":\"qux\"}"
    )
  end
end 