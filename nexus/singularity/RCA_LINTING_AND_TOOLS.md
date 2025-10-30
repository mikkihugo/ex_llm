# RCA + Linting Engines & Tools Guide

How to integrate RCA tracking with Singularity's Rust NIF linting engines and other system tools.

## Overview

RCA system tracks not just LLM-based code generation, but also **tool-based workflows** like:

- **Linting Engines** (Credo, Dialyzer, Clippy, ESLint, etc.)
- **Code Analysis Tools** (Parser Engine, Quality Engine)
- **Testing & Validation** (Test execution, coverage)
- **System Operations** (Database migrations, deployments)

## Architecture

```
┌────────────────────────────────────────────────────────┐
│ Any Workflow (LLM-based or Tool-based)                │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│ RcaWorkflow Base Class                                │
│ (Automatic tracking for any workflow)                 │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│ Tool Execution (Linters, Parsers, Analyzers)         │
│ - Rust NIF Engines                                    │
│ - External Tools (clippy, credo, etc.)               │
│ - Internal Services                                   │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│ RCA Session Records                                   │
│ - Tool selection & performance                        │
│ - Execution time & resource usage                     │
│ - Results & metrics                                   │
│ - Success/failure rates                               │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│ System Learning                                       │
│ - Best linting engines for each language              │
│ - Optimal tool combinations                           │
│ - Cost vs quality tradeoffs                           │
│ - Tool performance trends                             │
└────────────────────────────────────────────────────────┘
```

## Example: Linting Workflow with RCA

### Step 1: Create RCA-Enabled Linting Workflow

```elixir
defmodule MyProject.Workflows.LintingWithRca do
  use Singularity.Workflows.RcaWorkflow
  require Logger

  @impl true
  def rca_config do
    %{
      agent_id: "linting-engine",
      template_id: "code-linting"
    }
  end

  def __workflow_steps__ do
    [
      {:select_linters, &select_linters/1},
      {:run_linters, &run_linters/1},
      {:aggregate, &aggregate/1}
    ]
  end

  def execute(input), do: execute_with_rca(input)

  def select_linters(input) do
    # Query RCA to find best linters for this project
    {:ok, Map.put(input, "linters", ["credo", "dialyzer"])}
  end

  def run_linters(%{"linters" => linters} = input) do
    # Run Rust NIF engines with automatic tracking
    results = Enum.map(linters, &run_linter/1)

    {:ok, Map.put(input, "results", results)}
  end

  def aggregate(%{"results" => results} = input) do
    {:ok, Map.put(input, "aggregated", merge_results(results))}
  end

  defp run_linter("credo"), do: Singularity.CodeQualityEngine.analyze_elixir()
  defp run_linter("dialyzer"), do: Singularity.CodeQualityEngine.type_check()
end
```

### Step 2: Query RCA to Understand Linting Performance

```elixir
# Which linters are most effective?
workflows = Singularity.RCA.PgflowIntegration.compare_workflows()
|> Enum.filter(&String.contains?(&1.workflow, "Linting"))

Enum.each(workflows, fn w ->
  IO.inspect(%{
    linter: w.workflow,
    success_rate: w.success_rate,
    avg_time_ms: calculate_time_from_tokens(w.avg_cost_tokens),
    total_runs: w.total_sessions
  })
end)

# Result:
# %{linter: "LintingWithRca[credo]", success_rate: 99.2, avg_time_ms: 1234, ...}
# %{linter: "LintingWithRca[dialyzer]", success_rate: 96.5, avg_time_ms: 5678, ...}
```

### Step 3: Agents Select Best Linting Strategy

```elixir
defmodule LintingAgent do
  alias Singularity.RCA.PgflowIntegration

  def lint_codebase(codebase_id) do
    # Get best linting approach
    workflows = PgflowIntegration.compare_workflows()
    linting_workflows = Enum.filter(workflows, &linting?/1)
    best = hd(linting_workflows)

    Logger.info("Using best linting strategy", %{
      workflow: best.workflow,
      success_rate: best.success_rate
    })

    # Execute with automatic RCA tracking
    Pgflow.Executor.execute(
      String.to_atom(best.workflow),
      %{codebase_id: codebase_id},
      timeout: 60000
    )
  end

  defp linting?(workflow) do
    String.contains?(workflow.workflow, "Linting")
  end
end
```

## Use Cases

### 1. Linting Engine Performance Tracking

Track which linting engines work best:

