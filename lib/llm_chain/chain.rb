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
      @retriever = if retriever.nil?
                    Embeddings::Clients::Local::WeaviateRetriever.new
                  elsif retriever == false
                    nil
                  else
                    retriever
                  end
      @client = ClientRegistry.client_for(model, **client_options)
    end

    # Основной метод для взаимодействия с цепочкой
    # @param prompt [String] Входной промпт
    # @param stream [Boolean] Использовать ли потоковый вывод
    # @param rag_context [Boolean] Использовать ли RAG-контекст
    # @param rag_options [Hash] Опции для RAG-поиска
    # @yield [String] Передает чанки ответа если stream=true
    def ask(prompt, stream: false, rag_context: false, rag_options: {}, &block)
      context = collect_context(prompt, rag_context, rag_options)
      full_prompt = build_prompt(prompt: prompt, **context)
      response = generate_response(full_prompt, stream: stream, &block)
      memory.store(prompt, response)
      response
    end

    def collect_context(prompt, rag_context, rag_options)
      context = memory.recall(prompt)
      tool_responses = process_tools(prompt)
      rag_documents = retrieve_rag_context(prompt, rag_options) if rag_context
      { memory_context: context, tool_responses: tool_responses, rag_documents: rag_documents }
    end

    private

    def retrieve_rag_context(query, options = {})
      return [] unless @retriever

      limit = options[:limit] || 3
      @retriever.search(query, limit: limit)
    rescue => e
      raise Error, "Cannot retrieve rag context"
    end

    def process_tools(prompt)
      return {} if @tools.nil? || (@tools.respond_to?(:empty?) && @tools.empty?)
      
      # Если @tools - это ToolManager
      if @tools.respond_to?(:auto_execute)
        @tools.auto_execute(prompt)
      elsif @tools.is_a?(Array)
        # Старая логика для массива инструментов
        @tools.each_with_object({}) do |tool, acc|
          if tool.match?(prompt)
            response = tool.call(prompt)
            acc[tool.name] = response unless response.nil?
          end
        end
      else
        {}
      end
    end

    def build_prompt(prompt:, memory_context: nil, tool_responses: {}, rag_documents: nil)
      parts = []
      parts << build_memory_context(memory_context) if memory_context&.any?
      parts << build_rag_documents(rag_documents) if rag_documents&.any?
      parts << build_tool_responses(tool_responses) unless tool_responses.empty?
      parts << "Сurrent question: #{prompt}"
      parts.join("\n\n")
    end

    def build_memory_context(memory_context)
      parts = ["Dialogue history:"]
      memory_context.each do |item|
        parts << "User: #{item[:prompt]}"
        parts << "Assistant: #{item[:response]}"
      end
      parts.join("\n")
    end

    def build_rag_documents(rag_documents)
      parts = ["Relevant documents:"]
      rag_documents.each_with_index do |doc, i|
        parts << "Document #{i + 1}: #{doc['content']}"
        parts << "Metadata: #{doc['metadata'].to_json}" if doc['metadata']
      end
      parts.join("\n")
    end

    def build_tool_responses(tool_responses)
      parts = ["Tool results:"]
      tool_responses.each do |name, response|
        if response.is_a?(Hash) && response[:formatted]
          parts << "#{name}: #{response[:formatted]}"
        else
          parts << "#{name}: #{response}"
        end
      end
      parts.join("\n")
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