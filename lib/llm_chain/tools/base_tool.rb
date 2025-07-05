# frozen_string_literal: true
require_relative 'base'

module LLMChain
  module Tools
    # @deprecated Use {LLMChain::Tools::Base}. Will be removed in 0.7.0.
    class BaseTool < Base
      # Empty shim for backward compatibility
    end
  end
end 