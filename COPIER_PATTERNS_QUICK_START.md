# Copier Patterns - Quick Start (5 min)

**Status:** ✅ Integrated into QualityCodeGenerator

## What Just Got Added

Template generation tracking is now live in `QualityCodeGenerator`!

Every time you generate code with `output_path`, it gets tracked:
- What template was used
- What version
- What parameters (task, language, quality)
- Success/failure

## Try It Now

### 1. Run Migration

```bash
cd singularity
mix ecto.migrate
```

This creates the `template_generations` table.

### 2. Generate Some Code

```elixir
# In iex -S mix
alias Singularity.QualityCodeGenerator
alias Singularity.Knowledge.TemplateGeneration

# Generate code (with tracking)
{:ok, result} = QualityCodeGenerator.generate(
  task: "Parse JSON API response with validation",
  language: "elixir",
  quality: :production,
  output_path: "lib/my_app/json_parser.ex"
)

# Check the generated code
IO.puts(result.code)
```

### 3. Verify Tracking Worked

```elixir
# Find what template generated this file
{:ok, gen} = TemplateGeneration.find_by_file("lib/my_app/json_parser.ex")

IO.inspect(gen, label: "Generation Record")
# => %TemplateGeneration{
#   template_id: "quality_template:elixir-production",
#   template_version: "1.0.0",
#   file_path: "lib/my_app/json_parser.ex",
#   answers: %{
#     task: "Parse JSON API response with validation",
#     language: "elixir",
#     quality: :production
#   },
#   success: true,
#   generated_at: ~U[2025-01-10 ...]
# }
```

### 4. Analyze Template Performance

```elixir
# Get all generations from elixir-production template
template_id = "quality_template:elixir-production"
generations = TemplateGeneration.list_by_template(template_id)

# Calculate success rate
success_rate = TemplateGeneration.calculate_success_rate(template_id)
IO.puts("Success rate: #{Float.round(success_rate * 100, 1)}%")

# Find recent failures (for improvement)
failures = Enum.filter(generations, &(!&1.success))
IO.inspect(failures, label: "Recent Failures")
```

### 5. Export Answer File

```elixir
# Export answer file (like .copier-answers.yml)
{:ok, yaml} = TemplateGeneration.export_answer_file("lib/my_app/json_parser.ex")
IO.puts(yaml)

# Output:
# _template_id: quality_template:elixir-production
# _template_version: 1.0.0
# _generated_at: 2025-01-10T12:00:00Z
# _success: true
# task: Parse JSON API response with validation
# language: elixir
# quality: production
```

## What You Can Do Now

✅ **Track all code generation**
```elixir
QualityCodeGenerator.generate(
  task: "...",
  output_path: "lib/file.ex"  # Add this!
)
```

✅ **Find what template generated a file**
```elixir
{:ok, gen} = TemplateGeneration.find_by_file("lib/file.ex")
```

✅ **Analyze template performance**
```elixir
success_rate = TemplateGeneration.calculate_success_rate("quality_template:elixir-production")
```

✅ **Debug why code was generated**
```elixir
{:ok, gen} = TemplateGeneration.find_by_file("lib/problematic.ex")
IO.inspect(gen.answers)  # See what parameters were used
```

## Run Tests

```bash
cd singularity
mix test test/singularity/knowledge/template_generation_integration_test.exs
```

## Next Steps (Optional)

Want more? See `COPIER_PATTERNS_INTEGRATION_MAP.md` for:

1. **Add Questions** - Let LLM ask contextual questions before generation
2. **Self-Improvement** - Agent analyzes template stats and improves bad templates
3. **Migrations** - Auto-upgrade old code when templates improve
4. **Bulk Generation** - Generate multiple files at once

## How It Works

**Before (no tracking):**
```
Generate code → {:ok, code}
❌ Lost forever, can't upgrade, can't learn
```

**After (with tracking):**
```
Generate code → {:ok, code}
  ↓
Track: template + version + answers + success
  ↓
Later:
- "What template made lib/file.ex?" → Easy to find
- "Which templates fail?" → Calculate success_rate
- Template v2.0 released → mix template.upgrade (future)
- Self-Improving Agent → Fix bad templates (future)
```

## Tips

**Always provide output_path:**
```elixir
# ✅ Good - tracked
QualityCodeGenerator.generate(
  task: "...",
  output_path: "lib/file.ex"
)

# ❌ Bad - not tracked (can't learn from it)
QualityCodeGenerator.generate(
  task: "..."
)
```

**Use in agents:**
```elixir
# When agent generates code, track it
defp handle_code_generation(task) do
  {:ok, result} = QualityCodeGenerator.generate(
    task: task,
    output_path: infer_file_path(task)
  )

  # Now tracked! Self-Improving Agent can learn from this.
end
```

## Questions?

- **"Do I need to change existing code?"** - No! It tracks automatically when you provide `output_path`
- **"What if I don't provide output_path?"** - Works fine, just doesn't track (won't learn from it)
- **"Can I track failures?"** - Yes! When quality_score < 0.7, it marks as `success: false`
- **"How do I upgrade old code?"** - Coming soon: `mix template.upgrade` (Phase 4)

## Summary

✅ **Installed:** Template tracking via Copier patterns
✅ **Working:** QualityCodeGenerator tracks all generations
✅ **Ready:** `TemplateGeneration` API for stats and debugging
✅ **Next:** Add questions to templates (see integration map)

Your Living Knowledge Base just got smarter! 🧠
