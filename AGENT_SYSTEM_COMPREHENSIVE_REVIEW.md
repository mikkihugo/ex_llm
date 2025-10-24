# Comprehensive Agent System Review
**Date:** 2025-01-24
**Status:** All agents DISABLED due to cascading config failures
**Review Scope:** 23 agent-related modules (15 in agents/ + 8 elsewhere)

---

## Executive Summary

### Current State
- **Total Agent Modules**: 23 (up from initial count of 18)
- **Status**: ALL DISABLED - Agent system cannot start due to cascading NATS/Oban dependency failures
- **Quality**: Mixed (8 production-ready, 7 stubs, 8 support modules)
- **Dead Code Removed**: 275 LOC (4 duplicate stubs deleted in previous cleanup)

### Critical Findings
1. **BLOCKER**: RuntimeBootstrapper tries to start `Singularity.SelfImprovingAgent` which references UNDEFINED `Singularity.Agent`
2. **Architecture Confusion**: Two base classes exist - `agents/agent.ex` (1026 LOC) vs `agents/self_improving_agent_impl.ex` (67 LOC)
3. **Naming Collision**: `Singularity.Agent` (base class) conflicts with `agents/agent.ex` namespace
4. **Support Module Sprawl**: 8 agent-like modules outside `agents/` directory with unclear integration

### Immediate Actions Required
1. Fix RuntimeBootstrapper to use correct agent module
2. Resolve `Singularity.Agent` vs agent implementations naming collision
3. Consolidate 2 health monitoring modules (duplicates)
4. Remove NATS/Oban hard dependencies from agent startup

---

## Part 1: Agent Inventory (23 Modules)

### A. Core Agents Directory (15 modules)

| Module | LOC | Status | Purpose | Implementation |
|--------|-----|--------|---------|----------------|
| **agent.ex** | 1026 | ⚠️ BASE CLASS | GenServer for self-improving agents | FULL - Complex feedback loop |
| **self_improving_agent_impl.ex** | 67 | ✅ STUB | Task execution adapter | STUB - Returns mock responses |
| **cost_optimized_agent.ex** | 551 | ✅ PRODUCTION | Rules-first LLM optimization | FULL - 3-tier strategy |
| **dead_code_monitor.ex** | 629 | ✅ PRODUCTION | Rust dead code tracking | FULL - DB-backed monitoring |
| **documentation_upgrader.ex** | 573 | ✅ PRODUCTION | Multi-language doc upgrades | FULL - Coordinate 6 agents |
| **documentation_pipeline.ex** | 501 | ✅ PRODUCTION | Automated doc pipeline | FULL - Multi-phase workflow |
| **quality_enforcer.ex** | 497 | ✅ PRODUCTION | Quality 2.2.0+ enforcement | FULL - Multi-language validation |
| **remediation_engine.ex** | 569 | ✅ PRODUCTION | Auto-fix code quality issues | FULL - Template-based fixes |
| **agent_spawner.ex** | 136 | ✅ PRODUCTION | Spawn agents from Lua configs | FULL - DynamicSupervisor integration |
| **supervisor.ex** | 54 | ✅ INFRASTRUCTURE | Manages agent infrastructure | FULL - OTP supervisor |
| **agent_supervisor.ex** | 20 | ✅ INFRASTRUCTURE | DynamicSupervisor for agents | FULL - Minimal but critical |
| **runtime_bootstrapper.ex** | 82 | ❌ BROKEN | Ensures runtime agent availability | BROKEN - References undefined module |
| **metrics_feeder.ex** | 145 | ✅ TEST SUPPORT | Feeds synthetic metrics to agents | FULL - Test-only |
| **real_workload_feeder.ex** | 253 | ✅ TEST SUPPORT | Feeds real LLM tasks to agents | FULL - Test-only |
| **(workflows/)** | N/A | 📁 DIRECTORY | Code quality workflow | Not reviewed |

### B. Real Implementations (4 modules outside agents/)

