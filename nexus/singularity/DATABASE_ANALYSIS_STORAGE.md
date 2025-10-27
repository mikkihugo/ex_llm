# Code Analysis Result Storage

**Database integration for persistent code analysis tracking**

---

## Overview

The `code_analysis_results` table stores comprehensive analysis results from CodeAnalyzer, enabling:

- **Historical tracking** - Track quality changes over time
- **Trend analysis** - Identify improving/declining code quality
- **Regression detection** - Alert when quality drops
- **Performance monitoring** - Track analysis duration and cache effectiveness
- **Error tracking** - Store and analyze analysis failures

---

## Database Schema

### Table: `code_analysis_results`

**Primary Key:** `id` (UUID)
**Foreign Key:** `code_file_id` → `code_files(id)` (CASCADE DELETE)

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `code_file_id` | UUID | Reference to analyzed file |
| `language_id` | STRING | Language identifier (elixir, rust, etc.) |
| `analyzer_version` | STRING | Analyzer version (default: "1.0.0") |
| `analysis_type` | STRING | "full", "rca_only", or "ast_only" |
| `inserted_at` | TIMESTAMP | When analysis was performed |

### Quality Metrics

| Field | Type | Description |
|-------|------|-------------|
| `quality_score` | FLOAT | Overall quality score (0.0-1.0) |
| `complexity_score` | FLOAT | Complexity score (0.0-1.0) |
| `maintainability_score` | FLOAT | Maintainability score (0.0-1.0) |

### RCA Metrics (9 Languages: Rust, C, C++, C#, JS, TS, Python, Java, Go)

| Field | Type | Description |
|-------|------|-------------|
| `cyclomatic_complexity` | INT | Number of decision paths |
| `cognitive_complexity` | INT | How hard code is to understand |
| `maintainability_index` | INT | Maintainability score (0-100) |
| `source_lines_of_code` | INT | Non-blank, non-comment lines |
| `physical_lines_of_code` | INT | Total lines including blanks |
| `logical_lines_of_code` | INT | Executable statements |
| `comment_lines_of_code` | INT | Comment lines |

### Halstead Metrics

| Field | Type | Description |
|-------|------|-------------|
| `halstead_difficulty` | FLOAT | How difficult code is to write/understand |
| `halstead_volume` | FLOAT | Program volume (bits) |
| `halstead_effort` | FLOAT | Mental effort to understand |
| `halstead_bugs` | FLOAT | Predicted number of bugs |

### AST Metrics (All 20 Languages)

| Field | Type | Description |
|-------|------|-------------|
| `functions_count` | INT | Number of functions extracted |
| `classes_count` | INT | Number of classes extracted |
| `imports_count` | INT | Number of imports |
| `exports_count` | INT | Number of exports |

### Full Analysis Data (JSONB)

| Field | Type | Description |
|-------|------|-------------|
| `analysis_data` | JSONB | Complete analysis result |
| `functions` | JSONB | Array of function definitions |
| `classes` | JSONB | Array of class definitions |
| `imports_exports` | JSONB | Import/export statements |
| `rule_violations` | JSONB | Language rule violations |
| `patterns_detected` | JSONB | Cross-language patterns |

### Error Tracking

| Field | Type | Description |
|-------|------|-------------|
| `has_errors` | BOOLEAN | Did analysis fail? |
| `error_message` | TEXT | Error message if failed |
| `error_details` | JSONB | Detailed error information |

### Performance Tracking

| Field | Type | Description |
|-------|------|-------------|
| `analysis_duration_ms` | INT | How long analysis took (ms) |
| `cache_hit` | BOOLEAN | Was result from cache? |

---

## Indexes

Optimized for common query patterns:

- **Primary lookup**: `code_file_id` (find all analyses for a file)
- **Trending**: `(code_file_id, inserted_at)` (historical analysis)
- **Quality filtering**: `quality_score`, `complexity_score`
- **Language queries**: `language_id`
- **Type filtering**: `analysis_type`
- **Time-based**: `inserted_at`
- **JSONB queries**: GIN indexes on `analysis_data`, `rule_violations`, `patterns_detected`

---

## Usage Examples

### 1. Analyze and Store Result

```elixir
# Basic usage
{:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")
{:ok, stored} = CodeAnalyzer.store_result(file_id, analysis, duration_ms: 125)

# Analyze from database and store
{:ok, result} = CodeAnalyzer.analyze_and_store(file_id)
IO.inspect(result.analysis.quality_score)
IO.inspect(result.stored.id)

# Batch analyze entire codebase
results = CodeAnalyzer.analyze_and_store_codebase("my-project")
success_count = Enum.count(results, fn {_, res} -> match?({:ok, _}, res) end)
IO.puts("Analyzed and stored #{success_count}/#{length(results)} files")
```

