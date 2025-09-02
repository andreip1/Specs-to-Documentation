spec_to_doc_2 — RSpec → Onboarding Docs (LLM-assisted)

spec_to_doc_2 turns your RSpec files into developer-friendly onboarding documentation.
Instead of listing APIs, it infers domain purpose, usage patterns, workflows, and quirks from your specs.

This README reflects the current code state in this commit:

OOP generator: SpecToDoc2Generator in spec_to_doc_2.rb

No OptionParser and no emojis

Safe CLI entrypoint guard (if $PROGRAM_NAME == __FILE__)

Per-batch headers list which spec files fed the batch (e.g., # File: path/to/spec.rb)

Uses OpenAI Responses API with Chat API fallback (depending on gem version)

RSpec suite stubs the OpenAI client

Quick start
1) Install dependencies
bundle install

2) Set your OpenAI API key

The tool requires the OPENAI_API_KEY environment variable.

macOS/Linux:

export OPENAI_API_KEY="sk-...your key..."


Windows (PowerShell):

setx OPENAI_API_KEY "sk-...your key..."
# restart your shell so the variable is visible


If this is not set you’ll see: Please set your OPENAI_API_KEY environment variable.

3) Run against a file or a folder
# Against a folder (recursively finds *_spec.rb)
ruby spec_to_doc_2.rb path/to/spec

# Single file
ruby spec_to_doc_2.rb path/to/spec/models/user_spec.rb


By default the output is written to user_docs.md in the current working directory.