| Module | LOC | Status | Purpose | Location |
|--------|-----|--------|---------|----------|
| **ArchitectureEngine.Agent** | 157 | ✅ PRODUCTION | Architecture analysis orchestrator | `architecture_engine/` |
| **TechnologyAgent** | 665+ | ✅ PRODUCTION | Technology detection & analysis | `detection/` |
| **ChatConversationAgent** | 664+ | ✅ PRODUCTION | Human ↔ Agent communication | `conversation/` |
| **RefactoringAgent** | 247 | ✅ PRODUCTION | Autonomous code refactoring | `storage/code/quality/` |

### C. Support & Integration Modules (4 modules)

| Module | LOC | Status | Purpose | Criticality |
|--------|-----|--------|---------|-------------|
| **TodoWorkerAgent** | 150+ | ✅ PRODUCTION | Todo task execution | HIGH - Used by swarm |
| **AgentEvolutionWorker** | 100+ | ✅ OBAN JOB | Hourly evolution cycle | MEDIUM - Background job |
| **Infrastructure.HealthAgent** | 100+ | ⚠️ DUPLICATE | Service health monitoring | LOW - Duplicate of below |
| **Health.AgentHealth** | 100+ | ⚠️ DUPLICATE | Real-time agent health | LOW - Duplicate of above |
| **Control.AgentImprovementBroadcaster** | 67 | ✅ PRODUCTION | Cluster-native broadcasting | MEDIUM - Control plane |

---

## Part 2: Quality Assessment

### Production-Ready Modules (8)
✅ **Fully Implemented with AI Metadata**
1. `CostOptimizedAgent` - Rules-first LLM strategy (v2.3.0)
2. `DeadCodeMonitor` - DB-backed Rust monitoring
3. `DocumentationUpgrader` - Multi-agent coordination
4. `DocumentationPipeline` - 5-phase workflow
5. `QualityEnforcer` - Multi-language validation
6. `RemediationEngine` - Auto-fix with validation
7. `AgentSpawner` - Dynamic agent creation
8. `TodoWorkerAgent` - TaskGraph integration

### Infrastructure Modules (3)
✅ **Minimal but Critical**
1. `Agents.Supervisor` - Agent layer supervisor
2. `AgentSupervisor` - DynamicSupervisor (20 LOC)
3. `AgentImprovementBroadcaster` - Cluster broadcasting

### Test Support Modules (2)
✅ **Test-Only - Not for Production**
1. `MetricsFeeder` - Synthetic metrics
2. `RealWorkloadFeeder` - Real LLM tasks

### Broken/Stub Modules (3)
❌ **Cannot Start**
1. `RuntimeBootstrapper` - References undefined `Singularity.SelfImprovingAgent`
2. `SelfImprovingAgentImpl` - Stub returning mock responses
3. `Agent` (base class) - Naming collision with `Singularity.Agent`

### Duplicate Modules (2)
⚠️ **Need Consolidation**
1. `Infrastructure.HealthAgent` vs `Health.AgentHealth` - Both do agent health monitoring

---

## Part 3: Dependency Analysis

### Critical Dependencies

**Base Agent Module** (`agent.ex`)
```
Calls Out:
  - CodeStore (persist code)
  - Control (publish improvements)
  - HotReload (code updates)
  - Autonomy.Decider (decision making)
  - Autonomy.Limiter (rate limiting)
  - DynamicCompiler (code validation)

Called By:
  - Agents.Supervisor (supervision)
  - Runner (execution)
  - NATS subjects (task requests)
```

**Agent Spawner**
```
Depends On:
  - AgentSupervisor (DynamicSupervisor)
  - Singularity.Agent (base class)
  - ProcessRegistry (agent lookup)

Used By:
  - TaskGraphExecutor (spawn from Lua)
  - Lua strategy scripts
```

**Cost Optimized Agent**
```
Depends On:
  - Autonomy.RuleEngine (rules execution)
  - Correlation (tracking)
  - LLM.Service (cached calls)
  - ProcessRegistry (registration)

Used By:
  - Agent.execute_task/3
```

