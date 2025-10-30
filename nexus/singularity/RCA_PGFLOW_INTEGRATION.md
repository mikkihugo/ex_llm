# RCA + PgFlow Integration Guide

Complete guide to integrating Singularity's **QuantumFlow workflow orchestration** with the **RCA (Root Cause Analysis) system** for comprehensive workflow execution tracking and learning.

## Overview

QuantumFlow workflows (CodeQualityImprovement, AgentImprovement, etc.) can now be tracked as part of RCA sessions, enabling the system to learn which workflows are most effective and how to optimize them.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Agent / Task                                        │
│ (Needs code improvement or analysis)               │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ GenerationSession started                          │
│ (RCA.SessionManager.start_session/1)              │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ PgFlow Workflow begins                             │
│ (CodeQualityImprovement, Architecture, etc.)      │
│ track_workflow_start/2                             │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Workflow executes steps                            │
│ Each step tracked as RefinementStep               │
│ record_workflow_step/4 called for each            │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Workflow completes                                 │
│ record_workflow_completion/3 finalizes session    │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ RCA Session complete                               │
│ Ready for analysis and learning                    │
└─────────────────────────────────────────────────────┘
```

## Core API

The RCA + QuantumFlow integration provides these key functions:

### Session Lifecycle

```elixir
alias Singularity.RCA.{SessionManager, QuantumFlowIntegration}

# 1. Start RCA session (before workflow)
{:ok, session} = SessionManager.start_session(%{
  initial_prompt: "Improve code quality across codebase",
  agent_id: "quality-improvement-agent"
})

# 2. Track workflow start
{:ok, session} = QuantumFlowIntegration.track_workflow_start(
  session.id,
  "Singularity.Workflows.CodeQualityImprovement"
)

# 3. For each workflow step
{:ok, step1} = QuantumFlowIntegration.record_workflow_step(
  session.id,
  1,
  "analyze_metrics",
  "Analyzed complexity, coupling, duplication",
  tokens_used: 450
)

{:ok, step2} = QuantumFlowIntegration.record_workflow_step(
  session.id,
  2,
  "generate_fixes",
  "Generated fixes for 23 issues",
  tokens_used: 1200,
  metrics: %{"issues_fixed" => 23}
)

{:ok, step3} = QuantumFlowIntegration.record_workflow_step(
  session.id,
  3,
  "validate",
  "All tests passing, coverage improved",
  tokens_used: 300,
  result: "success"
)

# 4. Complete session with results
{:ok, final_session} = QuantumFlowIntegration.record_workflow_completion(
  session.id,
  "success",
  %{
    "improvements" => 23,
    "complexity_reduction" => 12.5,
    "coverage_improvement" => 8.2
  }
)
```

## Integration Patterns

### Pattern 1: Inline Workflow Tracking

For workflows that execute synchronously, track steps inline:

```elixir
def run_code_quality_workflow(codebase_id) do
  # Start RCA session
  {:ok, session} = SessionManager.start_session(%{
    initial_prompt: "Improve code quality",
    agent_id: "quality-agent"
  })

  session_id = session.id

  try do
    # Track workflow start
    QuantumFlowIntegration.track_workflow_start(
      session_id,
      "Singularity.Workflows.CodeQualityImprovement"
    )

    # Step 1: Analyze
    {:ok, metrics} = analyze_code_quality(codebase_id)
    QuantumFlowIntegration.record_workflow_step(
      session_id,
      1,
      "analyze_metrics",
      "Analyzed #{map_size(metrics)} metrics"
    )

    # Step 2: Generate Fixes
    {:ok, fixes} = generate_quality_fixes(codebase_id, metrics)
    QuantumFlowIntegration.record_workflow_step(
      session_id,
      2,
      "generate_fixes",
      "Generated #{length(fixes)} fixes",
      tokens_used: 1500,
      metrics: %{"fixes_generated" => length(fixes)}
    )

    # Step 3: Apply and Validate
    {:ok, results} = apply_and_validate_fixes(fixes)
    QuantumFlowIntegration.record_workflow_step(
      session_id,
      3,
      "validate",
      "Applied #{results.applied} fixes, #{results.passed} passed validation",
      tokens_used: 800
    )

    # Complete session
    QuantumFlowIntegration.record_workflow_completion(session_id, "success", %{
      "improvements" => results.improvements,
      "tests_passing" => results.passed
    })

    {:ok, results}

  rescue
    error ->
      # Record failure
      QuantumFlowIntegration.record_workflow_completion(session_id, "failure_execution", %{
        "error" => inspect(error)
      })

      {:error, error}
  end