```elixir
# Which language-specific linters have highest success rate?
Singularity.RCA.SessionQueries.success_rate_by_template()
|> Enum.filter(&language_linter?/1)

# %{
#   "elixir-linting" => %{total: 500, successful: 495, success_rate: 99.0},
#   "rust-linting" => %{total: 300, successful: 285, success_rate: 95.0},
#   "typescript-linting" => %{total: 400, successful: 380, success_rate: 95.0}
# }
```

### 2. Tool Combination Optimization

Find best combination of linting tools:

```elixir
# Analyze which tool combinations work best
step_analysis = Singularity.RCA.PgflowIntegration.analyze_workflow_steps()

step_analysis
|> Enum.filter(&linting_step?/1)
|> Enum.sort_by(&elem(&1, 1).success_rate, :desc)
|> Enum.take(5)

# [
#   {"run_linters[credo+dialyzer]", %{success_rate: 99.2, ...}},
#   {"run_linters[credo]", %{success_rate: 98.5, ...}},
#   {"run_linters[clippy]", %{success_rate: 96.1, ...}}
# ]
```

### 3. Issue Detection & Fix Tracking

Track which issues are hardest to fix:

```elixir
# Which linting issues are most problematic?
Singularity.RCA.FailureAnalysis.difficult_to_fix_failures(min_frequency: 10)

# [
#   %{failure_mode: "complex_function", success_rate: 42.0, frequency: 45},
#   %{failure_mode: "unused_variable", success_rate: 78.5, frequency: 32},
#   %{failure_mode: "type_error", success_rate: 65.3, frequency: 28}
# ]
```

### 4. Cost vs Quality Analysis

Understand cost-quality tradeoffs:

```elixir
# Which linters give best quality at lowest cost?
Singularity.RCA.LearningQueries.pareto_frontier()
|> Enum.filter(&linting_strategy?/1)

# [
#   %{
#     template_id: "credo-only",
#     avg_cost_tokens: 1200,
#     quality_score: 92.0
#   },
#   %{
#     template_id: "credo-dialyzer",
#     avg_cost_tokens: 1800,
#     quality_score: 97.5
#   }
# ]
```

## Real-World Example: Intelligent Linting Agent

```elixir
defmodule IntelligentLintingAgent do
  alias Singularity.RCA.{
    PgflowIntegration,
    FailureAnalysis,
    LearningQueries
  }

  def lint_with_intelligence(codebase_info) do
    # 1. Understand current issues
    difficult_issues = FailureAnalysis.difficult_to_fix_failures(min_frequency: 5)

    Logger.info("Known difficult issues", %{
      count: length(difficult_issues),
      top_issue: hd(difficult_issues).failure_mode
    })

    # 2. Select best linting strategy
    pareto = LearningQueries.pareto_frontier()
    linting_strategies = Enum.filter(pareto, &linting?/1)
    best_strategy = hd(linting_strategies)

    Logger.info("Selected linting strategy", %{
      strategy: best_strategy.template_id,
      quality: best_strategy.quality_score,
      cost: best_strategy.avg_cost_tokens
    })

    # 3. Execute linting with automatic tracking
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: "Lint #{codebase_info.project}",
      agent_id: "intelligent-linting-agent",
      template_id: best_strategy.template_id
    })

    result = Pgflow.Executor.execute(
      get_linting_workflow(best_strategy),
      %{codebase: codebase_info, session_id: session.id},
      timeout: 120000
    )

    # 4. Learn for future linting operations
    case result do
      {:ok, linting_result} ->
        Logger.info("Linting successful", %{
          issues_found: linting_result.issue_count,
          fixable: linting_result.auto_fixable
        })

        # Recommend fixes for hardest issues
        recommendations = generate_fix_recommendations(
          linting_result.issues,
          difficult_issues
        )

        {:ok, %{result: result, recommendations: recommendations}}

      {:error, reason} ->
        Logger.error("Linting failed", %{error: inspect(reason)})
        {:error, reason}
    end
  end

  defp linting?(strategy) do
    String.contains?(strategy.template_id, "linting")
  end

  defp get_linting_workflow(strategy) do
    strategy.template_id
    |> String.capitalize()
    |> then(&"Singularity.Workflows.#{&1}RCA")
    |> String.to_atom()
  end

  defp generate_fix_recommendations(issues, difficult_issues) do
    issues
    |> Enum.filter(&issue_is_difficult?(&1, difficult_issues))
    |> Enum.map(&recommend_fix/1)
  end

  defp issue_is_difficult?(issue, difficult_issues) do
    Enum.any?(difficult_issues, &(&1.failure_mode == issue.type))
  end

  defp recommend_fix(issue) do
    %{issue: issue, recommendation: "Review and fix manually - auto-fix not reliable"}
  end
end
```

## Integration with Linting Engines

### Credo Integration Example

