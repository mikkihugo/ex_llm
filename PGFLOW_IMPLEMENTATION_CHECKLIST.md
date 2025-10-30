# PgFlow Integration Implementation Checklist

**Status:** Phase 1-3 Implementation Plan

---

## Phase 1: Foundation (2-3 hours)

### ✅ Code Implementation
- [x] Create `Singularity.Evolution.QuantumFlow.Producers` module
  - [x] `propose_for_consensus/1`
  - [x] `report_metrics_to_guardian/3`
  - [x] `report_pattern_to_aggregator/4`

- [x] Create `Singularity.Evolution.QuantumFlow.Consumers` module
  - [x] `handle_consensus_result/1`
  - [x] `handle_rollback_trigger/1`
  - [x] `handle_safety_profile_update/1`

- [x] Create `CentralCloud.Evolution.QuantumFlow.Producers` module
  - [x] `send_consensus_result/5`
  - [x] `send_rollback_trigger/4`
  - [x] `send_safety_profile_update/3`

- [x] Create `CentralCloud.Evolution.QuantumFlow.Consumers` module
  - [x] `handle_proposal_for_consensus/1`
  - [x] `handle_execution_metrics/1`
  - [x] `handle_pattern_discovered/1`

### ⏳ Configuration
- [ ] Add `ex_quantum_flow` to `mix.exs` (both projects)
  ```elixir
  {:ex_quantum_flow, "~> 0.1"}
  ```

- [ ] Create PgFlow configuration in `config/config.exs` (Singularity)
  - [ ] Producer queues (proposals, metrics, patterns)
  - [ ] Consumer queues (consensus_results, rollback_triggers, safety_profiles)
  - [ ] Telemetry events

- [ ] Create PgFlow configuration in `config/config.exs` (CentralCloud)
  - [ ] Producer queues (consensus_results, rollback_triggers, safety_profiles)
  - [ ] Consumer queues (proposals, metrics, patterns)
  - [ ] Telemetry events

- [ ] Set environment variables (.env or export)
  ```bash
  export PGFLOW_DATABASE_URL=postgresql://user:pass@localhost/singularity
  export PGFLOW_PROPOSALS_WORKERS=2
  export PGFLOW_METRICS_WORKERS=2
  # ... etc
  ```

- [ ] Run PgFlow migrations
  ```bash
  cd nexus/singularity && mix QuantumFlow.init
  cd ../central_services && mix QuantumFlow.init
  ```

### ⏳ Supervision Tree
- [ ] Update `Singularity.Application`
  - [ ] Add ExQuantumFlow.Consumer to supervision tree
  - [ ] Configure with consumers from config

- [ ] Update `CentralCloud.Application`
  - [ ] Add ExQuantumFlow.Consumer to supervision tree
  - [ ] Configure with consumers from config

### ⏳ Testing
- [ ] Unit test Singularity.Producers
  - [ ] Mock ExQuantumFlow.publish
  - [ ] Verify message format
  - [ ] Test error handling

- [ ] Unit test Singularity.Consumers
  - [ ] Test each handler with valid messages
  - [ ] Test invalid message rejection
  - [ ] Test database updates

- [ ] Unit test CentralCloud.Producers
  - [ ] Mock ExQuantumFlow.publish
  - [ ] Test message formats

- [ ] Unit test CentralCloud.Consumers
  - [ ] Test proposal reception
  - [ ] Test metrics recording
  - [ ] Test pattern collection

---

## Phase 2: Migrate ProposalQueue (2-3 hours)

### ⏳ Update ProposalQueue

**File:** `nexus/singularity/lib/singularity/evolution/proposal_queue.ex`

#### Change 1: Update `broadcast_to_consensus` method

**Before:**
```elixir
defp broadcast_to_consensus(proposal) do
  Logger.debug("Broadcasting proposal #{proposal.id} to CentralCloud.Consensus")

  try do
    case ConsensusEngine.propose_change(
      "singularity_#{System.get_env("INSTANCE_ID", "default")}",
      proposal.id,
      proposal.code_change,
      %{...}
    ) do
      {:ok, _} ->
        Logger.info("Proposal sent to consensus successfully")

      {:error, reason} ->
        Logger.error("Failed to send to consensus: #{inspect(reason)}")
    end
  rescue
    e ->
      Logger.error("Exception broadcasting to consensus: #{inspect(e)}")
  end
end
```

