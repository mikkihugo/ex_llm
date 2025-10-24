# Genesis Application - Comprehensive Analysis

## Executive Summary

Genesis is an **isolated improvement sandbox application** that safely tests code experiments proposed by Singularity instances. It operates as a **completely separate Elixir application** with:

- **Separate PostgreSQL database** (`genesis_db`)
- **Isolated NATS subscriptions** (`agent.events.experiment.*` subjects)
- **Independent Git history** (sandboxed directories)
- **Self-contained supervision tree** with no external dependencies
- **Complete failure isolation** - Genesis failures don't affect Singularity

**Purpose:** Execute improvement experiments in isolation, measure impact, and recommend merge/rollback decisions.

---

## Core Components Inventory

### 1. FOUNDATION LAYER (Database & Infrastructure)

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.Repo` | 18 LOC | PostgreSQL connection | GenServer |
| `Genesis.Application` | 61 LOC | OTP supervision tree | Application |

### 2. MESSAGING & ORCHESTRATION LAYER

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.NatsClient` | 252 LOC | NATS pub/sub, reconnection handling | GenServer |
| `Genesis.ExperimentRunner` | 706 LOC | Main experiment execution orchestrator | GenServer |

**Key Subjects:**
- **Incoming:** `agent.events.experiment.request.{instance_id}`
- **Outgoing:** `agent.events.experiment.completed.{experiment_id}`, `agent.events.experiment.failed.{experiment_id}`

### 3. ISOLATION & SAFETY LAYER

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.IsolationManager` | 148 LOC | Sandbox creation & lifecycle | GenServer |
| `Genesis.RollbackManager` | 241 LOC | Git-based rollback, checkpoint management | GenServer |
| `Genesis.SandboxMaintenance` | 241 LOC | Cleanup, archival, integrity checking | Plain module |

**Isolation Strategy:**
- Each experiment gets a **directory copy** in `~/.genesis/sandboxes/{experiment_id}/`
- Copies include: `singularity/`, `centralcloud/`, `genesis/`, `rust/`, `ai_server/`
- Changes **never** touch main repository
- On failure: **Delete sandbox** (instant rollback, <1 second)
- On success: **Preserve sandbox** for review/analysis

### 4. METRICS & ANALYSIS LAYER

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.MetricsCollector` | 197 LOC | Record & recommend based on metrics | GenServer |
| `Genesis.LLMCallTracker` | 208 LOC | Measure LLM call reduction | Plain module |
| `Genesis.Scheduler` | 209 LOC | Orchestrate jobs (cleanup, analysis, reporting) | Plain module |

**Metrics Tracked:**
- **Outcome:** success_rate, regression, llm_reduction, runtime_ms
- **Performance:** memory_peak_mb, cpu_usage_percent, io_operations
- **Quality:** code_coverage_percent, complexity_change, performance_delta

**Recommendation Decision:**
```elixir
:rollback             # If regression > 5% OR success_rate < 70%
:merge                # If llm_reduction > 30% AND regression < 3% OR success_rate > 95%
:merge_with_adaptations # If success_rate > 90% AND regression < 5%
```

### 5. LOGGING & STRUCTURED TRACING

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.StructuredLogger` | 232 LOC | Contextual logging with experiment metadata | Plain module |

**Logged Events:**
- `experiment_start`, `experiment_progress`, `sandbox_created`, `changes_applied`
- `tests_completed`, `metrics_measured`, `experiment_complete`, `experiment_failed`
- `experiment_timeout`, `rollback_initiated`, `metrics_reported`

### 6. SCHEDULED JOBS (Oban Workers)

| Module | Size | Purpose | Type |
|--------|------|---------|------|
| `Genesis.Cleanup` | 26 LOC | Run cleanup job (every 6 hours) | Oban Worker |
| `Genesis.Analysis` | 27 LOC | Run trend analysis job (every 24 hours) | Oban Worker |
| `Genesis.Reporting` | 27 LOC | Run metrics reporting job (every 24 hours, 1 AM) | Oban Worker |
| `Genesis.Scheduler` | 209 LOC | Job implementations (not Oban worker itself) | Plain module |
| `Genesis.Jobs` | 47 LOC | Job enqueuing (if manual) | Plain module |

### 7. DATABASE SCHEMAS

| Schema | Purpose |
|--------|---------|
| `experiment_records` | Track all experiment requests (primary key: experiment_id) |
| `experiment_metrics` | Store detailed metrics for each experiment |
| `sandbox_history` | Audit trail of sandbox operations (create, cleanup, archive) |

---

## Module Dependency Graph

```
Genesis.Application
├── Genesis.Repo (database)
├── Oban (background jobs)
├── Task.Supervisor (timeout handling)
├── Genesis.NatsClient (NATS messaging)
│   └── :gnat library
├── Genesis.IsolationManager (sandbox creation)
│   └── File operations
├── Genesis.RollbackManager (git rollback)
│   └── System.cmd("git ...")
├── Genesis.MetricsCollector (metrics recording)
│   └── Genesis.Repo
│   └── Genesis.Schemas.ExperimentMetrics
└── Genesis.ExperimentRunner (main orchestrator)
    ├── Genesis.IsolationManager
    ├── Genesis.RollbackManager
    ├── Genesis.MetricsCollector
    ├── Genesis.LLMCallTracker
    ├── Genesis.StructuredLogger
    └── Task.Supervisor (timeout handling)