```elixir
defmodule CredoLintingWorkflow do
  use Singularity.Workflows.RcaWorkflow

  @impl true
  def rca_config do
    %{agent_id: "credo-linting-engine"}
  end

  def __workflow_steps__ do
    [{:run_credo, &run_credo/1}]
  end

  def execute(input), do: execute_with_rca(input)

  def run_credo(input) do
    # Execute Credo
    {:ok, issues} = Singularity.CodeQualityEngine.run_credo(
      Map.get(input, :codebase_path)
    )

    {:ok, Map.merge(input, %{
      "issues" => issues,
      "issue_count" => length(issues),
      "tokens_used" => 500,
      "metrics" => %{"issues_found" => length(issues)}
    })}
  end
end
```

### Clippy (Rust) Integration Example

```elixir
defmodule ClippyLintingWorkflow do
  use Singularity.Workflows.RcaWorkflow

  @impl true
  def rca_config do
    %{agent_id: "clippy-linting-engine"}
  end

  def __workflow_steps__ do
    [{:run_clippy, &run_clippy/1}]
  end

  def execute(input), do: execute_with_rca(input)

  def run_clippy(input) do
    # Execute Clippy via Rust NIF
    {:ok, warnings} = Singularity.LintingEngine.run_clippy(
      Map.get(input, :codebase_path)
    )

    {:ok, Map.merge(input, %{
      "warnings" => warnings,
      "warning_count" => length(warnings),
      "tokens_used" => 300,
      "metrics" => %{"warnings_found" => length(warnings)}
    })}
  end
end
```

## Monitoring & Optimization

### Track Linting Tool Performance

```elixir
# Get all linting workflows
linting_workflows = PgflowIntegration.compare_workflows(limit: 50)
  |> Enum.filter(&linting?/1)

# Analyze performance
performance_summary = linting_workflows
  |> Enum.group_by(&language_from_workflow/1)
  |> Enum.map(fn {lang, workflows} ->
    %{
      language: lang,
      best_success_rate: workflows |> Enum.max_by(&.success_rate) |> Map.get(:success_rate),
      avg_cost: workflows |> Enum.map(&.avg_cost_tokens) |> Enum.sum() / length(workflows),
      tool_count: length(workflows)
    }
  end)

Enum.each(performance_summary, &IO.inspect/1)
```

### Find Optimization Opportunities

```elixir
# 1. Slow linting tools
slow_tools = PgflowIntegration.compare_workflows()
  |> Enum.filter(&(&1.avg_cost_tokens > 2000))
  |> Enum.filter(&linting?/1)

IO.puts("Slow linting tools that could be optimized:")
Enum.each(slow_tools, &IO.inspect/1)

# 2. Unreliable tools (low success rate)
unreliable = PgflowIntegration.compare_workflows()
  |> Enum.filter(&(&1.success_rate < 85))
  |> Enum.filter(&linting?/1)

IO.puts("Unreliable linting tools:")
Enum.each(unreliable, &IO.inspect/1)

# 3. Tools that find most issues per cost
efficient = PgflowIntegration.compare_workflows()
  |> Enum.filter(&linting?/1)
  |> Enum.map(&calculate_efficiency/1)
  |> Enum.sort_by(&Map.get(&1, :efficiency), :desc)
  |> Enum.take(5)

IO.puts("Most efficient linting tools:")
Enum.each(efficient, &IO.inspect/1)
```

## Best Practices

1. **Use RcaWorkflow Base Class**
   ```elixir
   use Singularity.Workflows.RcaWorkflow
   ```

2. **Return Metrics from Steps**
   ```elixir
   {:ok, Map.merge(input, %{
     "issues" => issues,
     "tokens_used" => 500,
     "metrics" => %{"issue_count" => length(issues)}
   })}
   ```

3. **Query Learnings Before Tool Selection**
   ```elixir
   best_tools = PgflowIntegration.compare_workflows(limit: 5)
   selected = hd(best_tools)
   ```

4. **Monitor Tool Performance Trends**
   ```elixir
   # Monthly
   performance = PgflowIntegration.compare_workflows()
   # Compare with last month's data
   ```

5. **Optimize High-Usage Tools**
   ```elixir
   # Tools run > 1000 times should be optimized
   high_volume = PgflowIntegration.compare_workflows()
     |> Enum.filter(&(&1.total_sessions > 1000))
   ```

## See Also

- `lib/singularity/workflows/linting_analysis_rca.ex` - Example linting workflow
- `RCA_PGFLOW_OPTIMAL_USAGE.md` - Optimal usage patterns
- `RCA_SYSTEM_GUIDE.md` - Complete system guide
