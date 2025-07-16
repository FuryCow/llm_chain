require 'spec_helper'

# Minimal tool for specs
class TestTool < LLMChain::Tools::Base
  def initialize
    super(name: "calc", description: "Test tool for specs", parameters: {})
  end

  def match?(_prompt)
    true
  end

  def call(_prompt, context: {})
    "42"
  end
end

RSpec.describe LLMChain::Chain do
  let(:memory) { double("Memory", recall: nil, store: true) }
  let(:client) { double("Client", chat: "Test response") }

  before do
    allow(LLMChain::ClientRegistry).to receive(:client_for).and_return(client)
  end

  describe "#ask" do
    it "returns response from client" do
      chain = described_class.new(memory: memory)
      expect(chain.ask("test")).to eq("Test response")
    end

    context "with memory" do
      it "stores and recalls context" do
        memory = LLMChain::Memory::Array.new
        client = double("Client")
        allow(client).to receive(:chat) { |prompt| prompt }
        allow(LLMChain::ClientRegistry).to receive(:client_for).and_return(client)

        chain = described_class.new(memory: memory)

        chain.ask("first")
        result = chain.ask("context?")
        expect(result).to include("first")
      end
    end

    context "with tools" do
      it "processes tools before asking" do
        tool = TestTool.new
        client = double("Client")
        allow(client).to receive(:chat) { |prompt| prompt }
        allow(LLMChain::ClientRegistry).to receive(:client_for).and_return(client)

        chain = described_class.new(tools: [tool])

        expect(chain.ask("calculate")).to include("42")
      end
    end
  end
end