end
```

### Pattern 2: Async Workflow with Callback Tracking

For asynchronous QuantumFlow workflows, track completion via callback:

```elixir
def run_async_workflow(session_id, workflow_name) do
  # QuantumFlow workflow executes
  {:ok, workflow_ref} = QuantumFlow.Executor.execute(
    workflow_module(workflow_name),
    %{session_id: session_id},
    timeout: 60000
  )

  # Handle completion
  case wait_for_workflow(workflow_ref) do
    {:ok, result} ->
      # Track each step from workflow result
      Enum.each(result.steps, fn {step_num, step_name, metrics} ->
        QuantumFlowIntegration.record_workflow_step(
          session_id,
          step_num,
          step_name,
          Map.get(metrics, "description", ""),
          tokens_used: Map.get(metrics, "tokens", 0),
          metrics: metrics
        )
      end)

      # Complete session
      QuantumFlowIntegration.record_workflow_completion(
        session_id,
        "success",
        result.metrics
      )

      {:ok, result}

    {:error, reason} ->
      QuantumFlowIntegration.record_workflow_completion(
        session_id,
        "failure_execution",
        %{"error" => inspect(reason)}
      )

      {:error, reason}
  end
end
```

### Pattern 3: Nested Workflows (Workflow within Workflow)

For complex workflows that call other workflows:

```elixir
def run_complex_improvement_workflow(codebase_id) do
  {:ok, main_session} = SessionManager.start_session(%{
    initial_prompt: "Comprehensive code improvement",
    agent_id: "improvement-orchestrator"
  })

  QuantumFlowIntegration.track_workflow_start(
    main_session.id,
    "Singularity.Workflows.ComprehensiveImprovement"
  )

  # Step 1: Quality Improvement (sub-workflow)
  QuantumFlowIntegration.record_workflow_step(main_session.id, 1, "quality_improvement", "Running...")

  {:ok, quality_session} = SessionManager.start_session(%{
    initial_prompt: "Improve code quality",
    agent_id: "quality-agent",
    parent_session_id: main_session.id  # Link to parent
  })

  run_code_quality_workflow_tracked(quality_session.id, codebase_id)

  QuantumFlowIntegration.record_workflow_step(
    main_session.id,
    1,
    "quality_improvement",
    "Completed",
    result: "success"
  )

  # Step 2: Architecture Improvement (sub-workflow)
  QuantumFlowIntegration.record_workflow_step(main_session.id, 2, "architecture_improvement", "Running...")

  {:ok, arch_session} = SessionManager.start_session(%{
    initial_prompt: "Improve code architecture",
    agent_id: "architecture-agent",
    parent_session_id: main_session.id
  })

  run_architecture_improvement_tracked(arch_session.id, codebase_id)

  # Complete main session
  QuantumFlowIntegration.record_workflow_completion(main_session.id, "success", %{
    "sub_workflows" => 2,
    "overall_improvements" => 45
  })
end
```

## Analysis and Learning

### Finding Most Effective Workflows

```elixir
alias Singularity.RCA.QuantumFlowIntegration

# Compare all workflows by success rate
workflows = QuantumFlowIntegration.compare_workflows(limit: 10)

