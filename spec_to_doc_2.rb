#!/usr/bin/env ruby
# frozen_string_literal: true

require 'openai'

class SpecToDoc2Generator
  Batch = Struct.new(:files, :char_count)

  SYSTEM_PROMPT = <<~SYSTEM
    You are a senior Ruby on Rails engineer writing onboarding documentation
    for a new developer joining the team. You will be given RSpec test files
    from the codebase. Your task is to read them carefully, infer how the system works,
    and explain it in natural, developer-friendly documentation.

    Focus less on listing methods and more on explaining:
    - What the codebase as a whole is trying to achieve (its domain and purpose).
    - How the main models, controllers, or services fit together.
    - Typical usage patterns: how a developer or feature might interact with these classes.
    - Quirks, edge cases, and implicit rules that a developer must be aware of.
    - Domain knowledge that can be inferred from the specs (business rules, workflows, permissions).
    - Validations, callbacks, and background jobs — but explain them in the context of "why they exist" and "how to use them safely".
    - Examples: illustrate key behaviors with short, practical examples drawn from the specs.

    Style guidelines:
    - Write as though you are explaining the system to a new teammate.
    - Organize into clear sections with headings.
    - When multiple files are in a batch, synthesize knowledge into a coherent narrative rather than just repeating file by file.
    - Conclude with a high-level summary of the app: what it does, how it works at a domain level, and what a developer should keep in mind when extending it.

    The goal is to capture the intent and usage of the codebase, not just generate an API reference.
  SYSTEM

  def initialize(path:, out: 'user_docs.md', files_per_batch: nil, max_chars: 120_000, max_tokens: 24_000,
                 model: 'gpt-5-mini', reasoning_effort: 'low', sleep_between: ENV.fetch('LLM_SLEEP_BETWEEN',
                                                                                        '0.0').to_f)
    @path = path
    @out = out
    @files_per_batch = files_per_batch
    @max_chars = max_chars
    @max_tokens = max_tokens
    @model = model
    @reasoning_effort = reasoning_effort
    @sleep_between = sleep_between
    validate_environment!
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'], log_errors: true)
  end

  def run
    spec_files = collect_files(@path)
    abort("No spec files found in: #{@path}") if spec_files.empty?
    batches = build_batches(spec_files)
    write_header(@out, @path, @model, @max_tokens, @max_chars)
    batches.each_with_index do |batch, idx|
      messages = [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: batch.files.map { |f| f[:wrapped] }.join }
      ]
      markdown = call_llm(messages)
      if markdown && !markdown.strip.empty?
        File.open(@out, 'a') do |f|
          f.puts "\n\n## Batch #{idx + 1}\n\n"

          batch.files.each do |bf|
            f.puts "# File: #{bf[:path]}"
          end
          f.puts

          f.puts markdown
          f.puts "\n\n---"
        end
      end
      sleep(@sleep_between) if @sleep_between.positive?
    end
    puts "Done. Combined documentation written to #{@out}"
  end

  private

  def validate_environment!
    abort('Please set your OPENAI_API_KEY environment variable.') unless ENV['OPENAI_API_KEY']
    abort('Provide a file or directory path as the first argument.') if @path.nil? || @path.strip.empty?
    abort("File not found: #{@path}") unless File.exist?(@path)
  end

  def collect_files(path)
    if File.directory?(path)
      Dir.glob(File.join(path, '**/*_spec.rb')).sort
    else
      [path]
    end
  end

  def approx_tokens_for_chars(chars)
    (chars / 4.0).ceil
  end

  def build_batches(spec_files)
    batches = []
    current = Batch.new([], 0)
    spec_files.each do |file|
      text = File.read(file)
      wrapper = "# File: #{file}\n\n#{text}\n"
      wrapper = "\n\n---\n\n#{wrapper}" if current.files.any?
      projected = current.char_count + wrapper.length
      too_many_files = @files_per_batch && current.files.size >= @files_per_batch
      too_many_chars = projected > @max_chars
      if too_many_files || too_many_chars
        batches << current
        current = Batch.new([], 0)
      end
      current.files << { path: file, wrapped: wrapper, len: wrapper.length }
      current.char_count += wrapper.length
    end
    batches << current if current.files.any?
    batches
  end

  def write_header(out, path, model, max_tokens, max_chars)
    File.write(out, <<~MD)
      # Inferred Documentation from RSpec

      > Generated on #{Time.now} for path: `#{path}`
      > Model: `#{model}` | Heuristic budget: ~#{max_tokens} tokens/batch (#{max_chars} chars)

      ---
    MD
  end

  def supports_responses_api?
    @client.respond_to?(:responses) && @client.responses.respond_to?(:create)
  rescue StandardError
    false
  end

  def call_llm(messages)
    if supports_responses_api?
      res = @client.responses.create(
        parameters: {
          model: @model,
          input: messages,
          reasoning: { effort: @reasoning_effort }
        }
      )
      res.dig('output', 1, 'content', 0, 'text') || res.dig('output', 0, 'content', 0, 'text')
    else
      res = @client.chat(
        parameters: {
          model: @model,
          messages: messages.map { |m| { role: m[:role], content: m[:content] } }
        }
      )
      res.dig('choices', 0, 'message', 'content')
    end
  end
end

if $PROGRAM_NAME == __FILE__
  path = ARGV.first
  SpecToDoc2Generator.new(path: path).run
end
