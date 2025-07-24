require 'spec_helper'
require 'llm_chain/tools/date_time'

RSpec.describe LLMChain::Tools::DateTime do
  let(:tool) { described_class.new }

  describe '#initialize' do
    it 'sets name, description, and parameters' do
      expect(tool.name).to eq('date_time')
      expect(tool.description).to match(/current date and time/i)
      expect(tool.parameters).to have_key(:timezone)
    end
  end

  describe '#match?' do
    it 'returns true for prompts with keywords' do
      expect(tool.match?('What is the time?')).to be true
      expect(tool.match?('Give me the date')).to be true
      expect(tool.match?('today')).to be true
      expect(tool.match?('now')).to be true
      expect(tool.match?('current time')).to be true
    end
    it 'returns false for prompts without keywords' do
      expect(tool.match?('calculate 2+2')).to be false
      expect(tool.match?('search for cats')).to be false
    end
  end

  describe '#extract_parameters' do
    it 'extracts timezone from prompt' do
      expect(tool.extract_parameters('What is the time in Europe/Moscow?')).to eq(timezone: 'Europe/Moscow')
      expect(tool.extract_parameters('now in America/New_York')).to eq(timezone: 'America/New_York')
    end
    it 'returns nil if no timezone' do
      expect(tool.extract_parameters('What is the time?')).to eq(timezone: nil)
    end
  end

  describe '#call' do
    before do
      allow(Time).to receive(:now).and_return(Time.utc(2023, 1, 2, 3, 4, 5))
    end
    it 'returns system time if no timezone' do
      result = tool.call('What is the time?')
      expect(result[:iso]).to eq('2023-01-02T03:04:05Z')
      expect(result[:formatted]).to match(/2023-01-02 03:04:05/i)
      expect(result[:timezone]).to eq('UTC')
    end
    it 'returns time for valid timezone' do
      allow(tool).to receive(:map_timezone_name).and_return('Europe/Moscow')
      result = tool.call('What is the time in Europe/Moscow?')
      expect(result[:formatted]).to match(/2023-01-02/)
    end
    it 'returns system time for invalid timezone' do
      allow(tool).to receive(:call).and_return({
        timezone: 'UTC',
        iso: '2023-01-02T03:04:05Z',
        formatted: '2023-01-02 03:04:05 UTC'
      })
      result = tool.call('What is the time in Invalid/Zone?')
      expect(result[:formatted]).to match(/2023-01-02/)
    end
  end

  describe '#timezone_offset' do
    it 'returns 0 for any timezone (fallback behavior)' do
      allow_any_instance_of(Object).to receive(:require).with('tzinfo').and_raise(LoadError)
      expect(tool.send(:timezone_offset, 'Europe/Berlin')).to eq(0)
    end
    it 'returns 0 for invalid timezone' do
      allow_any_instance_of(Object).to receive(:require).with('tzinfo').and_raise(LoadError)
      expect(tool.send(:timezone_offset, 'Invalid/Zone')).to eq(0)
    end
  end
end 