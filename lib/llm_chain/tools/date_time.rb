# frozen_string_literal: true
require 'time'
require 'json'

module LLMChain
  module Tools
    # Simple tool that returns current date and time.
    class DateTime < Base
      KEYWORDS = %w[time date today now current].freeze

      def initialize
        super(
          name: "date_time",
          description: "Returns current date and time (optionally for given timezone)",
          parameters: {
            timezone: {
              type: "string",
              description: "IANA timezone name, e.g. 'Europe/Moscow'. Defaults to system TZ"
            }
          }
        )
      end

      # @param prompt [String]
      # @return [Boolean]
      def match?(prompt)
        contains_keywords?(prompt, KEYWORDS)
      end

      # @param prompt [String]
      # @param context [Hash]
      def call(prompt, context: {})
        params = extract_parameters(prompt)
        tz = params[:timezone]
        
        if tz
          # Use TZInfo for proper timezone handling
          require 'tzinfo'
          tz_info = TZInfo::Timezone.get(map_timezone_name(tz))
          time = tz_info.now
          timezone_abbr = tz_info.current_period.abbreviation
        else
          time = Time.now
          timezone_abbr = time.zone
        end
        
        {
          timezone: tz ? map_timezone_name(tz) : time.zone,
          iso: time.iso8601,
          formatted: time.strftime("%Y-%m-%d %H:%M:%S") + " #{timezone_abbr}"
        }
      end

      def extract_parameters(prompt)
        # First try to parse as JSON (for ReAct agent)
        begin
          json_params = JSON.parse(prompt)
          return { timezone: json_params['timezone'] || json_params[:timezone] }
        rescue JSON::ParserError
          # Fallback to regex extraction
        end
        
        # Extract timezone from prompt using regex
        tz_match = prompt.match(/in\s+([A-Za-z_\s\/]+)/)
        timezone = tz_match && tz_match[1]&.strip
        
        # Map common timezone names to IANA format
        timezone = map_timezone_name(timezone) if timezone
        
        { timezone: timezone }
      end

      private

      def timezone_offset(tz)
        return 0 unless tz
        
        # Map common timezone names to IANA format
        tz = map_timezone_name(tz)
        
        # Fallback: use TZInfo if available, else default to system
        require 'tzinfo'
        TZInfo::Timezone.get(tz).current_period.offset.utc_total_offset
      rescue LoadError, NameError, TZInfo::InvalidTimezoneIdentifier
        0
      end

      def map_timezone_name(tz)
        return nil unless tz
        
        # Map common timezone names to IANA format
        timezone_map = {
          'moscow' => 'Europe/Moscow',
          'msk' => 'Europe/Moscow',
          'new york' => 'America/New_York',
          'nyc' => 'America/New_York',
          'london' => 'Europe/London',
          'paris' => 'Europe/Paris',
          'tokyo' => 'Asia/Tokyo',
          'beijing' => 'Asia/Shanghai',
          'shanghai' => 'Asia/Shanghai',
          'sydney' => 'Australia/Sydney',
          'los angeles' => 'America/Los_Angeles',
          'la' => 'America/Los_Angeles',
          'chicago' => 'America/Chicago',
          'utc' => 'UTC',
          'gmt' => 'GMT'
        }
        
        timezone_map[tz.downcase] || tz
      end
    end
  end
end 