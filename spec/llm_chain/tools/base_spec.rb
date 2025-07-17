require 'spec_helper'
require 'llm_chain/tools/base'

RSpec.describe LLMChain::Tools::Base do
  let(:params) { { foo: { type: 'string' }, bar: { type: 'integer' } } }
  let(:tool) { described_class.new(name: 'test', description: 'desc', parameters: params) }

  describe '#initialize' do
    it 'saves name, description, parameters' do
      expect(tool.name).to eq('test')
      expect(tool.description).to eq('desc')
      expect(tool.parameters).to eq(params)
    end
  end

  describe '#match?' do
    it 'raises NotImplementedError' do
      expect { tool.match?('prompt') }.to raise_error(NotImplementedError)
    end
  end

  describe '#call' do
    it 'raises NotImplementedError' do
      expect { tool.call('prompt') }.to raise_error(NotImplementedError)
    end
  end

  describe '#to_schema' do
    it 'returns correct schema' do
      expect(tool.to_schema).to eq({
        name: 'test',
        description: 'desc',
        parameters: {
          type: 'object',
          properties: params,
          required: []
        }
      })
    end
  end

  describe '#extract_parameters' do
    it 'returns empty hash by default' do
      expect(tool.extract_parameters('prompt')).to eq({})
    end
  end

  describe '#format_result' do
    it 'returns string as is' do
      expect(tool.format_result('foo')).to eq('foo')
    end
    it 'formats hash as pretty JSON' do
      expect(tool.format_result({ a: 1, b: 2 })).to include('{
')
    end
    it 'formats array as pretty JSON' do
      expect(tool.format_result([1, 2, 3])).to include('[
')
    end
    it 'formats other types as string' do
      expect(tool.format_result(123)).to eq('123')
    end
  end

  describe '#contains_keywords?' do
    it 'returns true if prompt contains any keyword' do
      expect(tool.send(:contains_keywords?, 'foo bar', ['bar', 'baz'])).to be true
    end
    it 'returns false if prompt contains none' do
      expect(tool.send(:contains_keywords?, 'foo', ['bar', 'baz'])).to be false
    end
    it 'is case-insensitive' do
      expect(tool.send(:contains_keywords?, 'FOO', ['foo'])).to be true
    end
  end

  describe '#extract_numbers' do
    it 'extracts integers and floats' do
      expect(tool.send(:extract_numbers, 'a 1 b 2.5 c -3')).to eq([1.0, 2.5, -3.0])
    end
    it 'returns empty array if no numbers' do
      expect(tool.send(:extract_numbers, 'foo')).to eq([])
    end
  end

  describe '#extract_urls' do
    it 'extracts all URLs' do
      text = 'see https://a.com and http://b.com/page.'
      expect(tool.send(:extract_urls, text)).to eq(['https://a.com', 'http://b.com/page.'])
    end
    it 'returns empty array if no urls' do
      expect(tool.send(:extract_urls, 'foo')).to eq([])
    end
  end
end 