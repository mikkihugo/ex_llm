# Agent and Execution System - Quick Reference

## System Status

| Component | Status | Notes |
|-----------|--------|-------|
| **Agent Supervision** | DISABLED | Oban config cascade failures |
| **Agent Infrastructure** | PRODUCTION | 16 modules, 95K+ LOC |
| **Execution Orchestrators** | PRODUCTION | 50+ modules across 5 subsystems |
| **Test Coverage** | PARTIAL | 20% gaps in execution systems |

---

## Documentation

For complete architecture details, see: **AGENT_EXECUTION_ARCHITECTURE.md**

This file contains:
- 11 major sections
- 20+ detailed tables
- 5+ architecture diagrams
- 15+ code examples
- Complete integration points
- Test gap analysis
- Implementation recommendations

---

## Agent System Summary

**16 Modules** (95K+ LOC)
- **Core**: Agent (GenServer base), AgentSupervisor (DynamicSupervisor), Agents.Supervisor
- **Specialized**: SelfImprovingAgent, CostOptimizedAgent, + 6 others via detection
- **Support**: MetricsFeeder, RealWorkloadFeeder, QualityEnforcer, RemediationEngine, etc.

**Key Capabilities**:
- Autonomous improvement with feedback loops
- Metrics tracking and outcome recording
- Improvement queue with fingerprint deduplication
- Rate limiting with queue backoff
- Regression validation (baseline vs current)
- Hot-reload integration
- Pause/resume control

**Lifecycle**: Spawn → Observe → Decide → Improve → Validate → Queue Process

---

## Execution System Summary

**50+ Modules** across 5 subsystems:
- **Orchestration** (3): ExecutionOrchestrator, ExecutionStrategyOrchestrator, ExecutionStrategy
- **Planning** (12): SafeWorkPlanner, StoryDecomposer, TaskGraph, TaskGraphExecutor, etc.
- **SPARC** (2): SPARC.Orchestrator, template-driven execution
- **Autonomy** (10): RuleEngine, RuleEngineCore, Decider, Limiter, etc.
- **Todos** (6): TodoSwarmCoordinator, TodoWorkerAgent, TodoStore, etc.
- **TaskGraph** (8): Worker, WorkerPool, adapters (Shell, Docker, Lua, HTTP), etc.

**Key Features**:
- Config-driven strategy selection
- Rule-based execution with caching
- Template-driven SPARC execution
- Swarm-based todo coordination
- Low-level task adapters

---

## Test Coverage

### What's Tested ✅
- Agent startup, initialization, metrics tracking
- Outcome recording (success/failure)
- Pause/resume control
- Basic improvement queueing
- Concurrent operations
- Supervisor behavior

### What's Missing ❌
**Critical Gaps** (40+ tests needed):
- ExecutionOrchestrator routing
- RuleEngine execution flow
- TaskGraph DAG execution
- Task adapter routing
- Agent validation/fingerprinting/rate limiting

**Major Gaps** (60+ tests needed):
- SPARC orchestrator
- Planning subsystem
- TodoSwarmCoordinator
- All execution adapters
- Autonomy decision-making

---

## Architecture Patterns

### 1. Config-Driven Orchestration
Load execution strategies from config, auto-discover implementations.

### 2. Fingerprinting & Deduplication
:erlang.phash2() for stable IDs, MapSet for tracking (max 500), CRDT for atomic reserve.

### 3. Regression Validation
Baseline snapshot → apply improvement → compare metrics → rollback if degraded.

### 4. Queue Processing with Rate Limiting
Dequeue with Limiter.allow?(), re-queue with backoff if blocked.

---

## Module Dependency Graph

```
Agent (GenServer)
  ├─ Decider (decide: continue/improve)
  ├─ Limiter (rate limiting)
  ├─ CodeStore (persist queue)
  ├─ HotReload.ModuleReloader (apply changes)
  ├─ Control (publish events)
  └─ QueueCrdt (fingerprinting)

ExecutionOrchestrator
  └─ ExecutionStrategyOrchestrator
      ├─ TaskDAG Strategy
      ├─ SPARC.Orchestrator
      └─ Methodology Strategy

RuleEngine
  ├─ RuleEngineCore (pure Elixir)
  ├─ RuleLoader (ETS cache)
  └─ Cachex (result caching)

TaskGraph
  └─ Adapters (Shell, Docker, Lua, HTTP)
```

---

## File Locations

**Agent Code**: `/singularity/lib/singularity/agents/` (16 files)
**Agent Tests**: `/singularity/test/singularity/agents/` (4 files)

**Execution Code**: `/singularity/lib/singularity/execution/` (50+ files)
**Execution Tests**: `/singularity/test/singularity/` (1 file)

**Configuration**: `singularity/config/config.exs`

---

## Immediate Action Items

1. **Implement ExecutionOrchestrator tests** (5-6 tests)
2. **Implement RuleEngine tests** (8-10 tests)
3. **Implement Agent lifecycle tests** (10-12 tests)
4. **Mock HotReload integration** for improvement testing
5. **Document SPARC system** (templates, performance DAG)

---

## See Also

- `AGENT_EXECUTION_ARCHITECTURE.md` - Complete technical details
- `AGENTS.md` - Agent system documentation
- `singularity/lib/singularity/agents/agent.ex` - Core agent implementation (1100 LOC)
- `singularity/lib/singularity/execution/execution_orchestrator.ex` - Dispatcher
- `singularity/lib/singularity/execution/autonomy/rule_engine.ex` - Rule execution

