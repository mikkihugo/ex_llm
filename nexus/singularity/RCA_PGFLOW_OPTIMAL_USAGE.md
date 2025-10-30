# RCA + PgFlow - Optimal Usage Guide

**Complete guide to using RCA with pgflow workflows for maximum learning and optimization.**

## Overview

The RCA system is **fully integrated with pgflow workflows** enabling:

✅ Automatic RCA tracking in pgflow workflows
✅ Agent learning from workflow execution patterns
✅ Intelligent workflow selection based on learnings
✅ Continuous optimization of workflow execution
✅ Cost reduction via optimal strategy selection

## Architecture

### Workflow Execution with RCA

```
┌──────────────────────────────────────┐
│ Agent / System Task                  │
└──────────────────┬───────────────────┘
                   ↓
┌──────────────────────────────────────┐
│ Query RCA Learnings                  │
│ - Best workflows                     │
│ - Optimal step patterns              │
│ - Cost-effective strategies          │
└──────────────────┬───────────────────┘
                   ↓
┌──────────────────────────────────────┐
│ Select Best Workflow                 │
│ (Based on learnings)                 │
└──────────────────┬───────────────────┘
                   ↓
┌──────────────────────────────────────┐
│ Pgflow Workflow Execution            │
│ (RcaWorkflow base class)             │
│ ├─ Step 1 (tracked)                  │
│ ├─ Step 2 (tracked)                  │
│ └─ Step 3 (tracked)                  │
└──────────────────┬───────────────────┘
                   ↓
┌──────────────────────────────────────┐
│ RCA Session Completed                │
│ Ready for analysis                   │
└──────────────────────────────────────┘
```

## Three-Tier Implementation

### Tier 1: Basic Workflow with RCA Tracking

Workflows automatically track all steps with minimal code changes:

```elixir
# Before: No tracking
defmodule MyWorkflow do
  def execute(input) do
    {:ok, result}
  end
end

# After: With RCA tracking (just change base class!)
defmodule MyWorkflow do
  use Singularity.Workflows.RcaWorkflow  # <-- Add this

  @impl Singularity.Workflows.RcaWorkflow
  def rca_config do
    %{agent_id: "my-agent"}
  end

  def __workflow_steps__ do
    [{:step1, &step1/1}, {:step2, &step2/1}]
  end

  def execute(input) do
    execute_with_rca(input)  # <-- Replace this
  end

  def step1(input) do
    # Step execution - automatically tracked!
    {:ok, output}
  end
end
```

**Benefits:**
- ✅ Zero breaking changes
- ✅ Automatic per-step tracking
- ✅ Automatic metrics collection
- ✅ Failure recording

### Tier 2: Agent-Guided Workflow Selection

Agents query RCA learnings to pick the best workflow:

```elixir
defmodule Singularity.Agents.QualityAgent do
  alias Singularity.RCA.{SessionManager, PgflowIntegration}

  def improve_code_quality(codebase_id) do
    # 1. Query RCA learnings
    best_workflows = PgflowIntegration.compare_workflows(limit: 5)
    workflow_patterns = PgflowIntegration.analyze_workflow_patterns()

    Logger.info("RCA learnings", %{
      best_workflow: hd(best_workflows).workflow,
      success_rate: hd(best_workflows).success_rate,
      optimal_steps: round(workflow_patterns["success"].avg_steps)
    })

    # 2. Select best workflow
    selected_workflow = select_workflow(best_workflows, codebase_id)

    # 3. Create RCA session with selected workflow metadata
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: "Improve code quality for #{codebase_id}",
      agent_id: "quality-agent",
      template_id: selected_workflow
    })

    # 4. Execute workflow (with automatic RCA tracking)
    {:ok, result} = Pgflow.Executor.execute(
      String.to_atom(selected_workflow),
      %{
        codebase_id: codebase_id,
        session_id: session.id
      },
      timeout: 60000
    )

    result
  end

  defp select_workflow(workflows, _codebase_id) do
    workflows
    |> Enum.max_by(fn w -> w.success_rate end)
    |> Map.get(:workflow)
  end
end
```

**Benefits:**
- ✅ Agent learns which workflows work best
- ✅ Automatic optimization of workflow selection
- ✅ Data-driven decision making
- ✅ Continuous improvement

### Tier 3: Complete Learning Loop

Full integration with agent feedback and continuous improvement:

