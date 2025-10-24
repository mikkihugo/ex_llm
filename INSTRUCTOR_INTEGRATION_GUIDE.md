# Instructor Integration Guide

## Overview

Singularity now uses **Instructor** for structured LLM outputs with validation in both Elixir and TypeScript. This enables:

- ✅ Validated tool parameters before NATS send
- ✅ Automatic code quality assessment
- ✅ LLM-driven refinement loops with auto-retry
- ✅ Type-safe schemas across languages
- ✅ Early error feedback to agents

## Architecture

```
┌─────────────────┐
│   Agent Code    │
└────────┬────────┘
         │ Call tool
         ↓
┌─────────────────────────────────────┐
│ Singularity.Tools.InstructorAdapter │
│  (Elixir validation)                │
│  • validate_parameters/2            │
│  • validate_output/3                │
│  • refine_output/3                  │
│  • generate_validated_code/2        │
└────────┬────────────────────────────┘
         │ NATS llm.request
         ↓
┌──────────────────────────────────────┐
│ InstructorAdapter (TypeScript)       │
│  (Second-line validation)            │
│  • validateToolParameters            │
│  • validateCodeQuality               │
│  • createRefinementFeedback          │
└────────┬─────────────────────────────┘
         │ HTTP call
         ↓
┌──────────────────────────────────┐
│  Claude / LLM Provider           │
│  (With Instructor schemas)       │
└──────────────────────────────────┘
```

## Components

### Elixir Side

#### 1. InstructorSchemas (`lib/singularity/tools/instructor_schemas.ex`)

Defines Ecto schemas with Instructor integration:

```elixir
defmodule GeneratedCode do
  use Instructor.Schema

  field :code, :string, llm_doc: "The generated source code"
  field :language, :string
  field :quality_level, :string
  field :has_docs, :boolean
  field :has_tests, :boolean
  field :has_error_handling, :boolean

  def validate_changeset(changeset) do
    changeset
    |> validate_required([:code, :language, :quality_level])
    |> validate_code_length()
    |> validate_production_requirements()
  end
end
```

**Available schemas:**
- `GeneratedCode` - Generated code with quality metadata
- `ToolParameters` - Tool parameter validation
- `CodeQualityResult` - Code quality assessment
- `RefinementFeedback` - Improvement guidance
- `CodeGenerationTask` - Task specification
- `ValidationError` - Validation error details

#### 2. InstructorAdapter (`lib/singularity/tools/instructor_adapter.ex`)

Provides validation functions:

```elixir
# Validate parameters before calling tool
{:ok, validated_params} = InstructorAdapter.validate_parameters(
  "code_generate",
  %{"task" => "write GenServer", "language" => "rust"},
  max_retries: 2
)

# Validate code output
{:ok, quality} = InstructorAdapter.validate_output(
  :code,
  generated_code,
  language: "elixir",
  quality: :production
)

# Refine code based on feedback
{:ok, refined_code} = InstructorAdapter.refine_output(
  :code,
  code,
  quality_result,
  language: "elixir",
  max_iterations: 3
)

# Generate and validate iteratively
{:ok, code, stats} = InstructorAdapter.generate_validated_code(
  "Create GenServer with TTL caching",
  language: "elixir",
  quality: :production,
  quality_threshold: 0.85,
  max_iterations: 3
)
```

### TypeScript Side

#### 1. InstructorAdapter (`llm-server/src/instructor-adapter.ts`)

Zod schemas and validation utilities:

```typescript
// Validate tool parameters
const result = InstructorAdapter.validateToolParameters('code_generate', {
  task: 'write GenServer',
  language: 'elixir',
});

// Assess code quality
const quality = InstructorAdapter.validateCodeQuality(
  generatedCode,
  'elixir',
  'production'
);

// Create refinement feedback
const feedback = InstructorAdapter.createRefinementFeedback(code, quality);

// Validate generation task
const taskResult = InstructorAdapter.validateGenerationTask({
  task_description: 'Generate GenServer',
  language: 'elixir',
  quality_requirement: 'production',
});
```

#### 2. Validation Utilities

```typescript
// Check if code meets production threshold
if (InstructorValidation.isProductionReady(quality)) {
  // Use code
}

// Format for display
const errorMsg = InstructorValidation.formatError(error);
const qualityMsg = InstructorValidation.formatQualityResult(quality);
```

## Integration Patterns

### Pattern 1: Simple Parameter Validation

```elixir
# Before executing tool
case InstructorAdapter.validate_parameters(tool_name, params) do
  {:ok, validated} ->
    execute_tool(tool_name, validated)

  {:error, reason} ->
    {:error, "Parameter validation failed: #{reason}"}
end
```

