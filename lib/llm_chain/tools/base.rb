# frozen_string_literal: true
module LLMChain
  module Tools
    # Base class for all LLMChain tools.
    #
    # Subclasses must implement:
    #   * {#match?} – decide whether the tool should run for a given prompt.
    #   * {#call}   – perform the work and return result (`String` or `Hash`).
    #
    # Optional overrides: {#extract_parameters}, {#format_result}.
    #
    # @abstract
    class Base
      attr_reader :name, :description, :parameters

      # @param name [String]
      # @param description [String]
      # @param parameters [Hash]
      def initialize(name:, description:, parameters: {})
        @name = name
        @description = description
        @parameters = parameters
      end

      # Check whether this tool matches the given prompt.
      # @param prompt [String]
      # @return [Boolean]
      def match?(prompt)
        raise NotImplementedError, "Subclasses must implement #match?"
      end

      # Perform the tool action.
      # @param prompt [String]
      # @param context [Hash]
      # @return [String, Hash]
      def call(prompt, context: {})
        raise NotImplementedError, "Subclasses must implement #call"
      end

      # Build a JSON schema describing the tool interface for LLMs.
      # @return [Hash]
      def to_schema
        {
          name: @name,
          description: @description,
          parameters: {
            type: "object",
            properties: @parameters,
            required: required_parameters
          }
        }
      end

      # Extract parameters from prompt if needed.
      # @param prompt [String]
      # @return [Hash]
      def extract_parameters(prompt)
        {}
      end

      # Format result for inclusion into LLM prompt.
      # @param result [Object]
      # @return [String]
      def format_result(result)
        case result
        when String then result
        when Hash, Array then JSON.pretty_generate(result)
        else result.to_s
        end
      end

      protected

      # List of required parameter names
      # @return [Array<String>]
      def required_parameters
        []
      end

      # Helper: checks if prompt contains any keyword
      # @param prompt [String]
      # @param keywords [Array<String>]
      # @return [Boolean]
      def contains_keywords?(prompt, keywords)
        keywords.any? { |keyword| prompt.downcase.include?(keyword.downcase) }
      end

      # Helper: extract numeric values from text
      # @param text [String]
      # @return [Array<Float>]
      def extract_numbers(text)
        text.scan(/-?\d+\.?\d*/).map(&:to_f)
      end

      # Helper: extract URLs from text
      # @param text [String]
      # @return [Array<String>]
      def extract_urls(text)
        text.scan(%r{https?://[^\s]+})
      end
    end
  end
end 