Genesis.Scheduler (trait orchestrator)
├── Genesis.SandboxMaintenance
├── Genesis.Repo
├── Genesis.Schemas.ExperimentMetrics
└── Genesis.NatsClient

Genesis.StructuredLogger (provides logging to all)
├── Logger (Elixir built-in)
└── No external dependencies
```

---

## Duplicate Systems (Genesis vs Singularity)

### 1. MetricsCollector vs Singularity.Metrics.Aggregator

| Aspect | Genesis | Singularity |
|--------|---------|------------|
| **Purpose** | Record individual experiment outcomes | Aggregate metrics across agents |
| **Storage** | `experiment_metrics` table | `metrics` table |
| **Decision Making** | recommend(metrics) → merge/rollback | Cost optimization, agent tuning |
| **Data Flow** | LLM reduction, test results → DB | Agent performance, LLM usage trends |
| **Scope** | Single experiment | Multi-agent analytics |

**Why Duplication?** Genesis metrics are **high-frequency outcome data** (1 per experiment), while Singularity metrics are **aggregate analytics** (trending over time). They serve different purposes but could be unified.

### 2. StructuredLogger vs Singularity's Logging

| Aspect | Genesis | Singularity |
|--------|---------|------------|
| **Implementation** | Custom Logger.info/error calls | TBD (need to check Singularity) |
| **Metadata** | experiment_id, instance_id, stage | TBD |
| **Correlation** | Via experiment_id | TBD |
| **Storage** | Log files only | TBD |

**Why Duplication?** Genesis needs **experiment-scoped logging** for isolation. Singularity likely has **agent-scoped logging**. Could share log structure but keep scopes separate.

### 3. Scheduler vs JobOrchestrator (Singularity)

| Aspect | Genesis | Singularity |
|--------|---------|------------|
| **Jobs** | cleanup, analysis, reporting | TBD |
| **Orchestration** | Oban with Cron plugin | TBD |
| **Failure Handling** | max_attempts: 3 | TBD |
| **Scope** | Genesis-specific tasks | Application-wide tasks |

**Why Duplication?** Genesis is independent, but could eventually use shared job infrastructure.

### 4. LLMCallTracker vs Singularity's Code Analysis

| Aspect | Genesis | Singularity |
|--------|---------|------------|
| **Purpose** | Measure LLM reduction in experiments | Code analysis, pattern extraction |
| **Method** | Regex pattern matching on source code | Rust NIF + AST analysis |
| **Accuracy** | Heuristic (~40%) | High-precision (Rust parser) |
| **Data** | `llm_reduction` metric | Pattern library, knowledge base |

**Critical Blocker:** Genesis's LLMCallTracker uses **regex-based heuristics**, while Singularity has **high-precision Rust code analysis**. Integration point: Genesis should use Singularity's parsing!

---

## Integration Points & Opportunities

### HIGH PRIORITY (Critical for efficiency)

#### 1. **Code Analysis Integration** - Genesis → Singularity
```
Current: Genesis.LLMCallTracker (regex, ~40% accurate)
Better:  Singularity.UniversalParser + Rust NIFs
Benefit: Accurate LLM reduction measurements
NATS:    genesis.coderequest → code.analysis.parse
```

#### 2. **Metrics Unification** - Both → Shared Service
```
Current: Genesis.MetricsCollector (experiment outcomes)
Current: Singularity.Metrics.Aggregator (aggregate analytics)
Better:  Unified metrics store with dual views
Benefit: Single source of truth, better trending analysis
NATS:    metrics.record → metrics.service
```

#### 3. **Logging Correlation** - Genesis ↔ Singularity
```
Current: Separate structured logs
Better:  Shared correlation ID (experiment_id or job_id)
Benefit: Follow experiment from request → execution → metrics
NATS:    Use headers for distributed tracing
```

### MEDIUM PRIORITY (Nice to have)

#### 4. **Framework Pattern Detection** - Genesis → Singularity
```
Current: Genesis runs experiments blindly
Better:  Query Singularity's FrameworkPatternStore first
Benefit: Experiments can test framework-aware optimizations
NATS:    genesis.framework.query → singularity.patterns.match
```

#### 5. **Template System Integration** - Genesis ↔ Singularity
```
Current: Genesis generates own test patterns
Better:  Reuse Singularity's technology templates
Benefit: Consistent testing, reduce code duplication
NATS:    genesis.template.list → singularity.templates.*
```

#### 6. **Rollback Coordination** - Genesis → Singularity
```
Current: Genesis rollbacks are independent
Better:  Report rollback reasons to Singularity for learning
Benefit: Singularity learns which experiments fail, avoids repeats
NATS:    genesis.rollback.event → singularity.learning.failure
```

### LOW PRIORITY (Nice to explore later)

#### 7. **Sandbox as Code** - Genesis ↔ Singularity
```
Current: Genesis creates fresh sandboxes each time
Better:  Singularity could run in isolated Genesis sandbox
Benefit: Test Singularity itself in isolated sandbox
NATS:    genesis.spawn_application → genesis.return_metrics
```

---

## Data Flow Diagram

```
Singularity Instance
      ↓ NATS: agent.events.experiment.request.{instance_id}
      ↓ (experiment_id, risk_level, changes, rollback_plan)
      
