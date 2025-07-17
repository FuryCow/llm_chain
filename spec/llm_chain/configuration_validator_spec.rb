require 'spec_helper'
require 'llm_chain/configuration_validator'
require 'open3'
require 'net/http'

RSpec.describe LLMChain::ConfigurationValidator do
  let(:validator) { described_class.new }

  describe '.validate_chain_config!' do
    it 'returns true for valid config with known model' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-validkey1234567890123456')
      allow_any_instance_of(described_class).to receive(:validate_openai_requirements!).and_return(true)
      expect(described_class.validate_chain_config!(model: 'gpt-3.5-turbo')).to eq(true)
    end

    it 'raises error if OPENAI_API_KEY is missing' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      expect {
        described_class.validate_chain_config!(model: 'gpt-3.5-turbo')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /OPENAI_API_KEY/)
    end

    it 'adds warning for unknown model' do
      allow_any_instance_of(described_class).to receive(:add_warning)
      expect(described_class.validate_chain_config!(model: 'unknown-model')).to eq(true)
    end

    it 'raises error if Ollama is not running' do
      allow_any_instance_of(described_class).to receive(:check_ollama_availability).and_return(false)
      expect {
        described_class.validate_chain_config!(model: 'llama2')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Ollama/)
    end
  end

  describe '.validate_chain_config! edge-cases' do
    it 'returns true if model is nil' do
      expect(described_class.validate_chain_config!(model: nil)).to eq(true)
    end
    it 'returns true if tools is nil' do
      expect(described_class.validate_chain_config!(tools: nil)).to eq(true)
    end
    it 'returns true if memory is nil' do
      expect(described_class.validate_chain_config!(memory: nil)).to eq(true)
    end
    it 'returns true if retriever is false' do
      expect(described_class.validate_chain_config!(retriever: false)).to eq(true)
    end
    it 'calls validate_single_tool! for each tool in ToolManager' do
      tool1 = double('Tool1')
      tool2 = double('Tool2')
      tool_manager = double('ToolManager', tools: [tool1, tool2])
      v = described_class.new
      expect(v).to receive(:validate_single_tool!).with(tool1)
      expect(v).to receive(:validate_single_tool!).with(tool2)
      v.send(:validate_tools!, tool_manager)
    end
    it 'calls validate_single_tool! for single tool' do
      tool = double('Tool')
      v = described_class.new
      expect(v).to receive(:validate_single_tool!).with(tool)
      v.send(:validate_tools!, tool)
    end
  end

  describe '#validate_single_tool! edge-case' do
    it 'does nothing for unknown tool type' do
      tool = double('UnknownTool')
      allow(tool).to receive_message_chain(:class, :name).and_return('UnknownTool')
      v = described_class.new
      expect { v.send(:validate_single_tool!, tool) }.not_to raise_error
    end
  end

  describe '#validate_memory! edge-case' do
    it 'does nothing for unknown memory type' do
      memory = double('UnknownMemory')
      allow(memory).to receive_message_chain(:class, :name).and_return('UnknownMemory')
      v = described_class.new
      expect { v.send(:validate_memory!, memory) }.not_to raise_error
    end
  end

  describe '#validate_retriever! edge-case' do
    it 'does nothing for unknown retriever type' do
      retriever = double('UnknownRetriever')
      allow(retriever).to receive_message_chain(:class, :name).and_return('UnknownRetriever')
      v = described_class.new
      expect { v.send(:validate_retriever!, retriever) }.not_to raise_error
    end
  end

  describe '.validate_environment' do
    it 'returns a hash with all checks' do
      allow_any_instance_of(described_class).to receive(:check_ollama_availability).and_return(true)
      allow_any_instance_of(described_class).to receive(:check_ruby_version).and_return(true)
      allow_any_instance_of(described_class).to receive(:check_python_availability).and_return(true)
      allow_any_instance_of(described_class).to receive(:check_node_availability).and_return(true)
      allow_any_instance_of(described_class).to receive(:check_internet_connectivity).and_return(true)
      allow_any_instance_of(described_class).to receive(:check_api_keys).and_return({ openai: true })
      result = described_class.validate_environment
      expect(result).to be_a(Hash)
      expect(result).to include(:ollama, :ruby, :python, :node, :internet, :apis, :warnings)
    end
  end

  describe '#add_warning' do
    it 'adds warning to @warnings' do
      v = described_class.new
      v.send(:add_warning, 'test warning')
      expect(v.instance_variable_get(:@warnings)).to include('test warning')
    end
  end

  describe '#warn_user' do
    it 'calls warn if Rails is not defined' do
      v = described_class.new
      expect(v).to receive(:warn).with(/test warn/)
      v.send(:warn_user, 'test warn')
    end
    it 'calls Rails.logger.warn if Rails is defined' do
      v = described_class.new
      stub_const('Rails', double('Rails', logger: double(warn: true)))
      expect(Rails.logger).to receive(:warn).with(/test warn/)
      v.send(:warn_user, 'test warn')
    end
  end

  describe '#validate_tools!' do
    it 'calls validate_web_search_tool! for WebSearch' do
      tool = double('WebSearch')
      allow(tool).to receive_message_chain(:class, :name).and_return('WebSearch')
      expect(validator).to receive(:validate_web_search_tool!).with(tool)
      validator.send(:validate_tools!, [tool])
    end
    it 'calls validate_code_interpreter_tool! for CodeInterpreter' do
      tool = double('CodeInterpreter')
      allow(tool).to receive_message_chain(:class, :name).and_return('CodeInterpreter')
      expect(validator).to receive(:validate_code_interpreter_tool!).with(tool)
      validator.send(:validate_tools!, [tool])
    end
    it 'does nothing for Calculator' do
      tool = double('Calculator')
      allow(tool).to receive_message_chain(:class, :name).and_return('Calculator')
      expect(validator).not_to receive(:validate_web_search_tool!)
      expect(validator).not_to receive(:validate_code_interpreter_tool!)
      validator.send(:validate_tools!, [tool])
    end
  end

  describe '#validate_redis_memory!' do
    it 'raises error if Redis ping fails' do
      redis = double('redis')
      allow(redis).to receive(:ping).and_raise(StandardError, 'fail')
      memory = double('RedisMemory', instance_variable_get: redis, redis: redis)
      expect {
        validator.send(:validate_redis_memory!, memory)
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Redis/)
    end
    it 'does not raise if Redis ping succeeds' do
      redis = double('redis', ping: true)
      memory = double('RedisMemory', instance_variable_get: redis, redis: redis)
      expect {
        validator.send(:validate_redis_memory!, memory)
      }.not_to raise_error
    end
  end

  describe '#validate_memory!' do
    it 'does nothing for Array memory' do
      memory = []
      expect {
        validator.send(:validate_memory!, memory)
      }.not_to raise_error
    end
  end

  describe '#validate_retriever!' do
    it 'raises error if Weaviate is not ready' do
      retriever = double('WeaviateRetriever')
      allow(retriever).to receive_message_chain(:class, :name).and_return('Weaviate')
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '500'))
      expect {
        validator.send(:validate_retriever!, retriever)
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Weaviate/)
    end
    it 'does not raise if Weaviate is ready' do
      retriever = double('WeaviateRetriever')
      allow(retriever).to receive_message_chain(:class, :name).and_return('Weaviate')
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200'))
      expect {
        validator.send(:validate_retriever!, retriever)
      }.not_to raise_error
    end
  end

  describe 'environment checks' do
    before(:each) do
      allow(Open3).to receive(:capture2).and_call_original
    end
    it 'check_ollama_availability returns true/false' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200'))
      expect(validator.send(:check_ollama_availability)).to eq(true)
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '500'))
      expect(validator.send(:check_ollama_availability)).to eq(false)
    end
    it 'check_ruby_version returns true' do
      expect(validator.send(:check_ruby_version)).to eq(RUBY_VERSION >= '2.5')
    end
    it 'check_python_availability returns true' do
      allow(Open3).to receive(:capture2).and_return(['Python 3.8.0', double(success?: true)])
      expect(validator.send(:check_python_availability)).to eq(true)
    end
    it 'check_python_availability returns false' do
      expect(Open3).to receive(:capture2).and_return(['', double(success?: false)])
      expect(validator.send(:check_python_availability)).to eq(false)
    end
    it 'check_node_availability returns true' do
      allow(Open3).to receive(:capture2).and_return(['v18.0.0', double(success?: true)])
      expect(validator.send(:check_node_availability)).to eq(true)
    end
    it 'check_node_availability returns false' do
      expect(Open3).to receive(:capture2).and_return(['', double(success?: false)])
      expect(validator.send(:check_node_availability)).to eq(false)
    end
    it 'check_internet_connectivity returns true' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200'))
      expect(validator.send(:check_internet_connectivity)).to eq(true)
    end
    it 'check_internet_connectivity returns false' do
      allow(Net::HTTP).to receive(:get_response).with(anything).and_raise(StandardError, 'fail')
      expect(validator.send(:check_internet_connectivity)).to eq(false)
    end
    it 'check_api_keys returns hash' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return(nil)
      expect(validator.send(:check_api_keys)).to be_a(Hash)
    end
  end

  describe '#validate_openai_requirements!' do
    it 'raises error if key too short' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('short')
      expect {
        validator.send(:validate_openai_requirements!, 'gpt-3.5-turbo')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /too short/)
    end
    it 'raises error if OpenAI returns 401' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-validkey1234567890123456')
      fake_resp = double('resp', code: '401')
      fake_http = double(request: fake_resp)
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      expect {
        validator.send(:validate_openai_requirements!, 'gpt-3.5-turbo')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /invalid or expired/)
    end
    it 'adds warning if OpenAI returns 429' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-validkey1234567890123456')
      fake_resp = double('resp', code: '429')
      fake_http = double(request: fake_resp)
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      validator.send(:validate_openai_requirements!, 'gpt-3.5-turbo')
      expect(validator.instance_variable_get(:@warnings).join).to match(/rate limit/)
    end
    it 'adds warning if OpenAI returns other code' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-validkey1234567890123456')
      fake_resp = double('resp', code: '500')
      fake_http = double(request: fake_resp)
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      validator.send(:validate_openai_requirements!, 'gpt-3.5-turbo')
      expect(validator.instance_variable_get(:@warnings).join).to match(/status 500/)
    end
    it 'adds warning if OpenAI connection fails' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-validkey1234567890123456')
      allow(Net::HTTP).to receive(:new).and_raise(StandardError, 'fail')
      validator.send(:validate_openai_requirements!, 'gpt-3.5-turbo')
      expect(validator.instance_variable_get(:@warnings).join).to match(/Cannot verify/)
    end
  end

  describe '#validate_web_search_tool!' do
    let(:validator) { described_class.new }
    let(:tool) { double('WebSearchTool') }

    before do
      allow(ENV).to receive(:[]).and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return(nil)
      allow(Net::HTTP).to receive(:get_response).and_return(double(code: '200'))
      allow_any_instance_of(Net::HTTP).to receive(:get).and_return(double(code: '200'))
    end

    it 'adds warning if no Google keys' do
      warnings = validator.send(:validate_web_search_tool!, tool)
      expect(validator.instance_variable_get(:@warnings)).to include(/Google Search API not configured/i)
    end

    it 'adds warning if no internet' do
      allow(Net::HTTP).to receive(:get_response).and_raise(SocketError)
      validator.send(:validate_web_search_tool!, tool)
      expect(validator.instance_variable_get(:@warnings).join).to match(/No internet connection detected/i)
    end
    it 'adds warning if Google API not available' do
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return('cx')
      fake_http = double
      allow(fake_http).to receive(:get).and_raise(StandardError, 'fail')
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      tool = double('WebSearch')
      allow(validator).to receive(:check_internet_connectivity).and_return(true)
      validator.send(:validate_web_search_tool!, tool)
      expect(validator.instance_variable_get(:@warnings).join).to match(/may be unavailable/)
    end
  end

  describe '#validate_ollama_requirements!' do
    it 'raises error if Ollama is not running' do
      allow(validator).to receive(:check_ollama_availability).and_return(false)
      expect {
        validator.send(:validate_ollama_requirements!, 'llama2')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Ollama is not running/)
    end
    it 'raises error if model not found in Ollama' do
      allow(validator).to receive(:check_ollama_availability).and_return(true)
      allow(validator).to receive(:model_available_in_ollama?).and_return(false)
      allow(validator).to receive(:list_ollama_models).and_return(['llama2', 'qwen'])
      expect {
        validator.send(:validate_ollama_requirements!, 'gemma')
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /not found in Ollama/)
    end
    it 'passes if Ollama is running and model is available' do
      allow(validator).to receive(:check_ollama_availability).and_return(true)
      allow(validator).to receive(:model_available_in_ollama?).and_return(true)
      expect {
        validator.send(:validate_ollama_requirements!, 'llama2')
      }.not_to raise_error
    end
  end

  describe '#validate_code_interpreter_tool!' do
    it 'adds warning if Ruby not found' do
      tool = double('CodeInterpreter', instance_variable_get: ['ruby'])
      allow(tool).to receive(:instance_variable_get).with(:@allowed_languages).and_return(['ruby'])
      allow(validator).to receive(:check_ruby_version).and_return(false)
      validator.send(:validate_code_interpreter_tool!, tool)
      expect(validator.instance_variable_get(:@warnings).join).to match(/Ruby interpreter not found/)
    end
    it 'adds warning if Python not found' do
      tool = double('CodeInterpreter', instance_variable_get: ['python'])
      allow(tool).to receive(:instance_variable_get).with(:@allowed_languages).and_return(['python'])
      allow(validator).to receive(:check_python_availability).and_return(false)
      validator.send(:validate_code_interpreter_tool!, tool)
      expect(validator.instance_variable_get(:@warnings).join).to match(/Python interpreter not found/)
    end
    it 'adds warning if Node.js not found' do
      tool = double('CodeInterpreter', instance_variable_get: ['javascript'])
      allow(tool).to receive(:instance_variable_get).with(:@allowed_languages).and_return(['javascript'])
      allow(validator).to receive(:check_node_availability).and_return(false)
      validator.send(:validate_code_interpreter_tool!, tool)
      expect(validator.instance_variable_get(:@warnings).join).to match(/Node\.js interpreter not found/)
    end
  end

  describe '#validate_weaviate_retriever!' do
    it 'raises error if cannot connect to Weaviate' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError, 'fail')
      retriever = double('WeaviateRetriever')
      expect {
        validator.send(:validate_weaviate_retriever!, retriever)
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Cannot connect to Weaviate/)
    end
    it 'raises error if Weaviate not ready' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '500'))
      retriever = double('WeaviateRetriever')
      expect {
        validator.send(:validate_weaviate_retriever!, retriever)
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Weaviate server is not ready/)
    end
    it 'passes if Weaviate is ready' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200'))
      retriever = double('WeaviateRetriever')
      expect {
        validator.send(:validate_weaviate_retriever!, retriever)
      }.not_to raise_error
    end
  end

  describe '#validate_memory! for Redis' do
    it 'raises error if Redis not responding' do
      redis = double('redis')
      allow(redis).to receive(:ping).and_raise(StandardError, 'fail')
      memory = double('RedisMemory', instance_variable_get: redis, redis: redis)
      expect {
        validator.send(:validate_redis_memory!, memory)
      }.to raise_error(LLMChain::ConfigurationValidator::ValidationError, /Redis connection failed/)
    end
    it 'passes if Redis responds' do
      redis = double('redis', ping: true)
      memory = double('RedisMemory', instance_variable_get: redis, redis: redis)
      expect {
        validator.send(:validate_redis_memory!, memory)
      }.not_to raise_error
    end
  end

  describe '#model_available_in_ollama?' do
    it 'returns true if model is present' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200', body: '{"models":[{"name":"llama2"}]}'))
      expect(validator.send(:model_available_in_ollama?, 'llama2')).to eq(true)
    end
    it 'returns false if model is absent' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200', body: '{"models":[{"name":"qwen"}]}'))
      expect(validator.send(:model_available_in_ollama?, 'llama2')).to eq(false)
    end
    it 'returns false on error' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError)
      expect(validator.send(:model_available_in_ollama?, 'llama2')).to eq(false)
    end
  end

  describe '#list_ollama_models' do
    it 'returns array of models on success' do
      allow(Net::HTTP).to receive(:get_response).and_return(double('resp', code: '200', body: '{"models":[{"name":"llama2"},{"name":"qwen"}]}'))
      expect(validator.send(:list_ollama_models)).to eq(['llama2', 'qwen'])
    end
    it 'returns empty array on error' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError)
      expect(validator.send(:list_ollama_models)).to eq([])
    end
  end

  describe '#check_api_keys' do
    it 'returns hash with openai: true if key present' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('key')
      expect(validator.send(:check_api_keys)[:openai]).to eq(true)
    end
    it 'returns hash with google_search: true if both keys present' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return('cx')
      expect(validator.send(:check_api_keys)[:google_search]).to eq(true)
    end
    it 'returns hash with false if keys missing' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return(nil)
      keys = validator.send(:check_api_keys)
      expect(keys[:openai]).to eq(false)
      expect(keys[:google_search]).to eq(false)
    end
  end

  describe '#validate_model!' do
    it 'adds warning for unknown model' do
      v = described_class.new
      expect(v).to receive(:add_warning).with(/Unknown model type/)
      v.send(:validate_model!, 'abracadabra')
    end
    it 'calls openai and client checks for gpt' do
      expect_any_instance_of(described_class).to receive(:validate_openai_requirements!).with('gpt-3.5-turbo').and_return(true)
      expect_any_instance_of(described_class).to receive(:validate_client_availability!).with('gpt-3.5-turbo').and_return(true)
      v = described_class.new
      v.send(:validate_model!, 'gpt-3.5-turbo')
    end
    it 'calls ollama and client checks for llama' do
      expect_any_instance_of(described_class).to receive(:validate_ollama_requirements!).with('llama2').and_return(true)
      expect_any_instance_of(described_class).to receive(:validate_client_availability!).with('llama2').and_return(true)
      allow_any_instance_of(described_class).to receive(:check_ollama_availability).and_return(true)
      v = described_class.new
      v.send(:validate_model!, 'llama2')
    end
  end

  describe '#validate_client_availability!' do
    it 'calls check_ollama_availability for ollama models' do
      v = described_class.new
      allow(v).to receive(:check_ollama_availability).and_return(true)
      expect(v).to receive(:check_ollama_availability)
      v.send(:validate_client_availability!, 'llama2')
    end
    it 'does nothing for non-ollama models' do
      v = described_class.new
      expect(v).not_to receive(:check_ollama_availability)
      v.send(:validate_client_availability!, 'gpt-3.5-turbo')
    end
  end
end 