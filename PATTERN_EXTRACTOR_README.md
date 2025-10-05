# Pattern Extraction System - Dependencies & Setup

## ✅ No New Dependencies Needed!

All required dependencies are already in your `mix.exs`:

- **Jason** (~> 1.4) - JSON parsing for templates ✅
- **Elixir** (>= 1.20) - Standard library only ✅

## What Was Created

1. **`lib/singularity/code_pattern_extractor.ex`** (278 lines)
   - Extracts architectural patterns from text and code
   - Language-specific: Elixir, Gleam, Rust
   - Zero external dependencies (pure Elixir)

2. **`lib/singularity/template_matcher.ex`** (220 lines)
   - Matches extracted patterns to templates
   - Loads architectural guidance
   - Uses Jason (already installed)

3. **`test/singularity/code_pattern_extractor_test.exs`** (227 lines)
   - Full test coverage
   - Tests all 3 languages

4. **`PATTERN_EXTRACTION_DEMO.md`**
   - Usage examples
   - Architectural overview

## Status

✅ **Compiles successfully**
✅ **No new dependencies needed**
✅ **Ready to use**

## Quick Test

```bash
# From singularity_app directory
mix compile
mix test test/singularity/code_pattern_extractor_test.exs
```

## Usage

```elixir
# Extract from user request
keywords = CodePatternExtractor.extract_from_text("Create NATS consumer")
# => ["create", "nats", "consumer"]

# Extract from code
code = "use GenServer\ndef handle_call..."
patterns = CodePatternExtractor.extract_from_code(code, :elixir)
# => ["genserver", "state", "synchronous", "handle_call"]

# Find matching template
{:ok, match} = TemplateMatcher.find_template("Create NATS consumer")
# => Full template with architectural guidance
```

## What It Does

Helps AI understand **what to build** by extracting concrete patterns:

- User: "Create NATS consumer with Broadway"
- Extracts: `["nats", "consumer", "broadway", "pipeline"]`
- Matches: NATS microservice template
- Returns: GenServer + Supervisor + Broadway structure

**No marketing fluff**, just concrete architectural patterns! 🎯
