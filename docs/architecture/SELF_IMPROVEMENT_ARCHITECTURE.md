# Self-Improvement Architecture

## Overview

Singularity implements **Request-Driven Hybrid Self-Improvement** where:
- **Singularity instances** self-improve locally and can request high-risk experiments
- **Genesis application** is a separate isolated app that safely executes requested improvements
- **Centralcloud** aggregates patterns and insights across all instances (optional, for learning)

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPROVEMENT ECOSYSTEM                         │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────┐         ┌────────────────┐
│   Singularity Instances              │         │   Genesis      │
│   (Production/Dev)                   │◄───────►│   (Sandbox)    │
│                                      │         │                │
│  • Self-improve locally (Type 1)     │         │  • Isolated    │
│  • Request experiments (Type 3)      │         │  • Hot reload  │
│  • Send patterns to Centralcloud     │         │  • High-risk   │
│  • Receive validated improvements    │         │  • Rollback    │
│    from Genesis                      │         │                │
└──────────────────────────────────────┘         └────────────────┘
         ▲            │
         │            │
         │            ▼
         │  ┌─────────────────────────┐
         │  │   Centralcloud (Optional)   │
         └──┤                         │
            │  • Aggregate patterns   │
            │  • Analyze trends       │
            │  • Recommend to Genesis │
            └─────────────────────────┘
```

## Infrastructure Overview

**Three PostgreSQL Databases (Single Instance)**

```
PostgreSQL Server (localhost:5432)
├── singularity (Singularity instances database)
│   └─ Agents, code chunks, patterns, templates, knowledge base
├── central_services (Centralcloud database)
│   └─ Package metadata, global patterns, aggregated insights
└── genesis_db (Genesis sandbox database)
    └─ Experiment records, metrics, sandbox history

Three BEAM Applications

├── singularity/ (Production/Development)
│   └─ Multiple instances across multiple machines
├── centralcloud/ (Central Intelligence Hub)
│   └─ Single instance aggregating all patterns
└── genesis/ (Improvement Sandbox)
    └─ Single instance testing experiments

NATS Server (Message Bus)
├── llm.provider.* - LLM provider requests
├── code.analysis.* - Code analysis operations
├── agents.* - Agent coordination
├── improvement.* - Local self-improvement
├── genesis.experiment.* - Genesis experiments
└── intelligence.* - Centralcloud insights
```

## Three Types of Improvements

### Type 1: Local Self-Improvement (Singularity Instance)
**Goal:** Fast iteration on patterns proven locally

- **Trigger:** New pattern discovered or success rate improvement observed
- **Validation:** Tested against local knowledge base and recent agent runs
- **Rollback:** Via Git commit + hot reload (automatic if validation fails)
- **Cost:** LLM-free (rules-based pattern application)
- **Timeline:** Minutes to hours

**Example:**
```elixir
# Agent discovers faster SPARC decomposition pattern
# → Applied immediately via hot reload with validation
# → Tested on next 10 agent runs
# → If success_rate > threshold, persisted to Git
# → Sent to Centralcloud for aggregation
```

### Type 2: Global Validated Improvement (Centralcloud → All Instances)
**Goal:** Framework improvements proven across multiple instances

- **Trigger:** Pattern aggregation shows >70% frequency across instances
- **Validation:** Tested in Centralcloud, then Genesis sandbox
- **Deployment:** Sent back to all instances via NATS
- **Cost:** Low (validated, reduces LLM calls by identifying common patterns)
- **Timeline:** Hours to days

**Example:**
```elixir
# Centralcloud detects same SPARC optimization across 3 instances
# → Validates improvement was successful in each
# → Sends to Genesis for safety testing
# → Genesis confirms no regressions
# → Broadcasts validated improvement to all instances
```

### Type 3: Experimental High-Risk Improvement (Genesis)
**Goal:** Safely test architectural or algorithmic changes

- **Trigger:** Singularity requests experiment or recommender suggests high-impact change
- **Location:** Genesis application (isolated, independent)
- **Execution:** Hotreload with full isolation
- **Validation:** Comprehensive testing before rollback decision
- **Rollback:** Guaranteed via separate Git history
- **Cost:** Can use expensive LLM calls (sandbox, not production)
- **Timeline:** Days to weeks

**Example:**
```elixir
# Singularity: "Test new multi-task decomposition approach"
#            "It might break existing patterns but could reduce 40% of LLM calls"
#
# Genesis:   Receives request
#            Clones code + hot reload
#            Runs expensive experiments
#            Tests against corpus of past problems
#            Reports success/failure metrics
#            Singularity rolls back or merges
```

## Request-Driven Experiment Model

Singularities **request** Genesis to test changes, not the other way around.

### Request Flow

```
Singularity                    Genesis                Centralcloud
    │                            │                        │
    │──Request Experiment────────>                        │
    │  {                          │                        │
    │    experiment_type: "decomposition",                 │
    │    description: "Test multi-task approach",          │
    │    risk_level: "high",                               │
    │    estimated_impact: 0.40,                           │
    │    rollback_plan: "git reset --hard"                 │
    │  }                          │                        │
    │                             │ Create isolated        │
    │                             │ Genesis instance       │
    │                             │ Apply changes          │
    │                             │ Run tests              │
    │                             │ Measure impact         │
    │<─────Report Results─────────│                        │
    │  {                          │                        │
    │    status: "success" | "failed",                     │
    │    metrics: {...},          │                        │
    │    recommendation: "merge" | "rollback"              │
    │  }                          │                        │
    │                             │                        │
    ├─────Send Pattern to Centralcloud────────────────────>
    │  (if success, for aggregation)                       │
    │<──────Receive Validated──────────────────────────────
    │  Improvement (if Type 2)
