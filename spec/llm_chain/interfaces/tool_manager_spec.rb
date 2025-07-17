require 'spec_helper'
require 'llm_chain/interfaces/tool_manager'

RSpec.describe LLMChain::Interfaces::ToolManager do
  let(:manager) { described_class.new }

  it 'raises NotImplementedError for #register_tool' do
    expect { manager.register_tool(:foo) }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #unregister_tool' do
    expect { manager.unregister_tool('foo') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #get_tool' do
    expect { manager.get_tool('foo') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #list_tools' do
    expect { manager.list_tools }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #find_matching_tools' do
    expect { manager.find_matching_tools('prompt') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #execute_tools' do
    expect { manager.execute_tools('prompt') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #format_tool_results' do
    expect { manager.format_tool_results({}) }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #tools_description' do
    expect { manager.tools_description }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #needs_tools?' do
    expect { manager.needs_tools?('prompt') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #auto_execute' do
    expect { manager.auto_execute('prompt') }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
  it 'raises NotImplementedError for #get_tools_schema' do
    expect { manager.get_tools_schema }.to raise_error(NotImplementedError, /Implement in subclass/)
  end
end 