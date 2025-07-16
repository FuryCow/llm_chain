# frozen_string_literal: true

require_relative '../interfaces/memory'

require 'redis'
require 'json'

module LLMChain
  module Memory
    # Redis-based memory adapter for LLMChain.
    # Stores conversation history in a Redis list.
    class Redis < Interfaces::Memory
      class Error < StandardError; end

      def initialize(max_size: 10, redis_url: nil, namespace: 'llm_chain')
        @max_size = max_size
        @redis = ::Redis.new(url: redis_url || ENV['REDIS_URL'] || 'redis://localhost:6379')
        @namespace = namespace
        @session_key = "#{namespace}:session"
      end

      # Store a prompt/response pair in memory.
      # @param prompt [String]
      # @param response [String]
      # @return [void]
      def store(prompt, response)
        entry = { prompt: prompt, response: response, timestamp: Time.now.to_i }.to_json
        @redis.multi do
          @redis.rpush(@session_key, entry)
          @redis.ltrim(@session_key, -@max_size, -1)
        end
      end

      # Recall conversation history (optionally filtered by prompt).
      # @param prompt [String, nil]
      # @return [Array<Hash>]
      def recall(_ = nil)
        entries = @redis.lrange(@session_key, 0, -1)
        entries.map { |e| symbolize_keys(JSON.parse(e)) }
      rescue JSON::ParserError
        []
      rescue ::Redis::CannotConnectError
        raise Error, "Cannot connect to Redis server"
      end

      # Clear all memory.
      # @return [void]
      def clear
        @redis.del(@session_key)
      end

      # Return number of stored items.
      # @return [Integer]
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