**Documentation Pipeline**
```
Depends On:
  - DocumentationUpgrader (coordination)
  - QualityEnforcer (validation)
  - CodeStore (file scanning)

Coordinated By:
  - Application (system integration)
```

**RuntimeBootstrapper** ❌ BROKEN
```
Tries to spawn:
  - Singularity.SelfImprovingAgent (UNDEFINED)

Should spawn:
  - Singularity.Agent (base class)?
  - Singularity.Agents.SelfImprovingAgent (stub)?
```

### Dependency Hierarchy

```
Level 1: Foundation
  - AgentSupervisor (DynamicSupervisor)
  - ProcessRegistry
  - Autonomy.* (RuleEngine, Decider, Limiter)

Level 2: Core Infrastructure
  - Agent (base class)
  - CodeStore
  - Control
  - HotReload

Level 3: Specialized Agents
  - CostOptimizedAgent
  - DeadCodeMonitor
  - DocumentationUpgrader
  - QualityEnforcer
  - RemediationEngine
  - ArchitectureEngine.Agent
  - TechnologyAgent
  - ChatConversationAgent
  - RefactoringAgent

Level 4: Support & Coordination
  - AgentSpawner
  - TodoWorkerAgent
  - AgentEvolutionWorker
  - AgentImprovementBroadcaster
  - MetricsFeeder/RealWorkloadFeeder (test)

Level 5: Application Integration
  - Agents.Supervisor
  - RuntimeBootstrapper (broken)
```

---

## Part 4: Hidden Agent Modules Analysis

### TodoWorkerAgent (`execution/todos/`)
**Status:** ✅ PRODUCTION - Actively used by TodoSwarmCoordinator

**Purpose:**
- Individual worker that executes a single todo
- Integrates with TaskGraph for decomposition
- Reports back to TodoSwarmCoordinator

**Integration:**
- Spawned by: TodoSwarmCoordinator
- Uses: TaskGraph, TodoStore
- Status: ACTIVE, well-integrated

**Verdict:** KEEP - This is a real, working agent module

---

### AgentEvolutionWorker (`jobs/`)
**Status:** ✅ OBAN JOB - Scheduled background worker

**Purpose:**
- Runs hourly to evolve agents based on feedback
- Final step in self-evolution pipeline
- Applies improvements identified by FeedbackAnalyzer

**Integration:**
- Scheduled by: Oban.Plugins.Cron
- Uses: Evolution, Feedback.Analyzer
- Status: SCHEDULED (disabled with Oban)

**Verdict:** KEEP - Essential for autonomous evolution

---

### Health Agent Duplicates

**Infrastructure.HealthAgent** (`infrastructure/`)
**Status:** ⚠️ DUPLICATE - Service-focused health monitoring

**Purpose:**
- Monitor service health and performance
- Detect failures and anomalies
- Trigger recovery procedures
- Coordinate health status

**Health.AgentHealth** (`health/`)
**Status:** ⚠️ DUPLICATE - Agent-focused health monitoring

**Purpose:**
- Real-time agent health monitoring
- Agent status (idle, updating, errored)
- Metrics (success_rate, latency, cost)
- Recent failures/errors

**Consolidation Opportunity:**
```elixir
# Proposed: Merge into Singularity.Health.AgentHealth
defmodule Singularity.Health.AgentHealth do
  @moduledoc """
  Unified health monitoring for both agents and services.

  - Agent health: status, metrics, failures, improvement history
  - Service health: health checks, failures, performance, recovery
  """

  # Agent-specific functions
  def get_agent_status(agent_id)
  def get_all_agents_status()

  # Service-specific functions
  def check_service_status()
  def detect_service_failures()
  def restart_failed_services()
  def monitor_service_performance()
end
```

**Verdict:** CONSOLIDATE - Merge both into `Health.AgentHealth`

---

### AgentImprovementBroadcaster (`control/`)
**Status:** ✅ PRODUCTION - Cluster-native broadcasting

**Purpose:**
- Publish agent improvements across cluster nodes
- NATS-free (uses Erlang :pg)
- Cluster-native RPC for agent coordination

