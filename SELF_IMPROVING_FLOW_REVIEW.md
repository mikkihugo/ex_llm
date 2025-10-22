# Self-Improving Flow Review

## Executive Summary

Singularity's self-improving system has **two distinct but complementary flows**:

1. **HTDAG Auto-Bootstrap** - Zero-touch startup self-diagnosis and repair
2. **Self-Improving Agent** - Runtime continuous improvement based on metrics

**Default Changed:** `dry_run` is now `true` by default (safe mode) - you must explicitly opt-in to apply fixes.

---

## 1. HTDAG Auto-Bootstrap Flow

### Purpose
Automatic codebase diagnosis and repair **on server startup** - zero human intervention required.

### When It Runs
- **Automatically on startup** (if `enabled: true`, `run_async: true`)
- **Manually via** `HTDAGAutoBootstrap.run_now()`

### Flow Diagram

```
Server Starts
    ↓
HTDAG Auto-Bootstrap Starts (async)
    ↓
Phase 1: Learn Codebase
    ├─ Scan all source files
    ├─ Read @moduledoc from every module
    ├─ Build dependency graph
    ├─ Extract integration points
    └─ Identify issues (broken deps, missing docs, etc.)
    ↓
Phase 2: Auto-Fix Issues (if enabled)
    ├─ Prioritize by severity (High > Medium > Low)
    ├─ For each issue:
    │   ├─ Search RAG for similar code examples
    │   ├─ Load quality templates from knowledge base
    │   ├─ Generate fix using LLM (via NATS)
    │   ├─ Validate fix (syntax, type checking)
    │   └─ Apply fix (if dry_run: false) OR simulate (if dry_run: true)
    ├─ Re-scan to find new issues
    └─ Iterate until max_iterations or all issues fixed
    ↓
System Ready ✓
```

### What Gets Fixed

| Issue Type | Severity | Detection | Fix Strategy |
|------------|----------|-----------|--------------|
| Broken dependencies | High | Static analysis (`alias` statements) | Add missing or remove invalid |
| Missing @moduledoc | Low | File scanning | Generate from module name |
| Isolated modules | Medium | Dependency graph | Connect to related modules |
| Dead code | Medium | Runtime tracing | Mark for review or remove |
| Crashed functions | High | Runtime tracing + logs | Wrap in error handling |
| Slow functions | Medium | Performance profiling | Optimization suggestions |
| Disconnected from Store | High | Check Store.search_knowledge | Add Store integration |
| Missing telemetry | Low | Check :telemetry.execute | Add telemetry events |

### Configuration

**Default (after this change):**
```elixir
@default_config [
  enabled: true,              # Enable auto-bootstrap
  max_iterations: 10,         # Max fix iterations
  fix_on_startup: true,       # Auto-fix issues on startup
  notify_on_complete: true,   # Log completion summary
  run_async: true,            # Run in background (non-blocking)
  dry_run: true               # SAFE MODE: Simulate fixes without applying (NEW DEFAULT)
]
```

**To Enable Real Fixes:**
```elixir
# In config/config.exs
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  dry_run: false  # Enable real fixes

# Or at runtime
HTDAGAutoBootstrap.run_now(dry_run: false)
```

### Manual Control

```elixir
# Check status
HTDAGAutoBootstrap.status()
# => %{
#   status: :completed,
#   enabled: true,
#   dry_run: true,
#   iterations: 3,
#   issues_found: 12,
#   issues_fixed: 8,
#   fixes_applied: 8
# }

# Disable auto-bootstrap
HTDAGAutoBootstrap.disable()

# Re-enable
HTDAGAutoBootstrap.enable()

# Trigger manually with custom config
HTDAGAutoBootstrap.run_now(dry_run: false, max_iterations: 5)
```

### Telemetry Events

All events are emitted for observability:

- `[:htdag, :auto_bootstrap, :start]` - Bootstrap started
- `[:htdag, :learn, :start]` - Learning phase started
- `[:htdag, :learn, :complete]` - Learning complete (with issues_found)
- `[:htdag, :identify_issues, :complete]` - Issue identification complete
- `[:htdag, :fix, :start]` - Fix phase started
- `[:htdag, :fix, :complete]` - Fix phase complete (with iterations, fixes_applied)
- `[:htdag, :fix, :error]` - Fix phase error
- `[:htdag, :auto_bootstrap, :complete]` - Bootstrap successful
- `[:htdag, :auto_bootstrap, :error]` - Bootstrap error

