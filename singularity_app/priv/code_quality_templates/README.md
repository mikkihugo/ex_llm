# Code Quality Templates

This directory contains quality templates that define standards for code generation.

## Available Templates

### Elixir
- `elixir_production.json` - Maximum quality (docs, specs, tests, strict)
- `elixir_standard.json` - Good quality (docs, specs, basic tests)
- `elixir_draft.json` - Minimal quality (just working code)

### Rust
- `rust_production.json` - Maximum quality (docs, Result types, tests, clippy)
- `rust_standard.json` - Good quality
- `rust_draft.json` - Minimal quality

### TypeScript
- `typescript_production.json` - Maximum quality (JSDoc, types, tests)
- `typescript_standard.json` - Good quality
- `typescript_draft.json` - Minimal quality

## Template Structure

```json
{
  "name": "Language Quality Level",
  "language": "elixir",
  "quality_level": "production",
  "description": "...",

  "requirements": {
    "documentation": { ... },
    "type_specs": { ... },
    "error_handling": { ... },
    "testing": { ... },
    "code_style": { ... },
    "code_smells": { ... }
  },

  "prompts": {
    "code_generation": "...",
    "documentation": "...",
    "type_specs": "...",
    "tests": "..."
  },

  "examples": {
    "good_code": "...",
    "bad_code": "..."
  },

  "quality_checklist": [ ... ],

  "scoring_weights": { ... }
}
```

## Usage

Templates are automatically loaded by `QualityCodeGenerator`:

```elixir
# Uses elixir_production.json template
{:ok, result} = QualityCodeGenerator.generate(
  task: "Parse JSON",
  language: "elixir",
  quality: :production
)
```

## Customization

1. **Edit existing templates** - Modify JSON files directly
2. **Add new templates** - Create new JSON files following the structure
3. **Custom prompts** - Edit the `prompts` section for your style
4. **Adjust weights** - Change `scoring_weights` to prioritize different quality aspects

## Template Fields

### `requirements`
Defines what the code must include (docs, specs, tests, etc.)

### `prompts`
LLM prompts used for generation. Available variables:
- `{task}` - The user's task description
- `{code}` - Existing code to enhance

### `examples`
Good and bad code examples to guide generation

### `quality_checklist`
Human-readable checklist for manual review

### `scoring_weights`
Weights for automated quality scoring (0.0-1.0)

## Adding a New Language

Create a new template file, e.g., `python_production.json`:

```json
{
  "name": "Python Production Quality",
  "language": "python",
  "quality_level": "production",
  "requirements": {
    "documentation": {
      "docstrings": {
        "required": true,
        "format": "Google style"
      }
    },
    "type_hints": {
      "required": true
    },
    "testing": {
      "framework": "pytest",
      "coverage_target": 90
    }
  },
  "prompts": {
    "code_generation": "Generate production-quality Python code..."
  }
}
```

Then use it:

```elixir
QualityCodeGenerator.generate(
  task: "Parse JSON",
  language: "python",
  quality: :production
)
```
