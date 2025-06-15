require "llm_chain/version"
require "faraday"
require "json"

module LLMChain
  class Error < StandardError; end
  class UnknownModelError < Error; end
  class ClientError < Error; end
  class ServerError < Error; end
  class TimeoutError < Error; end
end

require "llm_chain/clients/base"
require "llm_chain/clients/ollama_base"
require "llm_chain/clients/openai"
require "llm_chain/clients/qwen"
require "llm_chain/clients/llama2"
require "llm_chain/client_registry"
require "llm_chain/memory/array"
require "llm_chain/chain"