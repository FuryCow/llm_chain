require 'json'

module LLMChain
  class Chain
    attr_reader :model, :memory, :tools, :retriever

    # @param model [String] Имя модели (gpt-4, llama3 и т.д.)
    # @param memory [#recall, #store] Объект памяти
    # @param tools [Array<Tool>] Массив инструментов
    # @param retriever [#search] RAG-ретривер (Weaviate, Pinecone и т.д.)
    # @param client_options [Hash] Опции для клиента LLM
    def initialize(model: nil, memory: nil, tools: [], retriever: nil, **client_options)
      @model = model
      @memory = memory || Memory::Array.new
      @tools = tools
      @retriever = retriever || Embeddings::Clients::Local::WeaviateRetriever.new
      @client = ClientRegistry.client_for(model, **client_options)
    end

    # Основной метод для взаимодействия с цепочкой
    # @param prompt [String] Входной промпт
    # @param stream [Boolean] Использовать ли потоковый вывод
    # @param rag_context [Boolean] Использовать ли RAG-контекст
    # @param rag_options [Hash] Опции для RAG-поиска
    # @yield [String] Передает чанки ответа если stream=true
    def ask(prompt, stream: false, rag_context: false, rag_options: {}, &block)
      # 1. Сбор контекста
      context = memory.recall(prompt)
      tool_responses = process_tools(prompt)
      rag_documents = retrieve_rag_context(prompt, rag_options) if rag_context

      # 2. Построение промпта
      full_prompt = build_prompt(
        prompt: prompt,
        memory_context: context,
        tool_responses: tool_responses,
        rag_documents: rag_documents
      )

      # 3. Генерация ответа
      response = generate_response(full_prompt, stream: stream, &block)

      # 4. Сохранение в память
      memory.store(prompt, response)
      response
    end

    private

    def retrieve_rag_context(query, options = {})
      return [] unless @retriever

      limit = options[:limit] || 3
      @retriever.search(query, limit: limit)
    rescue => e
      puts "[RAG Error] #{e.message}"
      []
    end

    def process_tools(prompt)
      @tools.each_with_object({}) do |tool, acc|
        if tool.match?(prompt)
          response = tool.call(prompt)
          acc[tool.name] = response unless response.nil?
        end
      end
    end

    def build_prompt(prompt:, memory_context: nil, tool_responses: {}, rag_documents: nil)
      parts = []

      if memory_context&.any?
        parts << "Dialogue history:"
        memory_context.each do |item|
          parts << "User: #{item[:prompt]}"
          parts << "Assistant: #{item[:response]}"
        end
      end

      if rag_documents&.any?
        parts << "Relevant documents:"
        rag_documents.each_with_index do |doc, i|
          parts << "Document #{i + 1}: #{doc['content']}"
          parts << "Metadata: #{doc['metadata'].to_json}" if doc['metadata']
        end
      end

      unless tool_responses.empty?
        parts << "Tool results:"
        tool_responses.each do |name, response|
          parts << "#{name}: #{response}"
        end
      end

      parts << "Qurrent question: #{prompt}"

      parts.join("\n\n")
    end

    def generate_response(prompt, stream: false, &block)
      if stream
        stream_response(prompt, &block)
      else
        @client.chat(prompt)
      end
    end

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