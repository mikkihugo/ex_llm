# Agent CentralCloud Migration Guide

Complete guide for refactoring all Singularity agents to report metrics and patterns to CentralCloud.

## Overview

This migration adds CentralCloud Guardian integration to all 24 agents for:
- ✅ Change proposals to CentralCloud Guardian
- ✅ Pattern recording to CentralCloud Pattern Aggregator
- ✅ Consensus-based change approval
- ✅ Automatic rollback from Guardian
- ✅ Batched metrics reporting

**Key principle:** Backward compatible - agents work with/without CentralCloud (graceful degradation).

## New Modules

### 1. AgentBehavior - Unified agent interface
**Path:** `lib/singularity/agents/agent_behavior.ex`

Defines behavior contract with optional CentralCloud callbacks:
- `on_change_proposed/3` - Propose change to Guardian
- `on_pattern_learned/2` - Report pattern to Aggregator
- `on_change_approved/1` - Receive consensus approval
- `on_rollback_triggered/1` - Handle Guardian rollback
- `get_safety_profile/1` - Return agent-specific safety thresholds

### 2. AgentCoordinator - Bidirectional communication bridge
**Path:** `lib/singularity/evolution/agent_coordinator.ex`

GenServer managing agent ↔ CentralCloud communication:
- `propose_change/3` - Send change to Guardian via ex_quantum_flow
- `record_pattern/3` - Send pattern to Aggregator
- `await_consensus/1` - Wait for Consensus approval (blocks up to 30s)
- `handle_rollback/1` - Propagate rollback to agents

### 3. SafetyProfiles - Per-agent safety thresholds
**Path:** `lib/singularity/evolution/safety_profiles.ex`

ETS-cached safety profiles for Guardian:
- `get_profile/1` - Lookup agent safety thresholds
- Predefined profiles for all 24 agents
- Agent-specific overrides via `get_safety_profile/1`

### 4. MetricsReporter - Batched metrics to CentralCloud
**Path:** `lib/singularity/evolution/metrics_reporter.ex`

Batches agent metrics every 60s:
- `record_metric/3` - Record single metric
- `record_metrics/2` - Record multiple metrics
- `flush/0` - Force immediate batch report

## Migration Steps (Per Agent)

### Step 1: Implement AgentBehavior (if not already)

Add behavior implementation to agent module:

```elixir
defmodule Singularity.Agents.YourAgent do
  @behaviour Singularity.Agents.AgentBehavior

  # Required callbacks
  @impl true
  def execute_task(task, context) do
    # Your agent logic
    {:ok, result}
  end

  @impl true
  def get_agent_type, do: :your_agent

  # Optional: Override safety profile
  @impl true
  def get_safety_profile(context) do
    %{
      error_threshold: 0.02,
      needs_consensus: true,
      max_blast_radius: :medium
    }
  end
end
```

### Step 2: Add Change Proposal (for agents that modify code)

Before applying changes, propose to Guardian:

```elixir
# BEFORE (no Guardian integration)
def apply_refactoring(file_path, refactoring) do
  # Apply change directly
  apply_change(file_path, refactoring)
end

# AFTER (with Guardian integration)
alias Singularity.Evolution.AgentCoordinator

def apply_refactoring(file_path, refactoring) do
  change = %{
    type: :refactor,
    files: [file_path],
    description: "Applying #{refactoring.name}"
  }

  metadata = %{
    confidence: refactoring.confidence,
    blast_radius: :medium
  }

  # Propose to Guardian
  {:ok, change_record} = AgentCoordinator.propose_change(__MODULE__, change, metadata)

  # Wait for consensus if required
  case AgentCoordinator.await_consensus(change_record.id) do
    {:ok, :approved} ->
      # Consensus approved - proceed
      apply_change(file_path, refactoring)

    {:ok, :rejected} ->
      {:error, :consensus_rejected}

    {:error, :timeout} ->
      # Graceful degradation: proceed without consensus
      Logger.warning("Consensus timeout, proceeding without approval")
      apply_change(file_path, refactoring)
  end
end
```