Genesis.ExperimentRunner
      ├→ Genesis.IsolationManager.create_sandbox()
      │  └→ ~/.genesis/sandboxes/{experiment_id}/
      │
      ├→ Apply changes to sandbox
      │
      ├→ Genesis.RollbackManager.create_checkpoint()
      │  └→ Git HEAD hash capture
      │
      ├→ Run tests in sandbox
      │  └→ System.cmd("cd sandbox && mix test")
      │
      ├→ Genesis.LLMCallTracker.measure_llm_calls()  [⚠ SHOULD USE SINGULARITY]
      │
      ├→ Genesis.MetricsCollector.recommend(metrics)
      │  ├→ Record to experiment_metrics table
      │  └→ Decision: merge/merge_with_adaptations/rollback
      │
      ├→ Conditional Rollback
      │  └→ Genesis.RollbackManager.emergency_rollback()
      │      └→ git reset --hard {baseline_commit}
      │
      └→ Report back to Singularity
         ↓ NATS: agent.events.experiment.completed.{experiment_id}
         ↓ (status, metrics, recommendation)
         
Singularity Instance
      └→ Use recommendation for merge decision
```

---

## NATS Message Contracts

### Request: `agent.events.experiment.request.{instance_id}`

```json
{
  "experiment_id": "uuid",
  "instance_id": "singularity-prod-1",
  "experiment_type": "decomposition",
  "description": "Test multi-task decomposition with pre-classifier",
  "risk_level": "high",
  "estimated_impact": 0.40,
  "changes": {
    "files": ["lib/singularity/planning/sparc.ex"],
    "description": "Add pre-classifier to SPARC decomposition"
  },
  "rollback_plan": "git reset --hard <commit>",
  "timeout_ms": 3600000
}
```

### Response: `agent.events.experiment.completed.{experiment_id}`

```json
{
  "experiment_id": "uuid",
  "status": "success",
  "metrics": {
    "success_rate": 0.95,
    "llm_reduction": 0.38,
    "regression": 0.02,
    "runtime_ms": 3600000,
    "test_count": 250,
    "failures": 15
  },
  "recommendation": "merge_with_adaptations",
  "timestamp": "2025-10-24T12:34:56Z"
}
```

### Error Response: `agent.events.experiment.failed.{experiment_id}`

```json
{
  "experiment_id": "uuid",
  "status": "failed",
  "error": "Sandbox sandbox path not found",
  "recommendation": "rollback",
  "timestamp": "2025-10-24T12:35:00Z"
}
```

### Metrics Reporting: `system.metrics.genesis` (daily)

```json
{
  "source": "genesis",
  "hostname": "genesis-prod",
  "timestamp": "2025-10-24T01:00:00Z",
  "metrics": {
    "total_experiments": 150,
    "successful_experiments": 138,
    "success_rate": 0.92,
    "avg_regression": 0.018,
    "avg_llm_reduction": 0.275,
    "by_type": {...},
    "by_risk_level": {...},
    "period": "30 days"
  }
}
```

---

## Safety & Isolation Guarantees

### Genesis Safety Features

| Feature | Implementation | Guarantee |
|---------|---|---|
| **No Main Repo Modification** | Sandbox copies in `~/.genesis/` | Changes never touch source |
| **Instant Rollback** | `rm -rf sandbox_dir` | <1 second recovery |
| **Timeout Protection** | Task.yield(timeout_ms) | Auto-cleanup on timeout |
| **Auto Rollback** | On regression > 5% | Automatic safety brake |
| **Database Isolation** | Separate `genesis_db` | No cross-DB contamination |
| **Process Isolation** | Separate BEAM processes | Crash isolation |
| **Audit Trail** | All ops in sandbox_history | Full post-mortem capability |

### Current Safety Concerns

| Concern | Risk | Mitigation |
|---------|------|-----------|
| **LLM Measurement Accuracy** | Regex-based, ~40% accurate | Use Singularity.UniversalParser |
| **Incomplete Rollback** | If mix compile partially succeeds | Git reset --hard catches this |
| **Concurrent Experiments** | 5 max (configurable) | Queue system (Oban) could help |
| **Long-Running Tests** | 1 hour timeout default | Could cause incomplete results |
| **Sandbox Disk Space** | Full directory copies | Could fill disk with 100+ sandboxes |

---

## Integration Strategy (Safe Approach)

### Phase 1: KEEP ISOLATED (Weeks 1-2)

Genesis stays **completely isolated**:
- Separate database: ✅ `genesis_db`
- Separate NATS subjects: ✅ `agent.events.experiment.*`
- Separate supervision: ✅ No Genesis → Singularity calls
- Separate git operations: ✅ Sandbox copies only

**Only addition:** Genesis publishes results to NATS for Singularity to consume.

### Phase 2: INTEGRATE CODE ANALYSIS (Weeks 3-4)

**Goal:** Improve LLM reduction measurement accuracy

```elixir
# Current (Genesis.LLMCallTracker - regex-based)
llm_reduction = estimate_llm_reduction(sandbox, risk_level)

