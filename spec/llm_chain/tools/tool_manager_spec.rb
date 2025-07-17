require 'spec_helper'
require 'llm_chain/tools/tool_manager'

RSpec.describe LLMChain::Tools::ToolManager do
  let(:tool_class) do
    Class.new(LLMChain::Tools::Base) do
      attr_accessor :_name, :_match, :_call, :_format, :_desc, :_schema
      def initialize(name:, match: false, call: nil, format: nil, desc: '', schema: {})
        self._name = name
        self._match = match
        self._call = call
        self._format = format
        self._desc = desc
        self._schema = schema
      end
      def name; _name; end
      def match?(_); _match; end
      def call(*); _call; end
      def format_result(_); _format; end
      def description; _desc; end
      def to_schema; _schema; end
    end
  end

  let(:tool1) { tool_class.new(name: 'calculator', match: false, call: 42, format: '42', desc: 'Calc', schema: { name: 'calculator' }) }
  let(:tool2) { tool_class.new(name: 'web_search', match: true, call: 'result', format: 'result', desc: 'Search', schema: { name: 'web_search' }) }
  let(:base_class) { Class.new(LLMChain::Tools::Base) { def name; 'dummy'; end } }

  describe '#initialize' do
    it 'registers tools on init' do
      manager = described_class.new(tools: [tool1, tool2])
      expect(manager.list_tools).to include(tool1, tool2)
    end
  end

  describe '#register_tool' do
    let(:manager) { described_class.new }
    it 'registers a tool' do
      manager.register_tool(tool1)
      expect(manager.get_tool('calculator')).to eq(tool1)
    end
    it 'raises error for non-Base tool' do
      expect { manager.register_tool(Object.new) }.to raise_error(ArgumentError)
    end
  end

  describe '#unregister_tool' do
    let(:manager) { described_class.new(tools: [tool1]) }
    it 'removes tool by name' do
      manager.unregister_tool('calculator')
      expect(manager.get_tool('calculator')).to be_nil
    end
  end

  describe '#get_tool' do
    let(:manager) { described_class.new(tools: [tool1]) }
    it 'returns tool by name' do
      expect(manager.get_tool('calculator')).to eq(tool1)
    end
  end

  describe '#list_tools' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns all tools' do
      expect(manager.list_tools).to match_array([tool1, tool2])
    end
  end

  describe '#find_matching_tools' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns tools where match? is true' do
      expect(manager.find_matching_tools('prompt')).to eq([tool2])
    end
  end

  describe '#execute_tools' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'executes matching tools and returns results' do
      allow(tool2).to receive(:match?).and_return(true)
      allow(tool2).to receive(:call).and_return('ok')
      allow(tool2).to receive(:format_result).and_return('ok')
      results = manager.execute_tools('prompt')
      expect(results['web_search'][:success]).to be true
      expect(results['web_search'][:result]).to eq('ok')
      expect(results['web_search'][:formatted]).to eq('ok')
    end
    it 'handles tool errors gracefully' do
      allow(tool2).to receive(:match?).and_return(true)
      allow(tool2).to receive(:call).and_raise(StandardError, 'fail')
      results = manager.execute_tools('prompt')
      expect(results['web_search'][:success]).to be false
      expect(results['web_search'][:error]).to eq('fail')
    end
  end

  describe '#format_tool_results' do
    let(:manager) { described_class.new }
    it 'formats results for prompt' do
      results = {
        'calculator' => { formatted: '42' },
        'web_search' => { formatted: 'result' }
      }
      expect(manager.format_tool_results(results)).to include('Tool Results:', 'calculator: 42', 'web_search: result')
    end
    it 'returns empty string for empty results' do
      expect(manager.format_tool_results({})).to eq("")
    end
  end

  describe '#tools_description' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns description of all tools' do
      desc = manager.tools_description
      expect(desc).to include('Available tools:', '- calculator: Calc', '- web_search: Search')
    end
  end

  describe '#needs_tools?' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns true for tool keywords' do
      expect(manager.needs_tools?('please calculate 2+2')).to be true
      expect(manager.needs_tools?('can you search for this?')).to be true
    end
    it 'returns true if any tool matches' do
      allow(tool1).to receive(:match?).and_return(true)
      expect(manager.needs_tools?('foo')).to be true
    end
    it 'returns false otherwise' do
      allow(tool1).to receive(:match?).and_return(false)
      allow(tool2).to receive(:match?).and_return(false)
      expect(manager.needs_tools?('foo')).to be false
    end
  end

  describe '#auto_execute' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns results for best tools if needed' do
      allow(manager).to receive(:needs_tools?).and_return(true)
      allow(manager).to receive(:find_matching_tools).and_return([tool2])
      allow(tool2).to receive(:call).and_return('ok')
      allow(tool2).to receive(:format_result).and_return('ok')
      results = manager.auto_execute('prompt')
      expect(results['web_search'][:success]).to be true
    end
    it 'returns empty hash if not needed' do
      allow(manager).to receive(:needs_tools?).and_return(false)
      expect(manager.auto_execute('prompt')).to eq({})
    end
  end

  describe '#get_tools_schema' do
    let(:manager) { described_class.new(tools: [tool1, tool2]) }
    it 'returns schemas for all tools' do
      expect(manager.get_tools_schema).to eq([{ name: 'calculator' }, { name: 'web_search' }])
    end
  end

  describe '#select_best_tools (private)' do
    let(:manager) { described_class.new }
    let(:calc) { double('Calc', name: 'calculator') }
    let(:search) { double('Search', name: 'web_search') }
    let(:code) { double('Code', name: 'code_interpreter') }
    let(:other) { double('Other', name: 'other') }
    it 'prioritizes calculator for math prompt' do
      best = manager.send(:select_best_tools, [calc, search, code, other], 'calculate 2+2')
      expect(best.first.name).to eq('calculator')
    end
    it 'prioritizes web_search for question prompt' do
      best = manager.send(:select_best_tools, [calc, search, code, other], 'what is the capital?')
      expect(best.first.name).to eq('web_search')
    end
    it 'prioritizes code_interpreter for code prompt' do
      best = manager.send(:select_best_tools, [calc, search, code, other], 'run this code: ```puts 1```')
      expect(best.first.name).to eq('code_interpreter')
    end
    it 'returns up to limit best tools' do
      best = manager.send(:select_best_tools, [calc, search, code, other], 'foo', limit: 2)
      expect(best.size).to eq(2)
    end
  end
end 