### Integration Points

**Modules Used:**
- `Singularity.Planning.HTDAGLearner` - Codebase understanding and issue detection
- `Singularity.Planning.HTDAGTracer` - Runtime analysis and function health
- `Singularity.Planning.HTDAGBootstrap` - Fixing broken components
- `Singularity.LLM.Service` - LLM calls via NATS (cost-optimized)
- `Singularity.Knowledge.ArtifactStore` - Quality templates and code patterns
- `Singularity.CodeSearch` - RAG for finding similar code examples

**File Location:** [htdag_auto_bootstrap.ex](singularity/lib/singularity/planning/htdag_auto_bootstrap.ex)

---

## 2. Self-Improving Agent Flow

### Purpose
**Continuous runtime improvement** based on observed performance metrics.

### When It Runs
- **Every tick** (default: 5 seconds)
- **Triggered by metrics** (success rate, failures, stagnation)
- **Forced via API** (`SelfImprovingAgent.force_improvement/2`)

### Flow Diagram

```
Agent Running (Tick every 5s)
    ↓
Autonomy Decider: Evaluate Metrics
    ├─ Calculate score: (successes / (successes + failures))
    ├─ Check stagnation: cycles since last improvement
    ├─ Check backoff: cycles since last failure
    └─ Decision:
        ├─ Continue (no action needed)
        └─ Improve (trigger evolution)
    ↓
Autonomy Planner: Generate Strategy
    ├─ Check for vision-driven tasks (SAFe Work Planner)
    ├─ Check for critical refactoring needs (Refactoring Analyzer)
    └─ Generate code:
        ├─ Vision Task → SPARC decomposition → LLM code generation
        ├─ Refactoring → Pattern-based refactoring code
        └─ Simple → Placeholder improvement module
    ↓
Autonomy Limiter: Rate Limiting
    ├─ Check improvements per day (default: 100)
    ├─ Check concurrent operations
    └─ Allow or queue
    ↓
Hot Reload Manager: Apply Improvement
    ├─ Validate payload (syntax, structure)
    ├─ Check for duplicates (fingerprint)
    ├─ Compile to BEAM
    ├─ Load new module
    └─ Notify agent: :reload_complete or :reload_failed
    ↓
Validation Period (30s default)
    ├─ Capture baseline metrics (memory, run_queue)
    ├─ Monitor for regressions
    └─ Decision:
        ├─ Validated → Keep new code
        └─ Regression → Rollback to previous
    ↓
Agent Continues (Idle → Observing → ...)
```

### Key Components

#### Autonomy Decider
**Purpose:** Decide when to evolve

**Metrics:**
- `successes` - Successful task executions
- `failures` - Failed task executions
- `score` - Normalized success rate (0.0 to 1.0)
- `stagnation` - Cycles since last improvement

**Triggers:**
1. **Score Drop:** `samples >= 8 AND score < 0.75`
2. **Stagnation:** `stagnation_cycles >= 30`
3. **Forced:** Manual trigger via API

**Backoff:** After failure, wait 10 cycles before next attempt

**File:** [decider.ex](singularity/lib/singularity/autonomy/decider.ex)

#### Autonomy Planner
**Purpose:** Generate new code for agent improvement

**Priority Order:**
1. **Critical Refactoring** (highest) - Technical debt, code duplication
2. **Vision-Driven Tasks** (medium) - WSJF-prioritized features from SAFe
3. **Simple Improvement** (fallback) - Placeholder evolution

**Code Generation:**
- Uses `Singularity.LLM.Service` via NATS
- Complexity level: `:complex` (uses Claude Opus, GPT-4)
- Integrates with:
  - `SafeWorkPlanner` - Feature backlog
  - `StoryDecomposer` - SPARC methodology
  - `PatternMiner` - Learned best practices
  - `Analyzer` - Refactoring needs

**File:** [planner.ex](singularity/lib/singularity/autonomy/planner.ex)

#### Autonomy Limiter
**Purpose:** Rate limiting and budget control

**Limits:**
- Max improvements per day (configurable via `IMP_LIMIT_PER_DAY`)
- Prevents thrashing
- Budget-aware (tracks LLM costs)

**File:** [limiter.ex](singularity/lib/singularity/autonomy/limiter.ex)

#### Hot Reload Manager
**Purpose:** Dynamic code compilation and activation