### Pattern 2: Code Quality Loop

```elixir
# Generate and validate
case InstructorAdapter.generate_validated_code(
  task,
  quality: :production,
  quality_threshold: 0.85,
  max_iterations: 3
) do
  {:ok, code, %{final: true, score: score}} ->
    Logger.info("Code generated with quality #{score}")
    {:ok, code}

  {:ok, code, %{final: false, reason: reason}} ->
    Logger.warning("Code quality insufficient: #{reason}")
    {:error, "Could not meet quality threshold"}

  {:error, reason} ->
    {:error, reason}
end
```

### Pattern 3: Iterative Refinement

```elixir
# Generate code
{:ok, generated} = InstructorAdapter.validate_output(
  :code,
  generated_code,
  language: language,
  quality: quality
)

# If not passing, refine
if not generated.passing do
  {:ok, refined} = InstructorAdapter.refine_output(
    :code,
    generated_code,
    generated,
    language: language,
    max_iterations: 2
  )

  refined
else
  generated_code
end
```

### Pattern 4: TypeScript Validation in NATS Handler

```typescript
// In nats-handler.ts
import { InstructorAdapter } from './instructor-adapter';

// Validate tool parameters
const paramValidation = InstructorAdapter.validateToolParameters(
  toolName,
  request.parameters
);

if (!paramValidation.valid) {
  return sendError('Parameter validation failed', paramValidation.errors);
}

// Validate generated code before returning
const codeQuality = InstructorAdapter.validateCodeQuality(
  response.text,
  response.metadata.language,
  response.metadata.quality
);

if (!InstructorValidation.isProductionReady(codeQuality)) {
  Logger.warn('Code quality below threshold: ' + codeQuality.score);
}
```

## Configuration

### Elixir Dependencies

Added to `mix.exs`:

```elixir
{:instructor, "~> 0.1"}
```

Depends on: `ecto`, `jason`, `jaxon`, `req`

### TypeScript Dependencies

Already included in `llm-server/package.json`:

```json
{
  "zod": "^3.25.76"
}
```

## API Reference

### Elixir

#### `InstructorAdapter.validate_parameters(tool_name, params, opts \\ [])`

**Options:**
- `:max_retries` (integer, default: 2) - Max LLM retry attempts
- `:model` (string, default: "claude-opus") - LLM model to use

**Returns:** `{:ok, validated_params} | {:error, reason}`

#### `InstructorAdapter.validate_output(type, content, opts \\ [])`

**Types:** `:code` (others in future)

**Options:**
- `:language` (string) - Code language
- `:quality` (atom: `:production`, `:prototype`, `:quick`)
- `:max_retries` (integer, default: 3)
- `:model` (string, default: "claude-opus")

**Returns:** `{:ok, result_map} | {:error, reason}`

#### `InstructorAdapter.refine_output(type, content, feedback, opts \\ [])`

**Options:**
- `:language` (string) - Code language
- `:max_iterations` (integer, default: 3)
- `:max_retries` (integer, default: 2)
- `:model` (string, default: "claude-opus")

**Returns:** `{:ok, refined_code} | {:error, reason}`

#### `InstructorAdapter.generate_validated_code(task, opts \\ [])`

**Options:**
- `:language` (string, default: "elixir")
- `:quality` (atom, default: `:production`)
- `:quality_threshold` (float, default: 0.85)
- `:max_iterations` (integer, default: 3)

**Returns:** `{:ok, code, stats} | {:error, reason}`

### TypeScript

#### `InstructorAdapter.validateToolParameters(toolName, parameters)`

**Returns:** `ToolParameters` object

#### `InstructorAdapter.validateCodeQuality(code, language, quality)`

**Quality:** `'production'` | `'prototype'` | `'quick'`

**Returns:** `CodeQualityResult`

#### `InstructorAdapter.createRefinementFeedback(code, qualityResult)`

**Returns:** `RefinementFeedback`

#### `InstructorAdapter.validateGenerationTask(task)`

**Returns:** `{ valid: boolean, errors: string[], task?: CodeGenerationTask }`

#### `InstructorAdapter.validateGeneratedCode(code, metadata)`

**Returns:** `{ valid: boolean, errors: string[], code?: GeneratedCode }`

## Testing

### Elixir Tests

```bash
cd singularity
mix test test/singularity/tools/instructor_adapter_test.exs
```

Note: Tests require mocking `Instructor.chat_completion` via Mox for isolated testing.

### TypeScript Tests

