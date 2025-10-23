# Quick Start: Multi-Language Code Analyzer

**5-minute guide to get started with CodeAnalyzer**

---

## Installation ✅

Already installed! CodeAnalyzer is integrated into Singularity and starts automatically with the application.

```bash
cd singularity
mix compile  # Compiles Rust NIFs automatically
```

---

## Verify Installation

```bash
# Show supported languages (should list 20)
mix analyze.languages

# Run production verification
mix run scripts/verify_code_analyzer.exs
```

Expected output:
```
✅ All 20 languages supported
✅ RCA metrics available for 9 languages
✅ Cache operational
✅ All verifications passed!
```

---

## Basic Usage

### 1. Analyze Code (IEx)

```elixir
# Start IEx
iex -S mix

# Analyze Elixir code
code = """
defmodule Hello do
  def world, do: :ok
end
"""

{:ok, analysis} = Singularity.CodeAnalyzer.analyze_language(code, "elixir")

IO.inspect(analysis.language_id)       # "elixir"
IO.inspect(analysis.complexity_score)  # 0.72
IO.inspect(analysis.quality_score)     # 0.85
```

### 2. Extract Functions

```elixir
{:ok, functions} = Singularity.CodeAnalyzer.extract_functions(code, "elixir")

Enum.each(functions, fn func ->
  IO.puts("Function: #{func.name} at line #{func.line_start}")
end)
```

### 3. Get RCA Metrics (Rust, Python, etc.)

```elixir
rust_code = """
fn fibonacci(n: u32) -> u32 {
    match n {
        0 => 0,
        1 => 1,
        _ => fibonacci(n - 1) + fibonacci(n - 2)
    }
}
"""

{:ok, metrics} = Singularity.CodeAnalyzer.get_rca_metrics(rust_code, "rust")

IO.inspect(metrics.cyclomatic_complexity)  # "4"
IO.inspect(metrics.maintainability_index)  # "65"
```

---

## From Database

### Analyze Single File

```elixir
# Get file ID from database
file_id = 1

{:ok, result} = Singularity.CodeAnalyzer.analyze_from_database(file_id)

IO.inspect(result.code_file.file_path)
IO.inspect(result.analysis.complexity_score)
```

### Batch Analyze Codebase

```elixir
results = Singularity.CodeAnalyzer.analyze_codebase_from_db("my-project")

# Count successes
successes = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
IO.puts("Analyzed #{successes}/#{length(results)} files successfully")
```

---

## Mix Tasks

### Analyze Entire Codebase

```bash
# Basic analysis
mix analyze.codebase --codebase-id my-project

# With RCA metrics
mix analyze.codebase --codebase-id my-project --rca

# Store results
mix analyze.codebase --codebase-id my-project --rca --store
```

### Check Supported Languages

```bash
# Simple list
mix analyze.languages

# Detailed capabilities
mix analyze.languages --detailed

# Only RCA-supported
mix analyze.languages --rca-only
```

### Cache Management

```bash
# Check cache performance
mix analyze.cache stats

# Clear cache
mix analyze.cache clear
```

---

## Language Support Quick Reference

### Full RCA Metrics (9 languages)
✅ Rust, C, C++, C#, JavaScript, TypeScript, Python, Java, Go

Provides: Cyclomatic Complexity, Halstead metrics, Maintainability Index, SLOC

### AST Analysis Only (11 languages)
✅ Elixir, Erlang, Gleam, Lua, Bash, JSON, YAML, TOML, Markdown, Dockerfile, SQL

Provides: Function/class extraction, imports/exports

---

## Performance Tips

### 1. Use Caching

```elixir
# Caching enabled by default
{:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")

# Disable if needed
{:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir", cache: false)
```

### 2. Check Cache Stats

```bash
mix analyze.cache stats
```

Expected for good performance:
- Hit rate: >70%
- Size: <80% of max_size

### 3. Batch Operations

```elixir
# Instead of this:
files |> Enum.map(fn file -> analyze(file) end)

# Use this:
CodeAnalyzer.analyze_codebase_from_db(codebase_id)
```

---

## Common Patterns

### Pattern 1: Quality Check

```elixir
def check_code_quality(code, language) do
  case CodeAnalyzer.analyze_language(code, language) do
    {:ok, analysis} ->
      if analysis.quality_score > 0.7 do
        {:ok, "Code quality acceptable"}
      else
        {:warning, "Code quality below threshold", analysis}
      end

    {:error, reason} ->
      {:error, "Analysis failed", reason}
  end
end
```

### Pattern 2: RCA Metrics Report

```elixir
def generate_rca_report(codebase_id) do
  CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)
  |> Enum.map(fn {path, {:ok, metrics}} ->
    %{
      file: path,
      complexity: metrics.cyclomatic_complexity,
      maintainability: metrics.maintainability_index,
      sloc: metrics.source_lines_of_code
    }
  end)
  |> Enum.sort_by(& &1.complexity, :desc)
end
```

### Pattern 3: Cross-Language Analysis

```elixir
def find_similar_patterns(codebase_id) do
  import Ecto.Query
  alias Singularity.{Repo, Schemas.CodeFile}

  # Get files in different languages
  files = Repo.all(
    from c in CodeFile,
    where: c.codebase_id == ^codebase_id,
    select: {c.language, c.content}
  )

  CodeAnalyzer.detect_cross_language_patterns(files)
end
```

---

## Troubleshooting

### Problem: "nif_not_loaded" error

```bash
# Solution: Recompile
mix clean
mix compile
```

### Problem: Cache always misses

```elixir
# Check if cache is running
Process.whereis(Singularity.CodeAnalyzer.Cache)
# Should return #PID<...>, not nil
```

### Problem: Database returns no files

```bash
# Solution: Ingest code first
mix parser.ingest --path /path/to/code
```

---

## Next Steps

1. **Read full docs:** `MULTI_LANGUAGE_ANALYZER_COMPLETE.md`
2. **Run tests:** `mix test test/singularity/code_analyzer*`
3. **Check examples:** `test/singularity/code_analyzer_test.exs`
4. **Verify installation:** `mix run scripts/verify_code_analyzer.exs`

---

## Key Functions Reference

```elixir
# Language support
CodeAnalyzer.supported_languages()          # All 20 languages
CodeAnalyzer.rca_supported_languages()      # 9 RCA languages
CodeAnalyzer.has_rca_support?("rust")       # true/false

# Analysis
CodeAnalyzer.analyze_language(code, "elixir")
CodeAnalyzer.check_language_rules(code, "python")
CodeAnalyzer.get_rca_metrics(code, "rust")

# AST extraction
CodeAnalyzer.extract_functions(code, "python")
CodeAnalyzer.extract_classes(code, "java")
CodeAnalyzer.extract_imports_exports(code, "typescript")

# Cross-language
CodeAnalyzer.detect_cross_language_patterns([{"elixir", code1}, {"rust", code2}])

# Database
CodeAnalyzer.analyze_from_database(file_id)
CodeAnalyzer.analyze_codebase_from_db(codebase_id)
CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)
```

---

## Support

**Documentation:**
- Full guide: `MULTI_LANGUAGE_ANALYZER_COMPLETE.md`
- Summary: `COMPLETE_INTEGRATION_SUMMARY.md`
- This guide: `QUICK_START_CODE_ANALYZER.md`

**Verification:**
```bash
mix run scripts/verify_code_analyzer.exs
```

**Tests:**
```bash
mix test test/singularity/code_analyzer*
```

---

**You're ready to analyze code in 20 languages! 🚀**