**Safety Features:**
- Preflight validation (syntax, structure)
- Duplicate detection (fingerprint-based)
- Rollback capability (stores previous code)
- Validation period (30s default)

**File:** [hot_reload.ex](singularity/lib/singularity/hot_reload.ex)

### Agent State Machine

**States:**
- `:idle` - Waiting for next evaluation cycle
- `:updating` - Improvement in progress

**Lifecycle:**
```
Init (Load queue from CodeStore)
  ↓
:idle → (tick) → Evaluate → (continue) → :idle
                            ↓ (improve)
                         :updating → HotReload
                            ↓ (:reload_complete)
                         Validation Period (30s)
                            ↓ (no regression)
                         :idle (success)
                            ↓ (regression)
                         Rollback → :updating → :idle
```

### Configuration

**Environment Variables:**
```bash
IMP_LIMIT_PER_DAY=100                 # Max improvements per day
IMP_VALIDATION_DELAY_MS=30000         # Validation delay (30s)
IMP_VALIDATION_MEMORY_MULT=1.25       # Memory regression threshold (25% growth)
IMP_VALIDATION_RUNQ_DELTA=50          # Run queue regression threshold
MIN_CONFIDENCE_THRESHOLD=95           # Initial deployment confidence
```

**Agent Options:**
```elixir
SelfImprovingAgent.start_link(
  id: "agent-001",
  tick_interval_ms: 5000,  # Evaluation frequency
  context: %{
    goals: ["improve_response_time", "reduce_memory"],
    constraints: ["no_breaking_changes"]
  }
)
```

### API

```elixir
# Record outcomes
SelfImprovingAgent.record_outcome("agent-001", :success)
SelfImprovingAgent.record_outcome("agent-001", :failure)

# Update metrics
SelfImprovingAgent.update_metrics("agent-001", %{
  response_time_ms: 120,
  memory_mb: 45
})

# Force improvement
SelfImprovingAgent.force_improvement("agent-001", "manual_trigger")

# Enqueue improvement (external)
payload = %{
  "code" => "defmodule ...",
  "metadata" => %{"reason" => "external"}
}
SelfImprovingAgent.improve("agent-001", payload)
```

### Telemetry Events

- `[:singularity, :improvement, :attempt]` - Improvement attempt started
- `[:singularity, :improvement, :success]` - Improvement succeeded
- `[:singularity, :improvement, :failure]` - Improvement failed
- `[:singularity, :improvement, :validated]` - Improvement validated (no regression)
- `[:singularity, :improvement, :validation_failed]` - Regression detected
- `[:singularity, :improvement, :rollback]` - Rolled back to previous code
- `[:singularity, :improvement, :queued]` - Improvement queued (rate limited)
- `[:singularity, :improvement, :duplicate]` - Duplicate improvement ignored
- `[:singularity, :improvement, :rate_limited]` - Rate limit hit
- `[:singularity, :improvement, :invalid]` - Invalid payload rejected

### File Location

[self_improving_agent.ex](singularity/lib/singularity/agents/self_improving_agent.ex)

---

## Comparison: Auto-Bootstrap vs Self-Improving Agent

| Feature | HTDAG Auto-Bootstrap | Self-Improving Agent |
|---------|---------------------|---------------------|
| **When** | Startup (one-time or manual) | Continuous runtime |
| **Trigger** | Automatic on server start | Metrics-driven (success rate, stagnation) |
| **What** | Fix broken code (deps, docs, dead code) | Evolve agent behavior (features, refactoring) |
| **How** | Static analysis + runtime tracing | Performance metrics + decision logic |
| **Code Generation** | RAG + quality templates | SPARC decomposition + pattern mining |
| **Safety** | dry_run mode (default: true) | Validation period + rollback |
| **Scope** | Entire codebase | Single agent instance |
| **Iterations** | Max 10 (configurable) | Unlimited (rate limited) |
| **Telemetry** | `[:htdag, :auto_bootstrap, ...]` | `[:singularity, :improvement, ...]` |

---

## Safety Features

### 1. Dry-Run Mode (HTDAG Auto-Bootstrap)

**DEFAULT: ON** (as of this change)

- **Simulates fixes without applying them**
- **Shows what would be fixed**
- **Safe for production (no actual changes)**

To enable real fixes:
```elixir
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  dry_run: false
```

### 2. Validation Period (Self-Improving Agent)