```elixir
defmodule Singularity.Agents.LearningAgent do
  alias Singularity.RCA.{
    SessionManager,
    PgflowIntegration,
    LearningQueries,
    FailureAnalysis
  }

  def execute_with_learning(task_spec) do
    # 1. Analyze current state
    insights = gather_insights()

    # 2. Determine strategy based on learnings
    strategy = select_optimal_strategy(insights, task_spec)

    Logger.info("Selected strategy", %{
      workflow: strategy.workflow,
      expected_success_rate: strategy.success_rate,
      expected_cost: strategy.avg_cost_tokens
    })

    # 3. Create session with strategy metadata
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: task_spec.description,
      agent_id: "learning-agent",
      template_id: strategy.workflow
    })

    # 4. Execute workflow
    result = execute_workflow(strategy.workflow, session.id, task_spec)

    # 5. Record outcome
    PgflowIntegration.record_workflow_completion(
      session.id,
      if(result.success, do: "success", else: "failure_execution"),
      result.metrics
    )

    # 6. Learn for next iteration
    update_agent_learnings(session.id, result, strategy)

    result
  end

  defp gather_insights do
    %{
      # Most cost-effective strategies
      efficient: LearningQueries.efficient_strategies(80.0, 5),
      # Highest quality strategies
      high_quality: LearningQueries.highest_quality_strategies(5),
      # Most effective actions
      effective_actions: LearningQueries.most_effective_refinement_actions(),
      # Areas needing improvement
      difficult_failures: FailureAnalysis.difficult_to_fix_failures(5, 50.0),
      # Workflow patterns
      workflow_comparison: PgflowIntegration.compare_workflows(10),
      workflow_patterns: PgflowIntegration.analyze_workflow_patterns(),
      workflow_steps: PgflowIntegration.analyze_workflow_steps()
    }
  end

  defp select_optimal_strategy(insights, task_spec) do
    # Prioritize based on:
    # 1. Success rate for similar tasks
    # 2. Cost efficiency
    # 3. Recent performance trends

    insights.workflow_comparison
    |> Enum.max_by(fn w -> w.success_rate * (1 - w.avg_cost_tokens / 5000) end)
  end

  defp execute_workflow(workflow_module, session_id, task_spec) do
    case Pgflow.Executor.execute(
      String.to_atom(workflow_module),
      Map.merge(task_spec, %{session_id: session_id}),
      timeout: 60000
    ) do
      {:ok, result} -> %{success: true, metrics: result}
      {:error, reason} -> %{success: false, metrics: %{error: inspect(reason)}}
    end
  end

  defp update_agent_learnings(session_id, result, strategy) do
    # Log this execution for future learning
    Logger.info("Learning recorded", %{
      session_id: session_id,
      workflow: strategy.workflow,
      success: result.success,
      expected_success_rate: strategy.success_rate,
      actual_success: result.success
    })
  end
end
```

**Benefits:**
- ✅ Complete learning loop with RCA integration
- ✅ Data-driven agent decisions
- ✅ Continuous optimization
- ✅ Measurable improvement tracking

## Common Usage Patterns

### Pattern 1: Simple Workflow with Tracking

```elixir
# Minimal changes to existing workflows
defmodule MyWorkflow do
  use Singularity.Workflows.RcaWorkflow

  @impl true
  def rca_config, do: %{agent_id: "my-agent"}

  def __workflow_steps__, do: [{:step1, &step1/1}]

  def execute(input), do: execute_with_rca(input)

  def step1(input) do
    {:ok, result}
  end
end
```

### Pattern 2: Complex Multi-Step Workflow

```elixir
defmodule ComplexWorkflow do
  use Singularity.Workflows.RcaWorkflow

  @impl true
  def rca_config do
    %{
      agent_id: "complex-agent",
      template_id: "complex-workflow",
      agent_version: "v2.0.0"
    }
  end

  def __workflow_steps__ do
    [
      {:analysis, &analyze/1},
      {:planning, &plan/1},
      {:execution, &execute_changes/1},
      {:validation, &validate/1},
      {:reporting, &report/1}
    ]
  end

  def execute(input), do: execute_with_rca(input)

  def analyze(input) do
    # Step 1: Analyze
    {:ok, Map.put(input, :analysis, analysis_results)}
  end

  def plan(input) do
    # Step 2: Plan
    {:ok, Map.put(input, :plan, plan_results)}
  end

  # ... more steps
end
```

