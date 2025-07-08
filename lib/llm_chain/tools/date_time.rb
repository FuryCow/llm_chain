# frozen_string_literal: true
require 'time'

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
        time = tz ? Time.now.getlocal(timezone_offset(tz)) : Time.now
        {
          timezone: tz || Time.now.zone,
          iso: time.iso8601,
          formatted: time.strftime("%Y-%m-%d %H:%M:%S %Z")
        }
      end

      def extract_parameters(prompt)
        tz_match = prompt.match(/in\s+([A-Za-z_\/]+)/)
        { timezone: tz_match && tz_match[1] }
      end

      private

      def timezone_offset(tz)
        # Fallback: use TZInfo if available, else default to system
        require 'tzinfo'
        TZInfo::Timezone.get(tz).current_period.offset
      rescue LoadError, TZInfo::InvalidTimezoneIdentifier
        0
      end
    end
  end
end 