**After:**
```elixir
defp broadcast_to_consensus(proposal) do
  Logger.debug("Publishing proposal #{proposal.id} to consensus queue via QuantumFlow")

  case Singularity.Evolution.QuantumFlow.Producers.propose_for_consensus(proposal) do
    {:ok, _message_id} ->
      Logger.info("Proposal published to consensus queue successfully")
      :ok

    {:error, reason} ->
      Logger.error("Failed to publish proposal: #{inspect(reason)}")
      {:error, reason}
  end
end
```

**Steps to implement:**
1. [ ] Update imports to use QuantumFlow.Producers instead of ConsensusEngine
2. [ ] Change function call to use producers
3. [ ] Remove try-rescue (handled by QuantumFlow)
4. [ ] Test locally with single instance

#### Change 2: Update consensus checking

**Before:**
```elixir
defp check_consensus_from_centralcloud(proposal) do
  Logger.debug("Checking consensus result from CentralCloud for #{proposal.id}")

  try do
    case ConsensusEngine.get_consensus_result(proposal.id) do
      {:ok, %{status: "approved", votes: votes}} ->
        # ... process result
      # ... etc
    end
  rescue
    e ->
      Logger.error("Exception checking consensus: #{inspect(e)}")
  end
end
```

**After:**
```elixir
# Consumers now handle this automatically via QuantumFlow!
# When CentralCloud sends consensus result, Consumers.handle_consensus_result
# processes it and marks proposal as consensus_reached or consensus_failed.

# This is now automatic - remove the check_consensus_from_centralcloud method entirely
# or simplify to just logging/monitoring
```

**Steps:**
1. [ ] Remove `check_consensus_from_centralcloud/1` method
2. [ ] Remove `:check_consensus` handle_info
3. [ ] Remove consensus check scheduling

### ⏳ Integration Testing

- [ ] Test locally: submit proposal → receives consensus result via QuantumFlow
- [ ] Test with 2 instances: instance 1 proposes, instance 2 receives
- [ ] Test message retry: stop service during consensus, verify retry works
- [ ] Test queue monitoring: view pending messages in database

---

## Phase 3: Migrate ExecutionFlow & Guardian (2-3 hours)

### ⏳ Update ExecutionFlow

**File:** `nexus/singularity/lib/singularity/evolution/execution_flow.ex`

#### Change: Update `report_to_guardian` method

**Before:**
```elixir
defp report_to_guardian(proposal, metrics_before, metrics_after) do
  Logger.debug("Reporting execution metrics to Guardian for proposal #{proposal.id}")

  instance_id = "singularity_#{System.get_env("INSTANCE_ID", "default")}"

  metrics = %{
    proposal_id: proposal.id,
    agent_type: proposal.agent_type,
    # ... metrics
  }

  case RollbackService.report_metrics(instance_id, proposal.id, metrics) do
    {:ok, _} ->
      Logger.debug("Metrics reported successfully")
      :ok

    {:error, reason} ->
      Logger.warn("Failed to report metrics: #{inspect(reason)}")
      :ok
  end
end
```

**After:**
```elixir
defp report_to_guardian(proposal, metrics_before, metrics_after) do
  Logger.debug("Publishing execution metrics to Guardian via QuantumFlow")

  case Singularity.Evolution.QuantumFlow.Producers.report_metrics_to_guardian(
    proposal,
    metrics_before,
    metrics_after
  ) do
    {:ok, _message_id} ->
      Logger.debug("Metrics published successfully")
      :ok

    {:error, reason} ->
      Logger.warn("Failed to publish metrics: #{inspect(reason)}")
      # Non-blocking - don't fail execution
      :ok
  end
end
```

**Steps:**
1. [ ] Update import to use QuantumFlow.Producers
2. [ ] Remove direct call to RollbackService
3. [ ] Change to use producers
4. [ ] Test metrics flow

### ⏳ Update Guardian (CentralCloud)

**File:** `nexus/central_services/lib/centralcloud/guardian/rollback_service.ex`