```

## Genesis Application Architecture

Genesis is a **separate Elixir application** with **three-layer isolation**:

```
genesis/                          (NEW APPLICATION)
├── lib/
│   └── genesis/
│       ├── application.ex         # Standalone supervisor
│       ├── experiment_runner.ex    # Execute improvement requests
│       ├── isolation_manager.ex    # Create sandboxed code copies
│       ├── rollback_manager.ex     # Delete sandbox (instant rollback)
│       ├── metrics_collector.ex    # Track success/failure
│       ├── nats_client.ex          # NATS messaging
│       └── scheduler.ex            # Maintenance jobs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── prod.exs
├── mix.exs
└── test/

Three Isolation Layers:

1. **Filesystem Isolation** (Monorepo-based)
   └─ Sandboxes: ~/.genesis/sandboxes/{experiment_id}/
   └─ Each experiment gets copy of code directories
   └─ Main repo never modified (safe from accidents)
   └─ Rollback: delete sandbox directory (<1 second)

2. **Database Isolation** (Separate Database, Same PostgreSQL)
   └─ genesis_db (separate database name, same PostgreSQL instance)
   └─ Same PostgreSQL as singularity and central_services DBs
   └─ Logically isolated via database name
   └─ No data sharing with production DBs

3. **Process Isolation** (Separate BEAM App)
   └─ Genesis runs in separate Elixir application
   └─ Hotreload runs in Genesis context (not Singularity)
   └─ Communication via NATS (async messaging)
   └─ No shared state between Genesis and Singularities

Key Features:
• Works within monorepo (same git repository)
• Sandboxes never touch main repository
• Separate genesis_db PostgreSQL
• Separate NATS subscriptions (genesis.* subjects)
• Aggressive hotreload (test unsafe changes safely)
• Auto-rollback on regression (delete sandbox)
```

## Data Flow Architecture

### Local Self-Improvement (Type 1)

```
Agent Execution
    ↓
Pattern Detected (new or improved)
    ↓
Hot Reload (apply pattern)
    ↓
Validation Test
    ├─ Success → Git commit + publish to Centralcloud
    └─ Failure → Automatic rollback via git reset
```

### Global Improvement (Type 2)

```
Multiple Singularities
    ↓
Send Patterns to Centralcloud (via NATS)
    ↓
Aggregate & Analyze (frequency >70%)
    ↓
Genesis Safety Testing
    ↓
Broadcast to All (via NATS)
    ↓
Apply with Validation
```

### High-Risk Experiment (Type 3)

```
Singularity requests change
    ↓
Genesis receives (isolated instance)
    ↓
Apply to own codebase + hotreload
    ↓
Run comprehensive tests (expensive LLM calls OK)
    ↓
