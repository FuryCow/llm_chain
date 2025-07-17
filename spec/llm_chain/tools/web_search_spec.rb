require 'llm_chain/tools/web_search'

RSpec.describe LLMChain::Tools::WebSearch do
  let(:tool) { described_class.new(api_key: "test", search_engine: :google) }

  describe "#match?" do
    it "matches prompt with search keyword" do
      expect(tool.match?("search for Ruby 3.2 features")).to be true
    end

    it "does not match unrelated prompt" do
      expect(tool.match?("Tell me a joke")).to be false
    end
  end

  describe "#extract_query" do
    it "extracts query from prompt" do
      expect(tool.send(:extract_query, "search for Ruby 3.2 features")).to eq("Ruby 3.2 features")
    end

    it "handles multiple items and results at end" do
      expect(tool.send(:extract_query, "search for Ruby, Rails, and Sinatra, 5 results")).to eq("Ruby, Rails, and Sinatra")
    end

    it "handles semicolons and results" do
      expect(tool.send(:extract_query, "find Python; Django; Flask; 3 results")).to eq("Python; Django; Flask")
    end

    it "removes politeness and results" do
      expect(tool.send(:extract_query, "Can you please search for JavaScript, TypeScript, 2 results")).to eq("JavaScript, TypeScript")
    end

    it "keeps all items if no results specified" do
      expect(tool.send(:extract_query, "lookup Go, Rust, Elixir")).to eq("Go, Rust, Elixir")
    end

    it "handles results at start" do
      expect(tool.send(:extract_query, "10 results for search: C++, C#, F#")).to eq("C++, C#, F#")
    end

    it "handles results in the middle" do
      expect(tool.send(:extract_query, "search for Java, 4 results, Kotlin, Scala")).to eq("Java, Kotlin, Scala")
    end

    it "handles extra spaces and commas" do
      expect(tool.send(:extract_query, "search for   Ruby ,  Python , 3 results  ")).to eq("Ruby , Python")
    end
  end

  describe "#extract_num_results" do
    it "extracts number of results from prompt" do
      expect(tool.send(:extract_num_results, "find Ruby, 3 results")).to eq(3)
    end

    it "returns default if not specified" do
      expect(tool.send(:extract_num_results, "find Ruby")).to eq(5)
    end
  end

  describe "#call" do
    it "returns fallback if no API key" do
      tool = described_class.new(api_key: nil)
      result = tool.call("search for Ruby")
      expect(result).to be_a(Hash)
      expect(result[:results]).to eq([])
    end

    it "returns error for empty query" do
      result = tool.call("")
      expect(result).to eq("No search query found")
    end

    it "returns error if search fails and no fallback" do
      allow(tool).to receive(:perform_search_with_retry).and_raise(StandardError.new("fail!"))
      result = tool.call("search for Ruby")
      expect(result[:error]).to eq("fail!")
      expect(result[:results]).to eq([])
    end
  end

  describe "#format_search_results" do
    it "formats results correctly" do
      results = [
        { title: "Ruby", url: "https://ruby-lang.org", snippet: "Ruby language" },
        { title: "Rails", url: "https://rubyonrails.org", snippet: "Rails framework" }
      ]
      formatted = tool.send(:format_search_results, "Ruby", results)
      expect(formatted[:formatted]).to include("1. Ruby")
      expect(formatted[:formatted]).to include("2. Rails")
      expect(formatted[:results].size).to eq(2)
    end

    it "formats empty results" do
      formatted = tool.send(:format_search_results, "Ruby", [])
      expect(formatted[:formatted]).to match(/No results found/i)
      expect(formatted[:results]).to eq([])
    end
  end

  describe "#extract_parameters" do
    it "extracts both query and num_results" do
      params = tool.extract_parameters("search for Ruby, 7 results")
      puts "DEBUG extract_parameters: #{params.inspect}"
      expect(params[:query]).to eq("Ruby")
      expect(params[:num_results]).to eq(7)
    end
  end

  describe "Bing search engine" do
    let(:bing_tool) { described_class.new(api_key: "test", search_engine: :bing) }

    it "calls Bing search methods" do
      expect(bing_tool).to receive(:search_bing_results).with("Ruby", 3).and_return([{ title: "Bing Ruby", url: "http://bing.com", snippet: "Bing result" }])
      expect(bing_tool.send(:perform_search, "Ruby", 3)).to eq([{ title: "Bing Ruby", url: "http://bing.com", snippet: "Bing result" }])
    end

    it "returns empty array if no API key" do
      tool = described_class.new(api_key: nil, search_engine: :bing)
      expect(tool.send(:search_bing_results, "Ruby", 3)).to eq([])
    end
  end

  describe "#perform_search_with_retry" do
    it "retries on timeout and succeeds" do
      tries = 0
      allow(tool).to receive(:perform_search) do
        tries += 1
        raise Net::ReadTimeout if tries < 2
        [{ title: "Retry Ruby", url: "http://retry.com", snippet: "Retried result" }]
      end
      expect(tool.send(:perform_search_with_retry, "Ruby", 3)).to eq([{ title: "Retry Ruby", url: "http://retry.com", snippet: "Retried result" }])
      expect(tries).to eq(2)
    end

    it "raises after max retries" do
      allow(tool).to receive(:perform_search).and_raise(Net::ReadTimeout)
      expect {
        tool.send(:perform_search_with_retry, "Ruby", 3, max_retries: 2)
      }.to raise_error(Net::ReadTimeout)
    end
  end

  describe "#handle_api_error" do
    it "logs error via log_error" do
      expect(tool).to receive(:log_error).with("context", instance_of(StandardError))
      tool.send(:handle_api_error, StandardError.new("fail"), "context")
    end
  end

  describe "#parse_google_response" do
    let(:valid_response) do
      double("response", code: "200", body: {
        items: [
          { "title" => "Ruby", "link" => "https://ruby-lang.org", "snippet" => "Ruby language" }
        ]
      }.to_json)
    end

    it "parses valid Google response" do
      results = tool.send(:parse_google_response, valid_response)
      expect(results).to eq([{ title: "Ruby", url: "https://ruby-lang.org", snippet: "Ruby language" }])
    end

    it "returns empty array for error response" do
      response = double("response", code: "500", body: "")
      expect(tool.send(:parse_google_response, response)).to eq([])
    end

    it "returns empty array for invalid JSON" do
      response = double("response", code: "200", body: "not a json")
      expect(tool.send(:parse_google_response, response)).to eq([])
    end

    it "returns empty array for Google API error" do
      response = double("response", code: "200", body: { error: { message: "API error" } }.to_json)
      expect(tool.send(:parse_google_response, response)).to eq([])
    end
  end

  describe "#parse_bing_response" do
    let(:valid_response) do
      double("response", code: "200", body: {
        webPages: {
          value: [
            { "name" => "Ruby", "url" => "https://ruby-lang.org", "snippet" => "Ruby language" }
          ]
        }
      }.to_json)
    end

    it "parses valid Bing response" do
      results = tool.send(:parse_bing_response, valid_response)
      expect(results).to eq([{ title: "Ruby", url: "https://ruby-lang.org", snippet: "Ruby language" }])
    end

    it "returns empty array for error response" do
      response = double("response", code: "500", body: "")
      expect(tool.send(:parse_bing_response, response)).to eq([])
    end

    it "returns empty array for invalid JSON" do
      response = double("response", code: "200", body: "not a json")
      expect(tool.send(:parse_bing_response, response)).to eq([])
    end

    it "returns empty array for Bing API error" do
      response = double("response", code: "200", body: { error: { message: "API error" } }.to_json)
      expect(tool.send(:parse_bing_response, response)).to eq([])
    end
  end

  describe "#format_search_results (edge cases)" do
    it "handles nil and missing fields gracefully" do
      results = [
        { title: nil, url: nil, snippet: nil },
        { }
      ]
      formatted = tool.send(:format_search_results, "Ruby", results)
      expect(formatted[:formatted]).to include("Untitled")
      expect(formatted[:formatted]).to include("No description available")
    end
  end

  describe "#parse_hardcoded_results" do
    it "returns empty array if no hardcoded results" do
      expect(tool.send(:parse_hardcoded_results, "abracadabra123")).to eq([])
    end
  end

  describe "#should_log?" do
    around do |example|
      orig_debug = ENV["LLM_CHAIN_DEBUG"]
      orig_rails = ENV["RAILS_ENV"]
      ENV["LLM_CHAIN_DEBUG"] = nil
      ENV["RAILS_ENV"] = nil
      example.run
      ENV["LLM_CHAIN_DEBUG"] = orig_debug
      ENV["RAILS_ENV"] = orig_rails
    end

    it "returns true if LLM_CHAIN_DEBUG is true" do
      ENV["LLM_CHAIN_DEBUG"] = "true"
      expect(tool.send(:should_log?)).to eq(true)
    end

    it "returns true if RAILS_ENV is development" do
      ENV["RAILS_ENV"] = "development"
      expect(tool.send(:should_log?)).to eq(true)
    end

    it "returns false otherwise" do
      expect(tool.send(:should_log?)).to eq(false)
    end
  end

  describe "#retryable_error?" do
    it "returns true for Timeout::Error" do
      expect(tool.send(:retryable_error?, Timeout::Error.new)).to eq(true)
    end
    it "returns true for Net::OpenTimeout" do
      expect(tool.send(:retryable_error?, Net::OpenTimeout.new)).to eq(true)
    end
    it "returns true for Net::ReadTimeout" do
      expect(tool.send(:retryable_error?, Net::ReadTimeout.new)).to eq(true)
    end
    it "returns true for SocketError" do
      expect(tool.send(:retryable_error?, SocketError.new)).to eq(true)
    end
    it "returns true for ECONNREFUSED" do
      expect(tool.send(:retryable_error?, Errno::ECONNREFUSED.new)).to eq(true)
    end
    it "returns false for StandardError" do
      expect(tool.send(:retryable_error?, StandardError.new)).to eq(false)
    end
    it "returns true for Net::HTTPError with 5xx message" do
      err = Net::HTTPError.new("500 Internal Server Error", nil)
      expect(tool.send(:retryable_error?, err)).to eq(true)
    end
    it "returns false for Net::HTTPError with 404 message" do
      err = Net::HTTPError.new("404 Not Found", nil)
      expect(tool.send(:retryable_error?, err)).to eq(false)
    end
  end

  describe "#fetch_google_response" do
    let(:search_engine_id) { "cx" }
    it "returns nil on Timeout::Error" do
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
      expect(tool.send(:fetch_google_response, "Ruby", 3, search_engine_id)).to be_nil
    end
    it "returns Net::HTTPResponse on success" do
      fake_response = double("response")
      fake_http = double("http")
      allow(fake_http).to receive(:get).and_return(fake_response)
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Timeout).to receive(:timeout).and_yield
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      expect(tool.send(:fetch_google_response, "Ruby", 3, search_engine_id)).to eq(fake_response)
    end
  end

  describe "#fetch_bing_response" do
    it "returns nil on Timeout::Error" do
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
      expect(tool.send(:fetch_bing_response, "Ruby", 3)).to be_nil
    end
    it "returns Net::HTTPResponse on success" do
      fake_response = double("response")
      fake_http = double("http")
      allow(fake_http).to receive(:request).and_return(fake_response)
      allow(fake_http).to receive(:use_ssl=)
      allow(fake_http).to receive(:open_timeout=)
      allow(fake_http).to receive(:read_timeout=)
      allow(Timeout).to receive(:timeout).and_yield
      allow(Net::HTTP).to receive(:new).and_return(fake_http)
      allow(Net::HTTP::Get).to receive(:new).and_return(double("request").as_null_object)
      expect(tool.send(:fetch_bing_response, "Ruby", 3)).to eq(fake_response)
    end
  end

  describe "#search_google_results" do
    it "returns [] if no API key" do
      tool = described_class.new(api_key: nil)
      expect(tool.send(:search_google_results, "Ruby", 3)).to eq([])
    end
    it "returns [] if no search_engine_id" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_SEARCH_ENGINE_ID").and_return(nil)
      allow(ENV).to receive(:[]).with("GOOGLE_CX").and_return(nil)
      allow(tool).to receive(:warn)
      expect(tool.send(:search_google_results, "Ruby", 3)).to eq([])
    end
    it "returns [] on error" do
      allow(tool).to receive(:fetch_google_response).and_raise(StandardError)
      expect(tool.send(:search_google_results, "Ruby", 3)).to eq([])
    end
  end

  describe "#search_bing_results" do
    it "returns [] if no API key" do
      tool = described_class.new(api_key: nil, search_engine: :bing)
      expect(tool.send(:search_bing_results, "Ruby", 3)).to eq([])
    end
    it "returns [] on error" do
      allow(tool).to receive(:fetch_bing_response).and_raise(StandardError)
      expect(tool.send(:search_bing_results, "Ruby", 3)).to eq([])
    end
  end

  describe "#log_error and #log_retry" do
    before { allow(tool).to receive(:should_log?).and_return(true) }
    it "calls warn if Rails is not defined" do
      expect(tool).to receive(:warn).with(/WebSearch/)
      tool.send(:log_error, "msg", StandardError.new("fail"))
    end
    it "calls Rails.logger.error if Rails is defined" do
      stub_const("Rails", double("Rails", logger: double(error: true), env: double(development?: false)))
      expect(Rails.logger).to receive(:error).with(/WebSearch/)
      tool.send(:log_error, "msg", StandardError.new("fail"))
    end
    it "calls warn for log_retry" do
      expect(tool).to receive(:warn).with(/WebSearch/)
      tool.send(:log_retry, "msg", StandardError.new("fail"))
    end
  end

  describe "#handle_api_error" do
    it "calls log_error with context and error" do
      expect(tool).to receive(:log_error).with("ctx", instance_of(StandardError))
      tool.send(:handle_api_error, StandardError.new("fail"), "ctx")
    end
    it "calls log_error with default context if none given" do
      expect(tool).to receive(:log_error).with("API error", instance_of(StandardError))
      tool.send(:handle_api_error, StandardError.new("fail"))
    end
  end
end 