### Pattern 3: Nested Workflows

```elixir
defmodule OrchestrationWorkflow do
  use Singularity.Workflows.RcaWorkflow

  def __workflow_steps__ do
    [
      {:run_quality_workflow, &run_quality/1},
      {:run_architecture_workflow, &run_architecture/1},
      {:aggregate_results, &aggregate/1}
    ]
  end

  def run_quality(input) do
    # Execute sub-workflow
    case Pgflow.Executor.execute(
      Singularity.Workflows.CodeQualityImprovementRca,
      input,
      timeout: 30000
    ) do
      {:ok, result} -> {:ok, Map.put(input, :quality_result, result)}
      {:error, reason} -> {:error, reason}
    end
  end

  def run_architecture(input) do
    # Execute another sub-workflow
    case Pgflow.Executor.execute(
      Singularity.Workflows.ArchitectureAnalysisRca,
      input,
      timeout: 30000
    ) do
      {:ok, result} -> {:ok, Map.put(input, :architecture_result, result)}
      {:error, reason} -> {:error, reason}
    end
  end

  def aggregate(input) do
    # Combine results
    {:ok, %{
      quality: Map.get(input, :quality_result),
      architecture: Map.get(input, :architecture_result),
      combined_improvements: calculate_improvements(input)
    }}
  end
end
```

## Real-World Example: Self-Improving Agent

Complete example of agent that learns and improves:

```elixir
defmodule Singularity.Agents.SelfImprovingQualityAgent do
  alias Singularity.RCA.{SessionManager, PgflowIntegration, LearningQueries}

  @doc """
  Execute code quality improvement with learning.

  This agent:
  1. Queries RCA system for best workflows
  2. Selects optimal workflow based on success rate
  3. Executes with automatic RCA tracking
  4. Records learnings for next iteration
  5. Continuously improves workflow selection
  """
  def improve_code_quality(codebase_id, opts \\ []) do
    Logger.info("Self-improving quality agent starting", %{codebase: codebase_id})

    # 1. Get learnings from RCA system
    best_workflows = PgflowIntegration.compare_workflows(limit: 3)

    if Enum.empty?(best_workflows) do
      Logger.info("No workflow learnings yet, using default")
      run_default_workflow(codebase_id)
    else
      # 2. Select best workflow
      selected = hd(best_workflows)

      Logger.info("Selected workflow based on learnings", %{
        workflow: selected.workflow,
        success_rate: selected.success_rate,
        total_sessions: selected.total_sessions
      })

      # 3. Create session
      {:ok, session} = SessionManager.start_session(%{
        initial_prompt: "Improve code quality for #{codebase_id}",
        agent_id: "self-improving-quality-agent",
        template_id: selected.workflow
      })

      # 4. Execute workflow (with automatic RCA tracking)
      result = execute_with_timeout(selected.workflow, session.id, codebase_id, 60000)

      # 5. Get immediate learnings for logging
      current_learnings = get_learnings_summary()

      Logger.info("Quality improvement completed", %{
        success: result.success,
        improvements: result.improvements,
        cost_tokens: result.cost_tokens,
        best_workflow: current_learnings.best_workflow,
        best_success_rate: current_learnings.best_success_rate
      })

      result
    end
  end

  defp execute_with_timeout(workflow_module, session_id, codebase_id, timeout) do
    case Pgflow.Executor.execute(
      String.to_atom(workflow_module),
      %{
        codebase_id: codebase_id,
        session_id: session_id
      },
      timeout: timeout
    ) do
      {:ok, result} ->
        %{
          success: true,
          improvements: Map.get(result, "improvements", 0),
          cost_tokens: Map.get(result, "tokens_used", 0),
          details: result
        }

      {:error, reason} ->
        Logger.error("Workflow execution failed", %{error: inspect(reason)})

        %{
          success: false,
          improvements: 0,
          cost_tokens: 0,
          error: reason
        }
    end
  end

  defp run_default_workflow(codebase_id) do
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: "Improve code quality",
      agent_id: "self-improving-quality-agent"
    })

    Pgflow.Executor.execute(
      Singularity.Workflows.CodeQualityImprovementRca,
      %{codebase_id: codebase_id, session_id: session.id},
      timeout: 60000
    )
  end

  defp get_learnings_summary do
    workflows = PgflowIntegration.compare_workflows(limit: 1)

    if Enum.empty?(workflows) do
      %{best_workflow: "none", best_success_rate: 0}
    else
      best = hd(workflows)

      %{
        best_workflow: best.workflow,
        best_success_rate: best.success_rate
      }
    end
  end
end
```

