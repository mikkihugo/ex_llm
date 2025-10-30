# Evolution System + ex_pgflow Integration Guide

**Purpose:** Replace direct function calls with durable message queues for distributed messaging

---

## Why ex_pgflow?

Current implementation makes **direct function calls** between instances and CentralCloud:
```elixir
# ❌ Synchronous, fragile
ConsensusEngine.propose_change(instance_id, change_id, ...)
```

Problems:
- ❌ No retry on failure
- ❌ No message persistence
- ❌ No ordering guarantees
- ❌ Synchronous blocks execution
- ❌ If CentralCloud is down, proposal hangs

**Solution: Use ex_pgflow queues** for asynchronous, durable messaging:
```elixir
# ✅ Asynchronous, durable, reliable
PgflowQueues.propose_for_consensus(proposal_id, ...)
# Message persists in DB, retried automatically
```

---

## Queue Architecture

```
Singularity Instance
├─ LOCAL: proposals (ETS cache)
├─ PGFLOW → proposals_for_consensus_queue
│           (async, durable, retried)
│           ↓
├─ PGFLOW ← consensus_results_queue
│           (results from CentralCloud)
│           ↓
├─ PGFLOW → proposals_for_execution_queue
├─ PGFLOW → metrics_to_guardian_queue
│           ↓
└─ PGFLOW ← rollback_triggers_queue
           (from Guardian)

CentralCloud
├─ PGFLOW → proposals_for_consensus_queue (receives)
├─ PGFLOW ← consensus_results_queue (sends)
├─ PGFLOW → metrics_to_guardian_queue (receives)
├─ PGFLOW ← guardian_safety_profiles_queue (sends)
├─ PGFLOW → patterns_for_aggregator_queue (receives)
├─ PGFLOW ← rollback_triggers_queue (sends)
└─ PGFLOW → learning_loop_queue (receives)
```

---

## Message Types

### 1. Proposal → Consensus
**Queue:** `proposals_for_consensus_queue`

```elixir
%{
  type: "proposal_for_consensus",
  proposal_id: "123e4567-e89b-12d3-a456-426614174000",
  instance_id: "singularity_1",
  agent_type: "BugFixerAgent",
  code_change: %{file: "...", change: "..."},
  impact_score: 8.0,
  risk_score: 1.0,
  safety_profile: %{success_rate: 0.95, cost_factor: 2.0},
  timestamp: DateTime.utc_now(),
  retry_count: 0,
  max_retries: 3
}
```

**Producers:** Singularity (ProposalQueue)
**Consumers:** CentralCloud (ConsensusEngine)

---

### 2. Consensus Result → Instance
**Queue:** `consensus_results_queue`

```elixir
%{
  type: "consensus_result",
  proposal_id: "123e4567-e89b-12d3-a456-426614174000",
  instance_id: "singularity_1",
  status: "approved",  # or "rejected"
  votes: %{
    singularity_1: "approve",
    singularity_2: "approve",
    singularity_3: "reject"
  },
  confidence: 0.95,
  decision_rationale: "Similar to pattern_X",
  timestamp: DateTime.utc_now()
}
```

**Producers:** CentralCloud (ConsensusEngine)
**Consumers:** Singularity (ProposalQueue)

---

### 3. Metrics → Guardian
**Queue:** `metrics_to_guardian_queue`

```elixir
%{
  type: "execution_metrics",
  proposal_id: "123e4567-e89b-12d3-a456-426614174000",
  instance_id: "singularity_1",
  agent_type: "BugFixerAgent",
  metrics_before: %{cpu_usage: 45.2, memory: 512.0, error_count: 2},
  metrics_after: %{cpu_usage: 46.1, memory: 513.5, error_count: 3},
  status: "executing",
  timestamp: DateTime.utc_now()
}
```

**Producers:** Singularity (ExecutionFlow)
**Consumers:** CentralCloud (Guardian)

---

### 4. Pattern → Aggregator
**Queue:** `patterns_for_aggregator_queue`

```elixir
%{
  type: "pattern_discovered",
  instance_id: "singularity_1",
  pattern_type: "refactoring",  # or "optimization", "bug_fix"
  code_pattern: %{
    before: "...",
    after: "...",
    description: "Extract function for readability"
  },
  success_rate: 0.97,
  agent_type: "RefactoringAgent",
  timestamp: DateTime.utc_now()
}
```

