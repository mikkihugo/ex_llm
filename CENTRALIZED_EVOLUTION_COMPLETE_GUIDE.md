# Centralized Evolution Architecture - Complete Implementation Guide

## Overview

This document describes the complete centralized evolution system where **Guardian** and **Patterns** are centrally managed via CentralCloud, enabling multi-instance learning and safe autonomous code generation.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CentralCloud                           │
│              (Central Intelligence Hub)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Guardian Service (Safety Keeper)                     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • Register changes across instances                  │   │
│  │ • Monitor metrics in real-time                       │   │
│  │ • Auto-rollback on threshold breach                  │   │
│  │ • Maintain safety profiles per agent/pattern         │   │
│  │ • Learn from cross-instance patterns                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Pattern Aggregator (Intelligence)                    │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • Collect patterns from all instances                │   │
│  │ • Consensus voting (3+ instances)                    │   │
│  │ • Semantic search (pgvector)                         │   │
│  │ • Promote to Genesis when mature                     │   │
│  │ • Suggest patterns to instances                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Consensus Engine (Governance)                        │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • Broadcast proposals from instances                 │   │
│  │ • Collect votes from all instances                   │   │
│  │ • 2/3+ majority rule                                 │   │
│  │ • Prevent conflicting changes                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Genesis Pattern Learning Loop (Daily)                │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • Aggregate consensus patterns (24h window)          │   │
│  │ • Convert patterns → Genesis rules                   │   │
│  │ • Update safety thresholds                           │   │
│  │ • Report learnings to RuleEngine                     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         ↑ Reports ↑ Consults ↑ Proposes ↑ Learns ↑
         │                                         │
    ┌────┴────────────────────────────┬───────────┴────┐
    │                                  │                 │
    ▼                                  ▼                 ▼
┌─────────────────┐          ┌─────────────────┐  ┌──────────────┐
│  Instance 1     │          │  Instance 2     │  │ Instance 3   │
│ (Singularity)   │          │ (Singularity)   │  │(Singularity) │
├─────────────────┤          ├─────────────────┤  ├──────────────┤
│ Agents:         │          │ Agents:         │  │ Agents:      │
│ ├─ Bug Fixer    │          │ ├─ Refactor     │  │ ├─ Optimize  │
│ ├─ Optimizer    │          │ ├─ Synthesizer  │  │ ├─ Refactor  │
│ └─ Profiler     │          │ └─ Profiler     │  │ └─ Profiler  │
│                 │          │                 │  │              │
│ Proposal Queue: │          │ Proposal Queue: │  │ Proposal Q:  │
│ ├─ submit       │          │ ├─ submit       │  │ ├─ submit    │
│ ├─ prioritize   │          │ ├─ prioritize   │  │ ├─ prioritize
│ └─ execute      │          │ └─ execute      │  │ └─ execute   │
└─────────────────┘          └─────────────────┘  └──────────────┘
```

## Complete Data Flow

### Phase 1: Proposal Submission

```
Singularity Agent (Instance 1)
  ↓ (calls)
AgentCoordinator.propose_change()
  ↓
ProposalQueue.submit_proposal()
  ├─ Create proposal in DB
  ├─ Score priority (impact × success_rate / cost × risk)
  ├─ Cache in ETS (fast lookup)
  └─ Return {:ok, proposal}

Agent proceeds with local work...
```

### Phase 2: Proposal Prioritization & Consensus

```
ProposalQueue.next_proposal()
  ↓ (highest priority waiting)
Selected Proposal (pending)
  ↓ (high risk? needs consensus)
ProposalQueue.send_for_consensus()
  ├─ Mark as "sent_for_consensus"
  └─ Broadcast to CentralCloud.Consensus.Engine

CentralCloud.Consensus.Engine.propose_change()
  ├─ Store proposal in CentralCloud
  ├─ Broadcast voting request to ALL instances
  └─ Collect votes (timeout: 30s)

Instance 1:
  └─ CentralCloud.Consensus.Engine.vote_on_change(
       proposal_id,
       vote: :approve,
       confidence: 0.95,
       reason: "Similar to pattern_X with 98% success"
     )

Instance 2:
  └─ Same pattern...

