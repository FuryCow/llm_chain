require 'spec_helper'

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
        chain = described_class.new(memory: memory)
        
        chain.ask("first")
        expect(chain.ask("context?")).to include("first")
      end
    end

    context "with tools" do
      it "processes tools before asking" do
        tool = double("Tool", match?: true, call: "42", name: "calc")
        chain = described_class.new(tools: [tool])
        
        expect(chain.ask("calculate")).to include("42")
      end
    end
  end
end