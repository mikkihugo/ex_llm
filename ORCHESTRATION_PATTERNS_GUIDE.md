# Orchestration Patterns Guide

**Comprehensive reference for Singularity's config-driven orchestration system**

Version: 1.0 | Updated: October 24, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Core Pattern](#core-pattern)
3. [Execution Patterns](#execution-patterns)
4. [All Orchestrators](#all-orchestrators)
5. [How to Add New Implementations](#how-to-add-new-implementations)
6. [Best Practices](#best-practices)
7. [Testing Orchestrators](#testing-orchestrators)
8. [Troubleshooting](#troubleshooting)

---

## Overview

Singularity uses a unified **Behavior + Orchestrator** pattern for all extensible systems. This design enables:

- **Config-driven configuration** - Enable/disable/reorder implementations without code changes
- **Consistent interfaces** - All orchestrators follow the same patterns
- **Automatic discovery** - Orchestrators discover implementations from config
- **Extensibility** - Add new implementations by creating module + updating config
- **Testability** - Behaviors define clear contracts for testing

### The Problem Solved

Before this pattern, Singularity had scattered, hardcoded systems:

```elixir
# ❌ BEFORE: Hardcoded everywhere
case strategy do
  :task_dag -> TaskGraphExecutor.execute(goal)
  :sparc -> SparcOrchestrator.execute(goal)
  :methodology -> MethodologyExecutor.execute(goal)
end

# ❌ Can't add new strategy without changing code
# ❌ Can't disable unused strategies
# ❌ Hard to test different combinations
```

After the pattern:

```elixir
# ✅ AFTER: Config-driven
ExecutionOrchestrator.execute(goal)
# Automatically uses configured strategies in priority order
# Can add, remove, or reorder strategies via config only
```

---

## Core Pattern

### 1. Define Behavior Contract

Create a behavior module defining the interface:

```elixir
# lib/singularity/analysis/analyzer_type.ex
defmodule Singularity.Analysis.AnalyzerType do
  @moduledoc "Behavior contract for code analyzers"

  @callback analyzer_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback analyze(input :: term(), opts :: Keyword.t()) ::
              {:ok, term()} | {:error, term()}

  # Config loading helper
  def load_enabled_analyzers do
    :singularity
    |> Application.get_env(:analyzer_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end
end
```

### 2. Create Orchestrator

The orchestrator discovers and routes to implementations:

```elixir
# lib/singularity/analysis/analysis_orchestrator.ex
defmodule Singularity.Analysis.AnalysisOrchestrator do
  @moduledoc "Routes analysis requests to configured analyzers"

  require Logger
  alias Singularity.Analysis.AnalyzerType

  def analyze(input, opts \\ []) do
    try do
      analyzers = AnalyzerType.load_enabled_analyzers()

      # Parallel execution: run all analyzers, collect results
      results =
        analyzers
        |> Enum.map(fn {type, _priority, config} ->
          Task.async(fn -> run_analyzer(type, config, input, opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      {:ok, results}
    rescue
      e ->
        Logger.error("Analysis failed", error: inspect(e))
        {:error, :analysis_failed}
    end
  end

  defp run_analyzer(type, config, input, opts) do
    module = config[:module]

    case module.analyze(input, opts) do
      {:ok, result} -> {type, result}
      {:error, reason} -> {type, {:error, reason}}
    end
  end
end
```

### 3. Implement Behavior

Create one or more implementations:

```elixir
# lib/singularity/analysis/analyzers/quality_analyzer.ex
defmodule Singularity.Analysis.Analyzers.QualityAnalyzer do
  @behaviour Singularity.Analysis.AnalyzerType

  def analyzer_type, do: :quality
  def description, do: "Analyze code quality issues"
  def capabilities, do: ["complexity", "duplication", "style"]

  def analyze(input, _opts) do
    # Actual analysis logic
    {:ok, %{violations: []}}
  end
end
```

### 4. Add to Config

Register implementations in configuration:

```elixir
# config/config.exs
config :singularity, :analyzer_types,
  quality: %{
    module: Singularity.Analysis.Analyzers.QualityAnalyzer,
    enabled: true,
    priority: 10,
    description: "Analyze code quality issues"
  },
  feedback: %{
    module: Singularity.Analysis.Analyzers.FeedbackAnalyzer,
    enabled: true,
    priority: 20,
    description: "Identify improvement opportunities"
  }
```

### 5. Use the Orchestrator

Applications use the orchestrator, not implementations directly:

```elixir
# Users of the system
{:ok, results} = AnalysisOrchestrator.analyze(code)
# Results = %{
#   quality: %{violations: [...]},
#   feedback: %{improvements: [...]}
# }
```

---

## Execution Patterns

Different orchestrators use different execution patterns:

### Pattern 1: Parallel Execution (Run All At Once)

**Used By**: SearchOrchestrator, AnalysisOrchestrator, ScanOrchestrator, GenerationOrchestrator

**When**: You want results from all implementations, fast

**Implementation**:
```elixir
results =
  searches
  |> Enum.map(fn {type, config} ->
    Task.async(fn -> run_search(type, config, query) end)
  end)
  |> Enum.map(&Task.await/1)
  |> Enum.into(%{})
```

**Semantics**:
- Runs all enabled implementations simultaneously
- Collects results from all
- Returns aggregated map: `{:ok, %{type1 => [results], type2 => [results]}}`
- Fails only if orchestration itself fails (not if individual implementations fail)

**Config Example**:
```elixir
config :singularity, :search_types,
  semantic: %{module: ..., enabled: true, priority: 10},
  hybrid: %{module: ..., enabled: true, priority: 20},
  package: %{module: ..., enabled: true, priority: 30}
```

---

### Pattern 2: Priority-Ordered First-Match (Stop on Success)

**Used By**: TaskAdapterOrchestrator, BuildToolOrchestrator, ExecutionStrategyOrchestrator, FrameworkLearningOrchestrator

**When**: You want the best/fastest implementation, not all of them

**Implementation**:
```elixir
def execute(task) do
  try_strategies(load_enabled_strategies(), task)
end

defp try_strategies([], _task), do: {:error, :no_strategy_found}

defp try_strategies([{type, _priority, config} | rest], task) do
  module = config[:module]

  case module.execute(task) do
    {:ok, result} ->
      Logger.info("Strategy succeeded", strategy: type)
      {:ok, result}

    {:error, _reason} ->
      try_strategies(rest, task)  # Try next
  end
end
```

**Semantics**:
- Tries adapters in priority order (lowest first)
- Stops on first success
- Falls back to next on failure
- Returns result from first successful adapter
- Returns error only if all fail

**Config Example**:
```elixir
config :singularity, :task_adapters,
  oban_adapter: %{module: ..., enabled: true, priority: 10},
  nats_adapter: %{module: ..., enabled: true, priority: 15},
  genserver_adapter: %{module: ..., enabled: true, priority: 20}
# Will try: Oban → NATS → GenServer, stopping on first success
```

---

### Pattern 3: All-Must-Pass (Collect Violations)

**Used By**: ValidationOrchestrator

**When**: You must enforce all quality gates (all must pass)

**Implementation**:
```elixir
def validate(input) do
  violations =
    load_enabled_validators()
    |> Enum.flat_map(fn {type, _priority, config} ->
      module = config[:module]

      case module.validate(input) do
        :ok -> []
        {:error, v} -> v
      end
    end)

  if Enum.empty?(violations) do
    :ok
  else
    {:error, violations}
  end
end
```

**Semantics**:
- Runs all validators
- Collects violations from all
- Returns `:ok` only if all pass
- Returns `{:error, violations}` if any fail
- No short-circuiting (runs all for complete error picture)

**Config Example**:
```elixir
config :singularity, :validators,
  type_checker: %{module: ..., enabled: true, priority: 10},
  security_validator: %{module: ..., enabled: true, priority: 15},
  schema_validator: %{module: ..., enabled: true, priority: 20}
# All three must pass, all violations reported
```

---

## All Orchestrators

### Active Orchestrators (13 total)

| Orchestrator | Behavior | Pattern | Config Key | Purpose |
|--------------|----------|---------|-----------|---------|
| **PatternDetector** | PatternType | Parallel | `:pattern_types` | Detect frameworks, tech, architecture |
| **AnalysisOrchestrator** | AnalyzerType | Parallel | `:analyzer_types` | Analyze code quality, feedback, refactoring |
| **ScanOrchestrator** | ScannerType | Parallel | `:scanner_types` | Scan for quality/security issues |
| **GenerationOrchestrator** | GeneratorType | Parallel | `:generator_types` | Generate code (quality, RAG, templates) |
| **ValidationOrchestrator** | Validator | All-Must-Pass | `:validators` | Enforce type/security/schema validation |
| **SearchOrchestrator** | SearchType | Parallel | `:search_types` | Search code (semantic, hybrid, AST, packages) |
| **JobOrchestrator** | JobType | N/A (Oban) | `:job_types` | Manage background jobs (cron scheduling) |
| **BuildToolOrchestrator** | BuildToolType | First-Match | `:build_tools` | Detect & run build tools (Bazel, NX, Moon) |
| **TaskAdapterOrchestrator** | TaskAdapter | First-Match | `:task_adapters` | Execute tasks (Oban, NATS, GenServer) |
| **ExecutionStrategyOrchestrator** | ExecutionStrategy | First-Match | `:execution_strategies` | Route execution (TaskDAG, SPARC, Methodology) |
| **FrameworkLearningOrchestrator** | FrameworkLearner | First-Match | `:framework_learners` | Learn frameworks (templates, then LLM) |
| **AnalysisOrchestrator** (CentralCloud) | Analyzer | Parallel | `:analyzers` | Multi-system analysis coordination |
| **MetricsOrchestrator** | N/A | N/A | N/A | Collect and aggregate metrics |

### Legacy/Disabled (2 total)

| Orchestrator | Status | Reason |
|--------------|--------|--------|
| **LanguageDetection** | Production | Single Rust NIF (not orchestrated) |
| **Legacy ValidatorType** | Removed | Superseded by unified Validator system |

---

## How to Add New Implementations

### Quick Start: Adding a New Search Type

#### 1. Create the Implementation Module

```elixir
# lib/singularity/search/searchers/custom_search.ex
defmodule Singularity.Search.Searchers.CustomSearch do
  @behaviour Singularity.Search.SearchType

  require Logger

  def search_type, do: :custom

  def description, do: "Custom implementation for special searches"

  def capabilities, do: ["custom", "domain_specific", "fast"]

  def search(query, opts) do
    Logger.info("Custom search", query: query)

    # Your implementation here
    results = search_implementation(query, opts)
    {:ok, results}
  rescue
    e ->
      Logger.error("Custom search failed", error: inspect(e))
      {:error, :search_failed}
  end

  defp search_implementation(query, _opts) do
    # Return list of result maps
    []
  end
end
```

#### 2. Add to Config

```elixir
# config/config.exs
config :singularity, :search_types,
  custom: %{
    module: Singularity.Search.Searchers.CustomSearch,
    enabled: true,
    priority: 25,  # Runs after semantic (10), hybrid (20)
    description: "Custom implementation for special searches"
  }
```

#### 3. Start Using It

```elixir
# SearchOrchestrator automatically discovers and uses it
{:ok, results} = SearchOrchestrator.search("query")
# results.custom will be included automatically
```

#### 4. Write Tests

```elixir
test "custom search finds results" do
  {:ok, results} = SearchOrchestrator.search("test")

  assert Map.has_key?(results, :custom)
  assert is_list(results.custom)
end
```

---

## Best Practices

### 1. Configuration Organization

**DO**:
```elixir
# Clear, grouped config sections
config :singularity, :search_types,
  semantic: %{...},
  hybrid: %{...}

config :singularity, :validators,
  type_checker: %{...},
  security: %{...}
```

**DON'T**:
```elixir
# Scattered config across multiple files
config :singularity, :search_semantic, [...]
config :singularity, :search_hybrid, [...]
```

### 2. Priority Ordering

**DO**:
```elixir
config :singularity, :task_adapters,
  oban: %{priority: 10},      # Try first: reliable, queued
  nats: %{priority: 15},      # Try second: distributed
  genserver: %{priority: 20}  # Try last: local only
```

**DON'T**:
```elixir
# Duplicate priorities make ordering ambiguous
oban: %{priority: 10},
nats: %{priority: 10},  # ← Unclear order!
```

### 3. Implementation Naming

**DO**:
```elixir
defmodule Singularity.Search.Searchers.SemanticSearch do
  def search_type, do: :semantic
end

# Clear: What it is (SemanticSearch) + What it does (Search)
```

**DON'T**:
```elixir
defmodule Singularity.Search.S1 do
  def search_type, do: :type1
end

# Unclear: What is S1? What is type1?
```

### 4. Error Handling

**DO**:
```elixir
def search(query, opts) do
  try do
    results = perform_search(query)
    {:ok, results}
  rescue
    e ->
      Logger.error("Search failed", error: inspect(e))
      {:error, :search_failed}
  end
end
```

**DON'T**:
```elixir
def search(query, opts) do
  # Let crashes propagate
  perform_search(query)
end
```

### 5. Documentation

**DO**:
```elixir
@doc """
Search for code using semantic similarity.

Returns list of results ranked by relevance score.

## Options
- `:limit` - Maximum results to return (default: unlimited)
- `:min_similarity` - Filter by minimum similarity (default: none)

## Returns
`{:ok, [results]}` or `{:error, reason}`
"""
def search(query, opts \\ [])
```

**DON'T**:
```elixir
def search(query, opts) do
  # No documentation what this does or what it returns
end
```

---

## Testing Orchestrators

### Pattern: Integration Testing

Each orchestrator should have comprehensive integration tests:

```elixir
describe "MyOrchestrator" do
  test "discovers all enabled implementations" do
    items = MyOrchestrator.get_implementations_info()
    assert length(items) > 0
  end

  test "executes implementations correctly" do
    {:ok, results} = MyOrchestrator.process(input)
    assert is_map(results)
  end

  test "respects priority ordering" do
    items = MyOrchestrator.get_implementations_info()
    priorities = Enum.map(items, & &1.priority)
    assert priorities == Enum.sort(priorities)
  end

  test "handles implementation failures gracefully" do
    # Even if one implementation fails, orchestrator continues
    result = MyOrchestrator.process(complex_input)
    assert match?({:ok, _} | {:error, _}, result)
  end

  test "configuration matches implementation" do
    config = Application.get_env(:singularity, :my_config, [])
    assert length(config) > 0

    Enum.each(config, fn {name, impl_config} ->
      assert Code.ensure_loaded?(impl_config[:module])
    end)
  end
end
```

### See Also

- `test/singularity/execution/task_adapter_orchestrator_test.exs` - 30 tests
- `test/singularity/validation/validation_orchestrator_test.exs` - 35 tests
- `test/singularity/search/search_orchestrator_test.exs` - 44 tests

---

## Troubleshooting

### Issue: "Implementation not found"

**Problem**: Config references module that doesn't exist

```elixir
config :singularity, :my_types,
  custom: %{module: Nonexistent.Module}  # ← Module doesn't exist
```

**Solution**:
1. Create the module: `lib/singularity/.../custom_implementation.ex`
2. Implement the behavior
3. Update config with correct module path
4. Run `mix compile` to verify

### Issue: "No implementation matched"

**Problem**: All implementations failed or none applicable

**For First-Match orchestrators**:
- Check that at least one implementation has `:enabled: true`
- Verify implementation's `applicable?/1` returns true for your input
- Check logs for why implementations failed

**For Parallel orchestrators**:
- Normal if no implementations match
- Check that implementations are configured and enabled
- Verify they accept your input format

### Issue: "Priority ordering not working"

**Problem**: Orchestrator tries implementations in wrong order

**Check**:
```elixir
# Get actual priority order
iex> MyOrchestrator.get_info_info()
[%{priority: 10, ...}, %{priority: 20, ...}]  # ✅ Correct order

# If wrong, fix config
config :singularity, :my_types,
  impl_a: %{priority: 20},  # ← Runs second
  impl_b: %{priority: 10}   # ← Runs first
```

### Issue: "Config changes not applied"

**Problem**: Changed config but orchestrator still uses old

**Solution**:
1. Stop the app
2. Run `mix compile` (checks for config changes)
3. Restart the app
4. Verify with `MyOrchestrator.get_info_info()`

### Issue: "Test failures due to NATS/Dependencies"

**Problem**: Tests fail because infrastructure not available

**Solution**:
```elixir
# Use --no-start to skip full supervision tree
mix test --no-start

# Or configure test mode to skip NATS
# (already done in Application.ex)
```

---

## Summary

The Orchestrator pattern provides:

✅ **Consistency** - All orchestrators follow same patterns
✅ **Configurability** - Change behavior via config, not code
✅ **Extensibility** - Add implementations without changing orchestrator
✅ **Testability** - Clear contracts for mocking and testing
✅ **Maintainability** - Centralized discovery, clear separation of concerns

### Quick Reference

| Task | Pattern | Example |
|------|---------|---------|
| Add new implementation | Implement behavior + add to config | Add SemanticSearch → register in `:search_types` |
| Enable/disable feature | Toggle `:enabled` in config | Change `semantic: %{enabled: false}` |
| Change order | Update `:priority` in config | Change `semantic: %{priority: 20}` |
| Add new orchestrator | Define behavior + create orchestrator | New `AudioOrchestrator` for audio analyzers |
| Test implementation | Write integration tests | 30-50 tests covering all scenarios |

---

**For questions or updates, see:**
- `CODEBASE_ORCHESTRATION_ASSESSMENT.md` - Detailed system analysis
- `ORCHESTRATOR_QUICK_REFERENCE.md` - Quick lookup tables
- Individual orchestrator modules for specific documentation