**Producers:** Singularity (PatternMiner/Analysis)
**Consumers:** CentralCloud (PatternAggregator)

---

### 5. Rollback Trigger → Instance
**Queue:** `rollback_triggers_queue`

```elixir
%{
  type: "rollback_trigger",
  proposal_id: "123e4567-e89b-12d3-a456-426614174000",
  instance_id: "singularity_1",
  reason: "error_rate_breach",
  threshold: %{error_rate: 0.10, actual: 0.15},
  timestamp: DateTime.utc_now()
}
```

**Producers:** CentralCloud (Guardian)
**Consumers:** Singularity (ProposalQueue)

---

### 6. Safety Profile Update → Instance
**Queue:** `guardian_safety_profiles_queue`

```elixir
%{
  type: "safety_profile_update",
  instance_id: "singularity_1",
  agent_type: "BugFixerAgent",
  safety_profile: %{
    success_rate: 0.99,
    error_threshold: 0.10,
    latency_threshold: 3000,
    cost_threshold: 0.10
  },
  source: "genesis_learning_loop",
  timestamp: DateTime.utc_now()
}
```

**Producers:** CentralCloud (PatternLearningLoop)
**Consumers:** Singularity (AgentCoordinator)

---

### 7. Learning Loop Complete → Genesis
**Queue:** `learning_loop_completed_queue`

```elixir
%{
  type: "learning_loop_completed",
  patterns_processed: 5,
  rules_generated: 2,
  thresholds_updated: 3,
  timestamp: DateTime.utc_now()
}
```

**Producers:** CentralCloud (PatternLearningLoop)
**Consumers:** Genesis (RuleEngine)

---

## Implementation Steps

### Step 1: Define Queue Configuration

**File:** `config/config.exs`

```elixir
# Add to Singularity config
config :singularity, :pgflow_queues,
  producers: [
    {:proposals_for_consensus, "postgres://...", [workers: 2]},
    {:metrics_to_guardian, "postgres://...", [workers: 2]},
    {:patterns_for_aggregator, "postgres://...", [workers: 1]}
  ],
  consumers: [
    {:consensus_results_consumer, "postgres://...", [workers: 2]},
    {:rollback_triggers_consumer, "postgres://...", [workers: 1]},
    {:safety_profiles_consumer, "postgres://...", [workers: 1]}
  ]

# Add to CentralCloud config
config :centralcloud, :pgflow_queues,
  producers: [
    {:consensus_results, "postgres://...", [workers: 2]},
    {:rollback_triggers, "postgres://...", [workers: 1]},
    {:guardian_safety_profiles, "postgres://...", [workers: 1]}
  ],
  consumers: [
    {:proposals_consumer, "postgres://...", [workers: 3]},
    {:metrics_consumer, "postgres://...", [workers: 2]},
    {:patterns_consumer, "postgres://...", [workers: 1]}
  ]
```

### Step 2: Create Producer Modules

**File:** `lib/singularity/evolution/pgflow_producers.ex`

```elixir
defmodule Singularity.Evolution.PgflowProducers do
  @moduledoc """
  Producers for sending messages to CentralCloud via pgflow queues.
  """

  require Logger

  @doc "Publish proposal to consensus queue"
  def propose_for_consensus(proposal) do
    message = %{
      type: "proposal_for_consensus",
      proposal_id: proposal.id,
      instance_id: instance_id(),
      agent_type: proposal.agent_type,
      code_change: proposal.code_change,
      impact_score: proposal.impact_score,
      risk_score: proposal.risk_score,
      safety_profile: proposal.safety_profile,
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :singularity,
      "proposals_for_consensus_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.info("Published proposal #{proposal.id} with message_id #{message_id}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.error("Failed to publish proposal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Publish metrics to Guardian"
  def report_metrics_to_guardian(proposal, metrics_before, metrics_after) do
    message = %{
      type: "execution_metrics",
      proposal_id: proposal.id,
      instance_id: instance_id(),
      agent_type: proposal.agent_type,
      metrics_before: metrics_before,
      metrics_after: metrics_after,
      status: proposal.status,
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :singularity,
      "metrics_to_guardian_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.debug("Published metrics for proposal #{proposal.id}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.warn("Failed to publish metrics: #{inspect(reason)}")
        # Don't fail execution if metrics publishing fails
        {:ok, :async}
    end
  end

  @doc "Publish pattern to Aggregator"
  def report_pattern_to_aggregator(pattern_type, code_pattern, success_rate, agent_type) do
    message = %{
      type: "pattern_discovered",
      instance_id: instance_id(),
      pattern_type: pattern_type,
      code_pattern: code_pattern,
      success_rate: success_rate,
      agent_type: agent_type,
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :singularity,
      "patterns_for_aggregator_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.debug("Published pattern of type #{pattern_type}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.warn("Failed to publish pattern: #{inspect(reason)}")
        {:ok, :async}
    end
  end

  defp instance_id do
    System.get_env("INSTANCE_ID", "singularity_default")
  end
end
```