### Step 3: Add Pattern Recording (when learning reusable patterns)

Report learned patterns to Aggregator:

```elixir
alias Singularity.Evolution.AgentCoordinator

def learn_pattern_from_success(refactoring, result) do
  if result.success_rate > 0.95 do
    pattern = %{
      name: refactoring.name,
      code: refactoring.code_template,
      success_rate: result.success_rate,
      applicability: refactoring.applicable_languages
    }

    # Report to CentralCloud Aggregator
    AgentCoordinator.record_pattern(__MODULE__, :refactoring, pattern)
  end
end
```

### Step 4: Add Metrics Reporting (during execution)

Record performance metrics throughout execution:

```elixir
alias Singularity.Evolution.MetricsReporter

def execute_with_metrics(task, context) do
  start_time = :os.system_time(:millisecond)

  result = case do_execute(task, context) do
    {:ok, data} ->
      # Record success metrics
      MetricsReporter.record_metrics(__MODULE__, %{
        execution_time: :os.system_time(:millisecond) - start_time,
        success_rate: 1.0,
        error_count: 0
      })

      {:ok, data}

    {:error, reason} ->
      # Record failure metrics
      MetricsReporter.record_metrics(__MODULE__, %{
        execution_time: :os.system_time(:millisecond) - start_time,
        success_rate: 0.0,
        error_count: 1
      })

      {:error, reason}
  end

  result
end
```

### Step 5: Add Rollback Handling (optional - for high-risk agents)

Override `on_rollback_triggered/1` for custom rollback logic:

```elixir
@impl true
def on_rollback_triggered(rollback) do
  Logger.warning("Guardian triggered rollback",
    change_id: rollback.change_id,
    reason: rollback.reason
  )

  # Custom rollback logic
  case revert_change(rollback.change_id) do
    :ok ->
      {:ok, :rolled_back}

    {:error, reason} ->
      {:error, reason}
  end
end
```

## Agent Refactoring Checklist

### High-Risk Agents (Strict thresholds, consensus required)

| Agent | Status | Notes |
|-------|--------|-------|
| ✅ **QualityEnforcer** | ⏳ Pending | Enforce quality standards - needs consensus |
| ✅ **RefactoringAgent** | ⏳ Pending | Code transformations - high blast radius |
| ✅ **SelfImprovingAgent** | ⏳ Pending | Self-evolution - critical changes |
| ✅ **AgentSpawner** | ⏳ Pending | Dynamic agent creation - infrastructure |
| ✅ **AgentSupervisor** | ⏳ Pending | Supervision tree management - critical |
| ✅ **RuntimeBootstrapper** | ⏳ Pending | System initialization - high risk |

### Medium-Risk Agents (Balanced thresholds)

| Agent | Status | Notes |
|-------|--------|-------|
| ✅ **CostOptimizedAgent** | ⏳ Pending | Cost optimization - needs monitoring |
| ✅ **TechnologyAgent** | ⏳ Pending | Tech stack detection - low risk |
| ✅ **DocumentationPipeline** | ⏳ Pending | Doc generation - safe operations |
| ✅ **SchemaGenerator** | ⏳ Pending | Schema generation - needs validation |
| ✅ **RemediationEngine** | ⏳ Pending | Fix suggestions - medium risk |

### Low-Risk Agents (Permissive thresholds, no consensus)

| Agent | Status | Notes |
|-------|--------|-------|
| ✅ **DeadCodeMonitor** | ⏳ Pending | Detection only - no changes |
| ✅ **ChangeTracker** | ⏳ Pending | Tracking only - read-only |
| ✅ **MetricsFeeder** | ⏳ Pending | Metrics collection - safe |
| ✅ **AgentPerformanceDashboard** | ⏳ Pending | Monitoring - read-only |
| ✅ **RealWorkloadFeeder** | ⏳ Pending | Workload injection - safe |
| ✅ **TemplatePerformance** | ⏳ Pending | Performance tracking - read-only |

