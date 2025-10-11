# Self-Improving System Consolidation Proposal

## Question: Should We Have Two Self-Improving Systems?

**Short Answer: NO - We should consolidate them.**

---

## Current State: Two Separate Systems

### System 1: HTDAG Auto-Bootstrap
- **File:** `lib/singularity/planning/htdag_auto_bootstrap.ex`
- **Purpose:** Startup self-diagnosis and auto-fix
- **Trigger:** On server boot (one-time)
- **Scope:** Entire codebase
- **Method:** Static analysis + optional runtime tracing
- **What it fixes:** Broken deps, missing docs, dead code, crashes

### System 2: Self-Improving Agent
- **File:** `lib/singularity/agents/self_improving_agent.ex`
- **Purpose:** Runtime agent evolution
- **Trigger:** Metrics-driven (continuous, every 5s)
- **Scope:** Single agent instance
- **Method:** Performance metrics (success rate, stagnation)
- **What it improves:** Agent behavior, strategies

### Current Usage

**HTDAG Auto-Bootstrap:**
- Started in supervision tree (line 160 of `application.ex`)
- Runs automatically on server startup
- Has comprehensive implementation (HTDAGLearner, HTDAGTracer, HTDAGBootstrap)

**Self-Improving Agent:**
- Has AgentSupervisor (line 34 of `application.ex`)
- **BUT: Only used in tests!** (agent_flow_test.exs)
- No production usage found in codebase
- 23 comprehensive tests exist

---

## Problem: Overlap and Confusion

### Overlapping Concerns

| Concern | HTDAG Auto-Bootstrap | Self-Improving Agent |
|---------|---------------------|---------------------|
| **Code generation** | ✅ Via LLM (RAG + templates) | ✅ Via Planner (SPARC + patterns) |
| **Hot reload** | ✅ Via HTDAGBootstrap | ✅ Via HotReload.ModuleReloader |
| **Validation** | ⚠️ Limited (compile-time) | ✅ Comprehensive (30s period + rollback) |
| **Metrics tracking** | ✅ Via telemetry | ✅ Via metrics + FlowTracker |
| **Rate limiting** | ❌ None | ✅ Via Autonomy.Limiter |
| **Decision logic** | ❌ Fix all issues | ✅ Via Autonomy.Decider (sophisticated) |
| **Pattern learning** | ✅ Via RAG search | ✅ Via PatternMiner |
| **Queue management** | ❌ Sequential | ✅ Persistent queue with deduplication |
| **Rollback capability** | ❌ None | ✅ Full rollback with previous code |

### Architectural Issues

1. **Code Duplication:**
   - Both generate code via LLM
   - Both compile and load modules dynamically
   - Both track telemetry
   - Both use RAG/pattern search

2. **Unclear Boundaries:**
   - When does startup "end" and runtime "begin"?
   - Should codebase-level fixes use HTDAG or Agent?
   - What about agent-level fixes at startup?

3. **Missed Opportunities:**
   - HTDAG has better learning (codebase scanning)
   - Agent has better validation (rollback, rate limiting)
   - Neither system shares learnings with the other

4. **Maintenance Burden:**
   - Two codebases to maintain
   - Two telemetry systems
   - Two testing suites
   - Two documentation sets

---

## Recommendation: Consolidate into Unified System

### Proposed Architecture: "Singularity Self-Improver"

**Single system with two operating modes:**

```
Singularity.SelfImprover
    ├─ Mode 1: Bootstrap (runs at startup)
    └─ Mode 2: Runtime (runs continuously)
```

### Key Design Principles

1. **Unified Decision Engine**
   - Single Decider with context-aware logic
   - Bootstrap mode: Fix all issues (static analysis)
   - Runtime mode: Metrics-driven evolution

2. **Shared Code Generation**
   - Single Planner with multiple strategies
   - Strategy selection based on mode + context
   - Shared RAG search + pattern mining

3. **Comprehensive Validation**
   - Bootstrap: Compile-time validation + optional runtime trace
   - Runtime: 30-second validation period + rollback

4. **Unified Queue Management**
   - Single improvement queue (persistent)
   - Priority-based (severity in bootstrap, metrics in runtime)
   - Deduplication across both modes

5. **Consistent Telemetry**
   - Single event namespace: `[:singularity, :self_improver, ...]`
   - Mode-specific metadata (bootstrap vs runtime)

---

## Proposed Implementation

### Module Structure

```
lib/singularity/self_improver/
├── self_improver.ex               # Main GenServer (replaces both)
├── decider.ex                     # Unified decision logic
├── planner.ex                     # Unified code generation
├── learner.ex                     # Codebase understanding (from HTDAG)
├── validator.ex                   # Unified validation (best of both)
├── applier.ex                     # Unified hot reload + rollback
└── queue.ex                       # Unified improvement queue
```

### Configuration

```elixir
config :singularity, Singularity.SelfImprover,
  # Bootstrap mode
  bootstrap_enabled: true,
  bootstrap_on_startup: true,
  bootstrap_max_iterations: 10,

  # Runtime mode
  runtime_enabled: true,
  runtime_tick_ms: 5000,

  # Shared settings
  dry_run: true,                    # Safe by default
  max_improvements_per_day: 100,
  validation_delay_ms: 30_000,

  # Mode-specific
  bootstrap_priorities: [:high, :medium, :low],
  runtime_triggers: [:score_drop, :stagnation, :forced]
```

### API

