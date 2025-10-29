# Singularity Metrics System

Complete metrics pipeline integrating Rust NIF calculation with PostgreSQL enrichment.

## Overview

The metrics system provides AI-powered code analysis:

```
Code File
    ↓
Rust NIF (Fast Language-Aware Analysis)
    ├─ Type Safety Score (0-100)
    ├─ Dependency Coupling Score (0-100)
    └─ Error Handling Coverage (0-100)
    ↓
PostgreSQL Enrichment (Context & Patterns)
    ├─ Similar code patterns
    ├─ Historical trends
    ├─ Language benchmarks
    └─ Refactoring patterns
    ↓
Elixir Storage & Insights
    ├─ Store in code_metrics table
    ├─ Generate insights
    └─ Track trends over time
```

## Architecture

### Components

**1. Metrics.NIF** - Rust bindings for fast metric calculation
- `type_safety(:rust, code)` - Type annotation coverage and safety
- `dependency_coupling(imports, language)` - Module coupling strength
- `error_handling(:python, code)` - Error path completeness

**2. Metrics.CodeMetrics** - Ecto schema for persistent storage
- Stores all metric results with rich metadata
- Indexes for efficient querying
- Historical tracking

**3. Metrics.Enrichment** - PostgreSQL queries for context
- Pattern matching via pgvector semantic search
- Historical metric trends
- Language benchmarks and comparisons
- Refactoring pattern library

**4. Metrics.Orchestrator** - High-level pipeline orchestration
- End-to-end analysis workflow
- Batch processing
- Report generation
- Insight synthesis

**5. Metrics.Supervisor** - OTP supervision
- Proper initialization and lifecycle

## Usage

### Basic Single File Analysis

```elixir
# Analyze a single file with full enrichment and storage
{:ok, result} = Singularity.Metrics.Orchestrator.analyze_file("lib/my_module.ex")

result = %{
  file_path: "lib/my_module.ex",
  language: :elixir,
  metrics: %{
    type_safety: 85.5,
    coupling: 72.0,
    error_handling: 90.0,
    overall_quality: 82.5
  },
  enrichment: %{
    similar_patterns: [...],  # Patterns from knowledge base
    history: [...],           # Previous analysis results
    benchmarks: {...},        # Language-wide statistics
    relationships: {...}      # Import/dependency graph
  },
  insights: [...]             # Auto-generated recommendations
}
```

### Direct Metric Calculation (No Enrichment)

```elixir
# Just get the metrics, no database operations
{:ok, metrics} = Singularity.Metrics.NIF.analyze_all(:rust, code)

metrics = %{
  type_safety: %{
    score: 85.5,
    annotation_coverage: 90.0,
    generic_usage: 50.0,
    unsafe_ratio: 0.1,
    explicit_type_ratio: 85.0,
    pattern_matching_score: 60.0
  },
  error_handling: %{
    score: 90.0,
    error_type_coverage: 95.0,
    unhandled_paths_ratio: 0.05,
    specific_catches_ratio: 90.0,
    logging_coverage: 85.0,
    fallback_coverage: 90.0
  }
}
```

### Batch Analysis

```elixir
# Analyze multiple files efficiently
file_paths = ["lib/module_a.ex", "lib/module_b.ex", "lib/module_c.ex"]
{ok_count, err_count, results} = Singularity.Metrics.Orchestrator.analyze_batch(file_paths)

# Results include all metrics, enrichment, and insights
```

### Get Language Report

```elixir
# Aggregate statistics for a programming language
{:ok, report} = Singularity.Metrics.Orchestrator.language_report(:rust)

report = %{
  language: :rust,
  file_count: 42,
  avg_quality_score: 76.8,
  type_safety_avg: 81.2,
  coupling_avg: 68.5,
  error_handling_avg: 79.3,
  complexity_avg: 7.2,
  best_files: [...],
  worst_files: [...]
}
```

### Find Refactoring Opportunities

```elixir
# Find files that need refactoring
opportunities = Singularity.Metrics.Orchestrator.find_refactoring_opportunities(:elixir)

opportunities = [
  %{
    file_path: "lib/risky_module.ex",
    language: "elixir",
    overall_quality: 42.0,
    opportunities: [
      %{type: :type_safety, severity: :high, score: 35.0},
      %{type: :high_coupling, severity: :high, score: 82.0}
    ]
  },
  ...
]
```

### Query Enrichment Data

```elixir
# Get similar patterns from knowledge base
patterns = Singularity.Metrics.Enrichment.find_similar_patterns(code, :rust, limit: 10)

# Get historical metrics for a file
history = Singularity.Metrics.Enrichment.get_metric_history("lib/my_module.ex", :elixir)

# Get language benchmarks
benchmarks = Singularity.Metrics.Enrichment.get_language_benchmarks(:elixir)

# Get refactoring patterns that worked well
patterns = Singularity.Metrics.Enrichment.get_refactoring_patterns(:rust)
```

### Query Stored Metrics

