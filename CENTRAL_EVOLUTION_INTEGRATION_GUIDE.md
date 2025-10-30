# CentralCloud Evolution Integration Guide

**Version**: 1.0
**Date**: 2025-10-30
**Status**: Implementation Complete

## Executive Summary

This guide shows how Singularity instances integrate with CentralCloud's evolution services (Guardian, Pattern Aggregator, Consensus Engine) for centralized coordination, cross-instance learning, and autonomous improvement.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SINGULARITY INSTANCE                      │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐        │
│  │   Agent    │───▶│ Evolution  │───▶│  Feedback  │        │
│  │ Execution  │    │   Module   │    │  Analyzer  │        │
│  └────────────┘    └────┬───────┘    └────────────┘        │
└────────────────────────┬│─────────────────────────────────┘
                         ││
        ┌────────────────┘└────────────────┐
        ▼                                   ▼
┌─────────────────┐              ┌─────────────────┐
│    GUARDIAN     │              │    PATTERNS     │
│  (CentralCloud) │              │   AGGREGATOR    │
│                 │              │  (CentralCloud) │
│ • Rollback      │              │ • Record        │
│ • Safety        │              │ • Consensus     │
│ • Metrics       │              │ • Suggest       │
└────────┬────────┘              └────────┬────────┘
         │                                 │
         └────────────┬────────────────────┘
                      ▼
              ┌─────────────────┐
              │    CONSENSUS    │
              │     ENGINE      │
              │  (CentralCloud) │
              │                 │
              │ • Propose       │
              │ • Vote          │
              │ • Execute       │
              └─────────────────┘
```

## Integration Point 1: Guardian (Rollback Service)

### Purpose
Guardian tracks all code changes across instances and provides centralized rollback coordination with learned strategies.

### When to Use
- **Before applying any evolution** - Register change for safety monitoring
- **During execution** - Report real-time metrics for threshold monitoring
- **Before proposing to Consensus** - Check if change should be auto-approved

### Integration Flow

```elixir
# Step 1: Register change with Guardian (before applying)
alias CentralCloud.Evolution.Guardian.RollbackService

{:ok, change_id} = RollbackService.register_change(
  "dev-1",                    # instance_id
  Ecto.UUID.generate(),       # change_id
  %{
    change_type: :pattern_enhancement,
    before_code: agent.prompt,
    after_code: improved_prompt,
    agent_id: "elixir-specialist"
  },
  %{
    risk_level: :low,
    blast_radius: :single_agent,
    reversibility: :automatic,
    test_coverage: 0.95,
    similar_changes_success_rate: 0.98
  }
)

# Step 2: Apply change locally (A/B testing)
apply_improvement_to_agent(agent_id, improvement)

# Step 3: Report metrics every 30 seconds
Task.start(fn ->
  Stream.interval(30_000)
  |> Enum.each(fn _ ->
    metrics = collect_agent_metrics(agent_id)

    case RollbackService.report_metrics("dev-1", change_id, metrics) do
      {:ok, :threshold_breach_detected} ->
        Logger.warning("Guardian triggered auto-rollback!")
        # Rollback handled automatically by Guardian

      {:ok, :monitored} ->
        Logger.debug("Metrics within thresholds")
    end
  end)
end)

# Step 4: Check if change should skip consensus voting
case RollbackService.approve_change?(change_id) do
  {:ok, :auto_approved, similarity} ->
    Logger.info("Change auto-approved by Guardian (similarity: #{similarity})")
    # Skip consensus, apply to all instances

  {:ok, :requires_consensus, similarity} ->
    Logger.info("Change requires consensus voting (similarity: #{similarity})")
    # Proceed to Consensus Engine
