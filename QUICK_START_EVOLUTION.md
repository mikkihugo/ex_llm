# Centralized Evolution System - Quick Start Guide

**5-Minute Setup | 10-Minute First Proposal**

---

## Setup (5 minutes)

### 1. Run Migrations
```bash
cd /home/mhugo/code/singularity/nexus/singularity
mix ecto.migrate

cd ../central_services
mix ecto.migrate
```

### 2. Start Services
```bash
# Terminal 1: Singularity
cd /home/mhugo/code/singularity/nexus/singularity
mix phx.server
# → Running on localhost:4000

# Terminal 2: CentralCloud
cd /home/mhugo/code/singularity/nexus/central_services
mix phx.server
# → Running on localhost:4001
```

### 3. Verify Setup
```bash
# Terminal 3: iex console
cd /home/mhugo/code/singularity/nexus/singularity
iex -S mix

# Check ProposalQueue is running
iex> Process.whereis(Singularity.Evolution.ProposalQueue)
#PID<...>  ✅ Running

# Check table exists
iex> Singularity.Repo.all(Singularity.Schemas.Evolution.Proposal)
[]  ✅ Empty (ready to use)
```

---

## Your First Proposal (10 minutes)

### Step 1: Submit a Proposal from an Agent
```elixir
# In iex console:
alias Singularity.Evolution.ProposalQueue

# Submit a code change proposal
{:ok, proposal} = ProposalQueue.submit_proposal(
  "BugFixerAgent",                          # Agent type
  %{file: "lib/foo.ex", fix: "fix_bug"},    # Code change
  agent_id: "bf_001",                       # Agent ID
  impact_score: 8.0,                        # How much impact? (1-10)
  risk_score: 1.0,                          # How risky? (1-10)
  safety_profile: %{
    success_rate: 0.95,                     # Historical success
    cost_factor: 2.0,                       # Cost relative to 5.0
    force_consensus: true                   # Require consensus? (for high risk)
  }
)

IO.inspect(proposal, label: "✅ Proposal Created")
# Outputs:
# ✅ Proposal Created: %Singularity.Schemas.Evolution.Proposal{
#   id: "123e4567-e89b-12d3-a456-426614174000",
#   agent_type: "BugFixerAgent",
#   status: "pending",
#   priority_score: 3.83,
#   ...
# }
```

### Step 2: Check Proposal Status
```elixir
# List all pending proposals
proposals = ProposalQueue.list_pending()
IO.inspect(proposals, label: "📋 Pending Proposals")
# Outputs list sorted by priority_score (highest first)

# Get highest priority
{:ok, proposal} = ProposalQueue.next_proposal()
IO.inspect(proposal, label: "🎯 Next Proposal")
```

### Step 3: Send for Consensus
```elixir
# Send the proposal to CentralCloud for voting
{:ok, proposal} = ProposalQueue.send_for_consensus(proposal.id)

IO.inspect(proposal.status, label: "📤 Proposal Status")
# Outputs: "sent_for_consensus"
```

### Step 4: Wait for Consensus (Simulate)
```elixir
# In a real system, other instances vote
# For now, let's simulate approval in CentralCloud:

# Option A: Check what consensus would be
case ProposalQueue.check_consensus_result(proposal.id) do
  {:ok, "consensus_reached"} ->
    IO.puts("✅ Consensus reached! Proposal executing...")
  {:error, :consensus_pending} ->
    IO.puts("⏳ Still waiting for votes...")
  {:error, :consensus_rejected} ->
    IO.puts("❌ Consensus rejected")
end

# Option B: Manually approve for testing
# (You would normally do this from another instance)
# Skip for now - the system waits for consensus
```

### Step 5: Apply Approved Proposal
```elixir
# Once consensus is reached, apply it:
{:ok, result} = ProposalQueue.apply_proposal(proposal.id)

IO.inspect(result, label: "✅ Proposal Applied")
# Outputs:
# ✅ Proposal Applied: %{
#   proposal_id: "123e4567-e89b-12d3-a456-426614174000",
#   status: "applied",
#   execution_time_ms: 123,
#   metrics_before: %{cpu_usage: 45.2, ...},
#   metrics_after: %{cpu_usage: 46.1, ...}
# }
```

### Step 6: Check Final Status
```elixir
{:ok, status} = ProposalQueue.get_status(proposal.id)
IO.inspect(status, label: "📊 Final Status")
# Outputs: "applied" ✅
```

---

## Common Tasks

### List Proposals by Status
```elixir
alias Singularity.Evolution.ProposalQueue

# All pending (not yet sent for consensus)
ProposalQueue.list_pending()

# Awaiting consensus result
ProposalQueue.list_awaiting_consensus()

# Currently executing
ProposalQueue.list_executing()

# Get specific proposal
{:ok, proposal} = ProposalQueue.get_proposal(proposal_id)
```