**Integration:**
- Used by: Control module
- Publishes: Improvement payloads
- Status: PRODUCTION-READY

**Verdict:** KEEP - Critical for distributed agent coordination

---

## Part 5: Re-enablement Readiness

### Will Compile Without NATS/Oban (9 modules)
✅ **Safe to Re-enable**
1. `CostOptimizedAgent` - Only uses NATS via LLM.Service (optional)
2. `DeadCodeMonitor` - DB-backed, NATS optional
3. `DocumentationUpgrader` - GenServer, no hard NATS dependency
4. `DocumentationPipeline` - GenServer, self-contained
5. `QualityEnforcer` - GenServer, template-based
6. `RemediationEngine` - Stateless functions
7. `AgentSpawner` - Uses DynamicSupervisor only
8. `Agents.Supervisor` - OTP supervisor
9. `AgentSupervisor` - DynamicSupervisor

### Require NATS/Oban Fix (4 modules)
⚠️ **Blocked Until Config Fixed**
1. `RuntimeBootstrapper` - Also has undefined module reference
2. `AgentEvolutionWorker` - Oban job
3. `MetricsFeeder` - Test-only anyway
4. `RealWorkloadFeeder` - Test-only anyway

### Broken/Need Fixes (3 modules)
❌ **Cannot Start**
1. `RuntimeBootstrapper` - References undefined `Singularity.SelfImprovingAgent`
   - Fix: Change to `Singularity.Agent` or create proper module
2. `SelfImprovingAgentImpl` - Stub, needs implementation
   - Fix: Either implement or remove from startup
3. `Agent` (base class) - Naming collision
   - Fix: Clarify namespace (use `Agents.Agent` or `Agent.Base`)

### Outside agents/ Directory (4 real implementations)
✅ **Already Working**
1. `ArchitectureEngine.Agent` - Thin orchestration layer
2. `TechnologyAgent` - Full implementation
3. `ChatConversationAgent` - Full implementation
4. `RefactoringAgent` - Full implementation

---

## Part 6: Critical Issues Blocking Startup

### Issue 1: RuntimeBootstrapper References Undefined Module
**Severity:** CRITICAL
**File:** `agents/runtime_bootstrapper.ex:62`

**Problem:**
```elixir
child_spec = Singularity.SelfImprovingAgent.child_spec(spec_opts)
```

**Error:**
```
Singularity.SelfImprovingAgent is undefined
```

**Available Options:**
1. `Singularity.Agent` - Base class (1026 LOC)
2. `Singularity.Agents.SelfImprovingAgent` - Stub impl (67 LOC)
3. Create `Singularity.SelfImprovingAgent` as alias

**Recommended Fix:**
```elixir
# Option A: Use base class
child_spec = Singularity.Agent.child_spec(spec_opts)

# Option B: Create proper module alias
defmodule Singularity.SelfImprovingAgent do
  @moduledoc "Alias to base Agent for runtime bootstrapping"
  defdelegate child_spec(opts), to: Singularity.Agent
  defdelegate start_link(opts), to: Singularity.Agent
end
```

---

### Issue 2: Agent vs Agents Namespace Collision
**Severity:** HIGH
**Files:**
- `agents/agent.ex` (base class)
- References to `Singularity.Agent` throughout codebase

