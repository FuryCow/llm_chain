require 'spec_helper'
require 'llm_chain/memory/array'

RSpec.describe LLMChain::Memory::Array do
  describe '#initialize' do
    it 'sets default max_size' do
      mem = described_class.new
      expect(mem.instance_variable_get(:@max_size)).to eq(10)
      expect(mem.instance_variable_get(:@storage)).to eq([])
    end
    it 'sets custom max_size' do
      mem = described_class.new(max_size: 3)
      expect(mem.instance_variable_get(:@max_size)).to eq(3)
    end
  end

  describe '#store' do
    it 'adds prompt/response pairs' do
      mem = described_class.new
      mem.store('p1', 'r1')
      expect(mem.recall).to eq([{ prompt: 'p1', response: 'r1' }])
    end
    it 'removes oldest if over max_size' do
      mem = described_class.new(max_size: 2)
      mem.store('p1', 'r1')
      mem.store('p2', 'r2')
      mem.store('p3', 'r3')
      expect(mem.recall).to eq([
        { prompt: 'p2', response: 'r2' },
        { prompt: 'p3', response: 'r3' }
      ])
    end
  end

  describe '#recall' do
    it 'returns a copy of storage' do
      mem = described_class.new
      mem.store('p', 'r')
      arr = mem.recall
      expect(arr).to eq([{ prompt: 'p', response: 'r' }])
      arr << { prompt: 'x', response: 'y' }
      expect(mem.recall).not_to include({ prompt: 'x', response: 'y' })
    end
  end

  describe '#clear' do
    it 'empties storage' do
      mem = described_class.new
      mem.store('p', 'r')
      mem.clear
      expect(mem.recall).to eq([])
    end
  end

  describe '#size' do
    it 'returns number of stored items' do
      mem = described_class.new
      3.times { |i| mem.store("p#{i}", "r#{i}") }
      expect(mem.size).to eq(3)
    end
  end
end 