#### Change: Update rollback triggering

When Guardian detects a threshold breach, instead of directly calling Singularity service:

**Before:**
```elixir
# Direct call to Singularity (won't work in distributed setup)
Singularity.Evolution.ProposalQueue.trigger_rollback(proposal_id)
```

**After:**
```elixir
# Use PgFlow to send rollback trigger
CentralCloud.Evolution.QuantumFlow.Producers.send_rollback_trigger(
  instance_id,
  proposal_id,
  "error_rate_breach",
  %{error_rate: 0.15, threshold: 0.10}
)
```

**Steps:**
1. [ ] Find all places in Guardian that trigger rollback
2. [ ] Replace with QuantumFlow.Producers calls
3. [ ] Test rollback flow

### ⏳ Integration Testing

- [ ] End-to-end: proposal → consensus → execution → metrics → guardian monitoring
- [ ] Rollback flow: metrics breach → Guardian → rollback trigger → instance rollback
- [ ] Multi-instance: 3 instances submitting proposals simultaneously
- [ ] Failure scenarios:
  - [ ] PgFlow database down → messages queue, retry when up
  - [ ] Instance down → CentralCloud queues messages, delivers when up
  - [ ] CentralCloud down → Singularity queues messages, sends when CentralCloud up

---

## Phase 4: Cleanup & Optimization (1-2 hours)

### ⏳ Remove Old Direct Calls

After verifying all PgFlow flows work:

- [ ] Remove direct imports of ConsensusEngine (Singularity)
- [ ] Remove direct imports of RollbackService (Singularity)
- [ ] Remove check_consensus scheduled job
- [ ] Verify no other direct calls to remote services

### ⏳ Add Monitoring

- [ ] Telemetry dashboards for queue depth
- [ ] Alerts for dead-letter queue > 10 messages
- [ ] Alerts for queue latency > 5 seconds
- [ ] Dashboard showing message flow

### ⏳ Documentation

- [ ] Update architecture diagrams (now with queues)
- [ ] Document message formats
- [ ] Write runbook for troubleshooting
- [ ] Add monitoring guide

### ⏳ Performance Testing

- [ ] Load test with 10 concurrent proposals
- [ ] Load test with 100 concurrent proposals
- [ ] Measure message latency (publish to processing)
- [ ] Verify no message loss under load

---

## Testing Checklist

### Unit Tests

**Singularity.Evolution.QuantumFlow.Producers**
```elixir
# Test each producer method
test "propose_for_consensus publishes message" do
  proposal = build(:proposal)
  {:ok, msg_id} = Producers.propose_for_consensus(proposal)
  assert msg_id
end

test "propose_for_consensus handles errors" do
  # Mock ExQuantumFlow.publish to return error
  {:error, reason} = Producers.propose_for_consensus(proposal)
  assert reason
end
```

**Singularity.Evolution.QuantumFlow.Consumers**
```elixir
# Test each consumer method
test "handle_consensus_result marks proposal approved" do
  proposal = insert(:proposal)
  message = %{
    "proposal_id" => proposal.id,
    "status" => "approved",
    "votes" => %{}
  }

  {:ok, status} = Consumers.handle_consensus_result(message)
  assert status == "processed"

  # Verify proposal was updated
  updated = Repo.get(Proposal, proposal.id)
  assert updated.status == "consensus_reached"
end
```

### Integration Tests

**Proposal Flow**
```elixir
test "proposal flows through QuantumFlow from instance to consensus" do
  # 1. Submit proposal
  {:ok, proposal} = ProposalQueue.submit_proposal(...)

  # 2. Publish to consensus
  {:ok, msg_id} = QuantumFlow.Producers.propose_for_consensus(proposal)

  # 3. Verify message in queue
  messages = ExQuantumFlow.list_pending_messages("proposals_for_consensus_queue")
  assert Enum.any?(messages, &(&1["proposal_id"] == proposal.id))

  # 4. Process message (simulates CentralCloud)
  [message] = messages
  {:ok, status} = CentralCloud.Evolution.QuantumFlow.Consumers.handle_proposal_for_consensus(message)

  # 5. Verify proposal recorded in CentralCloud
  assert Repo.exists?(CentralCloud.Consensus.Proposal, id: proposal.id)
end
```

