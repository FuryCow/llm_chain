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

      # --- Private constants for parsing ---
      QUERY_COMMANDS_REGEX = /\b(search for|find|lookup|google|what is|who is|where is|when is)\b/i.freeze
      POLITENESS_REGEX = /\b(please|can you|could you|would you)\b/i.freeze
      NUM_RESULTS_REGEX = /(\d+)\s*(results?|items?|links?)/i.freeze
      FOR_SEARCH_REGEX = /\A(for|to)?\s*search:?\s*/i.freeze
      DOUBLE_COMMA_REGEX = /,\s*,/
      TRAILING_PUNCTUATION_REGEX = /[,;]\s*$/
      MULTISPACE_REGEX = /\s+/
      MAX_QUERY_WORDS = 10

      SERVER_ERROR_REGEX = /5\d\d/

      # @param api_key [String, nil] API key for the search engine (Google or Bing)
      # @param search_engine [Symbol] :google or :bing
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

      # @param prompt [String]
      # @return [Boolean] Whether the prompt contains search keywords
      def match?(prompt)
        contains_keywords?(prompt, SEARCH_KEYWORDS)
      end

      # @param prompt [String] User's original query
      # @param context [Hash] (unused)
      # @return [Hash] Search results and formatted string
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

      # @param prompt [String]
      # @return [Hash] :query and :num_results
      def extract_parameters(prompt)
        {
          query: extract_query(prompt),
          num_results: extract_num_results(prompt)
        }
      end

      private

      # @param prompt [String] Original query
      # @return [String] Extracted search query
      def extract_query(prompt)
        return "" if prompt.nil? || prompt.strip.empty?
        query = prompt.gsub(QUERY_COMMANDS_REGEX, '')
                      .gsub(POLITENESS_REGEX, '')
                      .strip
        query = query.gsub(NUM_RESULTS_REGEX, '').strip
        query = query.sub(FOR_SEARCH_REGEX, '')
        query = query.gsub(DOUBLE_COMMA_REGEX, ',').gsub(MULTISPACE_REGEX, ' ')
        query = query.sub(TRAILING_PUNCTUATION_REGEX, '').strip
        query
      end

      # @param prompt [String] Original query
      # @return [Integer] Number of results (default)
      def extract_num_results(prompt)
        return DEFAULT_NUM_RESULTS if prompt.nil? || prompt.empty?
        match = prompt.match(NUM_RESULTS_REGEX)
        return match[1].to_i if match && match[1].to_i.between?(1, MAX_BING_RESULTS)
        DEFAULT_NUM_RESULTS
      end

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @param max_retries [Integer] Maximum number of attempts
      # @return [Array<Hash>] Array of search results
      # @raise [StandardError] If all attempts fail
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
            raise e
          end
        end
      end

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @return [Array<Hash>] Array of search results
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

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @return [Array<Hash>] Array of search results
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

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @param search_engine_id [String] Google search engine ID
      # @return [Net::HTTPResponse, nil] Google response or nil on error
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

      # @param response [Net::HTTPResponse, nil]
      # @return [Array<Hash>] Array of search results
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

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @return [Array<Hash>] Array of search results
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

      # @param query [String] Search query
      # @param num_results [Integer] Number of results
      # @return [Net::HTTPResponse, nil] Bing response or nil on error
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

      # @param response [Net::HTTPResponse, nil]
      # @return [Array<Hash>] Array of search results
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

      # @param error [Exception] Exception
      # @param context [String, nil] Error context
      # @return [void]
      def handle_api_error(error, context = nil)
        log_error(context || "API error", error)
      end

      # @param query [String] Search query
      # @return [Array<Hash>] Array of results
      def parse_hardcoded_results(query)
        hardcoded = get_hardcoded_results(query)
        return [] if hardcoded.empty?
        hardcoded
      end

      # Заглушка для hardcoded results
      def get_hardcoded_results(query)
        []
      end

      # @param query [String] Search query
      # @param results [Array<Hash>] Array of search results
      # @return [Hash] Formatted results
      def format_search_results(query, results)
        return {
          query: query,
          results: [],
          formatted: "No results found for '#{query}'"
        } if results.empty?

        formatted_results = results.map.with_index(1) do |result, index|
          title = result[:title].to_s.strip
          title = 'Untitled' if title.empty?
          snippet = result[:snippet].to_s.strip
          snippet = 'No description available' if snippet.empty?
          url = result[:url].to_s.strip
          "#{index}. #{title}\n   #{snippet}\n   #{url}"
        end.join("\n\n")

        {
          query: query,
          results: results,
          count: results.length,
          formatted: "Search results for '#{query}':\n\n#{formatted_results}"
        }
      end

      # @param message [String] Message
      # @param error [Exception] Exception
      # @return [void]
      def log_error(message, error)
        return unless should_log?
        if defined?(Rails) && Rails.logger
          Rails.logger.error "[WebSearch] #{message}: #{error.class} - #{error.message}"
        else
          warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        end
      end

      # @param message [String] Message
      # @param error [Exception] Exception
      # @return [void]
      def log_retry(message, error)
        return unless should_log?
        if defined?(Rails) && Rails.logger
          Rails.logger.warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        else
          warn "[WebSearch] #{message}: #{error.class} - #{error.message}"
        end
      end

      # @return [Boolean] Whether logging is enabled
      def should_log?
        return true if ENV['LLM_CHAIN_DEBUG'] == 'true'
        return true if ENV['RAILS_ENV'] == 'development'
        return true if defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
        false
      end

      # @param error [Exception]
      # @return [Boolean] Whether the error is retryable
      def retryable_error?(error)
        case error
        when Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
          true
        when SocketError
          # DNS ошибки обычно временные
          true
        when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH
          true
        when Net::HTTPError
          # Повторяем только для серверных ошибок (5xx)
          error.message.match?(SERVER_ERROR_REGEX)
        else
          false
        end
      end
    end
  end
end 