end
```

### Guardian API Reference

| Function | Purpose | Returns |
|----------|---------|---------|
| `register_change/4` | Register change for monitoring | `{:ok, change_id}` |
| `report_metrics/3` | Report real-time metrics | `{:ok, :monitored \| :threshold_breach_detected}` |
| `get_rollback_strategy/1` | Get learned rollback strategy | `{:ok, strategy}` |
| `approve_change?/1` | Check auto-approval eligibility | `{:ok, :auto_approved \| :requires_consensus, similarity}` |
| `auto_rollback_on_threshold_breach/3` | Trigger rollback | `{:ok, rollback_id}` |

### Threshold Rules

Guardian auto-rolls back changes when:
- `success_rate < 0.90` → Critical
- `error_rate > 0.10` → Critical
- `latency_p95_ms > 3000` → High
- `cost_cents > 10.0` → Medium

## Integration Point 2: Pattern Aggregator

### Purpose
Aggregates patterns discovered across all instances, computes consensus scores, and suggests relevant patterns during evolution.

### When to Use
- **After discovering a pattern** - Record it for cross-instance sharing
- **Before applying an improvement** - Suggest similar successful patterns
- **Daily (automated)** - Aggregate learnings and promote to Genesis

### Integration Flow

```elixir
# Step 1: Record discovered pattern
alias CentralCloud.Evolution.Patterns.Aggregator

{:ok, pattern_id} = Aggregator.record_pattern(
  "dev-1",                    # instance_id
  :error_handling,            # pattern_type
  %{
    name: "GenServer error recovery with exponential backoff",
    description: "Restart GenServer on crash with exponential backoff (1s, 2s, 4s, 8s)",
    code_template: """
    def handle_info(:restart, state) do
      backoff = calculate_exponential_backoff(state.restart_count)
      Process.send_after(self(), :do_restart, backoff)
      {:noreply, %{state | restart_count: state.restart_count + 1}}
    end
    """,
    metadata: %{
      language: "elixir",
      framework: "otp",
      applies_to: ["GenServer", "Supervisor"]
    }
  },
  0.96                        # success_rate on this instance
)

# Step 2: Suggest relevant patterns during evolution
current_code = """
def handle_call({:execute, task}, _from, state) do
  # Need better error handling here
  result = execute_task(task)
  {:reply, result, state}
end
"""

case Aggregator.suggest_pattern(:code_refactoring, current_code) do
  {:ok, suggestions} ->
    suggestions
    |> Enum.take(3)  # Top 3 suggestions
    |> Enum.each(fn suggestion ->
      Logger.info("Pattern suggestion: #{suggestion.name} (similarity: #{suggestion.similarity}, success: #{suggestion.success_rate})")
    end)

  {:error, reason} ->
    Logger.error("Pattern suggestion failed: #{inspect(reason)}")
end

# Step 3: Get consensus patterns (for high-confidence improvements)
{:ok, consensus_patterns} = Aggregator.get_consensus_patterns(
  :error_handling,
  threshold: 0.95,     # 95%+ consensus
  min_instances: 3     # Confirmed by 3+ instances
)

# Step 4: Aggregate learnings (daily background job)
{:ok, promoted_count} = Aggregator.aggregate_learnings()
Logger.info("Promoted #{promoted_count} patterns to Genesis")
```

### Pattern Aggregator API Reference

| Function | Purpose | Returns |
|----------|---------|---------|
| `record_pattern/4` | Record discovered pattern | `{:ok, pattern_id}` |
| `get_consensus_patterns/2` | Get high-confidence patterns | `{:ok, patterns}` |
| `suggest_pattern/2` | Semantic pattern search | `{:ok, suggestions}` |
| `aggregate_learnings/0` | Promote patterns to Genesis | `{:ok, promoted_count}` |

### Promotion Criteria (to Genesis)

Patterns are promoted when:
- `consensus_score >= 0.95`
- `success_rate >= 0.95`
- `source_instances.length >= 3`
- `usage_count >= 100`
- `promoted_to_genesis == false`

## Integration Point 3: Consensus Engine

### Purpose
Coordinates distributed voting across instances for autonomous change approval with 2/3 majority rule.

### When to Use
- **When Guardian requires consensus** - Changes that are too risky for auto-approval
- **For cross-agent changes** - Changes affecting multiple agents or all instances
- **For governance** - Transparent, auditable decision-making

### Integration Flow

```elixir
# Step 1: Propose change for consensus voting (from proposing instance)
alias CentralCloud.Evolution.Consensus.Engine, as: ConsensusEngine