## Migration Guide: Enable RCA on Existing Workflows

### Step 1: Update Base Class

```elixir
# Old
defmodule MyWorkflow do
  use Singularity.Workflows.BaseWorkflow
  # ...
end

# New
defmodule MyWorkflow do
  use Singularity.Workflows.RcaWorkflow
  # ... rest is the same!
end
```

### Step 2: Implement rca_config/0

```elixir
@impl Singularity.Workflows.RcaWorkflow
def rca_config do
  %{
    agent_id: "my-agent-name",
    template_id: "optional-template-id"
  }
end
```

### Step 3: Update execute/1

```elixir
# Old
def execute(input) do
  execute_workflow(input)
end

# New
def execute(input) do
  execute_with_rca(input)
end
```

**That's it!** All steps now tracked automatically.

## Monitoring and Optimization

### Dashboard Queries

```elixir
# Best performing workflows
best = PgflowIntegration.compare_workflows(limit: 10)

# Worst performing workflows (need improvement)
worst = Enum.reverse(best)

# Workflow evolution over time
recent = PgflowIntegration.compare_workflows(limit: 100)
  |> Enum.sort_by(& &1.total_sessions, :desc)

# Most impactful steps
impactful_steps = PgflowIntegration.analyze_workflow_steps()
  |> Enum.sort_by(&elem(&1, 1).success_rate, :desc)
```

### Optimization Opportunities

```elixir
# 1. Workflows with high cost but low success
expensive_failures = workflows
  |> Enum.filter(&(&1.success_rate < 80))
  |> Enum.filter(&(&1.avg_cost_tokens > 2000))

# 2. Workflows with room for improvement
improvable = workflows
  |> Enum.filter(&(&1.success_rate < 90))
  |> Enum.filter(&(&1.total_sessions > 100))

# 3. Expensive steps that could be optimized
expensive_steps = PgflowIntegration.analyze_workflow_steps()
  |> Enum.sort_by(&elem(&1, 1).avg_tokens, :desc)
  |> Enum.take(5)
```

## Best Practices

1. **Always implement rca_config/0**
   ```elixir
   @impl true
   def rca_config do
     %{agent_id: "meaningful-agent-name"}
   end
   ```

2. **Return metrics from steps**
   ```elixir
   {:ok, Map.merge(input, %{
     "tokens_used" => 1200,
     "improvements" => 42
   })}
   ```

3. **Query learnings regularly**
   ```elixir
   # Check workflow effectiveness
   PgflowIntegration.compare_workflows(limit: 10)
   |> IO.inspect()
   ```

4. **Monitor cost trends**
   ```elixir
   # Are workflows getting more expensive?
   workflows_old = # workflows from 1 week ago
   workflows_new = PgflowIntegration.compare_workflows()
   cost_increase = calculate_cost_trend(workflows_old, workflows_new)
   ```

5. **Optimize high-usage workflows**
   ```elixir
   # Workflows used > 100 times should be optimized
   high_volume = PgflowIntegration.compare_workflows()
     |> Enum.filter(&(&1.total_sessions > 100))
   ```

## Troubleshooting

### Workflows not creating RCA sessions

**Issue**: Workflows execute but no RCA sessions created

**Solution**:
- Verify workflow uses `RcaWorkflow` base class
- Verify `execute/1` calls `execute_with_rca/1`
- Check logs for RCA session creation errors

### RCA tracking interfering with workflow

**Issue**: Workflow runs slower or fails with RCA enabled

**Solution**:
- RCA failures don't fail workflows (graceful degradation)
- Check database connectivity
- Verify RCA migrations were run
- Review error logs

### Missing metrics in RCA

**Issue**: Metrics recorded but not appearing in queries

**Solution**:
- Ensure step results include `"tokens_used"` and `"metrics"` keys
- Verify workflow steps return `{:ok, map()}` format
- Check that workflow completion is being called

## See Also

- `lib/singularity/workflows/rca_workflow.ex` - RcaWorkflow base class
- `lib/singularity/workflows/code_quality_improvement_rca.ex` - Example implementation
- `RCA_SYSTEM_GUIDE.md` - Complete RCA system guide
- `RCA_PGFLOW_INTEGRATION.md` - pgflow integration details