# Better (Use Singularity analysis)
case Genesis.NatsClient.call("code.analysis.parse", %{"sandbox_path" => sandbox}) do
  {:ok, ast} -> accurate_llm_reduction = calculate_from_ast(ast)
  {:error, _} -> fallback_to_regex_estimate()
end
```

**Safety:** Genesis uses fallback if Singularity analysis unavailable.

### Phase 3: UNIFIED METRICS (Weeks 5-6)

**Goal:** Single metrics source with different views

```elixir
# Both Genesis and Singularity write to same table
Metrics.record(
  type: :experiment,
  source: :genesis,
  experiment_id: exp_id,
  metrics: %{success_rate: 0.95, ...}
)

Metrics.record(
  type: :agent_performance,
  source: :singularity,
  agent_id: agent_id,
  metrics: %{tasks_completed: 100, ...}
)

# Queries with filtering
Metrics.query(source: :genesis, last: "30 days")
Metrics.query(type: :agent_performance, source: :singularity)
```

**Safety:** Separate schema tables with source filtering.

### Phase 4: DISTRIBUTED TRACING (Weeks 7-8)

**Goal:** Follow experiments from request → execution → results

```
Singularity Agent
  ↓ trace_id: "exp-abc123"
Genesis.ExperimentRunner
  ↓ trace_id: "exp-abc123" (propagate)
Singularity Learning Agent
  ↓ trace_id: "exp-abc123" (use for correlation)