{:ok, proposal_id} = ConsensusEngine.propose_change(
  "dev-1",                    # instance_id
  change_id,                  # Must be registered with Guardian first
  %{
    change_type: :pattern_enhancement,
    description: "Add error recovery pattern to all GenServers",
    affected_agents: ["elixir-specialist", "otp-expert"],
    before_code: "def handle_call...",
    after_code: "def handle_call with recovery..."
  },
  %{
    expected_improvement: "+8% success_rate",
    blast_radius: :agent_group,
    rollback_time_sec: 15,
    trial_results: %{success_rate: 0.96, latency_ms: 120}
  }
)

# Broadcast via ex_quantum_flow: "evolution_voting_requests"
# All instances receive voting request

# Step 2: Vote on proposal (from other instances)
# Each instance analyzes the proposal and votes

analysis_result = analyze_proposed_change(code_change, metadata)

vote =
  if analysis_result.safe? and analysis_result.beneficial? do
    :approve
  else
    :reject
  end

reason = """
Pattern improves error handling consistency.
Trial results show #{analysis_result.trial_results.success_rate * 100}% success rate.
Similar to existing patterns in our codebase.
Low risk (#{metadata.blast_radius}), fast rollback (#{metadata.rollback_time_sec}s).
"""

case ConsensusEngine.vote_on_change("dev-2", change_id, vote, reason) do
  {:ok, :voted} ->
    Logger.info("Vote recorded, waiting for consensus")

  {:ok, :consensus_reached} ->
    Logger.info("Consensus reached! Change will be executed")
    # Change is broadcast to all instances via ex_quantum_flow

  {:error, reason} ->
    Logger.error("Vote failed: #{inspect(reason)}")
end

# Step 3: Receive and apply approved change (all instances)
# Listen to ex_quantum_flow queue: "evolution_approved_changes"

def handle_approved_change(%{change_id: change_id, code_change: code_change}) do
  Logger.info("Applying consensus-approved change", change_id: change_id)

  # Apply the change
  apply_change_to_agents(code_change)

  # Monitor metrics
  start_metric_monitoring(change_id)
