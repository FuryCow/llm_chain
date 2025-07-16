require 'bigdecimal'

module LLMChain
  module Tools
    # Performs mathematical calculations and evaluates expressions.
    # Supports basic arithmetic and common math functions (sqrt, sin, cos, etc).
    #
    # @example
    #   calculator = LLMChain::Tools::Calculator.new
    #   calculator.call('What is sqrt(16) + 2 * 3?')
    #   # => { expression: 'sqrt(16) + 2 * 3', result: 10.0, formatted: 'sqrt(16) + 2 * 3 = 10.0' }
    class Calculator < Base
      KEYWORDS = %w[
        calculate compute math equation formula
        add subtract multiply divide
        sum difference product quotient
        plus minus times divided
        + - * / = equals
      ].freeze

      # Regex patterns for expression extraction and validation
      FUNC_EXPR_PATTERN = /\w+\([^\)]+\)(?:\s*[+\-\*\/]\s*(?:-?\d+(?:\.\d+)?|\w+\([^\)]+\)|\([^\)]+\))*)*/.freeze
      MATH_EXPR_PATTERN = /((?:-?\d+(?:\.\d+)?|\w+\([^\(\)]+\)|\([^\(\)]+\))\s*(?:[+\-\*\/]\s*(?:-?\d+(?:\.\d+)?|\w+\([^\(\)]+\)|\([^\(\)]+\))\s*)+)/.freeze
      QUOTED_EXPR_PATTERN = /"([^"]+)"|'([^']+)'/.freeze
      SIMPLE_MATH_PATTERN = /(\d+(?:\.\d+)?\s*[+\-\*\/]\s*\d+(?:\.\d+)?(?:\s*[+\-\*\/]\s*\d+(?:\.\d+)?)*)/.freeze
      FUNC_CALL_PATTERN = /\b(sqrt|sin|cos|tan|log|ln|exp|abs|round|ceil|floor)\s*\([^\)]+\)/i.freeze
      MATH_OPERATOR_PATTERN = /\d+\s*[+\-\*\/]\s*\d+/.freeze
      MATH_FUNCTION_PATTERN = /\b(sqrt|sin|cos|tan|log|ln|exp|abs|round|ceil|floor)\s*\(/i.freeze
      CLEAN_EXTRA_WORDS_PATTERN = /\b(is|what|equals?|result|answer|the)\b/i.freeze
      CLEAN_NON_MATH_PATTERN = /[^\d+\-*\/().\s]/.freeze
      MULTIPLE_SPACES_PATTERN = /\s+/.freeze
      VALID_MATH_EXPRESSION_PATTERN = /\d+(?:\.\d+)?\s*[+\-\*\/]\s*\d+(?:\.\d+)?/.freeze
      SAFE_EVAL_PATTERN = /\A[\d+\-*\/().\s]+\z/.freeze
      SAFE_EVAL_METHOD_PATTERN = /\.(abs|round|ceil|floor)\b/.freeze

      # Initializes the calculator tool.
      def initialize
        super(
          name: "calculator",
          description: "Performs mathematical calculations and evaluates expressions",
          parameters: {
            expression: {
              type: "string",
              description: "Mathematical expression to evaluate (e.g., '2 + 2', '15 * 3.14', 'sqrt(16)')"
            }
          }
        )
      end

      # Checks if the prompt contains a mathematical expression or keyword.
      # @param prompt [String]
      # @return [Boolean]
      def match?(prompt)
        contains_keywords?(prompt, KEYWORDS) || 
        contains_math_pattern?(prompt)
      end

      # Evaluates a mathematical expression found in the prompt.
      # @param prompt [String]
      # @param context [Hash]
      # @return [Hash] result, expression, and formatted string; or error info
      def call(prompt, context: {})
        expression = extract_expression(prompt)
        return { error: "No mathematical expression found" } if expression.empty?

        begin
          result = evaluate_expression(expression)
          {
            expression: expression,
            result: result,
            formatted: "#{expression} = #{result}"
          }
        rescue => e
          {
            expression: expression,
            error: e.message,
            formatted: "Error calculating '#{expression}': #{e.message}"
          }
        end
      end

      # Extracts the parameters for the tool from the prompt.
      # @param prompt [String]
      # @return [Hash]
      def extract_parameters(prompt)
        { expression: extract_expression(prompt) }
      end

      private

      # Checks if the prompt contains a math pattern (numbers and operators or functions).
      # @param prompt [String]
      # @return [Boolean]
      def contains_math_pattern?(prompt)
        prompt.match?(MATH_OPERATOR_PATTERN) ||
        prompt.match?(MATH_FUNCTION_PATTERN)
      end

      # Extracts a mathematical expression from the prompt using multiple strategies.
      # @param prompt [String]
      # @return [String]
      def extract_expression(prompt)
        extract_math_expression(prompt).tap { |expr| return expr unless expr.empty? }
        extract_quoted_expression(prompt).tap { |expr| return expr unless expr.empty? }
        extract_simple_math_expression(prompt).tap { |expr| return expr unless expr.empty? }
        extract_function_call(prompt).tap { |expr| return expr unless expr.empty? }
        extract_keyword_expression(prompt).tap { |expr| return expr unless expr.empty? }
        ""
      end

      # Extracts a complex math expression (numbers, functions, operators, spaces) from the prompt.
      def extract_math_expression(prompt)
        # First, try to match an expression starting with a function call and any number of operator+operand pairs
        func_expr = prompt.match(FUNC_EXPR_PATTERN)
        if func_expr
          expr = func_expr[0].strip.gsub(/[.?!]$/, '')
          puts "[DEBUG_CALC] Extracted math expression (func first): '#{expr}' from prompt: '#{prompt}'" if ENV['DEBUG_CALC']
          return expr
        end
        # Fallback to previous logic
        match = prompt.match(MATH_EXPR_PATTERN)
        expr = match ? match[1].strip.gsub(/[.?!]$/, '') : ""
        puts "[DEBUG_CALC] Extracted math expression: '#{expr}' from prompt: '#{prompt}'" if ENV['DEBUG_CALC']
        expr
      end

      # Extracts an expression in quotes from the prompt.
      def extract_quoted_expression(prompt)
        quoted = prompt.match(QUOTED_EXPR_PATTERN)
        quoted ? (quoted[1] || quoted[2]) : ""
      end

      # Extracts a simple math expression (e.g., 2 + 2) from the prompt.
      def extract_simple_math_expression(prompt)
        math_expr = prompt.match(SIMPLE_MATH_PATTERN)
        math_expr ? math_expr[1].strip : ""
      end

      # Extracts a function call (e.g., sqrt(16)) from the prompt.
      def extract_function_call(prompt)
        func_expr = prompt.match(FUNC_CALL_PATTERN)
        func_expr ? func_expr[0] : ""
      end

      # Extracts an expression after a math keyword from the prompt.
      def extract_keyword_expression(prompt)
        KEYWORDS.each do |keyword|
          if prompt.downcase.include?(keyword)
            escaped_keyword = Regexp.escape(keyword)
            after_keyword = prompt.split(/#{escaped_keyword}/i, 2)[1]
            if after_keyword
              expr = after_keyword.strip.split(/[.!?]/).first
              if expr
                cleaned = clean_expression(expr)
                return cleaned unless cleaned.empty?
              end
            end
          end
        end
        ""
      end

      # Cleans up a candidate expression, removing extra words and keeping only numbers and operators.
      # @param expr [String]
      # @return [String]
      def clean_expression(expr)
        cleaned = expr.gsub(CLEAN_EXTRA_WORDS_PATTERN, '')
                     .gsub(CLEAN_NON_MATH_PATTERN, ' ')
                     .gsub(MULTIPLE_SPACES_PATTERN, ' ')
                     .strip
        if cleaned.match?(VALID_MATH_EXPRESSION_PATTERN)
          cleaned
        else
          ""
        end
      end

      # Evaluates a mathematical expression, supporting common math functions.
      # @param expression [String]
      # @return [Numeric]
      def evaluate_expression(expression)
        expr = expression.downcase
        max_iterations = 10
        max_iterations.times do
          before = expr.dup
          expr.gsub!(/(?<!Math\.)sqrt\s*\((.*?)\)/, 'Math.sqrt(\1)')
          expr.gsub!(/(?<!Math\.)sin\s*\((.*?)\)/, 'Math.sin(\1)')
          expr.gsub!(/(?<!Math\.)cos\s*\((.*?)\)/, 'Math.cos(\1)')
          expr.gsub!(/(?<!Math\.)tan\s*\((.*?)\)/, 'Math.tan(\1)')
          expr.gsub!(/(?<!Math\.)log\s*\((.*?)\)/, 'Math.log10(\1)')
          expr.gsub!(/(?<!Math\.)ln\s*\((.*?)\)/, 'Math.log(\1)')
          expr.gsub!(/(?<!Math\.)exp\s*\((.*?)\)/, 'Math.exp(\1)')
          expr.gsub!(/(?<!\.)abs\s*\((.*?)\)/, '(\1).abs')
          expr.gsub!(/(?<!\.)round\s*\((.*?)\)/, '(\1).round')
          expr.gsub!(/(?<!\.)ceil\s*\((.*?)\)/, '(\1).ceil')
          expr.gsub!(/(?<!\.)floor\s*\((.*?)\)/, '(\1).floor')
          break if expr == before
        end
        puts "[DEBUG_CALC] Final eval expression: '#{expr}'" if ENV['DEBUG_CALC']
        result = safe_eval(expr)
        if result.is_a?(Float)
          result.round(10)
        else
          result
        end
      end

      # Safely evaluates a mathematical expression.
      # Only allows numbers, operators, parentheses, and supported Math methods.
      # @param expression [String]
      # @return [Numeric]
      def safe_eval(expression)
        unless expression.match?(SAFE_EVAL_PATTERN) || 
               expression.include?('Math.') || 
               expression.match?(SAFE_EVAL_METHOD_PATTERN)
          raise "Unsafe expression: #{expression}"
        end
        eval(expression)
      end

      # @return [Array<String>]
      def required_parameters
        ['expression']
      end
    end
  end
end 