module LLMChain
  module ClientRegistry
    @clients = {}

    def self.register_client(name, klass)
      @clients[name.to_s] = klass
    end

    def self.client_for(model, **options)
      case model
      when /gpt/
        Clients::OpenAI.new(**options.merge(model: model))
      when /qwen/
        Clients::Qwen.new(**options.merge(model: model))
      else
        raise ArgumentError, "Unknown model: #{model}"
      end
    end
  end
end