### 2. Query Recent Results

```bash
# Show recent analysis results
mix analyze.results --codebase-id my-project

# Show results for specific file
mix analyze.results --file-path lib/my_module.ex

# Filter by quality score
mix analyze.results --codebase-id my-project --min-quality 0.8
```

### 3. Quality Trend Analysis

```bash
# Show quality trend over time for a file
mix analyze.results --file-path lib/my_module.ex --trend
```

**Output:**
```
================================================================================
Quality Trend for: lib/my_module.ex
================================================================================

Date                      Quality     Complexity  Maintainability
--------------------------------------------------------------------------------
2025-10-20 10:15:00      0.85        0.45        0.90
2025-10-21 14:30:00      0.82        0.48        0.88
2025-10-22 09:45:00      0.80        0.52        0.85
2025-10-23 16:00:00      0.78        0.55        0.83

📉 Declining (-0.07)
```

### 4. Find Degraded Files

```bash
# Find files with declining quality
mix analyze.results --codebase-id my-project --degraded
```

**Output:**
```
================================================================================
📉 Files with Declining Quality
================================================================================

File                                          First     Last      Change
--------------------------------------------------------------------------------
lib/my_complex_module.ex                     0.90      0.72      -0.18
lib/another_module.ex                        0.85      0.75      -0.10
lib/utils.ex                                 0.88      0.80      -0.08

Showing 3 files with declining quality
```

### 5. Detailed Metrics

```bash
# Show detailed metrics for specific file
mix analyze.results --file-path lib/my_module.ex --detailed
```

**Output:**
```
================================================================================
Detailed Analysis for: lib/my_module.ex
================================================================================

Language: elixir
Analysis Type: full
Analyzed: 2025-10-23 16:00:00
Duration: 125ms
Cache Hit: false

✅ Status: SUCCESS

Quality Metrics:
  Quality Score:        0.85
  Complexity Score:     0.45
  Maintainability:      0.90

AST Metrics:
  Functions:  12
  Classes:    2
  Imports:    5
  Exports:    8
```

### 6. Export Results

```bash
# Export to JSON for external analysis
mix analyze.results --codebase-id my-project --export results.json --limit 1000
```

---

## Querying in Code

### Find All Analyses for a File

```elixir
import Ecto.Query
alias Singularity.{Repo, Schemas.CodeAnalysisResult, Schemas.CodeFile}

# Get all analyses for a file
file_id = "some-uuid"
results = Repo.all(
  from r in CodeAnalysisResult,
  where: r.code_file_id == ^file_id,
  order_by: [desc: r.inserted_at]
)
```

### Quality Trend Query

```elixir
# Get quality trend for file
file_path = "lib/my_module.ex"
trend = Repo.all(
  from r in CodeAnalysisResult,
  join: f in CodeFile, on: r.code_file_id == f.id,
  where: f.file_path == ^file_path,
  order_by: [asc: r.inserted_at],
  select: {r.inserted_at, r.quality_score}
)
```

### Find Low-Quality Files

```elixir
# Find files with quality score < 0.7 in latest analysis
low_quality = Repo.all(
  from r in CodeAnalysisResult,
  join: f in CodeFile, on: r.code_file_id == f.id,
  where: f.codebase_id == ^codebase_id and r.quality_score < 0.7,
  distinct: r.code_file_id,
  order_by: [desc: r.inserted_at],
  select: {f.file_path, r.quality_score}
)
```

### Find Files with Declining Quality

```elixir
# Complex query: files where latest quality < initial quality
query = from r in CodeAnalysisResult,
  join: f in CodeFile, on: r.code_file_id == f.id,
  where: f.codebase_id == ^codebase_id,
  group_by: f.id,
  having: fragment(
    "(SELECT quality_score FROM code_analysis_results WHERE code_file_id = ? ORDER BY inserted_at DESC LIMIT 1) < " <>
    "(SELECT quality_score FROM code_analysis_results WHERE code_file_id = ? ORDER BY inserted_at ASC LIMIT 1)",
    f.id, f.id
  ),
  select: %{
    file_path: f.file_path,
    first_quality: fragment("(SELECT quality_score FROM code_analysis_results WHERE code_file_id = ? ORDER BY inserted_at ASC LIMIT 1)", f.id),
    latest_quality: fragment("(SELECT quality_score FROM code_analysis_results WHERE code_file_id = ? ORDER BY inserted_at DESC LIMIT 1)", f.id)
  }

degraded_files = Repo.all(query)
```

### JSONB Queries