**30-second validation window after deployment**

- Captures baseline metrics (memory, run_queue)
- Monitors for regressions
- Auto-rollback if regression detected

Regression thresholds:
- Memory growth > 25% (configurable via `IMP_VALIDATION_MEMORY_MULT`)
- Run queue delta > 50 (configurable via `IMP_VALIDATION_RUNQ_DELTA`)

### 3. Rate Limiting

**Prevents improvement thrashing**

- Max improvements per day (default: 100)
- Backoff after failures (10 cycles = 50 seconds)
- Queue overflows get persisted to disk

### 4. Duplicate Detection

**Prevents redundant improvements**

- Fingerprint-based deduplication
- Tracks last 500 fingerprints
- Checks pending queue for duplicates

### 5. Preflight Validation

**Validates code before compilation**

- Syntax checking
- Structure validation (must have `code` field)
- Compilation test (via `DynamicCompiler.validate/1`)

---

## Integration with Other Systems

### SPARC Methodology

**Used by:** Self-Improving Agent (Planner)

**Flow:**
```
Feature/Task
  ↓
StoryDecomposer.decompose_story(task)
  ↓
SPARC Result:
  ├─ Specification (what to build)
  ├─ Pseudocode (how to build)
  ├─ Architecture (structure)
  ├─ Refinement (edge cases)
  └─ Tasks (breakdown)
  ↓
LLM Code Generation (via NATS)
  ↓
Generated Implementation
```

### Pattern Mining

**Used by:** Self-Improving Agent (Planner)

**Purpose:** Learn from past successes

```elixir
patterns = PatternMiner.retrieve_patterns_for_task(task)
# => [
#   %{name: "NATS consumer", code: "...", description: "..."},
#   %{name: "GenServer", code: "...", description: "..."}
# ]
```

### RAG (Retrieval-Augmented Generation)

**Used by:** HTDAG Auto-Bootstrap

**Purpose:** Find similar code examples for fixing issues

```elixir
# Search knowledge base for similar code
similar_code = CodeSearch.search("NATS consumer with error handling")

# Use as context for LLM code generation
LLM.generate_fix(issue, context: similar_code)
```

### Knowledge Artifacts

**Used by:** Both systems

**Purpose:** Quality templates and code patterns

```elixir
# Load quality template for Elixir
template = ArtifactStore.get("quality_template", "elixir-production")

# Use for code generation
code = generate_code(task, quality_template: template)
```

### NATS Messaging

**Used by:** All LLM calls

**Flow:**
```
Elixir Code
  ↓ NATS subject: ai.llm.request
AI Server (TypeScript)
  ↓ HTTP to LLM API
LLM Provider (Claude, Gemini, etc.)
  ↓
AI Server
  ↓ NATS subject: ai.llm.response
Elixir Code
```

**Cost Optimization:**
- Complexity-based routing (`:simple`, `:medium`, `:complex`)
- Caching (LLM response cache)
- Fallback chains (Gemini Flash → Claude Sonnet → Claude Opus)

---

## Observability

### Telemetry Dashboard

All events are tracked in PostgreSQL (`executions` table) via `FlowTracker`.

**Metrics to monitor:**

**HTDAG Auto-Bootstrap:**
- Bootstrap success rate
- Issues found per bootstrap
- Fixes applied per bootstrap
- Average bootstrap duration
- Fix success rate by issue type

**Self-Improving Agent:**
- Improvement attempt rate
- Improvement success rate
- Validation failure rate
- Rollback frequency
- Average cycles between improvements
- Queue depth over time

### Logs

**HTDAG Auto-Bootstrap:**
```
[info] HTDAG AUTO-BOOTSTRAP: Self-Diagnosis Starting
[info] Phase 1: Learning codebase...
[info] Learning complete: 12 issues found
[info] Phase 2: Auto-fixing issues...
[info] Auto-fix complete: 3 iterations, 8 fixes applied (DRY-RUN mode - no changes applied)
[info] HTDAG AUTO-BOOTSTRAP: Self-Diagnosis Complete!
```

**Self-Improving Agent:**
```
[info] Agent improvement requested (agent_id: agent-001)
[info] Publishing self-improvement (reason: score_drop, score: 0.65, samples: 15)
[info] Processing queued improvement (agent_id: agent-001, queue_depth: 2)
[warning] Validation detected regression, rolling back (version: 5)
```

---

## Testing

