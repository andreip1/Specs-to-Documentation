# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

require_relative '../spec_to_doc_2'

RSpec.describe SpecToDoc2Generator do
  let(:api_key) { 'test-key' }

  before do
    @orig_env = ENV['OPENAI_API_KEY']
    ENV['OPENAI_API_KEY'] = api_key
  end

  after do
    ENV['OPENAI_API_KEY'] = @orig_env
  end

  def write_spec(dir, rel, body: "RSpec.describe 'X' do; it { expect(true).to be true }; end")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  describe '#run end-to-end' do
    it 'writes a header and batched docs using the Responses API path' do
      Dir.mktmpdir do |dir|
        f1 = write_spec(dir, 'spec/models/a_spec.rb', body: "RSpec.describe 'A' do; end")
        f2 = write_spec(dir, 'spec/models/b_spec.rb', body: "RSpec.describe 'B' do; end")
        out = File.join(dir, 'out.md')

        responses_double = instance_double('ResponsesAPI')
        client_double = instance_double('OpenAI::Client', responses: responses_double)

        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(responses_double).to receive(:create).and_return(
          { 'output' => [{ 'content' => [{ 'text' => 'Doc Batch Content' }] }] }
        )

        generator = described_class.new(
          path: File.join(dir, 'spec'),
          out: out,
          files_per_batch: 1,
          max_chars: 10_000,
          model: 'gpt-5-mini',
          reasoning_effort: 'low',
          sleep_between: 0.0
        )

        allow(client_double).to receive(:respond_to?).with(:responses).and_return(true)
        allow(client_double.responses).to receive(:respond_to?).with(:create).and_return(true)

        generator.run

        md = File.read(out)
        expect(md).to include('# Inferred Documentation from RSpec')
        expect(md).to include('## Batch 1')
        expect(md).to include('## Batch 2')
        expect(md.scan('Doc Batch Content').size).to eq(2)
        expect(md).to include("# File: #{f1}")
        expect(md).to include("# File: #{f2}")
      end
    end
    
    it 'handles single-file input and respects max_chars batching' do
      Dir.mktmpdir do |dir|
        file = write_spec(dir, 'only_spec.rb', body: 'RSpec.describe("Y") { }' * 10)
        out = File.join(dir, 'out.md')

        responses_double = instance_double('ResponsesAPI')
        client_double = instance_double('OpenAI::Client', responses: responses_double)

        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:respond_to?).with(:responses).and_return(true)
        allow(client_double.responses).to receive(:respond_to?).with(:create).and_return(true)
        allow(responses_double).to receive(:create).and_return(
          { 'output' => [{ 'content' => [{ 'text' => 'Chunk Doc' }] }] }
        )

        generator = described_class.new(
          path: file,
          out: out,
          files_per_batch: nil,
          max_chars: 50,
          sleep_between: 0.0
        )

        generator.run

        md = File.read(out)

        expect(md).to include('## Batch 1')
        expect(md).to match(/## Batch \d+/)
        expect(md).to include('Chunk Doc')
        expect(md).to include("# File: #{file}")
      end
    end

    it 'skips appending when the model returns an empty string' do
      Dir.mktmpdir do |dir|
        write_spec(dir, 'spec/a_spec.rb')
        out = File.join(dir, 'out.md')

        responses_double = instance_double('ResponsesAPI')
        client_double = instance_double('OpenAI::Client', responses: responses_double)

        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:respond_to?).with(:responses).and_return(true)
        allow(client_double.responses).to receive(:respond_to?).with(:create).and_return(true)
        allow(responses_double).to receive(:create).and_return(
          { 'output' => [{ 'content' => [{ 'text' => '' }] }] }
        )

        generator = described_class.new(
          path: File.join(dir, 'spec'),
          out: out
        )

        generator.run

        md = File.read(out)
        expect(md).to include('# Inferred Documentation from RSpec')
        expect(md).not_to include('## Batch 1')
      end
    end
  end

  describe 'guard rails' do
    it 'aborts when OPENAI_API_KEY is missing' do
      ENV['OPENAI_API_KEY'] = nil
      expect do
        described_class.new(path: __FILE__)
      end.to raise_error(SystemExit)
    end

    it 'aborts when path is missing' do
      expect do
        described_class.new(path: '   ')
      end.to raise_error(SystemExit)
    end

    it 'aborts when path does not exist' do
      expect do
        described_class.new(path: '/no/such/path')
      end.to raise_error(SystemExit)
    end

    it 'aborts when directory contains no spec files' do
      Dir.mktmpdir do |dir|
        out = File.join(dir, 'out.md')
        client_double = instance_double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:respond_to?).and_return(false)

        generator = described_class.new(path: dir, out: out)
        expect { generator.run }.to raise_error(SystemExit, /No spec files found/)
      end
    end
  end
end