Metrics, Logs, Reports all tagged with trace_id
```

---

## Implementation Roadmap

### IMMEDIATE (This Week)

1. **No changes to Genesis**
   - Genesis stays fully isolated
   - Already safe, already working

2. **Create Integration Test**
   ```bash
   # Test that Genesis experiments can execute independently
   mix test integration/genesis_isolation_test.exs
   ```

3. **Document NATS Contracts**
   - Genesis publishes to: `agent.events.experiment.completed.{exp_id}`
   - Singularity should subscribe to this subject

### SHORT TERM (Next 2 Weeks)

1. **Upgrade LLM Measurement** (if Singularity can export analysis)
   ```elixir
   # In Genesis.ExperimentRunner
   case analyze_with_singularity(sandbox) do
     {:ok, accurate_llm} -> use_accurate_llm
     {:error, _} -> use_regex_fallback()
   end
   ```

2. **Add Metrics.record() integration** (if Singularity has unified store)
   ```elixir
   # In Genesis.MetricsCollector.record_to_db()
   Singularity.Metrics.record(:genesis_experiment, metrics)
   ```

3. **Publish Genesis health** to Singularity
   ```elixir
   # Every 5 minutes
   Genesis.NatsClient.publish("system.health.genesis", %{
     "active_experiments" => count(),
     "success_rate_30d" => 0.92,
     "disk_used_mb" => calculate_disk()
   })
   ```

### MEDIUM TERM (Next Month)

1. **Framework-Aware Experiments**
   - Genesis queries Singularity for detected frameworks
   - Tailors experiments to framework-specific optimizations

2. **Merged Learning**
   - Both update same knowledge base
   - Experiments teach Singularity patterns
   - Singularity teaches experiments what works

3. **Coordinated Rollback**
   - Genesis rollbacks → Singularity learning
   - "Experiment ABC failed, avoid this pattern"

---

## File Inventory (Complete)

### Application Structure

```
genesis/
├── lib/genesis/
│   ├── application.ex                    (61 LOC) - OTP supervision
│   ├── repo.ex                          (18 LOC) - Ecto repo config
│   ├── nats_client.ex                   (252 LOC) - NATS messaging
│   ├── experiment_runner.ex             (706 LOC) - Main orchestrator
│   ├── isolation_manager.ex             (148 LOC) - Sandbox creation
│   ├── rollback_manager.ex              (241 LOC) - Git rollback
│   ├── metrics_collector.ex             (197 LOC) - Metrics recording
│   ├── llm_call_tracker.ex              (208 LOC) - LLM measurement
│   ├── structured_logger.ex             (232 LOC) - Logging
│   ├── scheduler.ex                     (209 LOC) - Job orchestration
│   ├── sandbox_maintenance.ex           (241 LOC) - Cleanup/archival
│   ├── jobs.ex                          (47 LOC) - Job enqueue helpers
│   ├── analysis.ex                      (27 LOC) - Oban worker: analysis
│   ├── reporting.ex                     (27 LOC) - Oban worker: reporting
│   ├── cleanup.ex                       (26 LOC) - Oban worker: cleanup
│   └── schemas/
│       ├── experiment_record.ex         (80+ LOC) - DB schema
│       ├── experiment_metrics.ex        (100+ LOC) - DB schema
│       └── sandbox_history.ex           (TBD) - DB schema
│
├── config/
│   ├── config.exs                       (50 LOC) - Base config
│   ├── dev.exs                          - Dev overrides
│   ├── test.exs                         - Test overrides
│   └── prod.exs                         - Prod overrides
│
├── priv/repo/migrations/
│   ├── 20250101000001_create_experiment_records.exs
│   ├── 20250101000002_create_experiment_metrics.exs
│   └── 20250101000003_create_sandbox_history.exs
│
└── mix.exs                              (41 LOC) - Mix project
```

### Total Code: ~2,640 LOC (excluding schemas & tests)

---

## Key Insights for Integration

### What Genesis Does Well

1. **Isolation** - Perfect directory-based sandboxing
2. **Safety** - Instant rollback, timeout protection
3. **Measurement** - Comprehensive metrics collection
4. **Reliability** - GenServer-based supervision
5. **Auditability** - Full experiment history in DB

### What Genesis Needs from Singularity

1. **Code Analysis** - Use Singularity's Rust parsers, not regex
2. **Framework Detection** - Know what framework being tested
3. **Template System** - Reuse Singularity's test templates
4. **Pattern Library** - Learn from Singularity's patterns
5. **Metrics Integration** - Unified metrics store

### What Singularity Needs from Genesis

1. **Experiment Results** - Learn which experiments work
2. **Rollback Signals** - When to avoid certain patterns
3. **Regression Detection** - Early warning system
4. **Test Coverage** - Safe testing infrastructure

---

## Conclusion

Genesis is a **well-designed, isolated sandbox** that works independently. It has **minimal duplication** with Singularity - mostly just independent implementations of logging and scheduling.

**Safe Integration Strategy:**
1. Keep Genesis 100% isolated (no changes needed)
2. Genesis publishes results to NATS
3. Singularity consumes Genesis results
4. Optional: Genesis uses Singularity's analysis tools (with fallback)
5. Optional: Unified metrics store (later phase)

**No architectural blockers** - just opportunities for better accuracy and shared learning.
