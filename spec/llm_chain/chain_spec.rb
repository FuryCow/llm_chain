require 'spec_helper'
require 'llm_chain/chain'

RSpec.describe LLMChain::Chain do
  let(:memory) { double('Memory', recall: ['history'], store: nil) }
  let(:tool_manager_class) { Class.new { def initialize(tools:); end } }
  let(:tools) do
    tm = tool_manager_class.new(tools: [])
    allow(tm).to receive(:execute_tools).and_return({ tool: { success: true, result: 1, formatted: '1' } })
    tm
  end
  let(:retriever) { double('Retriever') }
  let(:client) { double('Client', chat: 'answer', stream_chat: nil) }
  let(:prompt_builder) { double('PromptBuilder', build: 'full_prompt') }
  let(:memory_context_builder) { double('MemoryContextBuilder', build: 'mem_ctx') }
  let(:tool_responses_builder) { double('ToolResponsesBuilder', build: 'tool_resp') }
  let(:rag_documents_builder) { double('RagDocumentsBuilder', build: 'rag_docs') }
  let(:retriever_context_builder) { double('RetrieverContextBuilder', retrieve: ['doc']) }

  before do
    stub_const('LLMChain::ConfigurationValidator', Class.new)
    allow(LLMChain::ConfigurationValidator).to receive(:validate_chain_config!).and_return(true)
    stub_const('LLMChain::Memory::Array', Class.new { def initialize(*); end })
    stub_const('LLMChain::Tools::ToolManagerFactory', Class.new)
    allow(LLMChain::Tools::ToolManagerFactory).to receive(:create_default_toolset).and_return(tools)
    stub_const('LLMChain::Tools::ToolManager', tool_manager_class)
    stub_const('LLMChain::Embeddings::Clients::Local::WeaviateRetriever', Class.new { def initialize(*); end })
    stub_const('LLMChain::ClientRegistry', Class.new)
    allow(LLMChain::ClientRegistry).to receive(:client_for).and_return(client)
    stub_const('LLMChain::Builders::Prompt', Class.new { def initialize; end; def build(*); 'full_prompt'; end })
    stub_const('LLMChain::Builders::MemoryContext', Class.new { def initialize; end; def build(*); 'mem_ctx'; end })
    stub_const('LLMChain::Builders::ToolResponses', Class.new { def initialize; end; def build(*); 'tool_resp'; end })
    stub_const('LLMChain::Builders::RagDocuments', Class.new { def initialize; end; def build(*); 'rag_docs'; end })
    stub_const('LLMChain::Builders::RetrieverContext', Class.new { def initialize; end; def retrieve(*); ['doc']; end })
  end

  describe '#initialize' do
    it 'validates config if validate_config is true' do
      expect(LLMChain::ConfigurationValidator).to receive(:validate_chain_config!).with(hash_including(model: 'm', tools: true, memory: nil, retriever: false))
      described_class.new(model: 'm')
    end
    it 'does not validate config if validate_config is false' do
      expect(LLMChain::ConfigurationValidator).not_to receive(:validate_chain_config!)
      described_class.new(model: 'm', validate_config: false)
    end
    it 'sets memory, tools, retriever, client, and builders' do
      chain = described_class.new(model: 'm', memory: memory, tools: tools, retriever: retriever, validate_config: false)
      expect(chain.instance_variable_get(:@memory)).to eq(memory)
      expect(chain.instance_variable_get(:@tools)).to eq(tools)
      expect(chain.instance_variable_get(:@retriever)).to eq(retriever)
      expect(chain.instance_variable_get(:@client)).to eq(client)
      expect(chain.instance_variable_get(:@prompt_builder)).to be_a(LLMChain::Builders::Prompt)
    end
    it 'creates default memory if none given' do
      chain = described_class.new(model: 'm', memory: nil, validate_config: false)
      expect(chain.instance_variable_get(:@memory)).to be_a(LLMChain::Memory::Array)
    end
    it 'creates default tools if tools is true' do
      chain = described_class.new(model: 'm', tools: true, validate_config: false)
      expect(chain.instance_variable_get(:@tools)).to eq(tools)
    end
    it 'creates ToolManager if tools is array' do
      arr = [double('Tool')] 
      expect(LLMChain::Tools::ToolManager).to receive(:new).with(tools: arr)
      described_class.new(model: 'm', tools: arr, validate_config: false)
    end
    it 'creates ToolManager from config if tools is hash with :config' do
      expect(LLMChain::Tools::ToolManagerFactory).to receive(:from_config).with([:foo])
      described_class.new(model: 'm', tools: { config: [:foo] }, validate_config: false)
    end
    it 'creates default retriever if retriever is nil' do
      chain = described_class.new(model: 'm', retriever: nil, validate_config: false)
      expect(chain.instance_variable_get(:@retriever)).to be_a(LLMChain::Embeddings::Clients::Local::WeaviateRetriever)
    end
    it 'sets retriever to nil if retriever is false' do
      chain = described_class.new(model: 'm', retriever: false, validate_config: false)
      expect(chain.instance_variable_get(:@retriever)).to be_nil
    end
  end

  describe '#ask' do
    let(:chain) do
      c = described_class.new(model: 'm', memory: memory, tools: tools, retriever: retriever, validate_config: false)
      c.instance_variable_set(:@prompt_builder, prompt_builder)
      c.instance_variable_set(:@memory_context_builder, memory_context_builder)
      c.instance_variable_set(:@tool_responses_builder, tool_responses_builder)
      c.instance_variable_set(:@rag_documents_builder, rag_documents_builder)
      c.instance_variable_set(:@retriever_context_builder, retriever_context_builder)
      c.instance_variable_set(:@client, client)
      c
    end
    it 'calls all builders and client.chat, stores memory' do
      expect(memory).to receive(:recall).with('p').and_return(['history'])
      expect(memory_context_builder).to receive(:build).with(['history']).and_return('mem_ctx')
      expect(tools).to receive(:execute_tools).with('p').and_return({ tool: { success: true, result: 1, formatted: '1' } })
      expect(tool_responses_builder).to receive(:build).with({ tool: { success: true, result: 1, formatted: '1' } }).and_return('tool_resp')
      expect(retriever_context_builder).to receive(:retrieve).with(retriever, 'p', {}).and_return(['doc'])
      expect(rag_documents_builder).to receive(:build).with(['doc']).and_return('rag_docs')
      expect(prompt_builder).to receive(:build).with(memory_context: 'mem_ctx', tool_responses: 'tool_resp', rag_documents: 'rag_docs', prompt: 'p').and_return('full_prompt')
      expect(client).to receive(:chat).with('full_prompt').and_return('answer')
      expect(memory).to receive(:store).with('p', 'answer')
      expect(chain.ask('p', rag_context: true)).to eq('answer')
    end
    it 'calls stream_chat and yields chunks if stream: true' do
      allow(client).to receive(:stream_chat).and_yield('a').and_yield('b').and_return(nil)
      buffer = ''
      result = chain.ask('p', stream: true) { |chunk| buffer << chunk }
      expect(buffer).to eq('ab')
      expect(result).to eq('ab')
    end
    it 'does not include rag_documents if rag_context is false' do
      expect(rag_documents_builder).not_to receive(:build)
      chain.ask('p', rag_context: false)
    end
    it 'passes rag_options to retriever_context_builder' do
      expect(retriever_context_builder).to receive(:retrieve).with(retriever, 'p', { limit: 5 }).and_return(['doc'])
      chain.ask('p', rag_context: true, rag_options: { limit: 5 })
    end
  end
end 