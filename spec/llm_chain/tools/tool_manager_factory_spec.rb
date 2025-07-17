require 'spec_helper'
require 'llm_chain/tools/tool_manager_factory'

RSpec.describe LLMChain::Tools::ToolManagerFactory do
  let(:calculator) { double('Calculator') }
  let(:web_search) { double('WebSearch') }
  let(:code_interpreter) { double('CodeInterpreter') }
  let(:date_time) { double('DateTime') }
  let(:tool_manager) { double('ToolManager') }

  before do
    stub_const('LLMChain::Tools::Calculator', Class.new { def initialize(**_); end })
    stub_const('LLMChain::Tools::WebSearch', Class.new { def initialize(**_); end })
    stub_const('LLMChain::Tools::CodeInterpreter', Class.new { def initialize(**_); end })
    stub_const('LLMChain::Tools::DateTime', Class.new { def initialize(**_); end })
    stub_const('LLMChain::Tools::ToolManager', Class.new do
      attr_reader :tools
      def initialize(tools:); @tools = tools; end
    end)
  end

  describe '.create_default_toolset' do
    it 'returns ToolManager with default tools' do
      manager = described_class.create_default_toolset
      expect(manager).to be_a(LLMChain::Tools::ToolManager)
      expect(manager.tools.size).to eq(4)
      expect(manager.tools.map(&:class).map(&:to_s)).to include(
        'LLMChain::Tools::Calculator',
        'LLMChain::Tools::WebSearch',
        'LLMChain::Tools::CodeInterpreter',
        'LLMChain::Tools::DateTime'
      )
    end
  end

  describe '.from_config' do
    it 'creates ToolManager with specified tools (symbols)' do
      config = [
        { class: 'calculator' },
        { class: 'web_search', options: { foo: 1 } },
        { class: 'code_interpreter', options: { bar: 2 } },
        { class: 'date_time' }
      ]
      manager = described_class.from_config(config)
      expect(manager.tools.size).to eq(4)
      expect(manager.tools.map(&:class).map(&:to_s)).to include(
        'LLMChain::Tools::Calculator',
        'LLMChain::Tools::WebSearch',
        'LLMChain::Tools::CodeInterpreter',
        'LLMChain::Tools::DateTime'
      )
    end

    it 'creates ToolManager with specified tools (strings)' do
      config = [
        { 'class' => 'WebSearch', 'options' => { foo: 1 } }
      ]
      manager = described_class.from_config(config)
      expect(manager.tools.size).to eq(1)
      expect(manager.tools.first).to be_a(LLMChain::Tools::WebSearch)
    end

    it 'passes options to tool constructors' do
      expect(LLMChain::Tools::WebSearch).to receive(:new).with(foo: 42).and_call_original
      config = [{ class: 'web_search', options: { foo: 42 } }]
      described_class.from_config(config)
    end

    it 'raises ArgumentError for unknown tool class' do
      config = [{ class: 'unknown_tool' }]
      expect {
        described_class.from_config(config)
      }.to raise_error(ArgumentError, /Unknown tool class/)
    end

    it 'returns ToolManager with no tools for empty config' do
      manager = described_class.from_config([])
      expect(manager.tools).to eq([])
    end
  end
end 