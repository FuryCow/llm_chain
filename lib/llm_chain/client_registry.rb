module LLMChain
  module ClientRegistry
    @clients = {}

    def self.register_client(name, klass)
      @clients[name.to_s] = klass
    end

    def self.client_for(model, **options)
      instance = case model
      when /gpt|openai/
        Clients::OpenAI
      when /qwen/
        Clients::Qwen
      when /llama2/
        Clients::Llama2
      when /gemma3/
        Clients::Gemma3
      when /deepseek-coder-v2/
        Clients::DeepseekCoderV2
      else
        raise UnknownModelError, "Unknown model: #{model}"
      end

      instance.new(**options.merge(model: model))
    end
  end
end