### System Tests

- [ ] 2+ instances running, proposals flow correctly
- [ ] Metrics reported and processed
- [ ] Guardian rollback works across instances
- [ ] Patterns aggregated and available

---

## Deployment Steps

### Pre-Deployment
- [ ] All tests passing (unit + integration)
- [ ] Configuration tested in staging
- [ ] Database migrations verified
- [ ] Rollback plan documented

### Deployment
1. [ ] Add `ex_quantum_flow` to mix.exs
2. [ ] Run `mix deps.get`
3. [ ] Run PgFlow migrations
4. [ ] Update config files
5. [ ] Update supervision trees
6. [ ] Set environment variables
7. [ ] Restart services

### Post-Deployment
- [ ] Verify consumers are running: `Supervisor.which_children(Singularity.Supervisor)`
- [ ] Check queue status: `ExQuantumFlow.list_queues()`
- [ ] Submit test proposal and verify flow
- [ ] Monitor dead-letter queue: `ExQuantumFlow.list_dlq_messages()`
- [ ] Monitor metrics: check telemetry events

### Rollback Plan
If issues:
1. [ ] Revert config changes
2. [ ] Disable PgFlow consumers in supervision tree
3. [ ] Restart services
4. [ ] Direct calls still work as fallback during this phase

---

## Success Criteria

### Phase 1: Foundation ✓
- [x] All producer/consumer modules created
- [ ] Configuration file created
- [ ] No compilation errors
- [ ] Telemetry events defined

### Phase 2: ProposalQueue Integration ✓
- [ ] Proposals publish to QuantumFlow queue
- [ ] CentralCloud receives and processes
- [ ] Consensus results received via queue
- [ ] End-to-end flow working

### Phase 3: ExecutionFlow & Guardian Integration ✓
- [ ] Metrics published via queue
- [ ] Guardian processes metrics
- [ ] Rollback triggers delivered
- [ ] Instance receives and processes rollback

### Phase 4: Production Ready ✓
- [ ] All direct calls removed
- [ ] Monitoring dashboards working
- [ ] Load tests passing (100+ concurrent)
- [ ] Documentation complete
- [ ] Team trained

---

## Timeline Estimate

| Phase | Task | Estimate | Status |
|-------|------|----------|--------|
| 1 | Code & Config | 3 hours | ✅ Code done |
| 1 | Testing | 1 hour | ⏳ To do |
| 2 | ProposalQueue | 2 hours | ⏳ To do |
| 2 | Testing | 1 hour | ⏳ To do |
| 3 | ExecutionFlow | 2 hours | ⏳ To do |
| 3 | Testing | 1 hour | ⏳ To do |
| 4 | Cleanup | 1 hour | ⏳ To do |
| 4 | Docs & Perf | 2 hours | ⏳ To do |
| **Total** | | **13 hours** | |

---

## Quick Reference

### File Locations
```
Singularity Producers:   nexus/singularity/lib/singularity/evolution/QuantumFlow/producers.ex
Singularity Consumers:   nexus/singularity/lib/singularity/evolution/QuantumFlow/consumers.ex
CentralCloud Producers: nexus/central_services/lib/centralcloud/evolution/QuantumFlow/producers.ex
CentralCloud Consumers: nexus/central_services/lib/centralcloud/evolution/QuantumFlow/consumers.ex
```

### Key Methods to Implement
```
Singularity:
  - ProposalQueue: broadcast_to_consensus (use producers)
  - ExecutionFlow: report_to_guardian (use producers)
  - Remove: check_consensus periodic job

CentralCloud:
  - Guardian: trigger_rollback (use producers)
  - Consensus: send_result (use producers)
```

### Configuration Sections
```
Both projects:
  config :xxxx, :quantum_flow_queues
  - producers: list of producers with queue names
  - consumers: list of consumers with handlers
```

---

## Questions?

Refer to:
- **PGFLOW_CONFIGURATION.md** - Setup guide
- **EVOLUTION_PGFLOW_INTEGRATION_GUIDE.md** - Design guide
- **Producer/Consumer @moduledoc** - API reference