### Step 3: Create Consumer Modules

**File:** `lib/singularity/evolution/pgflow_consumers.ex`

```elixir
defmodule Singularity.Evolution.PgflowConsumers do
  @moduledoc """
  Consumers for handling messages from CentralCloud via pgflow queues.
  """

  require Logger
  alias Singularity.Evolution.ProposalQueue

  @doc "Handle consensus result from CentralCloud"
  def handle_consensus_result(message) do
    Logger.info("Received consensus result for proposal #{message.proposal_id}")

    case message do
      %{"status" => "approved", "proposal_id" => proposal_id} ->
        # Mark as consensus_reached and execute
        ProposalQueue.check_consensus_result(proposal_id)
        {:ok, "processed"}

      %{"status" => "rejected", "proposal_id" => proposal_id} ->
        # Mark as consensus_failed
        case ProposalQueue.get_proposal(proposal_id) do
          {:ok, proposal} ->
            updated = Singularity.Schemas.Evolution.Proposal.mark_consensus_failed(
              proposal,
              message["votes"]
            )
            Singularity.Repo.update(updated)
            {:ok, "processed"}

          _ ->
            {:error, "proposal not found"}
        end

      _ ->
        Logger.warn("Invalid consensus result message: #{inspect(message)}")
        {:error, "invalid message"}
    end
  end

  @doc "Handle rollback trigger from Guardian"
  def handle_rollback_trigger(message) do
    Logger.warn("Received rollback trigger for proposal #{message.proposal_id}")

    case ProposalQueue.get_proposal(message.proposal_id) do
      {:ok, proposal} ->
        # Revert code change, mark as rolled_back
        updated = Singularity.Schemas.Evolution.Proposal.mark_rolled_back(
          proposal,
          message["reason"]
        )
        Singularity.Repo.update(updated)
        {:ok, "rolled_back"}

      _ ->
        {:error, "proposal not found"}
    end
  end

  @doc "Handle safety profile update from Guardian"
  def handle_safety_profile_update(message) do
    Logger.info("Received safety profile update for #{message.agent_type}")

    # Cache in SafetyProfiles
    Singularity.Evolution.SafetyProfiles.update_from_central(
      message.agent_type,
      message.safety_profile
    )

    {:ok, "updated"}
  end
end
```

### Step 4: Update ProposalQueue to Use PgFlow

**File:** `lib/singularity/evolution/proposal_queue.ex` (update `broadcast_to_consensus`)

```elixir
# Replace this:
defp broadcast_to_consensus(proposal) do
  Logger.debug("Broadcasting proposal #{proposal.id} to CentralCloud.Consensus")

  try do
    case ConsensusEngine.propose_change(...) do  # ❌ Direct call
      {:ok, _} -> ...
    end
  rescue
    e -> ...
  end
end

# With this:
defp broadcast_to_consensus(proposal) do
  Logger.debug("Publishing proposal #{proposal.id} to consensus queue via pgflow")

  case Singularity.Evolution.PgflowProducers.propose_for_consensus(proposal) do
    {:ok, _message_id} ->
      Logger.info("Proposal published successfully")
      :ok

    {:error, reason} ->
      Logger.error("Failed to publish proposal: #{inspect(reason)}")
      # Will retry via pgflow backoff
      {:error, reason}
  end
end
```

### Step 5: Update ExecutionFlow to Use PgFlow

