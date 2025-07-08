require 'tempfile'
require 'timeout'

module LLMChain
  module Tools
    class CodeInterpreter < Base
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
        # Normalize line endings (CRLF -> LF)
        normalized_prompt = normalize_line_endings(prompt)
        
        # 1. Try various markdown block patterns
        code = extract_markdown_code_blocks(normalized_prompt)
        return clean_code(code) if code && !code.empty?

        # 2. Attempt inline "run code:" patterns
        code = extract_inline_code_commands(normalized_prompt)
        return clean_code(code) if code && !code.empty?

        # 3. Look for code after keywords across multiple lines
        code = extract_multiline_code_blocks(normalized_prompt)
        return clean_code(code) if code && !code.empty?

        # 4. Fallback: detect code-like lines
        code = extract_code_like_lines(normalized_prompt)
        return clean_code(code) if code && !code.empty?

        # 5. Last resort – everything after first code-looking line
        code = extract_fallback_code(normalized_prompt)
        clean_code(code)
      end

      private

      def normalize_line_endings(text)
        text.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
      end

      def extract_markdown_code_blocks(prompt)
        # Pattern list for markdown code blocks
        patterns = [
          # Standard fenced block with language tag
          /```(?:ruby|python|javascript|js)\s*\n(.*?)\n```/mi,
          # Fenced block without language tag
          /```\s*\n(.*?)\n```/mi,
          # Fenced block any language
          /```\w*\s*\n(.*?)\n```/mi,
          # Using ~~~ instead of ```
          /~~~(?:ruby|python|javascript|js)?\s*\n(.*?)\n~~~/mi,
          # Single-line fenced block
          /```(?:ruby|python|javascript|js)?(.*?)```/mi,
          # Indented code block (4 spaces)
          /^    (.+)$/m
        ]
        
        patterns.each do |pattern|
          match = prompt.match(pattern)
          return match[1] if match && match[1].strip.length > 0
        end
        
        nil
      end

      def extract_inline_code_commands(prompt)
        # Inline "run code" commands
        inline_patterns = [
          /execute\s+code:\s*(.+)/i,
          /run\s+code:\s*(.+)/i,
          /run\s+this:\s*(.+)/i,
          /execute:\s*(.+)/i,
          /run:\s*(.+)/i,
          /code:\s*(.+)/i
        ]
        
        inline_patterns.each do |pattern|
          match = prompt.match(pattern)
          return match[1] if match && match[1].strip.length > 0
        end
        
        nil
      end

      def extract_multiline_code_blocks(prompt)
        lines = prompt.split("\n")
        
        KEYWORDS.each do |keyword|
          keyword_line_index = lines.find_index { |line| line.downcase.include?(keyword.downcase) }
          next unless keyword_line_index
          
          # Take lines after the keyword
          code_lines = lines[(keyword_line_index + 1)..-1]
          next unless code_lines
          
          # Find the first non-empty line
          first_code_line = code_lines.find_index { |line| !line.strip.empty? }
          next unless first_code_line
          
          # Take all lines starting from the first non-empty line
          relevant_lines = code_lines[first_code_line..-1]
          
          # Determine indentation of the first code line
          first_line = relevant_lines.first
          indent = first_line.match(/^(\s*)/)[1].length
          
          # Collect all lines with the same or greater indentation
          code_block = []
          relevant_lines.each do |line|
            if line.strip.empty?
              code_block << "" # Preserve empty lines
            elsif line.match(/^(\s*)/)[1].length >= indent
              code_block << line
            else
              break # Stop when indentation decreases
            end
          end
          
          return code_block.join("\n") if code_block.any? { |line| !line.strip.empty? }
        end
        
        nil
      end

      def extract_code_like_lines(prompt)
        lines = prompt.split("\n")
        
        code_lines = lines.select do |line|
          stripped = line.strip
          next false if stripped.empty?
          
          # Check various code patterns
          stripped.match?(/^(def|class|function|var|let|const|print|puts|console\.log)/i) ||
          stripped.match?(/^\w+\s*[=+\-*\/]\s*/) ||
          stripped.match?(/^\s*(if|for|while|return|import|require)[\s(]/i) ||
          stripped.match?(/puts\s+/) ||
          stripped.match?(/print\s*\(/) ||
          stripped.match?(/^\w+\(.*\)/) ||
          stripped.match?(/^\s*#.*/) ||  # Comments
          stripped.match?(/^\s*\/\/.*/) || # JS comments
          stripped.match?(/^\s*\/\*.*\*\//) # Block comments
        end
        
        code_lines.join("\n") if code_lines.any?
      end

      def extract_fallback_code(prompt)
        # Final attempt – look for anything resembling code
        lines = prompt.split("\n")
        
        # Find first line that looks like code
        start_index = lines.find_index do |line|
          stripped = line.strip
          stripped.match?(/^(def|class|function|puts|print|console\.log|var|let|const)/i) ||
          stripped.include?('=') ||
          stripped.include?(';')
        end
        
        return nil unless start_index
        
        # Take all subsequent lines
        code_lines = lines[start_index..-1]
        
        # Stop when line clearly not code
        end_index = code_lines.find_index do |line|
          stripped = line.strip
          stripped.match?(/^(что|как|где|когда|зачем|почему|what|how|where|when|why)/i) || # Russian/English question words
          stripped.length > 100 # Too long -> unlikely code
        end
        
        relevant_lines = end_index ? code_lines[0...end_index] : code_lines
        relevant_lines.join("\n")
      end

      def clean_code(code)
        return "" unless code
        
        lines = code.strip.lines
        
        # Remove pure comment lines, keep inline comments
        cleaned_lines = lines.reject do |line|
          stripped = line.strip
          # Remove only lines that contain ONLY comments
          stripped.match?(/^\s*#[^{]*$/) || # Ruby comments (excluding interpolation)
          stripped.match?(/^\s*\/\/.*$/) || # JS comments
          stripped.match?(/^\s*\/\*.*\*\/\s*$/) # Block comments
        end
        
        # Remove blank lines at the beginning and end, but keep them inside
        start_index = cleaned_lines.find_index { |line| !line.strip.empty? }
        return "" unless start_index
        
        end_index = cleaned_lines.rindex { |line| !line.strip.empty? }
        return "" unless end_index
        
        cleaned_lines[start_index..end_index].join
      end

      def detect_language(code, prompt)
        # Explicit language specification
        return 'ruby' if prompt.match?(/```ruby/i) || prompt.include?('Ruby')
        return 'python' if prompt.match?(/```python/i) || prompt.include?('Python')
        return 'javascript' if prompt.match?(/```(javascript|js)/i) || prompt.include?('JavaScript')

        # Determine by syntax
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
          # Create a temporary file
          Tempfile.create(['code', '.rb']) do |file|
            file.write(code)
            file.flush
            
            # Execute code in a separate process
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
            
            # Try node.js
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