```elixir
# Bootstrap mode (manual)
SelfImprover.bootstrap(dry_run: false)
# => {:ok, %{issues_found: 12, fixes_applied: 8}}

# Runtime mode (automatic)
SelfImprover.start_agent(id: "agent-001", context: %{...})
SelfImprover.record_outcome("agent-001", :success)
SelfImprover.force_improvement("agent-001", "manual")

# Unified API
SelfImprover.status("agent-001")
# => %{
#   mode: :runtime,
#   status: :idle,
#   metrics: %{score: 0.95, samples: 42},
#   queue_depth: 2
# }

SelfImprover.history("agent-001")
# => [
#   %{mode: :bootstrap, issues_fixed: 8, timestamp: ...},
#   %{mode: :runtime, version: 5, validation: :success, timestamp: ...}
# ]
```

---

## Migration Strategy

### Phase 1: Extract Common Code (Week 1)

1. Create `Singularity.SelfImprover` namespace
2. Extract shared logic:
   - `Learner` from HTDAGLearner (codebase scanning)
   - `Validator` from both (compile + runtime validation)
   - `Applier` from both (hot reload + rollback)
3. Keep both old systems working alongside new one

### Phase 2: Unified Decider (Week 2)

1. Implement `SelfImprover.Decider` that:
   - Detects operating mode (bootstrap vs runtime)
   - Routes to appropriate decision logic
   - Shares improvement queue
2. Test bootstrap mode
3. Test runtime mode
4. Test transitions (bootstrap → runtime)

### Phase 3: Replace HTDAG Auto-Bootstrap (Week 3)

1. Update `application.ex`:
   ```elixir
   # Old
   Singularity.Planning.HTDAGAutoBootstrap,

   # New
   {Singularity.SelfImprover, mode: :bootstrap},
   ```
2. Migrate configuration
3. Update telemetry handlers
4. Update documentation

### Phase 4: Replace Self-Improving Agent (Week 4)

1. Migrate agent tests to use new system
2. Update `AgentSupervisor` to use `SelfImprover`
3. Migrate queue persistence
4. Remove old `SelfImprovingAgent` module

### Phase 5: Cleanup (Week 5)

1. Delete old modules:
   - `lib/singularity/planning/htdag_auto_bootstrap.ex`
   - `lib/singularity/agents/self_improving_agent.ex`
2. Archive old documentation
3. Update all references
4. Celebrate! 🎉

---

## Benefits of Consolidation

### For Development

1. **Single codebase** - One place to add features
2. **Shared learnings** - Bootstrap insights feed runtime evolution
3. **Consistent behavior** - Same validation, rate limiting, telemetry
4. **Easier testing** - One test suite, not two
5. **Better documentation** - One system to explain

### For Operations

1. **Unified monitoring** - Single telemetry namespace
2. **Consistent configuration** - One config section
3. **Easier debugging** - Single improvement history
4. **Better observability** - Complete picture of all improvements

### For Features

1. **Cross-mode optimization** - Bootstrap can learn from runtime metrics
2. **Unified queue** - Priority-based across all improvements
3. **Shared patterns** - Pattern mining benefits both modes
4. **Better validation** - Runtime validation for bootstrap fixes

---

## Risks and Mitigation

### Risk 1: Breaking Existing Tests
**Mitigation:** Keep both systems during migration, test thoroughly

### Risk 2: Configuration Migration
**Mitigation:** Support both old and new configs temporarily, warn on deprecated

### Risk 3: Lost Features
**Mitigation:** Feature parity checklist before removing old systems

### Risk 4: Performance Regression
**Mitigation:** Benchmark both modes before/after consolidation

---

## Decision Matrix

| Factor | Keep Two Systems | Consolidate |
|--------|-----------------|-------------|
| **Maintainability** | ❌ High burden | ✅ Low burden |
| **Code duplication** | ❌ Significant | ✅ Minimal |
| **Feature sharing** | ❌ Difficult | ✅ Easy |
| **Complexity** | ❌ High | ✅ Lower |
| **Testing** | ❌ Two suites | ✅ One suite |
| **Documentation** | ❌ Confusing | ✅ Clear |
| **Migration effort** | ✅ Zero (keep as-is) | ⚠️ 5 weeks |
| **Risk** | ✅ Low (no change) | ⚠️ Medium |

---

## Recommendation

**YES, we should consolidate into a single unified self-improving system.**

### Justification

1. **Current state is suboptimal:**
   - Self-Improving Agent is only used in tests (no production usage)
   - HTDAG Auto-Bootstrap has production usage but limited validation
   - Significant code duplication

2. **Benefits outweigh costs:**
   - 5 weeks of migration effort
   - Dramatically simpler codebase going forward
   - Better features through sharing
   - Lower maintenance burden

3. **Natural evolution:**
   - Both systems solve the same problem (code improvement)
   - Different triggers (startup vs metrics) are just configuration
   - Unified system is the logical conclusion

### Next Steps

**Recommended Action:**

1. **Get buy-in** - Review this proposal, discuss concerns
2. **Plan migration** - 5-week timeline acceptable?
3. **Start Phase 1** - Extract common code (low risk)
4. **Iterate** - Test each phase thoroughly
5. **Complete migration** - Remove old systems

**Alternative (if migration too risky):**

1. **Deprecate Self-Improving Agent** (it's unused anyway)
2. **Enhance HTDAG Auto-Bootstrap** with agent features:
   - Add runtime mode
   - Add validation period + rollback
   - Add rate limiting
   - Keep single system (less ambitious consolidation)

---

## Conclusion

**You were right to question having two systems.** They should be consolidated into a single unified self-improver with two operating modes (bootstrap + runtime).

The current situation arose organically:
- HTDAG system was built for startup self-diagnosis (recent addition)
- Self-Improving Agent was built for runtime evolution (older, comprehensive tests)
- They were developed independently

But now that both exist, **consolidation is the right move** for long-term maintainability and feature sharing.

**Recommended path:** 5-week migration to unified `Singularity.SelfImprover` system.