**HTDAG Auto-Bootstrap:**
- Manual testing: `HTDAGAutoBootstrap.run_now(dry_run: true)`
- Check logs for detected issues
- Review suggested fixes (dry-run mode)

**Self-Improving Agent:**
- Comprehensive test suite: [agent_flow_test.exs](singularity/test/singularity/agent_flow_test.exs)
- 23 tests covering all flows
- Manual testing: Force improvement via API

```bash
cd singularity
mix test test/singularity/agent_flow_test.exs
```

---

## Recommended Workflow

### 1. Startup (First Time)

```bash
# Server starts with dry_run: true (safe mode)
./start-all.sh

# HTDAG Auto-Bootstrap runs automatically
# - Scans codebase
# - Identifies issues
# - Simulates fixes (no actual changes)

# Review the findings
iex> HTDAGAutoBootstrap.status()
# => %{issues_found: 12, fixes_applied: 0, dry_run: true}
```

### 2. Enable Real Fixes (After Review)

```elixir
# In config/config.exs
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  dry_run: false  # Enable real fixes

# Restart server OR run manually
HTDAGAutoBootstrap.run_now(dry_run: false)
```

### 3. Monitor Self-Improving Agents

```elixir
# Start an agent
{:ok, _pid} = SelfImprovingAgent.start_link(id: "agent-001")

# Record outcomes as your system runs
SelfImprovingAgent.record_outcome("agent-001", :success)
SelfImprovingAgent.record_outcome("agent-001", :failure)

# Agent will automatically improve when:
# - Success rate drops below 75% (after 8+ samples)
# - 30 cycles of stagnation (150 seconds)
# - Manually forced

# Check state
GenServer.call(SelfImprovingAgent.via_tuple("agent-001"), :state)
```

### 4. Telemetry Monitoring

```elixir
# Attach telemetry handlers
:telemetry.attach_many(
  "singularity-monitor",
  [
    [:htdag, :auto_bootstrap, :complete],
    [:singularity, :improvement, :success],
    [:singularity, :improvement, :rollback]
  ],
  fn event, measurements, metadata, _config ->
    Logger.info("Telemetry: #{inspect(event)}, #{inspect(measurements)}")
  end,
  nil
)
```

---

## Future Enhancements

### Planned Features

1. **Adaptive Thresholds** - Learn optimal score thresholds per agent
2. **Cost Budgeting** - Set max LLM cost per day
3. **Multi-Agent Coordination** - Share learnings across agents
4. **A/B Testing** - Run two versions, pick winner
5. **Explainability** - Why did agent improve? What changed?
6. **Human-in-the-Loop** - Optional approval before deployment
7. **Rollback History** - Track all rollbacks, learn from failures

### Integration Opportunities

1. **GitHub Integration** - Auto-create PRs for fixes
2. **Slack Notifications** - Alert on critical failures
3. **Grafana Dashboard** - Real-time metrics visualization
4. **Sentry Integration** - Track improvement failures as exceptions

---

## Summary

**Key Takeaways:**

1. **Two Systems:**
   - HTDAG Auto-Bootstrap: Startup self-diagnosis
   - Self-Improving Agent: Runtime continuous evolution

2. **Safety First:**
   - `dry_run: true` by default (NEW)
   - Validation periods with auto-rollback
   - Rate limiting and backoff

3. **Observability:**
   - Comprehensive telemetry events
   - PostgreSQL tracking via FlowTracker
   - Detailed logging

4. **Integration:**
   - SPARC methodology
   - Pattern mining
   - RAG code search
   - Quality templates
   - NATS messaging

5. **Production Ready:**
   - 23 comprehensive tests
   - Error handling at every step
   - Graceful degradation
   - Resource-aware (memory, run queue)

**Documentation:**
- [AGENTS.md](AGENTS.md) - Agent overview
- [SYSTEM_FLOWS.md](SYSTEM_FLOWS.md) - Visual diagrams
- [HTDAG_QUICK_START.md](HTDAG_QUICK_START.md) - HTDAG getting started

**Files Changed:**
- [htdag_auto_bootstrap.ex:115](singularity/lib/singularity/planning/htdag_auto_bootstrap.ex#L115) - `dry_run: true` (default changed)
- [htdag_auto_bootstrap.ex:173](singularity/lib/singularity/planning/htdag_auto_bootstrap.ex#L173) - `Keyword.get(config, :dry_run, true)`