### Infrastructure/Utility Agents

| Agent | Status | Notes |
|-------|--------|-------|
| ✅ **HotReloader** | ⏳ Pending | Code hot-swapping - needs coordination |
| ✅ **Arbiter** | ⏳ Pending | Decision arbitration - critical |
| ✅ **Toolkit** | ⏳ Pending | Shared utilities - low risk |
| ✅ **Agent (Base)** | ⏳ Pending | Core agent GenServer - critical |
| ✅ **Supervisor** | ⏳ Pending | Agent supervision - infrastructure |

## Before/After Examples

### Example 1: QualityEnforcer (High-Risk Agent)

#### Before (No CentralCloud Integration)

```elixir
defmodule Singularity.Agents.QualityEnforcer do
  use GenServer

  def enforce_quality_standards(file_path) do
    case validate_quality(file_path) do
      {:ok, :compliant} ->
        {:ok, :approved}

      {:error, issues} ->
        # Auto-fix quality issues
        apply_quality_fixes(file_path, issues)
    end
  end
end
```

#### After (With CentralCloud Integration)

```elixir
defmodule Singularity.Agents.QualityEnforcer do
  @behaviour Singularity.Agents.AgentBehavior
  use GenServer

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  @impl true
  def execute_task(task, context), do: enforce_quality_standards(context.file_path)

  @impl true
  def get_agent_type, do: :quality_enforcer

  @impl true
  def get_safety_profile(_context) do
    %{
      error_threshold: 0.01,
      needs_consensus: true,
      max_blast_radius: :medium
    }
  end

  def enforce_quality_standards(file_path) do
    start_time = :os.system_time(:millisecond)

    result = case validate_quality(file_path) do
      {:ok, :compliant} ->
        record_success_metrics(start_time)
        {:ok, :approved}

      {:error, issues} ->
        # Propose fixes to CentralCloud Guardian
        change = %{
          type: :quality_fix,
          files: [file_path],
          issues: issues
        }

        {:ok, change_record} = AgentCoordinator.propose_change(
          __MODULE__,
          change,
          %{confidence: 0.95}
        )

        # Wait for consensus (strict agent requires approval)
        case AgentCoordinator.await_consensus(change_record.id) do
          {:ok, :approved} ->
            # Consensus approved - apply fixes
            result = apply_quality_fixes(file_path, issues)
            record_success_metrics(start_time)

            # Record learned pattern
            if length(issues) > 0 do
              pattern = extract_fix_pattern(issues)
              AgentCoordinator.record_pattern(__MODULE__, :quality_fix, pattern)
            end

            result

          {:ok, :rejected} ->
            record_rejection_metrics(start_time)
            {:error, :consensus_rejected}
        end
    end

    result
  end

  defp record_success_metrics(start_time) do
    MetricsReporter.record_metrics(__MODULE__, %{
      execution_time: :os.system_time(:millisecond) - start_time,
      success_rate: 1.0,
      error_count: 0
    })
  end

  defp record_rejection_metrics(start_time) do
    MetricsReporter.record_metrics(__MODULE__, %{
      execution_time: :os.system_time(:millisecond) - start_time,
      success_rate: 0.0,
      error_count: 1
    })
  end

  defp extract_fix_pattern(issues) do
    %{
      name: "quality_fix_pattern",
      issue_types: Enum.map(issues, & &1.type),
      fix_templates: Enum.map(issues, & &1.fix_template),
      success_rate: 0.98
    }
  end
end
```

### Example 2: CostOptimizedAgent (Medium-Risk Agent)

#### Before (No CentralCloud Integration)

```elixir
defmodule Singularity.Agents.CostOptimizedAgent do
  def optimize_llm_usage(request) do
    case try_rule_engine(request) do
      {:ok, result} -> {:ok, result, cost: 0}
      {:error, _} -> call_expensive_llm(request)
    end
  end
end
```

#### After (With CentralCloud Integration)

