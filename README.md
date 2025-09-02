### Vibe coded alpha
# Specs To Documentation → Onboarding Docs (LLM-assisted)

spec_to_doc_2 turns your RSpec files into developer-friendly onboarding documentation. Instead of listing APIs, it infers domain purpose, usage patterns, workflows, and quirks from your specs.

## Quick start

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **Set your OpenAI API key**

   The tool requires the `OPENAI_API_KEY` environment variable.

   macOS/Linux:
   ```bash
   export OPENAI_API_KEY="sk-...your key..."
   ```

3. **Run against a file or a folder**
   - Against a folder (recursively finds `*_spec.rb`)
     ```bash
     bundle exec ruby spec_to_doc_2.rb path/to/spec
     ```

   - Single file
     ```bash
     bundle exec ruby spec_to_doc_2.rb path/to/spec/models/user_spec.rb
     ```

By default, the output is written to `user_docs.md` in the current working directory.