Report metrics & recommendation
    ↓
Singularity decides: merge or rollback
```

## Implementation Phases

### Phase 1: Local Self-Improvement (NOW)
- ✅ Pattern discovery and scoring
- ✅ Hot reload infrastructure
- ✅ Git-based rollback
- ✅ Validation testing
- ✅ Centralcloud integration (optional)

**Timeline:** Already implemented via Oban + Quantum jobs

### Phase 2: Genesis Application Setup (WEEK 1)
- [ ] Create new `genesis/` Elixir application
- [ ] Setup separate `genesis_db` PostgreSQL database
- [ ] Implement experiment request receiver (NATS)
- [ ] Implement isolation manager (sandboxed environment)
- [ ] Implement rollback manager (Git-based)
- [ ] Create experiment runner (safe code execution)

**Deliverable:** Genesis app running, can accept experiment requests

### Phase 3: Experiment Validation Framework (WEEK 2)
- [ ] Build comprehensive metrics collection
- [ ] Implement safety checks (prevent data loss)
- [ ] Create auto-rollback on regression
- [ ] Build success/failure reporting
- [ ] Add test corpus for validation

**Deliverable:** Genesis can test changes and report results

### Phase 4: Centralcloud Aggregation (WEEK 3)
- [ ] Implement pattern aggregation logic
- [ ] Add frequency-based recommendation
- [ ] Integrate Genesis testing for Type 2 improvements
- [ ] Build dashboard for improvement tracking
- [ ] Implement broadcast to all instances

**Deliverable:** Multi-instance learning ecosystem

## NATS Subject Organization

```
# Local improvements (Singularity instance)
improvement.local.applied.<instance_id>
improvement.local.rolled_back.<instance_id>
improvement.local.validated.<instance_id>

# Experiment requests (Singularity → Genesis)
genesis.experiment.request.<instance_id>
genesis.experiment.status.<experiment_id>

# Genesis responses
genesis.experiment.completed.<experiment_id>
genesis.experiment.failed.<experiment_id>

# Centralcloud pattern aggregation
improvement.global.recommended
improvement.global.applied.<instance_id>

# Metrics and reporting
metrics.improvement.local
metrics.improvement.global
metrics.genesis.experiments
```

## Safety Guarantees

### Type 1 (Local) Safety
```
✓ Automatic rollback if validation fails
✓ Git commit before any change
✓ Pattern stored in Git (audit trail)
✓ No impact on other instances
✓ Fast rollback (seconds)
```

### Type 2 (Global) Safety
```
✓ Tested in Centralcloud first
✓ Tested in Genesis sandbox
✓ Requires consensus across instances
✓ Can be deployed gradually (gradual rollout)
✓ Easy rollback (revert NATS message)
```

### Type 3 (Genesis) Safety
```
✓ Complete isolation (separate DB, separate Git)
✓ Aggressive hotreload (can test unsafe changes)
✓ Automatic rollback on regression
✓ No production impact
✓ Full metrics collection (why did it fail?)
```

## Example Improvement Workflows

### Workflow 1: Local Pattern Discovery → Global Deployment

```
Day 1, Instance A:
  Pattern discovered: "Decompose multi-task problems with pre-classifier"
  Success rate: 85% (vs baseline 70%)
  → Applied locally, git committed, sent to Centralcloud

Day 2, Instance B & C:
  Receive pattern from Centralcloud
  Apply with validation
  Success rate: 84%, 86% (consistent!)

Day 3, Centralcloud:
  Detects >70% frequency
  Sends to Genesis for safety test
  Genesis confirms: no edge cases, safe to deploy

Day 4, All Instances:
  Receive validated improvement
  Apply to codebases
  Improvement now global standard
```

### Workflow 2: High-Risk Experiment Request

```
Singularity Instance:
  Discovery: "New approach could reduce LLM calls by 40%"
  Risk: "But might break existing decomposition patterns"
  → Sends experiment request to Genesis

Genesis (same day):
  Receives: "Test new multi-level decomposition with memoization"
  Creates isolated experiment environment
  Applies changes with hotreload
  Runs expensive LLM tests (cost OK in sandbox)
  Measures: Reduces LLM calls 38%, breaks 2% of patterns

  Reports:
    status: "partial_success"
    metrics: {llm_reduction: 0.38, regression: 0.02}
    recommendation: "Apply with pattern adaptation"