Instance 3:
  └─ Same pattern...

CentralCloud aggregates votes:
  ├─ 3 approvals / 3 votes = 100% approval
  ├─ Average confidence: 0.96
  └─ CONSENSUS REACHED ✅

ProposalQueue (each instance) checks:
  └─ CentralCloud.Consensus.Engine.get_consensus_result(proposal_id)
      ├─ Receives: {approved: true, votes: {...}}
      ├─ Updates proposal status to "consensus_reached"
      └─ Proceeds to execution
```

### Phase 3: Execution with Safety Gates

```
ProposalQueue.apply_proposal(proposal_id)
  ↓
ExecutionFlow.execute_proposal(proposal)
  ├─ validate_safety_profile()
  │  └─ Check: risk_score, requires_consensus, etc.
  │
  ├─ collect_metrics_before()
  │  └─ CPU, memory, error_count, execution_count
  │
  ├─ execute_code_change()
  │  └─ Apply actual code transformation
  │
  ├─ collect_metrics_after()
  │  └─ Same metrics, compare deltas
  │
  ├─ validate_execution_result()
  │  └─ Check: CPU spike < 50%, error_delta < 10, no critical errors
  │
  ├─ report_to_guardian()
  │  └─ CentralCloud.Guardian.RollbackService.report_metrics(
  │       instance_id, proposal_id, metrics_delta
  │     )
  │
  └─ Mark proposal as "applied"
```

### Phase 4: Guardian Monitoring & Rollback

```
CentralCloud.Guardian.RollbackService (Background)
  ├─ Monitor metrics for executing proposals
  │
  ├─ If metrics breach thresholds (per-proposal safety_profile):
  │  ├─ error_rate > threshold (e.g., 10%)
  │  ├─ latency > threshold (e.g., 3000ms)
  │  ├─ memory > threshold (e.g., 1GB delta)
  │  └─ cost > threshold (e.g., $0.10/request)
  │
  └─ Trigger auto-rollback:
      ├─ Send rollback signal to all instances
      ├─ Update proposal status to "rolled_back"
      ├─ Instance reverts code change
      ├─ Re-run test suite
      └─ Report rollback to Genesis
```

### Phase 5: Pattern Learning (Daily at 00:00 UTC)

```
CentralCloud.Genesis.PatternLearningLoop (scheduled daily)
  ├─ aggregate_consensus_patterns()
  │  ├─ Query patterns from all instances (created in last 24h)
  │  ├─ Filter: success_rate >= 95%
  │  ├─ Filter: source_instances >= 3
  │  └─ Result: High-confidence patterns
  │
  ├─ convert_patterns_to_rules()
  │  ├─ Pattern {code_before, code_after, 0.97_success}
  │  │   ↓
  │  │ Rule "IF code_matches_pattern THEN apply_transformation"
  │  │
  │  └─ Extract decision factors (what made this successful?)
  │
  ├─ update_safety_thresholds()
  │  ├─ For each pattern type (refactoring, optimization, bug_fix)
  │  ├─ Calculate average success rate
  │  ├─ Calculate instances confirming
  │  └─ Update CentralCloud.Guardian.safety_profiles
  │
  └─ report_to_genesis_rule_engine()
     ├─ Send learned rules to Genesis.RuleEngine
     ├─ Genesis autonomously improves rules
     └─ Next day agents use improved rules
```

## Key Components

### 1. CentralCloud.Guardian.RollbackService

**Location:** `nexus/central_services/lib/centralcloud/evolution/guardian/rollback_service.ex`

**Responsibilities:**
- Register changes before execution
- Monitor metrics in real-time
- Detect anomalies vs. safety thresholds
- Auto-rollback when thresholds breached
- Maintain cross-instance rollback decisions

**Public API:**
```elixir
# Register change (before execution)
RollbackService.register_change(
  instance_id,
  change_id,
  code_changeset,
  safety_profile: %{
    error_threshold: 0.10,
    latency_threshold: 3000,
    memory_threshold: 1_000_000_000,
    cost_threshold: 0.10
  }
)

# Report metrics (during execution)
RollbackService.report_metrics(instance_id, change_id, metrics)