```elixir
defmodule Singularity.Agents.CostOptimizedAgent do
  @behaviour Singularity.Agents.AgentBehavior

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  @impl true
  def execute_task(task, context), do: optimize_llm_usage(context.request)

  @impl true
  def get_agent_type, do: :cost_optimized

  @impl true
  def get_safety_profile(_context) do
    %{
      error_threshold: 0.03,
      needs_consensus: true,
      max_blast_radius: :medium
    }
  end

  def optimize_llm_usage(request) do
    start_time = :os.system_time(:millisecond)

    result = case try_rule_engine(request) do
      {:ok, result} ->
        # Success with rules - record savings
        MetricsReporter.record_metrics(__MODULE__, %{
          execution_time: :os.system_time(:millisecond) - start_time,
          cost_cents: 0,
          strategy: :rules
        })

        # Record successful pattern
        pattern = %{
          name: "rule_success",
          request_type: request.type,
          rule_matched: result.rule_id
        }
        AgentCoordinator.record_pattern(__MODULE__, :cost_optimization, pattern)

        {:ok, result, cost: 0}

      {:error, _} ->
        # Rules failed - propose expensive LLM call
        change = %{
          type: :expensive_llm_call,
          request: request
        }

        {:ok, change_record} = AgentCoordinator.propose_change(
          __MODULE__,
          change,
          %{estimated_cost_cents: 50}
        )

        # For cost optimization, we want consensus on expensive calls
        case AgentCoordinator.await_consensus(change_record.id) do
          {:ok, :approved} ->
            result = call_expensive_llm(request)

            MetricsReporter.record_metrics(__MODULE__, %{
              execution_time: :os.system_time(:millisecond) - start_time,
              cost_cents: 50,
              strategy: :llm
            })

            result

          {:ok, :rejected} ->
            {:error, :expensive_call_rejected}
        end
    end

    result
  end
end
```

### Example 3: DeadCodeMonitor (Low-Risk Agent)

#### Before (No CentralCloud Integration)

```elixir
defmodule Singularity.Agents.DeadCodeMonitor do
  def scan_for_dead_code(codebase_path) do
    # Detection only - no changes
    {:ok, find_dead_code(codebase_path)}
  end
end
```

#### After (With CentralCloud Integration)

```elixir
defmodule Singularity.Agents.DeadCodeMonitor do
  @behaviour Singularity.Agents.AgentBehavior

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  @impl true
  def execute_task(task, context), do: scan_for_dead_code(context.codebase_path)

  @impl true
  def get_agent_type, do: :dead_code_monitor

  # Low-risk agent: Permissive thresholds, no consensus
  @impl true
  def get_safety_profile(_context) do
    %{
      error_threshold: 0.10,
      needs_consensus: false,
      max_blast_radius: :low
    }
  end

  def scan_for_dead_code(codebase_path) do
    start_time = :os.system_time(:millisecond)

    dead_code = find_dead_code(codebase_path)

    # Record metrics (no consensus needed for read-only operations)
    MetricsReporter.record_metrics(__MODULE__, %{
      execution_time: :os.system_time(:millisecond) - start_time,
      dead_code_count: length(dead_code),
      success_rate: 1.0
    })

    # Record pattern if we found common dead code types
    if length(dead_code) > 0 do
      pattern = %{
        name: "dead_code_pattern",
        common_types: extract_common_types(dead_code),
        frequency: length(dead_code)
      }

      AgentCoordinator.record_pattern(__MODULE__, :dead_code_detection, pattern)
    end

    {:ok, dead_code}
  end
end
```

## Testing Migration

### Unit Tests (Per Agent)

```elixir
defmodule Singularity.Agents.YourAgentTest do
  use Singularity.DataCase

  alias Singularity.Agents.YourAgent
  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  test "proposes change to CentralCloud Guardian" do
    # Test change proposal
    assert {:ok, change_record} = YourAgent.perform_action(...)
    assert change_record.status == :pending
  end

  test "records metrics during execution" do
    YourAgent.perform_action(...)

    # Verify metrics recorded
    {:ok, metrics} = MetricsReporter.get_metrics(YourAgent)
    assert metrics[:execution_time] > 0
  end

  test "records learned patterns" do
    # Test pattern recording after successful execution
    YourAgent.perform_action_with_learning(...)
    # Verify pattern recorded via AgentCoordinator
  end
end
```