end
```

### Consensus Engine API Reference

| Function | Purpose | Returns |
|----------|---------|---------|
| `propose_change/4` | Propose change for voting | `{:ok, proposal_id}` |
| `vote_on_change/4` | Cast vote on proposal | `{:ok, :voted \| :consensus_reached}` |
| `execute_if_consensus/1` | Execute if consensus met | `{:ok, execution_id}` |

### Consensus Rules

Change is approved when:
1. **Minimum Votes**: >= 3 instances voted
2. **Majority**: >= 67% (2/3) voted "approve"
3. **Confidence**: Average confidence >= 0.85
4. **No Strong Rejections**: No vote with confidence > 0.90 and vote = "reject"

## Complete Evolution Flow Example

```elixir
defmodule Singularity.Agents.Evolution.CentralizedFlow do
  @moduledoc """
  Complete flow showing integration with CentralCloud evolution services.
  """

  alias CentralCloud.Evolution.Guardian.RollbackService
  alias CentralCloud.Evolution.Patterns.Aggregator
  alias CentralCloud.Evolution.Consensus.Engine, as: ConsensusEngine

  def evolve_agent_with_central_coordination(agent_id, improvement_suggestion) do
    # Phase 1: Pattern Discovery & Suggestion
    current_code = get_agent_code(agent_id)

    case Aggregator.suggest_pattern(:code_refactoring, current_code) do
      {:ok, [top_pattern | _]} ->
        Logger.info("Using consensus pattern: #{top_pattern.name}")
        improvement = build_improvement_from_pattern(top_pattern)

      {:ok, []} ->
        Logger.info("No consensus patterns, using original suggestion")
        improvement = improvement_suggestion
    end

    # Phase 2: Guardian Registration & Safety Check
    change_id = Ecto.UUID.generate()

    {:ok, ^change_id} = RollbackService.register_change(
      instance_id(),
      change_id,
      %{
        change_type: improvement.type,
        before_code: current_code,
        after_code: improvement.code,
        agent_id: agent_id
      },
      %{
        risk_level: improvement.risk_level,
        blast_radius: improvement.blast_radius,
        reversibility: :automatic,
        test_coverage: 0.95,
        similar_changes_success_rate: improvement.pattern_success_rate || 0.85
      }
    )

    # Phase 3: Guardian Auto-Approval Check
    case RollbackService.approve_change?(change_id) do
      {:ok, :auto_approved, similarity} ->
        Logger.info("✅ Guardian auto-approved (similarity: #{similarity})")
        apply_and_monitor_change(agent_id, change_id, improvement)

      {:ok, :requires_consensus, _similarity} ->
        Logger.info("🗳️  Requires consensus voting")

        # Phase 4: Consensus Voting
        {:ok, proposal_id} = ConsensusEngine.propose_change(
          instance_id(),
          change_id,
          %{
            change_type: improvement.type,
            description: improvement.description,
            affected_agents: [agent_id],
            before_code: current_code,
            after_code: improvement.code
          },
          %{
            expected_improvement: improvement.expected_improvement,
            blast_radius: improvement.blast_radius,
            rollback_time_sec: 15,
            trial_results: improvement.trial_results
          }
        )

        Logger.info("Proposal #{proposal_id} submitted for voting")
        {:ok, :pending_consensus, proposal_id}

      {:error, reason} ->
        Logger.error("❌ Guardian rejected change: #{inspect(reason)}")
        {:error, :guardian_rejected, reason}
    end
  end

  defp apply_and_monitor_change(agent_id, change_id, improvement) do
    # Apply improvement
    apply_improvement_to_agent(agent_id, improvement)

    # Start metric monitoring (report to Guardian every 30s)
    Task.start(fn ->
      monitor_and_report_metrics(agent_id, change_id)
    end)

    {:ok, :applied, change_id}
  end

  defp monitor_and_report_metrics(agent_id, change_id) do
    Stream.interval(30_000)
    |> Stream.take(20)  # Monitor for 10 minutes
    |> Enum.each(fn _ ->
      metrics = %{
        success_rate: get_agent_success_rate(agent_id),
        error_rate: get_agent_error_rate(agent_id),
        latency_p95_ms: get_agent_latency_p95(agent_id),
        cost_cents: get_agent_avg_cost(agent_id),
        throughput_per_min: get_agent_throughput(agent_id),
        timestamp: DateTime.utc_now()
      }

      case RollbackService.report_metrics(instance_id(), change_id, metrics) do
        {:ok, :threshold_breach_detected} ->
          Logger.warning("⚠️  Guardian triggered auto-rollback!")
          # Rollback handled by Guardian, stop monitoring
          :halt

        {:ok, :monitored} ->
          Logger.debug("Metrics OK")
          :continue
      end
    end)
  end

  # Consensus voting handler (called when proposal arrives)
  def handle_voting_request(%{change_id: change_id, code_change: code_change, metadata: metadata}) do
    # Analyze the proposal
    analysis = analyze_change_safety(code_change, metadata)

    vote =
      cond do
        analysis.high_risk? -> :reject
        analysis.beneficial? and analysis.safe? -> :approve
        true -> :reject
      end

    reason = build_vote_reasoning(analysis, code_change, metadata)

    ConsensusEngine.vote_on_change(instance_id(), change_id, vote, reason)
  end

  # Approved change handler (called when consensus reached)
  def handle_approved_change(%{change_id: change_id, code_change: code_change}) do
    Logger.info("Applying consensus-approved change", change_id: change_id)

    # Apply change to affected agents
    Enum.each(code_change.affected_agents, fn agent_id ->
      apply_improvement_to_agent(agent_id, code_change)
    end)

    # Start monitoring
    Task.start(fn ->
      monitor_and_report_metrics(hd(code_change.affected_agents), change_id)
    end)
  end

  defp instance_id, do: Application.get_env(:singularity, :instance_id, "dev-1")
end
```

## ex_quantum_flow Queue Integration

### Required Queues

| Queue Name | Direction | Purpose |
|------------|-----------|---------|
| `evolution_voting_requests` | CentralCloud → Instances | Broadcast voting requests |
| `evolution_approved_changes` | CentralCloud → Instances | Broadcast approved changes |
| `guardian_rollback_commands` | CentralCloud → Instances | Broadcast rollback commands |
| `pattern_discoveries` | Instances → CentralCloud | Report discovered patterns |
| `genesis_rule_proposals` | CentralCloud → Genesis | Promote patterns to Genesis |

### Queue Listeners (Singularity Instance)

```elixir
# In Singularity.Application

