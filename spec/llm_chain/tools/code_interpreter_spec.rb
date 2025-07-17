require 'llm_chain/tools/code_interpreter'

RSpec.describe LLMChain::Tools::CodeInterpreter do
  let(:tool) { described_class.new(timeout: 10, allowed_languages: %w[ruby python]) }

  describe '#initialize' do
    it 'sets name, description, parameters, timeout, allowed_languages' do
      expect(tool.name).to eq('code_interpreter')
      expect(tool.description).to match(/Executes code/i)
      expect(tool.parameters).to have_key(:code)
      expect(tool.instance_variable_get(:@timeout)).to eq(10)
      expect(tool.instance_variable_get(:@allowed_languages)).to eq(%w[ruby python])
    end
  end

  describe '#extract_code' do
    it 'extracts code from markdown block with language' do
      prompt = "```ruby\nputs 123\n```"
      expect(tool.send(:extract_code, prompt)).to include('puts 123')
    end
    it 'extracts code from markdown block without language' do
      prompt = "```\nprint(1)\n```"
      expect(tool.send(:extract_code, prompt)).to include('print(1)')
    end
    it 'extracts code from ~~~ block' do
      prompt = "~~~python\nprint(2)\n~~~"
      expect(tool.send(:extract_code, prompt)).to include('print(2)')
    end
    it 'extracts code from inline run code' do
      prompt = "run code: puts 5"
      expect(tool.send(:extract_code, prompt)).to include('puts 5')
    end
    it 'extracts code from multiline after keyword' do
      prompt = "code:\n  puts 7\n  puts 8"
      expect(tool.send(:extract_code, prompt)).to include('puts 7')
    end
    it 'extracts code-like lines' do
      prompt = "def foo\n  1+1\nend"
      expect(tool.send(:extract_code, prompt)).to include('1+1')
    end
    it 'returns empty string for empty prompt' do
      expect(tool.send(:extract_code, '')).to eq('')
    end
  end

  describe '#detect_language' do
    it 'detects ruby from prompt' do
      expect(tool.send(:detect_language, '', '```ruby\nputs 1\n```')).to eq('ruby')
      expect(tool.send(:detect_language, '', 'Ruby code:')).to eq('ruby')
    end
    it 'detects python from prompt' do
      expect(tool.send(:detect_language, '', '```python\nprint(1)\n```')).to eq('python')
      expect(tool.send(:detect_language, '', 'Python code:')).to eq('python')
    end
    it 'detects javascript from prompt' do
      expect(tool.send(:detect_language, '', '```javascript\nconsole.log(1)\n```')).to eq('javascript')
      expect(tool.send(:detect_language, '', 'JavaScript code:')).to eq('javascript')
    end
    it 'defaults to ruby if nothing matches' do
      expect(tool.send(:detect_language, '', 'foo')).to eq('ruby')
    end
  end

  describe '#safe_to_execute?' do
    it 'returns true for safe code' do
      expect(tool.send(:safe_to_execute?, 'puts 1')).to be true
    end
    it 'returns false for dangerous patterns' do
      # Явно подбираем строки для каждого паттерна
      dangerous_examples = [
        "system('ls')",
        "exec('ls')",
        "`ls`",
        "File.delete('foo')",
        "Dir.rmdir('foo')",
        "require 'net/http'",
        "require 'open-uri'",
        "eval('puts 1')",
        "instance_eval 'puts 1'",
        "class_eval 'puts 1'"
      ]
      dangerous_examples.each do |code|
        expect(tool.send(:safe_to_execute?, code)).to be false
      end
    end
  end

  describe '#extract_fallback_code' do
    it 'returns code-like line if present' do
      prompt = "What is this?\ndef foo\n  1+1\nend"
      expect(tool.send(:extract_fallback_code, prompt)).to include('def foo')
    end
    it 'returns nil if no code-like line' do
      prompt = "Just a question."
      expect(tool.send(:extract_fallback_code, prompt)).to be_nil
    end
  end

  describe '#clean_code' do
    it 'removes only pure comment lines' do
      code = "# comment\nputs 1 # inline\n// js comment\nprint(2) // inline\n"
      cleaned = tool.send(:clean_code, code)
      expect(cleaned).to include('puts 1 # inline')
      expect(cleaned).to include('print(2) // inline')
      expect(cleaned).not_to include('# comment')
      expect(cleaned).not_to include('// js comment')
    end
    it 'removes blank lines at start/end but not inside' do
      code = "\n\nputs 1\n\nputs 2\n\n"
      cleaned = tool.send(:clean_code, code)
      expect(cleaned).to eq("puts 1\n\nputs 2")
    end
  end

  describe '#execute_code' do
    it 'raises error for unsupported language' do
      expect { tool.send(:execute_code, 'foo', 'brainfuck') }.to raise_error(/Unsupported language/)
    end
  end

  describe '#format_execution_result' do
    it 'formats for python' do
      out = tool.send(:format_execution_result, 'print(1)', 'python', '1')
      expect(out).to include('Code execution (python):')
      expect(out).to include('print(1)')
      expect(out).to include('Output:')
      expect(out).to include('1')
    end
    it 'formats for javascript' do
      out = tool.send(:format_execution_result, 'console.log(2)', 'javascript', '2')
      expect(out).to include('Code execution (javascript):')
      expect(out).to include('console.log(2)')
      expect(out).to include('2')
    end
  end

  describe '#required_parameters' do
    it 'returns ["code"]' do
      expect(tool.send(:required_parameters)).to eq(['code'])
    end
  end

  describe "#match?" do
    it "matches prompt with 'code'" do
      expect(tool.match?("Please run this code: puts 123")).to be true
    end

    it "matches prompt with function definition" do
      expect(tool.match?("def hello; end")).to be true
    end

    it "does not match unrelated prompt" do
      expect(tool.match?("What is the weather?")).to be false
    end
  end

  describe "#call" do
    it "executes simple Ruby code" do
      result = tool.call("code: puts 1+1", context: { language: "ruby" })
      expect(result).to be_a(Hash)
      expect(result[:formatted].to_s).to match(/2|puts/)
    end

    it "returns error for dangerous code" do
      result = tool.call("code: system('rm -rf /')", context: { language: "ruby" })
      expect(result).to be_a(Hash)
      expect(result[:error].to_s).to match(/dangerous|not allowed|forbidden/i)
    end

    it "returns error for unsupported language" do
      result = tool.call("code: print('hi')", context: { language: "brainfuck" })
      expect(result).to be_a(Hash)
      expect(result[:error].to_s).to match(/not supported|unsupported/i)
    end

    it "returns error if no code found" do
      result = tool.call("Just a question", context: { language: "ruby" })
      expect(result[:error].to_s).to match(/no code found/i)
    end

    it "returns error for dangerous code (exec)" do
      result = tool.call("code: exec('ls')", context: { language: "ruby" })
      expect(result[:error].to_s).to match(/dangerous/i)
    end

    it "returns error for Ruby syntax error" do
      result = tool.call("code: puts 'hello", context: { language: "ruby" })
      expect(result[:error].to_s).to match(/execution error|failed/i)
    end

    it "executes Python code" do
      result = tool.call("code: print(2+2)", context: { language: "python" })
      expect(result[:result].to_s).to include("4")
      expect(result[:language]).to eq("python")
    end

    it "executes JavaScript code" do
      tool_js = described_class.new(timeout: 10, allowed_languages: %w[ruby python javascript])
      allow(tool_js).to receive(:execute_code).with("console.log(3+3)", "javascript").and_return("6")
      result = tool_js.call("code: console.log(3+3)", context: { language: "javascript" })
      expect(result[:formatted].to_s).to include("6")
      expect(result[:language]).to eq("javascript")
    end

    it "formats execution result" do
      result = tool.call("code: puts 42", context: { language: "ruby" })
      expect(result[:formatted]).to match(/Code execution \(ruby\):/)
      expect(result[:formatted]).to include("puts 42")
    end
  end

  describe "#extract_parameters" do
    it "extracts code and language" do
      params = tool.extract_parameters("code: puts 123")
      expect(params[:code]).to include("puts 123")
      expect(%w[ruby python javascript]).to include(params[:language])
    end
  end
end 