### Check Guardian Safety
```elixir
alias CentralCloud.Guardian.RollbackService

# Get safety profile for a proposal type
RollbackService.get_safety_profile("BugFixerAgent")
# Returns: %{error_threshold: 0.10, latency_threshold: 3000, ...}

# Check if a change would be auto-approved
RollbackService.approve_change?(change_id)
# Returns: {:ok, true} or {:ok, false}

# Get learned rollback strategy
RollbackService.get_rollback_strategy("refactoring")
```

### Check Patterns
```elixir
alias CentralCloud.Patterns.PatternAggregator

# Get consensus patterns (high confidence)
{:ok, patterns} = PatternAggregator.get_consensus_patterns(
  :refactoring,                    # pattern type
  threshold: 0.95                  # success rate threshold
)

# Suggest similar patterns
{:ok, suggestions} = PatternAggregator.suggest_pattern(
  :bug_fix,                        # pattern type
  "code from problem"              # current code to match
)
```

### Run Learning Loop Manually
```elixir
alias CentralCloud.Genesis.PatternLearningLoop

# Run daily learning immediately (for testing)
{:ok, results} = PatternLearningLoop.run_now()

IO.inspect(results, label: "📚 Learning Loop Results")
# Outputs:
# 📚 Learning Loop Results: %{
#   patterns_processed: 5,
#   rules_generated: 2,
#   thresholds_updated: 3,
#   timestamp: ~U[...]
# }

# Get statistics
{:ok, stats} = PatternLearningLoop.get_last_run_stats()
IO.inspect(stats)
```

---

## Testing End-to-End Flow

### Complete Example: Bug Fix Proposal
```elixir
alias Singularity.Evolution.{ProposalQueue, ExecutionFlow}

# 1. SUBMIT: Agent reports a bug fix
{:ok, proposal} = ProposalQueue.submit_proposal(
  "BugFixerAgent",
  %{file: "lib/bug.ex", fix: "return value fix"},
  agent_id: "bf_001",
  impact_score: 8.0,
  risk_score: 1.0,
  safety_profile: %{success_rate: 0.99, cost_factor: 1.0}
)
IO.puts("✅ 1. Proposal submitted: #{proposal.id}")

# 2. PRIORITIZE: Get highest priority
{:ok, proposal} = ProposalQueue.next_proposal()
IO.puts("✅ 2. Selected proposal (priority: #{proposal.priority_score})")

# 3. SEND FOR CONSENSUS: Request voting
{:ok, proposal} = ProposalQueue.send_for_consensus(proposal.id)
IO.puts("✅ 3. Sent for consensus voting")

# 4. SIMULATE CONSENSUS: In real system, wait for votes
# For testing, we'll jump to approved state
IO.puts("⏳ 4. Waiting for consensus (30s timeout)...")
Process.sleep(2000)  # Wait 2 seconds for demo

# 5. EXECUTE: Apply the approved proposal
case ProposalQueue.apply_proposal(proposal.id) do
  {:ok, result} ->
    IO.inspect(result, label: "✅ 5. Proposal executed")
  {:error, reason} ->
    IO.inspect(reason, label: "❌ 5. Execution failed")
end

# 6. VERIFY: Check final status
{:ok, status} = ProposalQueue.get_status(proposal.id)
IO.puts("📊 Final status: #{status}")
```

---

## Monitoring & Debugging

### View Proposal History
```elixir
# Get all proposals (with filters)
alias Singularity.Repo
alias Singularity.Schemas.Evolution.Proposal
import Ecto.Query

# All proposals
Repo.all(Proposal)

# Only applied proposals
Repo.all(from p in Proposal, where: p.status == "applied")

# Proposals by agent
Repo.all(from p in Proposal, where: p.agent_type == "BugFixerAgent")

# Proposals with high priority score
Repo.all(from p in Proposal, where: p.priority_score > 5.0)
```

### Check Proposal Details
```elixir
proposal = Repo.get(Proposal, proposal_id)

IO.inspect(%{
  id: proposal.id,
  agent_type: proposal.agent_type,
  status: proposal.status,
  priority_score: proposal.priority_score,
  impact_score: proposal.impact_score,
  risk_score: proposal.risk_score,
  created_at: proposal.created_at,
  execution_time_ms: execution_time(proposal),
  success: proposal.status == "applied"
})

defp execution_time(proposal) do
  case {proposal.execution_started_at, proposal.execution_completed_at} do
    {s, c} when not is_nil(s) and not is_nil(c) ->
      DateTime.diff(c, s, :millisecond)
    _ -> nil
  end
end
```

### Monitor Telemetry Events
```elixir
# Listen for proposal events
:telemetry.attach(
  "proposal_events",
  [:evolution, :proposal, :*],
  &log_event/4,
  nil
)

defp log_event(event, measurements, metadata, _) do
  IO.inspect({event, measurements, metadata})
end

# Now run proposals and see events printed:
# [:evolution, :proposal, :submitted]
# [:evolution, :proposal, :sent_for_consensus]
# [:evolution, :execution, :completed]
```

---

## Troubleshooting

