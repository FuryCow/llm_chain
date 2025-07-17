require 'spec_helper'
require 'llm_chain/tools/calculator'

RSpec.describe LLMChain::Tools::Calculator do
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

    context 'edge cases' do
      it 'handles negative numbers' do
        result = calculator.call('What is -5 + 3?')
        expect(result[:result]).to eq(-2)
      end

      it 'handles division by zero' do
        result = calculator.call('What is 10 / 0?')
        expect(result).to have_key(:error)
        expect(result[:error].to_s).to match(/divided by 0|ZeroDivisionError/i)
      end

      it 'handles nested functions' do
        result = calculator.call('What is sqrt(4 + 5)?')
        expect(result[:result]).to be_within(0.01).of(3.0)
      end

      it 'returns error for invalid expression' do
        result = calculator.call('Calculate foo bar baz')
        expect(result).to have_key(:error)
      end

      it 'handles empty prompt' do
        result = calculator.call('')
        expect(result).to have_key(:error)
      end

      it 'handles quoted expressions' do
        result = calculator.call('Calculate "2 + 2"')
        expect(result[:result]).to eq(4)
      end

      it 'handles function call without keyword' do
        result = calculator.call('sqrt(25)')
        expect(result[:result]).to eq(5.0)
      end

      it 'extracts expression after keyword' do
        result = calculator.call('sum 2 + 2')
        expect(result[:result]).to eq(4)
      end

      it 'returns error for cleaned non-math expression' do
        result = calculator.call('Calculate the answer')
        expect(result).to have_key(:error)
      end
    end
  end

  describe 'private methods' do
    it 'raises error for unsafe eval' do
      puts "Calculator class: ", calculator.class.name
      expect { calculator.send(:safe_eval, 'foo$2') }.to raise_error(/Unsafe expression/)
    end

    it 'evaluates safe expression' do
      expect(calculator.send(:safe_eval, '2 + 2')).to eq(4)
    end

    it 'extracts math expression via match fallback' do
      expr = calculator.send(:extract_math_expression, '2 + 2 * 2')
      expect(expr).to eq('2 + 2 * 2')
    end

    it 'returns empty string if no math expression found' do
      expr = calculator.send(:extract_math_expression, 'no math here')
      expect(expr).to eq("")
    end

    it 'returns quoted non-math expression' do
      expr = calculator.send(:extract_quoted_expression, 'Calculate "hello world"')
      expect(expr).to eq('hello world')
    end

    it 'returns empty string if no simple math expression' do
      expr = calculator.send(:extract_simple_math_expression, 'just text')
      expect(expr).to eq("")
    end

    it 'returns empty string if no function call' do
      expr = calculator.send(:extract_function_call, 'calculate nothing')
      expect(expr).to eq("")
    end

    it 'returns empty string if keyword but no expression' do
      expr = calculator.send(:extract_keyword_expression, 'sum')
      expect(expr).to eq("")
    end

    it 'returns empty string for expression that cleans to empty' do
      expr = calculator.send(:clean_expression, 'the result')
      expect(expr).to eq("")
    end

    it 'extract_expression: returns quoted expression if math fails' do
      allow(calculator).to receive(:extract_math_expression).and_return("")
      expr = calculator.send(:extract_expression, 'Calculate "2 + 2"')
      expect(expr).to eq('2 + 2')
    end

    it 'extract_expression: returns simple math expression if math and quoted fail' do
      allow(calculator).to receive(:extract_math_expression).and_return("")
      allow(calculator).to receive(:extract_quoted_expression).and_return("")
      expr = calculator.send(:extract_expression, '2 + 2')
      expect(expr).to eq('2 + 2')
    end

    it 'extract_expression: returns function call if previous strategies fail' do
      allow(calculator).to receive(:extract_math_expression).and_return("")
      allow(calculator).to receive(:extract_quoted_expression).and_return("")
      allow(calculator).to receive(:extract_simple_math_expression).and_return("")
      expr = calculator.send(:extract_expression, 'sqrt(16)')
      expect(expr).to eq('sqrt(16)')
    end

    it 'extract_expression: returns keyword expression if all previous fail' do
      allow(calculator).to receive(:extract_math_expression).and_return("")
      allow(calculator).to receive(:extract_quoted_expression).and_return("")
      allow(calculator).to receive(:extract_simple_math_expression).and_return("")
      allow(calculator).to receive(:extract_function_call).and_return("")
      expr = calculator.send(:extract_expression, 'sum 2 + 2')
      expect(expr).to eq('2 + 2')
    end

    it 'extract_expression: returns empty string if all strategies fail' do
      allow(calculator).to receive(:extract_math_expression).and_return("")
      allow(calculator).to receive(:extract_quoted_expression).and_return("")
      allow(calculator).to receive(:extract_simple_math_expression).and_return("")
      allow(calculator).to receive(:extract_function_call).and_return("")
      allow(calculator).to receive(:extract_keyword_expression).and_return("")
      expr = calculator.send(:extract_expression, 'no math here')
      expect(expr).to eq("")
    end
  end
end

RSpec.describe LLMChain::Tools do
  describe LLMChain::Tools::WebSearch do
    let(:web_search) { described_class.new }

    describe '#match?' do
      it 'matches search queries' do
        expect(web_search.match?('Search for Ruby gems')).to be true
        expect(web_search.match?('What is the weather today?')).to be false
        expect(web_search.match?('Hello friend')).to be false
      end
    end

    describe '#extract_query' do
      it 'extracts query from prompt' do
        query = web_search.send(:extract_query, 'Search for Ruby programming language')
        expect(query).to include('Ruby programming language')
      end
    end

    context 'edge cases' do
      it 'does not match mathematical prompts' do
        expect(web_search.match?('What is 2 + 2?')).to be false
        expect(web_search.match?('Calculate 15 * 3')).to be false
      end

      it 'matches only search-related keywords' do
        expect(web_search.match?('Search for Ruby gems')).to be true
        expect(web_search.match?('Find information about AI')).to be true
        expect(web_search.match?('Lookup weather today')).to be true
        expect(web_search.match?('Tell me a joke')).to be false
      end

      it 'handles empty prompt' do
        expect(web_search.match?('')).to be false
      end

      it 'handles prompt with multiple keywords' do
        expect(web_search.match?('Search and calculate 2 + 2')).to be true
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
    let(:tool_manager) { LLMChain::Tools::ToolManagerFactory.create_default_toolset }

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
        expect(tools.any? { |t| t.is_a?(LLMChain::Tools::Calculator) }).to be true
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
        toolset = LLMChain::Tools::ToolManagerFactory.create_default_toolset
        expect(toolset.list_tools.length).to eq(4)
        expect(toolset.get_tool('calculator')).to be_a(LLMChain::Tools::Calculator)
      end
    end
  end

  describe 'Integration with Chain' do
    let(:memory) { LLMChain::Memory::Array.new }
    let(:tool_manager) { LLMChain::Tools::ToolManagerFactory.create_default_toolset }
    let(:client) { double("Client") }

    before do
      allow(client).to receive(:chat) { |prompt| prompt }
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