# Get learned strategies
RollbackService.get_rollback_strategy(change_type)

# Check if similar change is safe
RollbackService.approve_change?(change_id)
```

### 2. CentralCloud.Patterns.PatternAggregator

**Location:** `nexus/central_services/lib/centralcloud/evolution/patterns/aggregator.ex`

**Responsibilities:**
- Record patterns from each instance
- Consensus voting (3+ instances = "trusted")
- Semantic search for similar patterns
- Promote to Genesis when mature

**Public API:**
```elixir
# Record pattern from instance
PatternAggregator.record_pattern(
  instance_id,
  :refactoring,
  %{code_before: "...", code_after: "..."},
  success_rate: 0.97
)

# Get consensus patterns (high confidence)
PatternAggregator.get_consensus_patterns(:refactoring, threshold: 0.95)

# Suggest similar patterns
PatternAggregator.suggest_pattern(:bug_fix, current_code)

# Aggregate learnings (promotes to Genesis)
PatternAggregator.aggregate_learnings()
```

### 3. CentralCloud.Consensus.Engine

**Location:** `nexus/central_services/lib/centralcloud/evolution/consensus/engine.ex`

**Responsibilities:**
- Broadcast proposals from instances
- Collect votes from all instances
- Enforce 2/3 majority rule
- Prevent conflicting changes

**Public API:**
```elixir
# Propose change (from instance)
ConsensusEngine.propose_change(
  instance_id,
  change_id,
  code_change,
  metadata: %{agent_type: "RefactoringAgent", ...}
)

# Vote on proposal (from instance)
ConsensusEngine.vote_on_change(
  instance_id,
  change_id,
  vote: :approve,
  confidence: 0.95,
  reason: "Similar to known pattern"
)

# Check consensus result
ConsensusEngine.execute_if_consensus(change_id)
```

### 4. Singularity.Evolution.ProposalQueue

**Location:** `nexus/singularity/lib/singularity/evolution/proposal_queue.ex`

**Responsibilities:**
- Collect proposals from agents
- Prioritize by impact/cost/risk
- Send for consensus voting
- Apply approved proposals
- Report metrics to Guardian

**Public API:**
```elixir
# Submit proposal from agent
ProposalQueue.submit_proposal(
  "RefactoringAgent",
  %{file: "lib/foo.ex", change: "..."},
  agent_id: "agent_001",
  impact_score: 6.0,
  risk_score: 2.0
)

# Get next highest-priority proposal
ProposalQueue.next_proposal()

# Send for consensus
ProposalQueue.send_for_consensus(proposal_id)

# Apply approved proposal
ProposalQueue.apply_proposal(proposal_id)

# Check proposal status
ProposalQueue.get_status(proposal_id)
```

### 5. Singularity.Evolution.ExecutionFlow

**Location:** `nexus/singularity/lib/singularity/evolution/execution_flow.ex`

**Responsibilities:**
- Validate safety profile
- Collect metrics before/after
- Execute code changes
- Verify no errors
- Report to Guardian

**Public API:**
```elixir
# Execute approved proposal end-to-end
ExecutionFlow.execute_proposal(proposal)
# Returns {:ok, result} with metrics

# Validate safety profile
ExecutionFlow.validate_safety_profile(proposal)

# Collect metrics
ExecutionFlow.collect_metrics_before(proposal)
ExecutionFlow.collect_metrics_after(proposal, result)

# Report to Guardian
ExecutionFlow.report_to_guardian(proposal, metrics_before, metrics_after)
```

### 6. Singularity.Evolution.ProposalScorer

**Location:** `nexus/singularity/lib/singularity/evolution/proposal_scorer.ex`

**Responsibilities:**
- Calculate priority scores
- Factor in agent success rates
- Adjust for urgency
- Rebalance as history improves

**Public API:**
```elixir
# Score a proposal
ProposalScorer.score_proposal(proposal)

# Calculate priority
ProposalScorer.calculate_priority(proposal)

# Get agent success rate
ProposalScorer.get_agent_success_rate("RefactoringAgent")