Singularity Instance (next day):
  Reviews report
  Decides: "Apply with fallback to old decomposition for edge cases"
  Genesis rolls back its version
  Singularities applies adapted version locally
```

### Workflow 3: Centralcloud-Recommended Experiment

```
Centralcloud (hourly):
  Analyzes patterns across 5 instances
  Discovers: "Framework X appears in 95% of instances"
  Trend: "New version 2.0 of Framework X could simplify 20% of patterns"

  → Recommends to Genesis: "Test Framework X 2.0 migration"

Genesis (next day):
  Tests Framework X 2.0 on all recent codebase samples
  Confirms: Simplifies patterns, reduces code by 18%
  No regressions found

  → Reports success to Centralcloud

Centralcloud:
  Broadcasts: "Framework X 2.0 migration available"
  Instances apply gradually, confirm benefits
```

## Configuration

### Singularity Configuration

```elixir
# singularity/config/config.exs

config :singularity,
  self_improvement: [
    enabled: true,
    local_validation: true,
    send_to_centralcloud: true,
    request_genesis_for: [:high_risk, :architectural_changes]
  ]

config :singularity, :genesis,
  host: "localhost",
  port: 4001,
  request_timeout_ms: 3600_000  # 1 hour for long-running experiments
```

### Genesis Configuration

```elixir
# genesis/config/config.exs

config :genesis,
  experiment: [
    timeout_ms: 3600_000,
    max_iterations: 100,
    auto_rollback_on_regression: true,
    regression_threshold: 0.05
  ],
  isolation: [
    separate_db: true,
    separate_git: true,
    aggressive_hotreload: true
  ]
```

## Key Differences from Genesis-Only Model

| Aspect | Request-Driven (Current) | Genesis-Only (Alternative) |
|--------|---------------------------|---------------------------|
| **Instance Independence** | High (instances self-improve) | Low (depends on Genesis) |
| **Improvement Speed** | Fast (Type 1 = minutes) | Slow (all via Genesis) |
| **Risk** | Low (isolated failures) | Medium (single point of failure) |
| **Scalability** | Excellent (N instances improve) | Limited (Genesis bottleneck) |
| **Experiment Cost** | Controlled (only high-risk to Genesis) | High (everything tested in Genesis) |
| **Rollback Complexity** | Simple (per instance) | Complex (coordinate all instances) |

## Rationale for Architecture

1. **Singularities are Autonomous:** Each instance should improve itself first, learning from its own experience
2. **Genesis is Safety Layer:** Not the improvement engine, but the sandbox for validating high-risk changes
3. **Centralcloud is Collective Intelligence:** Detects patterns that transcend single instances
4. **Request-Driven Reduces Waste:** Only expensive Genesis tests are done for genuinely risky changes
5. **Isolation Prevents Disaster:** Genesis failure doesn't impact production instances

## Comparison to Alternative Models

### Option A: Genesis-Only (Genesis decides all improvements)
**Problems:**
- Genesis is bottleneck
- Instances can't improve independently
- Requires constant Genesis availability
- High cost (everything tested in Genesis)

### Option B: Pure Self-Improvement (No Genesis)
**Problems:**
- No safety sandbox for high-risk changes
- Risk of global regression
- Difficult to test expensive hypotheses
- One bad rollout affects all instances

### Option C: Current Request-Driven Model ✅
**Benefits:**
- Fast local improvements (Type 1)
- Safe high-risk testing (Type 3)
- Collective intelligence (Type 2)
- Genesis is helper, not bottleneck
- Instances autonomous first

## Next Steps

1. **Commit current improvements** (ML training jobs, aggregation, documentation)
2. **Create Genesis application** (new Elixir app)
3. **Implement experiment request handler** (NATS receiver)
4. **Build isolation & rollback framework**
5. **Add metrics and success tracking**
6. **Test full workflow** (request → Genesis → report → apply/rollback)

---

**Document Version:** 2.1 (Request-Driven Model)
**Last Updated:** 2025-10-23
**Status:** Architecture Approved, Implementation Pending