**File:** `lib/singularity/evolution/execution_flow.ex` (update `report_to_guardian`)

```elixir
# Replace this:
defp report_to_guardian(proposal, metrics_before, metrics_after) do
  instance_id = "singularity_#{System.get_env("INSTANCE_ID", "default")}"

  metrics = %{...}

  case RollbackService.report_metrics(instance_id, proposal.id, metrics) do  # ❌ Direct call
    {:ok, _} -> ...
  end
end

# With this:
defp report_to_guardian(proposal, metrics_before, metrics_after) do
  Logger.debug("Publishing metrics to Guardian via pgflow")

  case Singularity.Evolution.PgflowProducers.report_metrics_to_guardian(
    proposal,
    metrics_before,
    metrics_after
  ) do
    {:ok, _message_id} ->
      Logger.debug("Metrics published successfully")
      :ok

    {:error, reason} ->
      Logger.warn("Failed to publish metrics: #{inspect(reason)}")
      # Metrics reporting is non-blocking
      :ok
  end
end
```

### Step 6: Create CentralCloud Consumers

**File:** `lib/centralcloud/evolution/pgflow_consumers.ex`

```elixir
defmodule CentralCloud.Evolution.PgflowConsumers do
  @moduledoc """
  Consumers for handling messages from Singularity instances via pgflow.
  """

  require Logger

  alias CentralCloud.Consensus.Engine
  alias CentralCloud.Guardian.RollbackService
  alias CentralCloud.Patterns.PatternAggregator

  @doc "Handle proposal for consensus from instance"
  def handle_proposal_for_consensus(message) do
    Logger.info("Received proposal #{message.proposal_id} for consensus")

    case Engine.propose_change(
      message.instance_id,
      message.proposal_id,
      message.code_change,
      %{
        agent_type: message.agent_type,
        impact_score: message.impact_score,
        risk_score: message.risk_score,
        safety_profile: message.safety_profile
      }
    ) do
      {:ok, _} ->
        {:ok, "proposal_recorded"}

      {:error, reason} ->
        Logger.error("Failed to record proposal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Handle metrics from instance"
  def handle_execution_metrics(message) do
    Logger.debug("Received metrics for proposal #{message.proposal_id}")

    case RollbackService.report_metrics(
      message.instance_id,
      message.proposal_id,
      message.metrics_before,
      message.metrics_after,
      message.status
    ) do
      {:ok, _} ->
        {:ok, "metrics_recorded"}

      {:error, reason} ->
        Logger.warn("Failed to record metrics: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Handle pattern from instance"
  def handle_pattern_discovered(message) do
    Logger.info("Received pattern from #{message.instance_id}")

    case PatternAggregator.record_pattern(
      message.instance_id,
      message.pattern_type,
      message.code_pattern,
      success_rate: message.success_rate,
      agent_type: message.agent_type
    ) do
      {:ok, _} ->
        {:ok, "pattern_recorded"}

      {:error, reason} ->
        Logger.warn("Failed to record pattern: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

### Step 7: Create CentralCloud Producers

**File:** `lib/centralcloud/evolution/pgflow_producers.ex`

```elixir
defmodule CentralCloud.Evolution.PgflowProducers do
  @moduledoc """
  Producers for sending messages to Singularity instances via pgflow.
  """

  require Logger

  @doc "Send consensus result to instance"
  def send_consensus_result(instance_id, proposal_id, status, votes, confidence) do
    message = %{
      type: "consensus_result",
      proposal_id: proposal_id,
      instance_id: instance_id,
      status: status,  # "approved" or "rejected"
      votes: votes,
      confidence: confidence,
      decision_rationale: "Multi-instance consensus voting",
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :centralcloud,
      "consensus_results_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.info("Published consensus result for proposal #{proposal_id}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.error("Failed to publish consensus result: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Send rollback trigger to instance"
  def send_rollback_trigger(instance_id, proposal_id, reason, threshold_details) do
    message = %{
      type: "rollback_trigger",
      proposal_id: proposal_id,
      instance_id: instance_id,
      reason: reason,
      threshold: threshold_details,
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :centralcloud,
      "rollback_triggers_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.warn("Published rollback trigger for proposal #{proposal_id}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.error("Failed to publish rollback: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Send safety profile update to instance"
  def send_safety_profile_update(instance_id, agent_type, safety_profile) do
    message = %{
      type: "safety_profile_update",
      instance_id: instance_id,
      agent_type: agent_type,
      safety_profile: safety_profile,
      source: "genesis_learning_loop",
      timestamp: DateTime.utc_now()
    }

    case ExPgflow.publish(
      :centralcloud,
      "guardian_safety_profiles_queue",
      message
    ) do
      {:ok, message_id} ->
        Logger.info("Published safety profile update for #{agent_type}")
        {:ok, message_id}

      {:error, reason} ->
        Logger.warn("Failed to publish safety profile: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

---

## Benefits of This Approach

### Reliability
✅ **Persistent** - Messages survive service restarts
✅ **Retry-able** - Automatic retry on failure with backoff
✅ **Ordered** - FIFO ordering within each queue
✅ **Transactional** - All-or-nothing processing

### Scalability
✅ **Async** - Non-blocking message publishing
✅ **Batching** - Process multiple messages at once
✅ **Distributed** - Scales across instances naturally
✅ **Load balancing** - Consumers can scale independently

### Observability
✅ **Traceable** - Every message has timestamp and ID
✅ **Auditable** - Full message history in DB
✅ **Monitorable** - Queue depth metrics
✅ **Debuggable** - Dead-letter queues for failed messages

### Decoupling
✅ **Loose coupling** - Services don't need to know about each other
✅ **Independent scaling** - Producers and consumers independent
✅ **Resilient** - One service down doesn't block others
✅ **Flexible** - Easy to add new consumers/producers

---

## Testing with PgFlow

```elixir
# Test publishing a proposal
{:ok, msg_id} = PgflowProducers.propose_for_consensus(proposal)
assert msg_id

# Verify message in queue
messages = ExPgflow.list_messages("proposals_for_consensus_queue")
assert Enum.any?(messages, &(&1.proposal_id == proposal.id))

# Manually consume and process
message = Enum.find(messages, ...)
{:ok, status} = PgflowConsumers.handle_proposal_for_consensus(message)
assert status == "proposal_recorded"

# Verify instance received consensus result
received_messages = ExPgflow.list_messages("consensus_results_queue")
assert Enum.any?(received_messages, &(&1.proposal_id == proposal.id))
```

---

## Configuration

**Environment variables:**
```bash
# Database for pgflow queues (can be same as app DB)
export PGFLOW_DATABASE_URL=postgresql://user:pass@localhost/singularity

# Queue configuration
export PGFLOW_QUEUE_WORKERS=2
export PGFLOW_MESSAGE_RETRY_DELAY=1000  # ms
export PGFLOW_MESSAGE_MAX_RETRIES=3
```

---

## Migration Path

### Phase 1: Add PgFlow Alongside (Backward Compatible)
- [x] Define new PgflowProducers and PgflowConsumers
- [x] Keep old direct calls working
- [x] Both work in parallel

### Phase 2: Migrate ProposalQueue
- [ ] Update `broadcast_to_consensus` to use PgflowProducers
- [ ] Update `check_consensus_from_centralcloud` to listen to PgflowConsumers
- [ ] Keep fallback to direct calls if queue unavailable

### Phase 3: Migrate ExecutionFlow & Guardian
- [ ] Update metrics reporting to use PgflowProducers
- [ ] Update Guardian to consume metrics via queue
- [ ] Update rollback trigger handling

### Phase 4: Migrate Patterns & Learning Loop
- [ ] Report patterns via queue
- [ ] Consume patterns in Aggregator
- [ ] Complete learning loop via queue

### Phase 5: Remove Direct Calls (Cleanup)
- [ ] Verify all Pgflow flows working
- [ ] Remove old direct call code
- [ ] Simplify service interfaces

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Messaging** | Direct function calls | Durable queues |
| **Reliability** | No retry on failure | Automatic retry with backoff |
| **Persistence** | Lost if service down | Survives restarts |
| **Ordering** | No ordering | FIFO per queue |
| **Decoupling** | Tight coupling | Loose coupling |
| **Scalability** | Limited | Scales independently |
| **Observability** | No history | Full message audit trail |

**Next step:** Implement PgFlow integration in phases, starting with proposal broadcasting and consensus results.
