require 'redis'
require 'json'

module LLMChain
  module Memory
    class Redis
      class Error < StandardError; end

      def initialize(max_size: 10, redis_url: nil, namespace: 'llm_chain')
        @max_size = max_size
        @redis = ::Redis.new(url: redis_url || ENV['REDIS_URL'] || 'redis://localhost:6379')
        @namespace = namespace
        @session_key = "#{namespace}:session"
      end

      def store(prompt, response)
        entry = { prompt: prompt, response: response, timestamp: Time.now.to_i }.to_json
        @redis.multi do
          @redis.rpush(@session_key, entry)
          @redis.ltrim(@session_key, -@max_size, -1) # Сохраняем только последние max_size записей
        end
      end

      def recall(_ = nil)
        entries = @redis.lrange(@session_key, 0, -1)
        entries.map { |e| symbolize_keys(JSON.parse(e)) }
      rescue JSON::ParserError
        []
      rescue ::Redis::CannotConnectError
        raise MemoryError, "Cannot connect to Redis server"
      end

      def clear
        @redis.del(@session_key)
      end

      def size
        @redis.llen(@session_key)
      end

      private

      def symbolize_keys(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end
    end
  end
end