```elixir
# Find files with specific rule violations
files_with_violations = Repo.all(
  from r in CodeAnalysisResult,
  join: f in CodeFile, on: r.code_file_id == f.id,
  where: fragment("? @> ?", r.rule_violations, ^[%{rule: "max_line_length"}]),
  select: {f.file_path, r.rule_violations}
)

# Find files with high cyclomatic complexity in RCA data
complex_files = Repo.all(
  from r in CodeAnalysisResult,
  join: f in CodeFile, on: r.code_file_id == f.id,
  where: r.cyclomatic_complexity > 10,
  order_by: [desc: r.cyclomatic_complexity],
  select: {f.file_path, r.cyclomatic_complexity}
)
```

---

## Performance Considerations

### Cache Usage

Analysis results are automatically cached for performance. The `cache_hit` field tracks this:

```elixir
# Check cache effectiveness
cache_stats = Repo.one(
  from r in CodeAnalysisResult,
  where: r.inserted_at > ago(1, "day"),
  select: %{
    total: count(r.id),
    cache_hits: count(r.id, :distinct) |> filter(r.cache_hit == true),
    cache_misses: count(r.id, :distinct) |> filter(r.cache_hit == false)
  }
)

hit_rate = cache_stats.cache_hits / cache_stats.total * 100
IO.puts("Cache hit rate: #{Float.round(hit_rate, 2)}%")
```

### Index Usage

The table includes optimized indexes for common queries:

1. **Trending queries** use `(code_file_id, inserted_at)` composite index
2. **Quality filtering** uses `quality_score` and `complexity_score` indexes
3. **Language queries** use `language_id` index
4. **JSONB searches** use GIN indexes (fast containment queries)

### Storage Optimization

For very large codebases (>10k files), consider:

1. **Pruning old results** - Keep only last N analyses per file
2. **Archiving** - Move old results to separate archive table
3. **Selective storage** - Only store full analysis for critical files

```elixir
# Prune old results, keep only last 10 per file
defp prune_old_results(file_id, keep_count \\ 10) do
  ids_to_keep = Repo.all(
    from r in CodeAnalysisResult,
    where: r.code_file_id == ^file_id,
    order_by: [desc: r.inserted_at],
    limit: ^keep_count,
    select: r.id
  )

  Repo.delete_all(
    from r in CodeAnalysisResult,
    where: r.code_file_id == ^file_id and r.id not in ^ids_to_keep
  )
end
```

---

## Files Created

### Migration
- `priv/repo/migrations/20251023160338_create_code_analysis_results.exs`

### Schema
- `lib/singularity/schemas/code_analysis_result.ex`

### Updated Module
- `lib/singularity/code_analyzer.ex` (added storage functions)

### Mix Task
- `lib/mix/tasks/analyze.results.ex`

---

## API Reference

### CodeAnalyzer Functions

```elixir
# Store analysis result
CodeAnalyzer.store_result(file_id, analysis_result, opts \\ [])

# Store error result
CodeAnalyzer.store_error(file_id, language_id, error, opts \\ [])

# Analyze and store
CodeAnalyzer.analyze_and_store(file_id, opts \\ [])

# Batch analyze and store entire codebase
CodeAnalyzer.analyze_and_store_codebase(codebase_id, opts \\ [])
```

### Mix Tasks

```bash
# Show recent results
mix analyze.results --codebase-id ID [--limit N] [--min-quality N] [--max-quality N]

# Show file results
mix analyze.results --file-path PATH [--limit N]

# Show quality trend
mix analyze.results --file-path PATH --trend

# Find degraded files
mix analyze.results --codebase-id ID --degraded [--limit N]

# Show detailed metrics
mix analyze.results --file-path PATH --detailed

# Export to JSON
mix analyze.results --codebase-id ID --export FILE [--limit N]
```

---

## Benefits

1. **Historical Tracking** - See how code quality evolves over time
2. **Regression Detection** - Alert when quality drops below threshold
3. **Team Metrics** - Track overall codebase health
4. **Performance Insights** - Understand analysis performance and cache effectiveness
5. **Error Analysis** - Identify patterns in analysis failures
6. **Compliance Reporting** - Generate quality reports for audits

---

## Next Steps

1. **Run first analysis:**
   ```bash
   # Analyze a file and store result
   iex> {:ok, result} = Singularity.CodeAnalyzer.analyze_and_store(file_id)
   ```

2. **Analyze codebase:**
   ```bash
   mix analyze.codebase --codebase-id my-project --store
   ```

3. **Check results:**
   ```bash
   mix analyze.results --codebase-id my-project
   ```

4. **Monitor trends:**
   ```bash
   mix analyze.results --file-path lib/important_module.ex --trend
   ```

---

**Ready to track code quality over time! 🎯**