# Rebalance all pending
ProposalScorer.rebalance_all_pending()
```

### 7. CentralCloud.Genesis.PatternLearningLoop

**Location:** `nexus/centralcloud/lib/centralcloud/genesis/pattern_learning_loop.ex`

**Responsibilities:**
- Daily aggregation of patterns
- Consensus validation
- Rule generation
- Safety threshold updates
- Report to Genesis.RuleEngine

**Public API:**
```elixir
# Run learning loop
PatternLearningLoop.run_now()

# Get statistics
PatternLearningLoop.get_last_run_stats()
```

## Database Schema

### Singularity (evolution_proposals)
```sql
CREATE TABLE evolution_proposals (
  id UUID PRIMARY KEY,
  agent_type TEXT NOT NULL,
  agent_id TEXT,
  code_change JSONB NOT NULL,
  metadata JSONB DEFAULT {},
  safety_profile JSONB DEFAULT {},
  impact_score FLOAT DEFAULT 5.0,
  risk_score FLOAT DEFAULT 5.0,
  priority_score FLOAT DEFAULT 0.0,

  status TEXT DEFAULT 'pending' NOT NULL,
  -- pending | sent_for_consensus | consensus_reached | consensus_failed
  -- | executing | applied | failed | rolled_back

  consensus_votes JSONB DEFAULT {},
  consensus_sent_at TIMESTAMP,
  consensus_result TEXT,
  consensus_required BOOLEAN DEFAULT true,

  execution_started_at TIMESTAMP,
  execution_completed_at TIMESTAMP,
  execution_error TEXT,

  metrics_before JSONB,
  metrics_after JSONB,

  rollback_triggered_at TIMESTAMP,
  rollback_reason TEXT,

  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_proposals_status ON evolution_proposals(status);
CREATE INDEX idx_proposals_priority ON evolution_proposals(priority_score);
CREATE INDEX idx_proposals_agent ON evolution_proposals(agent_type);
```

### CentralCloud (patterns)
```sql
CREATE TABLE patterns (
  id UUID PRIMARY KEY,
  pattern_type TEXT NOT NULL,
  code_pattern JSONB NOT NULL,
  source_instances TEXT[],
  consensus_score FLOAT DEFAULT 0.0,
  success_rate FLOAT DEFAULT 0.0,
  safety_profile JSONB DEFAULT {},
  promoted_to_genesis BOOLEAN DEFAULT false,
  embedding VECTOR(2560),
  created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_patterns_type ON patterns(pattern_type);
CREATE INDEX idx_patterns_consensus ON patterns(consensus_score);
CREATE INDEX idx_patterns_embedding ON patterns USING hnsw (embedding vector_cosine_ops);
```

### CentralCloud (approved_changes)
```sql
CREATE TABLE approved_changes (
  id UUID PRIMARY KEY,
  instance_id TEXT,
  change_id TEXT UNIQUE,
  pattern_id UUID REFERENCES patterns,
  rollback_strategy JSONB,
  safety_threshold JSONB,
  approved_at TIMESTAMP,
  metrics_start JSONB,
  metrics_current JSONB,
  status TEXT, -- pending, active, rolled_back, succeeded
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### CentralCloud (consensus_votes)
```sql
CREATE TABLE consensus_votes (
  id UUID PRIMARY KEY,
  change_id TEXT,
  instance_id TEXT,
  vote TEXT, -- approve, reject, abstain
  confidence FLOAT,
  reason TEXT,
  voted_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_votes_change ON consensus_votes(change_id);
CREATE INDEX idx_votes_instance ON consensus_votes(instance_id);
```

## Deployment Checklist

### 1. Database Setup
- [ ] Run migration: `cd nexus/singularity && mix ecto.migrate`
- [ ] Run migration: `cd nexus/central_services && mix ecto.migrate`
- [ ] Verify tables created: `SELECT * FROM evolution_proposals; SELECT * FROM patterns;`

### 2. Start Services
- [ ] PostgreSQL running
- [ ] Singularity: `cd nexus/singularity && mix phx.server` (port 4000)
- [ ] CentralCloud: `cd nexus/central_services && mix phx.server` (port 4001)
- [ ] Genesis: `cd nexus/genesis && mix phx.server` (optional, port 4003)

### 3. Supervision Tree
- [ ] Add ProposalQueue to Singularity.Application supervisor
- [ ] Add Guardian/Consensus/Aggregator to CentralCloud.Application
- [ ] Add PatternLearningLoop to CentralCloud.Application

### 4. Configuration
- [ ] Set `INSTANCE_ID` environment variable (unique per instance)
- [ ] Configure CentralCloud endpoints in Singularity config
- [ ] Enable Telemetry for monitoring

### 5. Testing
- [ ] Run integration tests: `cd nexus/singularity && mix test`
- [ ] Test proposal submission → consensus → execution
- [ ] Test Guardian monitoring and rollback
- [ ] Test pattern learning loop

## Common Workflows

### Submit a Proposal and Get It Executed

```elixir
alias Singularity.Evolution.{ProposalQueue, AgentCoordinator}

# 1. Agent submits proposal
{:ok, proposal} = AgentCoordinator.propose_change(
  MyAgent,
  %{file: "lib/foo.ex", change: "refactored"},
  metadata: %{reason: "improve readability"}
)

# 2. ProposalQueue scores and prioritizes
# (happens automatically)

# 3. Get next proposal
{:ok, proposal} = ProposalQueue.next_proposal()
# proposal.id, proposal.priority_score, etc.

# 4. Send for consensus
{:ok, proposal} = ProposalQueue.send_for_consensus(proposal.id)
# Status changes to "sent_for_consensus"

# 5. Wait for consensus (check periodically)
{:ok, status} = ProposalQueue.get_status(proposal.id)
# Eventually: "consensus_reached"

# 6. Apply approved proposal
{:ok, result} = ProposalQueue.apply_proposal(proposal.id)
# Status changes to "executing" then "applied"

# 7. Check final status
{:ok, status} = ProposalQueue.get_status(proposal.id)
# "applied" with result.metrics_after
```

### Check Consensus Result from Proposal

```elixir
# Send proposal for consensus
{:ok, proposal} = ProposalQueue.send_for_consensus(proposal.id)

# Check if consensus reached
case ProposalQueue.check_consensus_result(proposal.id) do
  {:ok, "consensus_reached"} ->
    {:ok, "Automatically executed!"}

  {:error, :consensus_pending} ->
    {:error, "Still waiting for votes..."}

  {:error, :consensus_rejected} ->
    {:error, "Consensus rejected proposal"}
end
```

### Learn from Patterns (Guardian Feedback Loop)

```elixir
# Instance 1: Submit bug fix proposal
{:ok, proposal1} = ProposalQueue.submit_proposal(
  "BugFixerAgent",
  %{file: "...", fix: "..."},
  agent_id: "bf_001",
  impact_score: 8.0
)

# Instance 2: Submit similar fix (same bug)
{:ok, proposal2} = ProposalQueue.submit_proposal(
  "BugFixerAgent",
  %{file: "...", fix: "..."},
  agent_id: "bf_002",
  impact_score: 8.0
)

# Instance 3: Submit similar fix
{:ok, proposal3} = ProposalQueue.submit_proposal(
  "BugFixerAgent",
  %{file: "...", fix: "..."},
  agent_id: "bf_003",
  impact_score: 8.0
)

# Daily (00:00 UTC):
# PatternLearningLoop.run_now() aggregates:
# - All 3 instances submit same pattern (refactoring_bug_fix_pattern_X)
# - All 3 succeed (100% success rate)
# - Consensus reached (3/3 instances)
# - Converts to Genesis rule
# - Updates Guardian.safety_profile:
#   %{"refactoring_bug_fix": %{success_rate: 1.0, instance_count: 3}}
# - Next day, similar fixes are auto-approved with lower safety threshold
```

## Monitoring & Debugging

### Check Proposal Status
```elixir
# Get a specific proposal
{:ok, proposal} = ProposalQueue.get_proposal(proposal_id)
proposal.status  # "pending", "sent_for_consensus", etc.

# List all pending
ProposalQueue.list_pending()

# List awaiting consensus
ProposalQueue.list_awaiting_consensus()

# List executing
ProposalQueue.list_executing()
```

### Monitor Guardian
```elixir
# Check registered changes
RollbackService.list_registered_changes()

# Get rollback strategy for change type
RollbackService.get_rollback_strategy("refactoring")

# Check if change would be auto-approved
RollbackService.approve_change?(change_id)
```

### Monitor Patterns
```elixir
# Get consensus patterns
PatternAggregator.get_consensus_patterns(:refactoring, threshold: 0.95)

# Suggest similar patterns
PatternAggregator.suggest_pattern(:bug_fix, current_code)

# Check aggregation status
PatternAggregator.get_aggregation_status()
```

### Monitor Learning Loop
```elixir
# Get last run statistics
PatternLearningLoop.get_last_run_stats()

# Run learning loop manually (for testing)
PatternLearningLoop.run_now()
```

## Troubleshooting

### Proposals Stuck in "sent_for_consensus"

```elixir
# Check if consensus engine is running
CentralCloud.Consensus.Engine.health_check()

# Check votes
:erlang.element(1, ConsensusEngine.get_consensus_result(proposal_id))

# Manually retry
ProposalQueue.check_consensus_result(proposal_id)
```

### Guardian Not Rolling Back

```elixir
# Check safety profile
RollbackService.get_safety_profile("RefactoringAgent")

# Check metrics being reported
RollbackService.get_current_metrics(proposal_id)

# Check rollback history
RollbackService.list_rolled_back_changes()
```

### Patterns Not Aggregating

```elixir
# Check pattern creation
PatternAggregator.list_all_patterns()

# Check consensus calculation
PatternAggregator.calculate_consensus_score("refactoring")

# Check learning loop
PatternLearningLoop.get_last_run_stats()
```

## Performance Considerations

### Proposal Queue Scalability
- **ETS caching** for O(1) proposal lookups
- **DB fallback** for persistence
- **Batch consensus checks** every 5 seconds
- **Batch metrics reporting** every 60 seconds

### Guardian Scalability
- **In-memory thresholds** cached in RollbackService
- **Periodic metric aggregation** (5s windows)
- **Semantic search** via pgvector (HNSW indexing)

### Pattern Aggregator Scalability
- **Consensus voting** scales with instance count
- **Daily aggregation** (not real-time)
- **Vector embeddings** precomputed offline

### Learning Loop Scalability
- **Daily run** (not continuous)
- **Parallel pattern → rule conversion**
- **Batch Genesis updates**

## Security & Safety

### Consensus Requirements
- **High-risk changes** (risk_score > 8.0) require 2/3+ approval
- **Medium-risk** (5-8) require simple majority
- **Low-risk** (<5) auto-approved with safety validation

### Guardian Protection
- **Real-time monitoring** of all executing changes
- **Auto-rollback** on threshold breach
- **Isolation** prevents cascade failures
- **Audit trail** for all changes/rollbacks

### Pattern Safety
- **Consensus before learning** (3+ instances confirm)
- **95%+ success rate** minimum
- **Genesis isolation** (tested in sandbox before deployment)

## Next Steps

1. **Deploy infrastructure:**
   - Run migrations
   - Start all services
   - Add to supervisors

2. **Enable agents:**
   - Update agents to use ProposalQueue
   - Configure safety profiles per agent
   - Set impact/risk scores

3. **Monitor system:**
   - Watch proposal flow
   - Monitor Guardian decisions
   - Track learning loop progress

4. **Tune thresholds:**
   - Adjust consensus voting rules
   - Update safety profiles
   - Refine priority scoring

5. **Scale:**
   - Add more instances
   - Monitor cross-instance patterns
   - Optimize learning loop

## See Also

- `lib/singularity/evolution/proposal_queue.ex` - Proposal queue implementation
- `lib/singularity/evolution/execution_flow.ex` - Execution orchestration
- `lib/singularity/evolution/proposal_scorer.ex` - Priority scoring
- `lib/singularity/agents/agent_coordinator.ex` - Agent integration
- `lib/centralcloud/evolution/guardian/rollback_service.ex` - Safety keeper
- `lib/centralcloud/evolution/patterns/aggregator.ex` - Pattern intelligence
- `lib/centralcloud/evolution/consensus/engine.ex` - Governance
- `lib/centralcloud/genesis/pattern_learning_loop.ex` - Daily learning