### Integration Tests

See `test/singularity/evolution/agent_coordinator_test.exs` for complete integration test suite.

## Deployment Checklist

- [ ] **Step 1:** Add AgentCoordinator, SafetyProfiles, MetricsReporter to supervision tree
- [ ] **Step 2:** Migrate high-risk agents first (QualityEnforcer, RefactoringAgent, SelfImprovingAgent)
- [ ] **Step 3:** Monitor metrics in CentralCloud Guardian dashboard
- [ ] **Step 4:** Migrate medium-risk agents
- [ ] **Step 5:** Migrate low-risk agents
- [ ] **Step 6:** Verify backward compatibility (agents work without CentralCloud)
- [ ] **Step 7:** Enable automatic rollbacks in production

## Supervision Tree Integration

Add new services to application supervisor:

```elixir
# lib/singularity/application.ex

children = [
  # ... existing children ...

  # Evolution services
  Singularity.Evolution.SafetyProfiles,
  Singularity.Evolution.AgentCoordinator,
  Singularity.Evolution.MetricsReporter
]
```

## Configuration

```elixir
# config/config.exs

config :singularity, :agent_coordinator,
  enabled: true,
  consensus_timeout_ms: 30_000,
  instance_id: System.get_env("SINGULARITY_INSTANCE_ID", "instance_default")

config :singularity, :metrics_reporter,
  enabled: true,
  flush_interval_ms: 60_000,
  batch_size: 1000

config :singularity, :safety_profiles,
  enabled: true,
  default_error_threshold: 0.05,
  default_needs_consensus: false
```

## Monitoring & Observability

### CentralCloud Guardian Dashboard

Monitor agent health in CentralCloud:
- Error rates by agent type
- Consensus approval rates
- Rollback frequency
- Cost trends
- Performance trends

### Local Metrics

```elixir
# Get reporter stats
MetricsReporter.get_stats()
# => %{total_metrics_recorded: 15234, total_batches_sent: 42, ...}

# Get agent safety profile
SafetyProfiles.get_profile(Singularity.Agents.QualityEnforcer)
# => %{error_threshold: 0.01, needs_consensus: true, ...}

# Get change status
AgentCoordinator.get_change_status("change-123")
# => {:ok, :approved}
```

## Troubleshooting

### CentralCloud Unavailable

All components gracefully degrade when CentralCloud is unavailable:
- Change proposals proceed without consensus
- Pattern recording is skipped
- Metrics are buffered locally
- No agent execution blocked

### Consensus Timeout

If consensus times out (default: 30s):
- High-risk agents reject the change
- Medium-risk agents may proceed with warning
- Low-risk agents always proceed

### Rollback Failures

If rollback fails:
- Agent receives `on_rollback_triggered/1` callback
- Manual intervention may be required
- Check logs for rollback failure reasons

## Next Steps

1. **Review this guide** for completeness
2. **Start with high-risk agents** (QualityEnforcer, RefactoringAgent)
3. **Monitor CentralCloud dashboards** for health metrics
4. **Iterate on safety profiles** based on production data
5. **Expand to remaining agents** incrementally

## References

- **AgentBehavior:** `lib/singularity/agents/agent_behavior.ex`
- **AgentCoordinator:** `lib/singularity/evolution/agent_coordinator.ex`
- **SafetyProfiles:** `lib/singularity/evolution/safety_profiles.ex`
- **MetricsReporter:** `lib/singularity/evolution/metrics_reporter.ex`
- **Integration Tests:** `test/singularity/evolution/agent_coordinator_test.exs`
- **CentralCloud Integration Guide:** `CENTRALCLOUD_INTEGRATION_GUIDE.md`
- **Agent System Expert:** `AGENT_SYSTEM_EXPERT.md`
