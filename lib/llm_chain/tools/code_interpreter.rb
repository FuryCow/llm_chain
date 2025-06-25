require 'tempfile'
require 'timeout'

module LLMChain
  module Tools
    class CodeInterpreter < BaseTool
      KEYWORDS = %w[
        code run execute script program
        ruby python javascript
        calculate compute
        def class function
      ].freeze

      SUPPORTED_LANGUAGES = %w[ruby python javascript].freeze
      
      DANGEROUS_PATTERNS = [
        /system\s*\(/i,
        /exec\s*\(/i, 
        /`[^`]*`/,
        /File\.(delete|rm|unlink)/i,
        /Dir\.(delete|rmdir)/i,
        /require\s+['"]net\/http['"]/i,
        /require\s+['"]open-uri['"]/i,
        /eval\s*\(/i,
        /instance_eval/i,
        /class_eval/i
      ].freeze

      def initialize(timeout: 30, allowed_languages: SUPPORTED_LANGUAGES)
        @timeout = timeout
        @allowed_languages = allowed_languages
        
        super(
          name: "code_interpreter",
          description: "Executes code safely in an isolated environment",
          parameters: {
            code: {
              type: "string",
              description: "Code to execute"
            },
            language: {
              type: "string", 
              description: "Programming language (ruby, python, javascript)",
              enum: @allowed_languages
            }
          }
        )
      end

      def match?(prompt)
        contains_keywords?(prompt, KEYWORDS) ||
        contains_code_blocks?(prompt) ||
        contains_function_definitions?(prompt)
      end

      def call(prompt, context: {})
        code = extract_code(prompt)
        language = detect_language(code, prompt)
        
        return "No code found to execute" if code.empty?
        return "Unsupported language: #{language}" unless @allowed_languages.include?(language)
        
        begin
          if safe_to_execute?(code)
            result = execute_code(code, language)
            {
              code: code,
              language: language,
              result: result,
              formatted: format_execution_result(code, language, result)
            }
          else
            {
              code: code,
              language: language,
              error: "Code contains potentially dangerous operations",
              formatted: "Cannot execute: Code contains potentially dangerous operations"
            }
          end
        rescue => e
          {
            code: code,
            language: language,
            error: e.message,
            formatted: "Execution error: #{e.message}"
          }
        end
      end

      def extract_parameters(prompt)
        code = extract_code(prompt)
        {
          code: code,
          language: detect_language(code, prompt)
        }
      end

      private

      def contains_code_blocks?(prompt)
        prompt.include?('```') || 
        prompt.match?(/^\s*def\s+\w+/m) ||
        prompt.match?(/^\s*class\s+\w+/m)
      end

      def contains_function_definitions?(prompt)
        prompt.match?(/\b(def|function|class)\s+\w+/i)
      end

      def extract_code(prompt)
        # Ищем код в блоках ```
        code_block = prompt.match(/```(?:ruby|python|javascript|js)?\s*\n(.*?)\n```/m)
        return code_block[1].strip if code_block

        # Ищем код после ключевых слов в той же строке (например, "Execute code: puts ...")
        execute_match = prompt.match(/execute\s+code:\s*(.+)/i)
        return execute_match[1].strip if execute_match

        run_match = prompt.match(/run\s+code:\s*(.+)/i)
        return run_match[1].strip if run_match

        # Ищем код после ключевых слов в разных строках
        KEYWORDS.each do |keyword|
          if prompt.downcase.include?(keyword)
            lines = prompt.split("\n")
            keyword_line = lines.find_index { |line| line.downcase.include?(keyword) }
            if keyword_line
              # Берем строки после ключевого слова
              code_lines = lines[(keyword_line + 1)..-1]
              code = code_lines&.join("\n")&.strip
              return code if code && !code.empty?
            end
          end
        end

        # Ищем строки, которые выглядят как код
        code_lines = prompt.split("\n").select do |line|
          line.strip.match?(/^(def|class|function|var|let|const|print|puts|console\.log)/i) ||
          line.strip.match?(/^\w+\s*[=+\-*\/]\s*/) ||
          line.strip.match?(/^\s*(if|for|while|return)[\s(]/i) ||
          line.strip.match?(/puts\s+/) ||
          line.strip.match?(/print\s*\(/)
        end

        code_lines.join("\n")
      end

      def detect_language(code, prompt)
        # Явное указание языка
        return 'ruby' if prompt.match?(/```ruby/i) || prompt.include?('Ruby')
        return 'python' if prompt.match?(/```python/i) || prompt.include?('Python')
        return 'javascript' if prompt.match?(/```(javascript|js)/i) || prompt.include?('JavaScript')

        # Определение по синтаксису
        return 'ruby' if code.include?('puts') || code.include?('def ') || code.match?(/\bend\b/)
        return 'python' if code.include?('print(') || code.match?(/def \w+\(.*\):/) || code.include?('import ')
        return 'javascript' if code.include?('console.log') || code.include?('function ') || code.include?('var ') || code.include?('let ')

        'ruby' # default
      end

      def safe_to_execute?(code)
        DANGEROUS_PATTERNS.none? { |pattern| code.match?(pattern) }
      end

      def execute_code(code, language)
        case language
        when 'ruby'
          execute_ruby(code)
        when 'python'
          execute_python(code)
        when 'javascript'
          execute_javascript(code)
        else
          raise "Unsupported language: #{language}"
        end
      end

      def execute_ruby(code)
        Timeout.timeout(@timeout) do
          # Создаем временный файл
          Tempfile.create(['code', '.rb']) do |file|
            file.write(code)
            file.flush
            
            # Выполняем код в отдельном процессе
            result = `ruby #{file.path} 2>&1`
            
            if $?.success?
              result.strip
            else
              raise "Ruby execution failed: #{result}"
            end
          end
        end
      end

      def execute_python(code)
        Timeout.timeout(@timeout) do
          Tempfile.create(['code', '.py']) do |file|
            file.write(code)
            file.flush
            
            result = `python3 #{file.path} 2>&1`
            
            if $?.success?
              result.strip
            else
              raise "Python execution failed: #{result}"
            end
          end
        end
      end

      def execute_javascript(code)
        Timeout.timeout(@timeout) do
          Tempfile.create(['code', '.js']) do |file|
            file.write(code)
            file.flush
            
            # Пробуем node.js
            result = `node #{file.path} 2>&1`
            
            if $?.success?
              result.strip
            else
              raise "JavaScript execution failed: #{result}"
            end
          end
        end
      end

      def format_execution_result(code, language, result)
        "Code execution (#{language}):\n\n```#{language}\n#{code}\n```\n\nOutput:\n```\n#{result}\n```"
      end

      def required_parameters
        ['code']
      end
    end
  end
end 