```bash
cd llm-server
bun test src/__tests__/instructor-adapter.test.ts
```

## Error Handling

### Validation Failures

When validation fails, use the errors for feedback:

```elixir
case InstructorAdapter.validate_parameters(tool, params) do
  {:ok, _validated} -> :ok
  {:error, errors} ->
    Logger.error("Validation failed: #{errors}")
    # Provide feedback to agent
    {:error, errors}
end
```

### Quality Not Met

When code doesn't meet quality threshold:

```elixir
{:ok, _code, %{final: false, reason: reason}} ->
  # Log and retry with different parameters
  Logger.warning("Quality not met: #{reason}")
  # Or escalate to human review
```

## Performance Considerations

### Validation Costs

- **Parameter validation:** 1 LLM call (fast, simple schema)
- **Code quality assessment:** 1 LLM call (heuristic + LLM)
- **Refinement loop:** N calls (where N = max_iterations)

### Optimization Tips

1. **Reduce max_retries** for faster feedback loops
2. **Use simpler models** for parameter validation (claude-haiku)
3. **Batch validations** when possible
4. **Cache validation results** for same inputs

### Caching Validation Results

```elixir
# Example: Cache code quality results
def validate_with_cache(code, language, quality) do
  cache_key = {:code_quality, code, language, quality}

  case Cachex.get(:validation_cache, cache_key) do
    {:ok, result} when not is_nil(result) ->
      {:ok, result}

    _ ->
      case InstructorAdapter.validate_output(:code, code, ...) do
        {:ok, result} ->
          Cachex.put(:validation_cache, cache_key, result, ttl: 3600)
          {:ok, result}

        error ->
          error
      end
  end
end
```

## Troubleshooting

### "Instructor.chat_completion not found"

Make sure `instructor` is in `mix.exs` dependencies and compiled:

```bash
cd singularity
mix deps.get
mix deps.compile instructor
```

### Validation Always Failing

Check:
1. LLM credentials are set (ANTHROPIC_API_KEY, etc.)
2. Model name is valid
3. Schemas are properly structured
4. Validation rules aren't too strict

### Performance Issues

- Reduce `max_retries` and `max_iterations`
- Use cheaper models for simple tasks
- Implement caching for repeated validations
- Validate in parallel when possible

## Migration Path

### Existing Code

If you have manual validation loops:

```elixir
# Before
iterate_until_quality(code, language, threshold, max_iter, current_iter, history) do
  {:ok, validation} = code_validate(code)
  if validation.score >= threshold do
    return code
  else
    {:ok, refined} = code_refine(code, validation)
    iterate_until_quality(refined, ...)
  end
end

# After
InstructorAdapter.generate_validated_code(
  task,
  quality_threshold: threshold,
  max_iterations: max_iter,
  language: language
)
```

### Phase In Gradually

1. Start with `validate_parameters` for new tools
2. Add `validate_output` to critical code generation paths
3. Migrate manual refinement loops to `generate_validated_code`

## Next Steps

1. ✅ Add Instructor dependency (Elixir, TypeScript, Rust)
2. ✅ Create schemas and adapters (Elixir, TypeScript, Rust)
3. ✅ Implement validation modules (Rust: prompt_engine, quality_engine)
4. ⏳ Integrate into agent tool pipelines
5. ⏳ Add comprehensive integration tests
6. ⏳ Monitor validation performance
7. ⏳ Optimize based on real-world usage

## Cross-Language Status

| Language | Module | Status | Details |
|----------|--------|--------|---------|
| **Elixir** | `lib/singularity/tools/instructor_adapter.ex` | ✅ Complete | Parameter & code validation |
| **TypeScript** | `llm-server/src/instructor-adapter.ts` | ✅ Complete | LLM output validation with MD_JSON |
| **Rust** | `rust/prompt_engine/src/validation.rs` | ✅ Complete | Prompt optimization validation |
| **Rust** | `rust/quality_engine/src/validation.rs` | ✅ Complete | Quality rule validation |

## References

- **Instructor Docs (Elixir):** https://hexdocs.pm/instructor
- **Instructor Docs (Rust):** https://crates.io/crates/instructor
- **Zod Docs:** https://zod.dev
- **Code Examples:** See `lib/singularity/tools/code_generation.ex` for usage
- **Tests:** See `test/singularity/tools/instructor_adapter_test.exs`
- **Rust Implementation Guide:** See `RUST_INSTRUCTOR_IMPLEMENTATION_GUIDE.md`
- **Rust Integration Analysis:** See `RUST_INSTRUCTOR_INTEGRATION_ANALYSIS.md`