Enum.each(workflows, fn w ->
  IO.inspect(%{
    workflow: w.workflow,
    success_rate: "#{w.success_rate}%",
    total_runs: w.total_sessions,
    avg_cost: w.avg_cost_tokens
  })
end)

# Result:
# %{workflow: "Singularity.Workflows.CodeQualityImprovement", success_rate: 96.67, ...}
# %{workflow: "Singularity.Workflows.AgentImprovement", success_rate: 92.5, ...}
# %{workflow: "Singularity.Workflows.ArchitectureLearning", success_rate: 87.2, ...}
```

### Analyzing Workflow Steps

```elixir
# Which workflow steps are most effective?
steps = QuantumFlowIntegration.analyze_workflow_steps()

Enum.each(steps, fn {step_name, stats} ->
  IO.inspect(%{
    step: step_name,
    success_rate: "#{stats.success_rate}%",
    times_used: stats.total_uses,
    avg_tokens: stats.avg_tokens
  })
end)

# Result:
# %{step: "analyze_metrics", success_rate: 98.2, times_used: 150, avg_tokens: 450}
# %{step: "generate_fixes", success_rate: 96.5, times_used: 150, avg_tokens: 1200}
# %{step: "validate", success_rate: 94.1, times_used: 150, avg_tokens: 500}
```

### Finding Optimal Workflow Patterns

```elixir
# What's the ideal number of workflow steps?
patterns = QuantumFlowIntegration.analyze_workflow_patterns()

IO.inspect(%{
  success_patterns: patterns["success"],
  failure_patterns: patterns["failure"]
})

# Result:
# %{
#   success_patterns: %{
#     avg_steps: 3.2,
#     min_steps: 2,
#     max_steps: 5
#   },
#   failure_patterns: %{
#     avg_steps: 4.8,
#     min_steps: 3,
#     max_steps: 8
#   }
# }

# Insight: Successful workflows complete in ~3 steps, failures take more
```

### Comparing Workflow Effectiveness

```elixir
# Get all sessions for a specific workflow
sessions = QuantumFlowIntegration.sessions_for_workflow(
  "Singularity.Workflows.CodeQualityImprovement"
)

# Analyze patterns
successful = Enum.filter(sessions, &QuantumFlowIntegration.workflow_successful?(&1.id))
failed = Enum.filter(sessions, fn s -> not QuantumFlowIntegration.workflow_successful?(s.id) end)

IO.inspect(%{
  success_rate: length(successful) / length(sessions) * 100,
  avg_tokens_successful: avg(successful, :generation_cost_tokens),
  avg_tokens_failed: avg(failed, :generation_cost_tokens),
  insights: [
    "Successful workflows use #{avg(successful, :generation_cost_tokens)} tokens",
    "Failed workflows use #{avg(failed, :generation_cost_tokens)} tokens",
    "Cost difference: #{abs(avg(successful, :generation_cost_tokens) - avg(failed, :generation_cost_tokens))} tokens"
  ]
})
```

### Getting Workflow Metrics

```elixir
# Retrieve metrics from a completed workflow
session_id = "..."
metrics = QuantumFlowIntegration.get_workflow_metrics(session_id)

IO.inspect(%{
  workflow_module: metrics["workflow_module"],
  improvements: metrics["improvements"],
  complexity_reduction: metrics["complexity_reduction"],
  coverage_improvement: metrics["coverage_improvement"]
})

