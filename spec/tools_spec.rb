require 'spec_helper'

RSpec.describe LLMChain::Tools do
  describe LLMChain::Tools::Calculator do
    let(:calculator) { described_class.new }

    describe '#match?' do
      it 'matches mathematical expressions' do
        expect(calculator.match?('What is 2 + 2?')).to be true
        expect(calculator.match?('Calculate 15 * 3')).to be true
        expect(calculator.match?('Hello world')).to be false
      end
    end

    describe '#call' do
      it 'evaluates simple expressions' do
        result = calculator.call('Calculate 2 + 2')
        expect(result[:result]).to eq(4)
        expect(result[:expression]).to eq('2 + 2')
      end

      it 'handles complex expressions' do
        result = calculator.call('What is sqrt(16) + 2 * 3?')
        expect(result[:result]).to eq(10.0)
      end

      it 'handles errors gracefully' do
        result = calculator.call('Calculate invalid expression')
        expect(result).to have_key(:error)
      end
    end
  end

  describe LLMChain::Tools::WebSearch do
    let(:web_search) { described_class.new }

    describe '#match?' do
      it 'matches search queries' do
        expect(web_search.match?('Search for Ruby gems')).to be true
        expect(web_search.match?('What is the weather today?')).to be true
        expect(web_search.match?('Hello friend')).to be false
      end
    end

    describe '#extract_query' do
      it 'extracts query from prompt' do
        query = web_search.send(:extract_query, 'Search for Ruby programming language')
        expect(query).to include('Ruby programming language')
      end
    end
  end

  describe LLMChain::Tools::CodeInterpreter do
    let(:code_interpreter) { described_class.new }

    describe '#match?' do
      it 'matches code blocks' do
        expect(code_interpreter.match?('Run this code: puts "hello"')).to be true
        expect(code_interpreter.match?('```ruby\nputs "test"\n```')).to be true
        expect(code_interpreter.match?('Just text')).to be false
      end
    end

    describe '#safe_to_execute?' do
      it 'rejects dangerous code' do
        expect(code_interpreter.send(:safe_to_execute?, 'system("rm -rf /")')).to be false
        expect(code_interpreter.send(:safe_to_execute?, 'puts "hello"')).to be true
      end
    end
  end

  describe LLMChain::Tools::ToolManager do
    let(:calculator) { LLMChain::Tools::Calculator.new }
    let(:web_search) { LLMChain::Tools::WebSearch.new }
    let(:tool_manager) { described_class.new(tools: [calculator]) }

    describe '#register_tool' do
      it 'registers a new tool' do
        tool_manager.register_tool(web_search)
        expect(tool_manager.get_tool('web_search')).to eq(web_search)
      end

      it 'raises error for invalid tool' do
        expect { tool_manager.register_tool("not a tool") }.to raise_error(ArgumentError)
      end
    end

    describe '#find_matching_tools' do
      it 'finds tools that match the prompt' do
        tools = tool_manager.find_matching_tools('Calculate 2 + 2')
        expect(tools).to include(calculator)
      end
    end

    describe '#execute_tools' do
      it 'executes matching tools' do
        results = tool_manager.execute_tools('What is 5 * 6?')
        expect(results).to have_key('calculator')
        expect(results['calculator'][:success]).to be true
      end
    end

    describe '.create_default_toolset' do
      it 'creates a toolset with default tools' do
        toolset = described_class.create_default_toolset
        expect(toolset.list_tools.length).to eq(3)
        expect(toolset.get_tool('calculator')).to be_a(LLMChain::Tools::Calculator)
      end
    end
  end

  describe 'Integration with Chain' do
    let(:memory) { LLMChain::Memory::Array.new }
    let(:tool_manager) { LLMChain::Tools::ToolManager.create_default_toolset }
    let(:client) { double("Client", chat: "Test response") }

    before do
      allow(LLMChain::ClientRegistry).to receive(:client_for).and_return(client)
    end

    it 'uses tools in chain' do
      chain = LLMChain::Chain.new(
        model: "test",
        memory: memory,
        tools: tool_manager,
        retriever: false
      )

      expect(chain.ask("What is 10 + 5?")).to include("15")
    end
  end
end 