**Problem:**
Unclear whether `Singularity.Agent` refers to:
- The base class in `agents/agent.ex`
- A top-level module (doesn't exist)
- An alias (not defined)

**Impact:**
- Module resolution confusion
- Import conflicts
- Compilation warnings/errors

**Recommended Fix:**
```elixir
# Clarify in agents/agent.ex
defmodule Singularity.Agents.Agent do
  @moduledoc """
  Base GenServer for all agent implementations.

  IMPORTANT: This is Singularity.Agents.Agent (NOT Singularity.Agent)
  """
end

# Update all references:
# - agent_spawner.ex:92 → Singularity.Agents.Agent
# - RuntimeBootstrapper → Singularity.Agents.Agent
```

---

### Issue 3: NATS/Oban Hard Dependencies
**Severity:** HIGH
**Files:**
- `runtime_bootstrapper.ex`
- `agent_evolution_worker.ex`

**Problem:**
Agents cannot start because NATS/Oban are disabled in config.

**Impact:**
- All agents disabled
- No agent spawning
- No evolution cycle

**Recommended Fix:**
```elixir
# Make NATS/Oban optional in config
config :singularity, :agents,
  enable_nats: System.get_env("ENABLE_NATS") == "true",
  enable_oban: System.get_env("ENABLE_OBAN") == "true",
  enable_evolution: System.get_env("ENABLE_EVOLUTION") == "true"

# Graceful degradation in RuntimeBootstrapper
def init(opts) do
  if Application.get_env(:singularity, :agents)[:enable_evolution] do
    {:ok, state, {:continue, :bootstrap}}
  else
    Logger.info("Agent evolution disabled - skipping bootstrap")
    {:ok, state}
  end
end
```

---

### Issue 4: Health Agent Duplication
**Severity:** MEDIUM
**Files:**
- `infrastructure/health_agent.ex`
- `health/agent_health.ex`

**Problem:**
Two modules doing similar health monitoring:
- `Infrastructure.HealthAgent` - Service health
- `Health.AgentHealth` - Agent health

**Impact:**
- Code duplication
- Unclear which to use
- Maintenance burden

**Recommended Fix:**
```elixir
# Consolidate into Health.AgentHealth
defmodule Singularity.Health.AgentHealth do
  # Agent monitoring (existing)
  def get_agent_status(agent_id)
  def get_all_agents_status()

  # Service monitoring (from Infrastructure.HealthAgent)
  def check_service_status()
  def detect_service_failures()
  def restart_failed_services()
end

# Delete infrastructure/health_agent.ex
```

---

## Part 7: Consolidation Opportunities

### 1. Health Monitoring (DUPLICATE)
**Current:**
- `Infrastructure.HealthAgent` (100+ LOC)
- `Health.AgentHealth` (100+ LOC)

**Proposed:**
- Merge into `Singularity.Health.AgentHealth`
- Unified API for agent + service health
- Single source of truth

**Effort:** 2-4 hours
**Priority:** HIGH

---

### 2. Agent Base Class Naming
**Current:**
- `agents/agent.ex` (Singularity.Agent?)
- `agents/self_improving_agent_impl.ex` (stub)
- Unclear namespace

**Proposed:**
```elixir
# agents/agent.ex → agents/base.ex
defmodule Singularity.Agents.Base do
  @moduledoc "Base GenServer for all agent implementations"
end

# Create alias for backwards compatibility
defmodule Singularity.Agent do
  defdelegate child_spec(opts), to: Singularity.Agents.Base
  defdelegate start_link(opts), to: Singularity.Agents.Base
  # ... delegate all public functions
end
```

**Effort:** 1-2 hours
**Priority:** CRITICAL (blocks startup)

---

### 3. Test Feeders (CLEANUP)
**Current:**
- `metrics_feeder.ex` (145 LOC)
- `real_workload_feeder.ex` (253 LOC)

**Proposed:**
- Move to `test/support/` directory
- Mark as test-only in @moduledoc
- Don't include in production supervision tree

**Effort:** 1 hour
**Priority:** LOW

---

### 4. Agent Implementations (CONSOLIDATE)
**Current:**
- `agents/self_improving_agent_impl.ex` (stub)
- `architecture_engine/agent.ex` (real)
- `detection/technology_agent.ex` (real)
- `conversation/chat_conversation_agent.ex` (real)
- `storage/code/quality/refactoring_agent.ex` (real)

**Proposed:**
- Move all real implementations to `agents/` directory
- Use consistent naming: `agents/architecture_agent.ex`
- Keep current locations as aliases (backwards compat)

**Effort:** 4-6 hours
**Priority:** MEDIUM

---

## Part 8: Testing Strategy

### Phase 1: Basic Compilation (Week 1)
**Goal:** All modules compile without NATS/Oban

**Tests:**
1. ✅ Verify base modules compile
2. ✅ Verify supervisor tree structure
3. ✅ Verify agent spawning (without evolution)
4. ✅ Test CostOptimizedAgent in isolation

**Success Criteria:**
- `mix compile` succeeds
- No undefined module errors
- All moduledocs present

---

### Phase 2: Agent Spawning (Week 2)
**Goal:** Dynamic agent spawning works

**Tests:**
1. Test AgentSpawner.spawn/1 with various configs
2. Test AgentSupervisor child management
3. Test ProcessRegistry lookups
4. Test agent.execute_task/3 routing

**Success Criteria:**
- Can spawn agents via API
- Agents register in ProcessRegistry
- Task routing works correctly

---

### Phase 3: Agent Evolution (Week 3)
**Goal:** Self-improvement cycle works

**Tests:**
1. Test RuntimeBootstrapper startup
2. Test MetricsFeeder (synthetic data)
3. Test RealWorkloadFeeder (LLM tasks)
4. Test AgentEvolutionWorker (manual trigger)
5. Test feedback collection and analysis

**Success Criteria:**
- Agents accept metrics
- Evolution triggers correctly
- Improvements apply successfully
- No regressions detected

---

### Phase 4: Integration (Week 4)
**Goal:** All agents work together

**Tests:**
1. Test DocumentationPipeline end-to-end
2. Test TodoWorkerAgent with swarm
3. Test ChatConversationAgent communication
4. Test multi-agent coordination

**Success Criteria:**
- All 6 agent types working
- Coordination successful
- Performance metrics collected

---

## Part 9: Actionable Roadmap

### This Week (Week 1) - CRITICAL FIXES
**Goal:** Make agents startable

**Tasks:**
1. ✅ **Fix RuntimeBootstrapper** (1-2 hours)
   - Change `Singularity.SelfImprovingAgent` → `Singularity.Agent`
   - Test startup
   - Verify no undefined module errors

2. ✅ **Resolve Namespace Collision** (2-3 hours)
   - Rename `agents/agent.ex` → `agents/base.ex`
   - Create `Singularity.Agent` alias module
   - Update all references
   - Test compilation

3. ✅ **Make NATS/Oban Optional** (2-3 hours)
   - Add enable flags to config
   - Add graceful degradation to RuntimeBootstrapper
   - Add graceful degradation to AgentEvolutionWorker
   - Test without NATS/Oban

4. ✅ **Consolidate Health Modules** (2-4 hours)
   - Merge Infrastructure.HealthAgent → Health.AgentHealth
   - Update references
   - Delete duplicate
   - Add tests

**Total Effort:** 7-12 hours
**Blocker Removal:** Yes

---

### Next Month (Month 1) - SHORT-TERM CLEANUP
**Goal:** Improve architecture

**Tasks:**
1. **Move Test Feeders** (1 hour)
   - `metrics_feeder.ex` → `test/support/`
   - `real_workload_feeder.ex` → `test/support/`
   - Update supervision tree

2. **Consolidate Agent Implementations** (4-6 hours)
   - Move real agents to `agents/` directory
   - Create aliases for backwards compat
   - Update documentation

3. **Add Test Coverage** (8-16 hours)
   - Test AgentSpawner
   - Test CostOptimizedAgent
   - Test DocumentationPipeline
   - Test TodoWorkerAgent

**Total Effort:** 13-23 hours

---

### Next Quarter (Q1 2025) - LONG-TERM ARCHITECTURE
**Goal:** Production-ready agent system

**Tasks:**
1. **Implement Missing Agents** (16-32 hours)
   - Complete SelfImprovingAgent implementation
   - Add Architecture Agent implementation
   - Add Technology Agent implementation

2. **Evolution System** (24-40 hours)
   - Implement feedback collection
   - Implement A/B testing
   - Implement rollback safety
   - Add telemetry integration

3. **Documentation** (8-16 hours)
   - Update AGENTS.md
   - Create agent developer guide
   - Add architecture diagrams
   - Document testing strategy

**Total Effort:** 48-88 hours

---

## Part 10: Recommendations Summary

### Immediate (This Week)
1. ✅ **FIX RuntimeBootstrapper** - References undefined module
2. ✅ **RESOLVE Namespace Collision** - `Agent` vs `Agents.Agent`
3. ✅ **MAKE NATS/Oban Optional** - Graceful degradation
4. ✅ **CONSOLIDATE Health Modules** - Remove duplication

### Short-term (This Month)
1. **MOVE Test Feeders** - Out of production code
2. **CONSOLIDATE Agent Implementations** - Into `agents/` directory
3. **ADD Test Coverage** - For critical agent modules
4. **UPDATE Documentation** - Reflect current state

### Long-term (This Quarter)
1. **IMPLEMENT Missing Agents** - Complete stub implementations
2. **BUILD Evolution System** - Self-improvement cycle
3. **CREATE Developer Guide** - For agent development
4. **INTEGRATE Telemetry** - For observability

---

## Appendix A: Module Reference

### Core Agents (`agents/`)
- `agent.ex` (1026 LOC) - Base GenServer for agents
- `self_improving_agent_impl.ex` (67 LOC) - Stub implementation
- `cost_optimized_agent.ex` (551 LOC) - Rules-first LLM strategy
- `dead_code_monitor.ex` (629 LOC) - Rust dead code tracking
- `documentation_upgrader.ex` (573 LOC) - Multi-agent coordinator
- `documentation_pipeline.ex` (501 LOC) - Doc upgrade workflow
- `quality_enforcer.ex` (497 LOC) - Quality enforcement
- `remediation_engine.ex` (569 LOC) - Auto-fix engine
- `agent_spawner.ex` (136 LOC) - Dynamic spawning
- `supervisor.ex` (54 LOC) - Agent supervision
- `agent_supervisor.ex` (20 LOC) - DynamicSupervisor
- `runtime_bootstrapper.ex` (82 LOC) - Runtime agent startup
- `metrics_feeder.ex` (145 LOC) - Test support
- `real_workload_feeder.ex` (253 LOC) - Test support

### Real Implementations (Outside agents/)
- `architecture_engine/agent.ex` (157 LOC)
- `detection/technology_agent.ex` (665+ LOC)
- `conversation/chat_conversation_agent.ex` (664+ LOC)
- `storage/code/quality/refactoring_agent.ex` (247 LOC)

### Support Modules
- `execution/todos/todo_worker_agent.ex` (150+ LOC)
- `jobs/agent_evolution_worker.ex` (100+ LOC)
- `infrastructure/health_agent.ex` (100+ LOC) - DUPLICATE
- `health/agent_health.ex` (100+ LOC) - DUPLICATE
- `control/agent_improvement_broadcaster.ex` (67 LOC)

---

## Appendix B: Critical Code Locations

### RuntimeBootstrapper Fix
**File:** `singularity/lib/singularity/agents/runtime_bootstrapper.ex:62`

**Before:**
```elixir
child_spec = Singularity.SelfImprovingAgent.child_spec(spec_opts)
```

**After:**
```elixir
child_spec = Singularity.Agent.child_spec(spec_opts)
```

### Namespace Collision Fix
**File:** `singularity/lib/singularity/agents/agent.ex:1`

**Before:**
```elixir
defmodule Singularity.Agent do
```

**After:**
```elixir
defmodule Singularity.Agents.Base do
```

**New Alias File:** `singularity/lib/singularity/agent.ex`
```elixir
defmodule Singularity.Agent do
  @moduledoc """
  Alias to Singularity.Agents.Base for backwards compatibility.

  This module exists to prevent namespace collisions.
  All implementations should use Singularity.Agents.Base directly.
  """

  defdelegate child_spec(opts), to: Singularity.Agents.Base
  defdelegate start_link(opts), to: Singularity.Agents.Base
  # ... delegate other public functions
end
```

---

**End of Report**