# Result:
# %{
#   workflow_module: "Singularity.Workflows.CodeQualityImprovement",
#   improvements: 23,
#   complexity_reduction: 12.5,
#   coverage_improvement: 8.2
# }
```

## Agent Integration

Agents can use QuantumFlow + RCA integration to improve:

```elixir
defmodule Singularity.Agents.QualityImprovement do
  alias Singularity.RCA.{SessionManager, QuantumFlowIntegration, LearningQueries}

  def improve_code_quality(codebase_id) do
    # 1. Get best-performing workflows from RCA analysis
    best_workflows = QuantumFlowIntegration.compare_workflows(limit: 3)

    # 2. Get recommended workflow patterns
    patterns = QuantumFlowIntegration.analyze_workflow_patterns()
    optimal_steps = patterns["success"].avg_steps |> round()

    # 3. Start session and track workflow
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: "Improve code quality",
      agent_id: "quality-agent",
      template_id: best_workflows |> hd() |> Map.get(:workflow)
    })

    # 4. Execute workflow with tracking
    result = run_selected_workflow(best_workflows, session.id, codebase_id)

    # 5. Complete and learn
    QuantumFlowIntegration.record_workflow_completion(session.id, "success", result.metrics)

    result
  end
end
```

## Query Examples

### Find all CodeQuality workflows

```elixir
from(gs in GenerationSession,
  where: fragment("? ->> ? LIKE ?",
    gs.success_metrics,
    "workflow_module",
    "%CodeQuality%"
  ),
  select: gs
)
|> Repo.all()
```

### Compare workflow costs

```elixir
from(gs in GenerationSession,
  where: not is_nil(gs.final_outcome),
  group_by: [fragment("? ->> ?", gs.success_metrics, "workflow_module")],
  select: {
    fragment("? ->> ?", gs.success_metrics, "workflow_module"),
    avg(gs.generation_cost_tokens),
    avg(gs.total_validation_cost_tokens)
  }
)
|> Repo.all()
```

### Track workflow evolution

```elixir
from(gs in GenerationSession,
  where: fragment("? ->> ? = ?",
    gs.success_metrics,
    "workflow_module",
    "Singularity.Workflows.CodeQualityImprovement"
  ),
  order_by: [asc: gs.completed_at],
  select: {gs.started_at, gs.final_outcome, gs.generation_cost_tokens}
)
|> Repo.all()
|> Enum.map(fn {date, outcome, cost} ->
  %{date: date, outcome: outcome, tokens: cost}
end)
```

## Best Practices

1. **Always track workflow start**
   ```elixir
   QuantumFlowIntegration.track_workflow_start(session_id, workflow_module)
   ```

2. **Record each step**
   - Call `record_workflow_step/4` for each workflow step
   - Include meaningful step names ("analyze_metrics", not "step_1")
   - Capture metrics and token usage

3. **Complete with metrics**
   ```elixir
   QuantumFlowIntegration.record_workflow_completion(
     session_id,
     outcome,
     %{"key_metrics" => value}
   )
   ```

4. **Regular analysis**
   - Compare workflow effectiveness monthly
   - Identify underperforming workflows
   - Optimize based on learnings

5. **Link to agents**
   - Use `compare_workflows()` to select best workflows
   - Use `analyze_workflow_steps()` to optimize step order
   - Use `analyze_workflow_patterns()` to determine ideal depth

## Troubleshooting

### Workflow metrics not appearing in RCA

**Issue**: Metrics are being recorded but not appearing in success_metrics

**Solution**:
- Check that `record_workflow_completion/3` is being called
- Verify workflow_module is set in `track_workflow_start/2`
- Ensure metrics map is being passed correctly

### Can't find sessions for a workflow

**Issue**: `sessions_for_workflow/1` returns empty list

**Solution**:
- Verify workflow module name matches exactly
- Use full module path: "Singularity.Workflows.CodeQualityImprovement"
- Check that sessions have been completed (status = "completed")

### Step analysis shows no data

**Issue**: `analyze_workflow_steps/0` returns empty map

**Solution**:
- Ensure workflow steps are being recorded with `record_workflow_step/4`
- Check that agent_action follows format: "workflow_#{step_name}"
- Verify RefinementStep records are being created

## See Also

- `lib/singularity/rca/quantum_flow_integration.ex` - Implementation
- `RCA_SYSTEM_GUIDE.md` - Complete RCA system guide
- `lib/singularity/QuantumFlow.ex` - QuantumFlow core
- `lib/singularity/workflows/` - Available workflows
