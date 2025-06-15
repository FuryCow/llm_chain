module LLMChain
  class Chain
    attr_reader :model, :memory, :tools

    # @param model [String] Имя модели (gpt-4, llama3 и т.д.)
    # @param memory [#recall, #store] Объект памяти (по умолчанию: Memory::Array)
    # @param tools [Array<Tool>] Массив инструментов
    def initialize(model: nil, memory: nil, tools: [], **client_options)
      @model = model
      @memory = memory || Memory::Array.new
      @tools = tools
      @client = ClientRegistry.client_for(model, **client_options)
    end

    # Основной метод для взаимодействия с цепочкой
    # @param prompt [String] Входной промпт
    # @param stream [Boolean] Использовать ли потоковый вывод
    # @yield [String] Передает чанки ответа если stream=true
    def ask(prompt, stream: false, &block)
      context = memory.recall(prompt)
      tool_responses = process_tools(prompt)
      
      full_prompt = build_prompt(prompt, context, tool_responses)
      response = generate_response(full_prompt, stream: stream, &block)
      
      memory.store(prompt, response)
      response
    end

    private

    # Обработка инструментов
    def process_tools(prompt)
      @tools.each_with_object({}) do |tool, acc|
        acc[tool.name] = tool.call(prompt) if tool.match?(prompt)
      end
    end

    # Построение итогового промпта
    def build_prompt(prompt, context, tool_responses)
      parts = []
      
      # Добавляем историю диалога
      if context.any?
        parts << "История диалога:"
        context.each do |item|
          parts << "Вопрос: #{item[:prompt]}"
          parts << "Ответ: #{item[:response]}"
        end
      end
      
      # Добавляем результаты инструментов
      unless tool_responses.empty?
        parts << "Данные инструментов: #{tool_responses.to_json}"
      end
      
      # Добавляем текущий запрос
      parts << "Текущий запрос: #{prompt}"
      
      parts.join("\n\n")
    end

    # Генерация ответа через LLM
    def generate_response(prompt, stream: false, &block)
      if stream
        stream_response(prompt, &block)
      else
        @client.chat(prompt)
      end
    end

    # Потоковый вывод
    def stream_response(prompt)
      buffer = ""
      @client.stream_chat(prompt) do |chunk|
        buffer << chunk
        yield chunk if block_given?
      end
      buffer
    end
  end
end