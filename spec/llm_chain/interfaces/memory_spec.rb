require 'spec_helper'
require 'llm_chain/interfaces/memory'

RSpec.describe LLMChain::Interfaces::Memory do
  let(:memory) { described_class.new }

  it 'raises NotImplementedError for #store' do
    expect { memory.store('prompt', 'response') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #recall' do
    expect { memory.recall('prompt') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #clear' do
    expect { memory.clear }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #size' do
    expect { memory.size }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
end 