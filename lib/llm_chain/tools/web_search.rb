require 'net/http'
require 'json'
require 'uri'

module LLMChain
  module Tools
    class WebSearch < BaseTool
      KEYWORDS = %w[
        search find lookup google bing
        what is who is where is when is
        latest news current information
        weather forecast stock price
        definition meaning wikipedia
      ].freeze

      def initialize(api_key: nil, search_engine: :duckduckgo)
        @api_key = api_key || ENV['SEARCH_API_KEY']
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
        contains_keywords?(prompt, KEYWORDS) ||
        contains_question_pattern?(prompt) ||
        contains_current_info_request?(prompt)
      end

      def call(prompt, context: {})
        query = extract_query(prompt)
        return "No search query found" if query.empty?

        num_results = extract_num_results(prompt)
        
        begin
          results = perform_search(query, num_results)
          format_search_results(query, results)
        rescue => e
          {
            query: query,
            error: e.message,
            formatted: "Error searching for '#{query}': #{e.message}"
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

      def contains_question_pattern?(prompt)
        prompt.match?(/\b(what|who|where|when|how|why|which)\b/i)
      end

      def contains_current_info_request?(prompt)
        prompt.match?(/\b(latest|current|recent|today|now|2024|2023)\b/i)
      end

      def extract_query(prompt)
        # Удаляем команды поиска и оставляем суть запроса
        query = prompt.gsub(/\b(search for|find|lookup|google|what is|who is|where is|when is)\b/i, '')
                     .gsub(/\b(please|can you|could you|would you)\b/i, '')
                     .strip
        
        # Если запрос слишком длинный, берем первые слова
        words = query.split
        if words.length > 10
          words.first(10).join(' ')
        else
          query
        end
      end

      def extract_num_results(prompt)
        # Ищем числа в контексте результатов
        match = prompt.match(/(\d+)\s*(results?|items?|links?)/i)
        return match[1].to_i if match && match[1].to_i.between?(1, 20)
        
        5 # default
      end

      def perform_search(query, num_results)
        case @search_engine
        when :duckduckgo
          search_duckduckgo(query, num_results)
        when :google
          search_google(query, num_results)
        when :bing
          search_bing(query, num_results)
        else
          raise "Unsupported search engine: #{@search_engine}"
        end
      end

      def search_duckduckgo(query, num_results)
        # DuckDuckGo Instant Answer API (бесплатный)
        uri = URI("https://api.duckduckgo.com/")
        params = {
          q: query,
          format: 'json',
          no_html: '1',
          skip_disambig: '1'
        }
        uri.query = URI.encode_www_form(params)

        response = Net::HTTP.get_response(uri)
        raise "DuckDuckGo API error: #{response.code}" unless response.code == '200'

        data = JSON.parse(response.body)
        
        results = []
        
        # Основной ответ
        if data['AbstractText'] && !data['AbstractText'].empty?
          results << {
            title: data['AbstractSource'] || 'DuckDuckGo',
            url: data['AbstractURL'] || '',
            snippet: data['AbstractText']
          }
        end

        # Связанные темы
        if data['RelatedTopics']
          data['RelatedTopics'].first(num_results - results.length).each do |topic|
            next unless topic['Text']
            results << {
              title: topic['Text'].split(' - ').first || 'Related',
              url: topic['FirstURL'] || '',
              snippet: topic['Text']
            }
          end
        end

        # Если результатов мало, добавляем информацию из Infobox
        if results.length < num_results / 2 && data['Infobox']
          infobox_text = data['Infobox']['content']&.map { |item| 
            "#{item['label']}: #{item['value']}" 
          }&.join('; ')
          
          if infobox_text
            results << {
              title: 'Information',
              url: data['AbstractURL'] || '',
              snippet: infobox_text
            }
          end
        end

        results.first(num_results)
      end

      def search_google(query, num_results)
        # Google Custom Search API (требует API ключ)
        raise "Google API key required" unless @api_key

        uri = URI("https://www.googleapis.com/customsearch/v1")
        params = {
          key: @api_key,
          cx: ENV['GOOGLE_SEARCH_ENGINE_ID'] || raise("GOOGLE_SEARCH_ENGINE_ID required"),
          q: query,
          num: [num_results, 10].min
        }
        uri.query = URI.encode_www_form(params)

        response = Net::HTTP.get_response(uri)
        raise "Google API error: #{response.code}" unless response.code == '200'

        data = JSON.parse(response.body)
        
        (data['items'] || []).map do |item|
          {
            title: item['title'],
            url: item['link'],
            snippet: item['snippet']
          }
        end
      end

      def search_bing(query, num_results)
        # Bing Web Search API (требует API ключ)
        raise "Bing API key required" unless @api_key

        uri = URI("https://api.bing.microsoft.com/v7.0/search")
        params = {
          q: query,
          count: [num_results, 20].min,
          responseFilter: 'Webpages'
        }
        uri.query = URI.encode_www_form(params)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        request['Ocp-Apim-Subscription-Key'] = @api_key
        
        response = http.request(request)
        raise "Bing API error: #{response.code}" unless response.code == '200'

        data = JSON.parse(response.body)
        
        (data.dig('webPages', 'value') || []).map do |item|
          {
            title: item['name'],
            url: item['url'],
            snippet: item['snippet']
          }
        end
      end

      def format_search_results(query, results)
        if results.empty?
          return {
            query: query,
            results: [],
            formatted: "No results found for '#{query}'"
          }
        end

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

      def required_parameters
        ['query']
      end
    end
  end
end 