### Proposal Stuck in "sent_for_consensus"
```elixir
# Check if consensus engine is running
CentralCloud.Consensus.Engine.health_check()

# Check votes cast
case CentralCloud.Consensus.Engine.get_consensus_result(proposal_id) do
  {:ok, result} -> IO.inspect(result, label: "Consensus result")
  {:error, reason} -> IO.inspect(reason, label: "Error")
end

# Manually retry
ProposalQueue.check_consensus_result(proposal_id)
```

### Proposal Execution Failed
```elixir
# Get proposal with error details
{:ok, proposal} = ProposalQueue.get_proposal(proposal_id)

IO.inspect(%{
  status: proposal.status,
  error: proposal.execution_error,
  metrics_before: proposal.metrics_before,
  metrics_after: proposal.metrics_after
})

# Check Guardian rollback
CentralCloud.Guardian.RollbackService.list_rolled_back_changes()
```

### Guardian Rolled Back a Proposal
```elixir
# Get proposal that was rolled back
{:ok, proposal} = ProposalQueue.get_proposal(proposal_id)

IO.inspect(%{
  status: proposal.status,
  reason: proposal.rollback_reason,
  triggered_at: proposal.rollback_triggered_at,
  metrics_delta: %{
    cpu: proposal.metrics_after.cpu_usage - proposal.metrics_before.cpu_usage,
    errors: proposal.metrics_after.error_count - proposal.metrics_before.error_count
  }
})

# Check Guardian's safety profile for this agent
CentralCloud.Guardian.RollbackService.get_safety_profile(proposal.agent_type)
```

---

## Next Steps

### For Development
1. ✅ Complete setup (above)
2. ✅ Run first proposal (above)
3. Integrate with your agents
4. Configure safety profiles
5. Monitor proposal flow

### For Operations
1. Deploy to staging
2. Monitor proposals daily
3. Check learning loop output
4. Tune safety thresholds
5. Scale to production

### For Advanced Use
1. Implement custom proposal types
2. Add custom safety profile rules
3. Integrate with monitoring (Prometheus)
4. Set up dashboards
5. Fine-tune learning loop

---

## Files to Reference

| File | Purpose |
|------|---------|
| `CENTRALIZED_EVOLUTION_COMPLETE_GUIDE.md` | Full reference |
| `REFACTORING_COMPLETION_SUMMARY.md` | What was built |
| `lib/singularity/evolution/proposal_queue.ex` | Proposal management |
| `lib/singularity/evolution/execution_flow.ex` | Execution orchestration |
| `lib/centralcloud/evolution/guardian/rollback_service.ex` | Safety monitoring |
| `lib/centralcloud/evolution/patterns/aggregator.ex` | Pattern learning |
| `lib/centralcloud/evolution/consensus/engine.ex` | Voting mechanism |
| `lib/centralcloud/genesis/pattern_learning_loop.ex` | Daily learning |

---

## Key Concepts

### Proposal Lifecycle
```
pending → sent_for_consensus → consensus_reached → executing → applied
                           ↘ consensus_failed (rejected)

Applied or Failed → rolled_back (if Guardian detects issues)
```

### Priority Scoring
- Bug fixes: HIGH (impact 8, success 0.95) → ~3.8
- Refactoring: MEDIUM (impact 6, success 0.75) → ~0.4
- Optimization: LOW (impact 5, success 0.60) → ~0.1

### Consensus Rules
- **Voting:** All instances vote (30s timeout)
- **Majority:** 2/3+ approve
- **Confidence:** 85%+ average confidence
- **Result:** Approved = execute, Rejected = rollback

### Guardian Rollback Triggers
- Error rate > 10%
- Latency > 3000ms
- Memory delta > 1GB
- Cost > $0.10/request

### Learning Loop (Daily at 00:00 UTC)
- Aggregates consensus patterns (3+ instances, 95%+ success)
- Converts patterns → Genesis rules
- Updates safety thresholds
- Reports to Genesis.RuleEngine

---

## FAQ

**Q: Why does my proposal stay "sent_for_consensus"?**
A: Waiting for other instances to vote. Timeout is 30 seconds. Check `CentralCloud.Consensus.Engine.get_consensus_result(proposal_id)`.

**Q: Can I skip consensus for low-risk changes?**
A: Yes! Set `consensus_required: false` when submitting (not recommended for safety).

**Q: How do I know a pattern was learned?**
A: Check `PatternLearningLoop.get_last_run_stats()` or query the patterns table.

**Q: Can I run the learning loop more than once per day?**
A: Yes! Call `PatternLearningLoop.run_now()` anytime for testing.

**Q: What if a proposal fails?**
A: Status changes to "failed" with error details. Guardian may auto-rollback if metrics breach thresholds.

---

## Success Indicators

✅ Proposals are submitted and prioritized
✅ Consensus voting works (if multiple instances)
✅ Approved proposals execute successfully
✅ Guardian monitors without false positives
✅ Patterns aggregate correctly
✅ Learning loop runs daily

**You're ready! Happy evolving! 🚀**