children = [
  # Listen for voting requests
  {QuantumFlow.Consumer,
   queue: "evolution_voting_requests",
   handler: Singularity.Evolution.VotingHandler},

  # Listen for approved changes
  {QuantumFlow.Consumer,
   queue: "evolution_approved_changes",
   handler: Singularity.Evolution.ApprovedChangeHandler},

  # Listen for rollback commands
  {QuantumFlow.Consumer,
   queue: "guardian_rollback_commands",
   handler: Singularity.Evolution.RollbackHandler}
]
```

## Background Jobs (Singularity)

```elixir
# In config/config.exs

config :singularity, Oban,
  queues: [
    evolution: 5
  ],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Report discovered patterns to CentralCloud (every 5 minutes)
       {"*/5 * * * *", Singularity.Jobs.PatternReportWorker},

       # Monitor active changes (every 30 seconds)
       {"*/30 * * * * *", Singularity.Jobs.ChangeMonitorWorker}
     ]}
  ]
```

## Decision Tree: When to Use Each Service

```
┌─────────────────────────────────────┐
│  Agent Evolution Triggered          │
└───────────────┬─────────────────────┘
                │
                ▼
        ┌───────────────┐
        │ Record Pattern│◀──── If pattern discovered
        │  (Aggregator) │
        └───────────────┘
                │
                ▼
        ┌───────────────┐
        │Register Change│◀──── Always, before applying
        │   (Guardian)  │
        └───────┬───────┘
                │
                ▼
        ┌───────────────────┐
        │ Auto-Approve?     │
        │   (Guardian)      │
        └────┬──────────┬───┘
             │          │
         Yes │          │ No
             │          │
             ▼          ▼
    ┌────────────┐  ┌──────────────┐
    │   Apply    │  │   Propose    │
    │ Immediately│  │  (Consensus) │
    └─────┬──────┘  └──────┬───────┘
          │                │
          │                ▼
          │         ┌──────────────┐
          │         │ Voting       │
          │         │ (Consensus)  │
          │         └──────┬───────┘
          │                │
          │                ▼
          │         ┌──────────────┐
          │         │ Consensus?   │
          │         └──┬────────┬──┘
          │            │        │
          │        Yes │        │ No
          │            │        │
          │            ▼        ▼
          │    ┌────────────┐ ┌────────┐
          │    │  Execute   │ │ Reject │
          │    └─────┬──────┘ └────────┘
          │          │
          └──────────┘
                     │
                     ▼
            ┌────────────────┐
            │ Monitor Metrics│◀──── Always, after applying
            │   (Guardian)   │
            └────────┬───────┘
                     │
                     ▼
            ┌────────────────┐
            │ Threshold      │
            │ Breach?        │
            └────┬──────┬────┘
                 │      │
             Yes │      │ No
                 │      │
                 ▼      ▼
        ┌────────────┐ ┌──────────┐
        │  Rollback  │ │ Continue │
        │ (Guardian) │ │Monitoring│
        └────────────┘ └──────────┘
```

## Summary

| Service | When to Use | Key Functions |
|---------|-------------|---------------|
| **Guardian** | Before/during/after every change | `register_change/4`, `report_metrics/3`, `approve_change?/1` |
| **Pattern Aggregator** | When discovering/suggesting patterns | `record_pattern/4`, `suggest_pattern/2`, `get_consensus_patterns/2` |
| **Consensus Engine** | For risky/cross-instance changes | `propose_change/4`, `vote_on_change/4` |

**All three services work together** to provide:
- **Safety** (Guardian monitors and auto-rolls back)
- **Intelligence** (Pattern Aggregator learns and suggests)
- **Governance** (Consensus Engine democratizes decisions)

## Next Steps

1. **Run migration**: `cd nexus/central_services && mix ecto.migrate`
2. **Add to supervision tree**: Update `CentralCloud.Application`
3. **Configure ex_quantum_flow queues**: Set up queue listeners
4. **Test integration**: Use example code to evolve an agent
5. **Monitor dashboards**: Check Observer for real-time evolution metrics
