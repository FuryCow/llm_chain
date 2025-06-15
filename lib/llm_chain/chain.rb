module LLMChain
  class Chain
    attr_reader :model, :memory, :tools

    # @param model [String] Имя модели (gpt-4, llama3 и т.д.)
    # @param memory [#recall, #store] Объект памяти (по умолчанию: Memory::Array)
    # @param tools [Array<Tool>] Массив инструментов
    def initialize(model: "gpt-3.5-turbo", memory: nil, tools: [], **client_options)
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
      parts << "Контекст: #{context}" if context
      parts << "Инструменты: #{tool_responses}" unless tool_responses.empty?
      parts << "Запрос: #{prompt}"
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