```elixir
# Get metrics for a specific file
metrics = Singularity.Metrics.CodeMetrics.get_by_file_path("lib/my_module.ex")

# Get files with low type safety
risky = Singularity.Metrics.CodeMetrics.risky_type_safety(:rust)

# Get high coupling modules
coupled = Singularity.Metrics.CodeMetrics.high_coupling_modules(:elixir)

# Get average metrics for a language
avg = Singularity.Metrics.CodeMetrics.average_by_language("rust")
```

## Metric Definitions

### Type Safety Score (0-100)

Measures type coverage and code type safety:

```
Score = 30% annotation_coverage +
         20% generic_usage +
         25% safety (1 - unsafe_ratio) +
         15% explicit_type_ratio +
         10% pattern_matching_score
```

**Language-Specific:**
- **Rust**: Type annotations, unsafe blocks, generics, pattern matching
- **TypeScript**: Type annotations, generics, type assertions
- **Python**: Type hints, typing.Generic, TypeVar
- **JavaScript**: Type comments, JSDoc
- **Java**: Type declarations, generics

### Dependency Coupling Score (0-100, Higher = Better)

Measures inter-module coupling strength:

```
Score = 100 - (
  30% import_density +
  25% cyclic_dependencies +
  20% max_chain_depth +
  15% layer_violations +
  10% external_ratio
)
```

Lower coupling is better. Score < 50 indicates tight coupling.

### Error Handling Coverage (0-100)

Measures exception path completeness:

```
Score = 30% error_type_coverage +
         25% (1 - unhandled_paths) +
         20% specific_catches +
         15% logging_coverage +
         10% fallback_coverage
```

**Language-Specific:**
- **Rust**: Result/Option, match, error propagation (?)
- **Python**: try/except, error types, finally blocks
- **JavaScript/TypeScript**: try/catch, Promise.catch, async/await
- **Java**: try/catch, checked exceptions, finally

## Schema: code_metrics Table

Stores complete metric analysis results:

```sql
id              UUID PRIMARY KEY
file_path       VARCHAR NOT NULL
language        VARCHAR NOT NULL
project_id      VARCHAR

-- AI Metrics
type_safety_score           FLOAT
type_safety_details         JSONB
coupling_score              FLOAT
coupling_details            JSONB
error_handling_score        FLOAT
error_handling_details      JSONB

-- Traditional Metrics
cyclomatic_complexity       INTEGER
cognitive_complexity        INTEGER
lines_of_code               INTEGER
comment_lines               INTEGER
blank_lines                 INTEGER
maintainability_index       FLOAT

-- Composite
overall_quality_score       FLOAT
overall_quality_factors     JSONB

-- Context
code_hash                   VARCHAR UNIQUE
analysis_timestamp          TIMESTAMPTZ
git_commit                  VARCHAR
branch                      VARCHAR

-- Enrichment
similar_patterns_found      INTEGER
pattern_matches             JSONB
refactoring_opportunities   INTEGER
test_coverage_predicted     FLOAT

-- Status
status                      VARCHAR (analyzed|enriched|anomaly)
error_message               TEXT
processing_time_ms          INTEGER

created_at                  TIMESTAMPTZ
updated_at                  TIMESTAMPTZ
```

## Integration Points

### With Singularity Core

Metrics integrate with:

- **Knowledge Base**: Pattern matching via `Singularity.Knowledge.ArtifactStore`
- **Code Analysis**: Complements existing analysis in `Singularity.CodeAnalysis`
- **LLM Service**: Could feed metrics to `Singularity.LLM.Service` for recommendations

### With External Systems

- **Git**: Track metrics per commit (branch, git_commit fields)
- **CI/CD**: Store metrics on each build
- **Observability**: Export metrics to Prometheus/Grafana via Observer UI

## Example: Complete Workflow

```elixir
# 1. Analyze a file
{:ok, analysis} = Singularity.Metrics.Orchestrator.analyze_file(
  "lib/risky_module.ex",
  enrich: true,
  store: true
)

# 2. Check the insights
Enum.each(analysis.insights, fn insight ->
  IO.puts("#{inspect(insight.type)}: #{insight.message}")
end)

# 3. Get language benchmarks
benchmarks = Singularity.Metrics.Enrichment.get_language_benchmarks(:elixir)

# 4. Contextualize the score
contextualized = Singularity.Metrics.Enrichment.contextualize_score(
  :type_safety,
  analysis.metrics.type_safety,
  :elixir,
  benchmarks
)

IO.puts("Type Safety: #{contextualized.status} (#{contextualized.percentile}th percentile)")

# 5. Find similar patterns to learn from
patterns = Singularity.Metrics.Enrichment.find_similar_patterns(
  code,
  :elixir,
  limit: 5
)

Enum.each(patterns, fn pattern ->
  IO.puts("Pattern: #{pattern.name} (success_rate: #{pattern.success_rate})")
end)
```

## Performance

Metric calculation times (approximate):

- **Type Safety**: 10-50ms (language-dependent)
- **Coupling**: 20-100ms (depends on import count)
- **Error Handling**: 15-60ms
- **Total Rust**: 50-200ms for typical file

Database enrichment adds ~100-500ms depending on pattern database size.

## Future Enhancements

- Trend analysis and anomaly detection
- ML-based quality prediction
- Integration with CI/CD for continuous metrics
- Metric-driven refactoring suggestions
- Cross-language comparison and learning
