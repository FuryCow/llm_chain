require 'bigdecimal'

module LLMChain
  module Tools
    class Calculator < Base
      KEYWORDS = %w[
        calculate compute math equation formula
        add subtract multiply divide
        sum difference product quotient
        plus minus times divided
        + - * / = equals
      ].freeze

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

      def match?(prompt)
        contains_keywords?(prompt, KEYWORDS) || 
        contains_math_pattern?(prompt)
      end

      def call(prompt, context: {})
        expression = extract_expression(prompt)
        return "No mathematical expression found" if expression.empty?

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

      def extract_parameters(prompt)
        { expression: extract_expression(prompt) }
      end

      private

      def contains_math_pattern?(prompt)
        # Проверяем наличие математических операторов и чисел
        prompt.match?(/\d+\s*[+\-*\/]\s*\d+/) ||
        prompt.match?(/\b(sqrt|sin|cos|tan|log|ln|exp|abs|round|ceil|floor)\s*\(/i)
      end

      def extract_expression(prompt)
        # Пробуем найти выражение в кавычках
        quoted = prompt.match(/"([^"]+)"/) || prompt.match(/'([^']+)'/)
        return quoted[1] if quoted

        # Пробуем найти простое выражение в тексте сначала (более точно)
        math_expr = prompt.match(/(\d+(?:\.\d+)?\s*[+\-*\/]\s*\d+(?:\.\d+)?(?:\s*[+\-*\/]\s*\d+(?:\.\d+)?)*)/)
        return math_expr[1].strip if math_expr

        # Ищем функции
        func_expr = prompt.match(/\b(sqrt|sin|cos|tan|log|ln|exp|abs|round|ceil|floor)\s*\([^)]+\)/i)
        return func_expr[0] if func_expr

        # Ищем выражение после ключевых слов
        KEYWORDS.each do |keyword|
          if prompt.downcase.include?(keyword)
            escaped_keyword = Regexp.escape(keyword)
            after_keyword = prompt.split(/#{escaped_keyword}/i, 2)[1]
            if after_keyword
              # Извлекаем математическое выражение
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

      def clean_expression(expr)
        # Удаляем лишние слова но оставляем числа и операторы
        cleaned = expr.gsub(/\b(is|what|equals?|result|answer|the)\b/i, '')
                     .gsub(/[^\d+\-*\/().\s]/, ' ')  # заменяем на пробелы, не удаляем
                     .gsub(/\s+/, ' ')  # убираем множественные пробелы
                     .strip
        
        # Проверяем что результат похож на математическое выражение
        if cleaned.match?(/\d+(?:\.\d+)?\s*[+\-*\/]\s*\d+(?:\.\d+)?/)
          cleaned
        else
          ""
        end
      end

      def evaluate_expression(expression)
        # Заменяем математические функции на Ruby-методы
        expr = expression.downcase
                        .gsub(/sqrt\s*\(([^)]+)\)/) { "Math.sqrt(#{$1})" }
                        .gsub(/sin\s*\(([^)]+)\)/) { "Math.sin(#{$1})" }
                        .gsub(/cos\s*\(([^)]+)\)/) { "Math.cos(#{$1})" }
                        .gsub(/tan\s*\(([^)]+)\)/) { "Math.tan(#{$1})" }
                        .gsub(/log\s*\(([^)]+)\)/) { "Math.log10(#{$1})" }
                        .gsub(/ln\s*\(([^)]+)\)/) { "Math.log(#{$1})" }
                        .gsub(/exp\s*\(([^)]+)\)/) { "Math.exp(#{$1})" }
                        .gsub(/abs\s*\(([^)]+)\)/) { "(#{$1}).abs" }
                        .gsub(/round\s*\(([^)]+)\)/) { "(#{$1}).round" }
                        .gsub(/ceil\s*\(([^)]+)\)/) { "(#{$1}).ceil" }
                        .gsub(/floor\s*\(([^)]+)\)/) { "(#{$1}).floor" }

        # Безопасная оценка выражения
        result = safe_eval(expr)
        
        # Округляем результат до разумного количества знаков
        if result.is_a?(Float)
          result.round(10)
        else
          result
        end
      end

      def safe_eval(expression)
        # Проверяем, что выражение содержит только безопасные символы
        unless expression.match?(/\A[\d+\-*\/().\s]+\z/) || 
               expression.include?('Math.') || 
               expression.match?(/\.(abs|round|ceil|floor)\b/)
          raise "Unsafe expression: #{expression}"
        end

        # Оцениваем выражение
        eval(expression)
      end

      def required_parameters
        ['expression']
      end
    end
  end
end 