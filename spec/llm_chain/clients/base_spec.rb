require 'spec_helper'
require 'llm_chain/clients/base'

RSpec.describe LLMChain::Clients::Base do
  let(:model) { 'test-model' }
  let(:client) { described_class.new(model) }

  it 'saves model on initialize' do
    expect(client.instance_variable_get(:@model)).to eq(model)
  end

  it 'raises NotImplementedError for #chat' do
    expect { client.chat('prompt') }.to raise_error(NotImplementedError)
  end

  it 'raises NotImplementedError for #stream_chat' do
    expect { client.stream_chat('prompt') }.to raise_error(NotImplementedError)
  end
end 