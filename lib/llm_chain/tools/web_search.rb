require 'net/http'
require 'json'
require 'uri'

module LLMChain
  module Tools
    class WebSearch < Base
      SEARCH_KEYWORDS = %w[
        search find lookup google bing web site news wikipedia
      ].freeze

      GOOGLE_API_URL = "https://www.googleapis.com/customsearch/v1".freeze
      DEFAULT_NUM_RESULTS = 5
      MAX_GOOGLE_RESULTS = 10
      GOOGLE_TIMEOUT = 20
      GOOGLE_SAFE = 'active'.freeze

      BING_API_URL = "https://api.bing.microsoft.com/v7.0/search".freeze
      MAX_BING_RESULTS = 20
      BING_TIMEOUT = 20
      BING_SAFE = 'Moderate'.freeze
      BING_RESPONSE_FILTER = 'Webpages'.freeze

      # --- Приватные константы для парсинга ---
      QUERY_COMMANDS_REGEX = /\b(search for|find|lookup|google|what is|who is|where is|when is)\b/i.freeze
      POLITENESS_REGEX = /\b(please|can you|could you|would you)\b/i.freeze
      NUM_RESULTS_REGEX = /(\d+)\s*(results?|items?|links?)/i.freeze
      MAX_QUERY_WORDS = 10

      def initialize(api_key: nil, search_engine: :google)
        @api_key = api_key || ENV['GOOGLE_API_KEY'] || ENV['SEARCH_API_KEY']
        @search_engine = search_engine
        
        super(
          name: "web_search",
          description: "Searches the internet for current information",
          parameters: {
            query: {
              type: "string", 
              description: "Search query to find information about"
            },
            num_results: {
              type: "integer",
              description: "Number of results to return (default: 5)"
            }
          }
        )
      end

      def match?(prompt)
        contains_keywords?(prompt, SEARCH_KEYWORDS)
      end

      def call(prompt, context: {})
        query = extract_query(prompt)
        return "No search query found" if query.empty?

        num_results = extract_num_results(prompt)
        
        begin
          results = perform_search_with_retry(query, num_results)
          format_search_results(query, results)
        rescue => e
          log_error("Search failed for '#{query}'", e)
          {
            query: query,
            error: e.message,
            results: [],
            formatted: "Search unavailable for '#{query}'. Please try again later or rephrase your query."
          }
        end
      end

      def extract_parameters(prompt)
        {
          query: extract_query(prompt),
          num_results: extract_num_results(prompt)
        }
      end

      private

      # @param prompt [String] Исходный запрос
      # @return [String] Извлечённая суть поискового запроса
      def extract_query(prompt)
        return "" if prompt.nil? || prompt.strip.empty?
        query = prompt.gsub(QUERY_COMMANDS_REGEX, '')
                      .gsub(POLITENESS_REGEX, '')
                      .strip
        words = query.split
        return words.first(MAX_QUERY_WORDS).join(' ') if words.length > MAX_QUERY_WORDS
        query
      end

      # @param prompt [String] Исходный запрос
      # @return [Integer] Количество результатов (по умолчанию)
      def extract_num_results(prompt)
        return DEFAULT_NUM_RESULTS if prompt.nil? || prompt.empty?
        match = prompt.match(NUM_RESULTS_REGEX)
        return match[1].to_i if match && match[1].to_i.between?(1, MAX_BING_RESULTS)
        DEFAULT_NUM_RESULTS
      end

      def perform_search_with_retry(query, num_results, max_retries: 3)
        retries = 0
        last_error = nil

        begin
          perform_search(query, num_results)
        rescue => e
          last_error = e
          retries += 1
          
          if retries <= max_retries && retryable_error?(e)
            sleep_time = [0.5 * (2 ** (retries - 1)), 5.0].min # exponential backoff, max 5 seconds
            log_retry("Retrying search (#{retries}/#{max_retries}) after #{sleep_time}s", e)
            sleep(sleep_time)
            retry
          else
            log_error("Search failed after #{retries} attempts", e)
            # Fallback to hardcoded results as last resort
            hardcoded = get_hardcoded_results(query)
            return hardcoded unless hardcoded.empty?
            raise e
          end
        end
      end

      def perform_search(query, num_results)
        case @search_engine
        when :google
          search_google_results(query, num_results)
        when :bing
          search_bing_results(query, num_results)
        else
          raise "Unsupported search engine: #{@search_engine}. Use :google or :bing"
        end
      end

      # --- Google Search SRP decomposition ---
      def search_google_results(query, num_results)
        unless @api_key
          handle_api_error(StandardError.new("No API key"), "Google API key not provided, using fallback")
          return []
        end
        search_engine_id = ENV['GOOGLE_SEARCH_ENGINE_ID'] || ENV['GOOGLE_CX']
        unless search_engine_id && search_engine_id != 'your-search-engine-id'
          handle_api_error(StandardError.new("Missing GOOGLE_SEARCH_ENGINE_ID"), "Google Search Engine ID not configured")
          return []
        end
        begin
          response = fetch_google_response(query, num_results, search_engine_id)
          parse_google_response(response)
        rescue => e
          handle_api_error(e, "Google search failed")
          []
        end
      end

      def fetch_google_response(query, num_results, search_engine_id)
        require 'timeout'
        Timeout.timeout(GOOGLE_TIMEOUT) do
          uri = URI(GOOGLE_API_URL)
          params = {
            key: @api_key,
            cx: search_engine_id,
            q: query,
            num: [num_results, MAX_GOOGLE_RESULTS].min,
            safe: GOOGLE_SAFE
          }
          uri.query = URI.encode_www_form(params)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 8
          http.read_timeout = 12
          http.get(uri.request_uri)
        end
      rescue Timeout::Error => e
        handle_api_error(e, "Google search timeout")
        nil
      end

      def parse_google_response(response)
        return [] unless response && response.code == '200'
        data = JSON.parse(response.body) rescue nil
        if data.nil? || data['error']
          handle_api_error(StandardError.new(data&.dig('error', 'message') || 'Invalid JSON'), "Google API error")
          return []
        end
        (data['items'] || []).map do |item|
          {
            title: item['title']&.strip || 'Untitled',
            url: item['link'] || '',
            snippet: item['snippet']&.strip || 'No description available'
          }
        end
      rescue JSON::ParserError => e
        handle_api_error(e, "Invalid JSON response from Google")
        []
      end

      # --- Bing Search SRP decomposition ---
      def search_bing_results(query, num_results)
        unless @api_key
          handle_api_error(StandardError.new("No API key"), "Bing API key not provided, using fallback")
          return []
        end
        begin
          response = fetch_bing_response(query, num_results)
          parse_bing_response(response)
        rescue => e
          handle_api_error(e, "Bing search failed")
          []
        end
      end

      def fetch_bing_response(query, num_results)
        require 'timeout'
        Timeout.timeout(BING_TIMEOUT) do
          uri = URI(BING_API_URL)
          params = {
            q: query,
            count: [num_results, MAX_BING_RESULTS].min,
            responseFilter: BING_RESPONSE_FILTER,
            safeSearch: BING_SAFE
          }
          uri.query = URI.encode_www_form(params)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 8
          http.read_timeout = 12
          request = Net::HTTP::Get.new(uri)
          request['Ocp-Apim-Subscription-Key'] = @api_key
          request['User-Agent'] = 'LLMChain/1.0'
          http.request(request)
        end
      rescue Timeout::Error => e
        handle_api_error(e, "Bing search timeout")
        nil
      end

      def parse_bing_response(response)
        return [] unless response && response.code == '200'
        data = JSON.parse(response.body) rescue nil
        if data.nil? || data['error']
          handle_api_error(StandardError.new(data&.dig('error', 'message') || 'Invalid JSON'), "Bing API error")
          return []
        end
        (data.dig('webPages', 'value') || []).map do |item|
          {
            title: item['name']&.strip || 'Untitled',
            url: item['url'] || '',
            snippet: item['snippet']&.strip || 'No description available'
          }
        end
      rescue JSON::ParserError => e
        handle_api_error(e, "Invalid JSON response from Bing")
        []
      end

      def handle_api_error(error, context = nil)
        log_error(context || "API error", error)
      end

      # --- Fallback/hardcoded results parsing ---
      def parse_hardcoded_results(query)
        hardcoded = get_hardcoded_results(query)
        return [] if hardcoded.empty?
        hardcoded
      end

      # --- Форматирование результатов поиска ---
      def format_search_results(query, results)
        return {
          query: query,
          results: [],
          formatted: "No results found for '#{query}'"
        } if results.empty?

        formatted_results = results.map.with_index(1) do |result, index|
          "#{index}. #{result[:title]}\n   #{result[:snippet]}\n   #{result[:url]}"
        end.join("\n\n")

        {
          query: query,
          results: results,
          count: results.length,
          formatted: "Search results for '#{query}':\n\n#{formatted_results}"
        }
      end

      # --- Логирование и обработка ошибок ---
      def log_error(message, error)
        return unless should_log?
        if defined?(Rails) && Rails.logger
          Rails.logger.error "[WebSearch] #{message}: #{error.class} - #{error.message}"
        else
          warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        end
      end

      def log_retry(message, error)
        return unless should_log?
        if defined?(Rails) && Rails.logger
          Rails.logger.warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        else
          warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        end
      end

      def should_log?
        ENV['LLM_CHAIN_DEBUG'] == 'true' || 
          ENV['RAILS_ENV'] == 'development' ||
          (defined?(Rails) && Rails.env.development?)
      end

      def retryable_error?(error)
        # Определяем, стоит ли повторять запрос при данной ошибке
        case error
        when Net::TimeoutError, Net::OpenTimeout, Net::ReadTimeout
          true
        when SocketError
          # DNS ошибки обычно временные
          true
        when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH
          true
        when Net::HTTPError
          # Повторяем только для серверных ошибок (5xx)
          error.message.match?(/5\d\d/)
        else
          false
        end
      end
    end
  end
end 