# Task & Job Execution Inventory - Complete Report

**Generated:** 2025-10-24
**Scope:** All task/job execution systems in Singularity
**Status:** Final inventory for consolidation planning

---

## Document Overview

This inventory contains a complete analysis of all task execution, job orchestration, and work processing systems in the Singularity codebase.

### Three Main Documents

1. **TASK_EXECUTION_INVENTORY.md** (448 lines, 15KB)
   - Complete inventory of all 4 execution patterns
   - Detailed code examples and signatures
   - Integration points and execution flows
   - Abstraction gaps analysis
   - Consolidation roadmap

2. **EXECUTION_PATTERN_ANALYSIS.md** (746 lines, 18KB)
   - Detailed comparison matrix of all 4 patterns
   - Complete module inventory with line counts
   - Execution flow diagrams
   - Configuration examples
   - Consolidation priority matrix
   - Roadmap with implementation phases

3. **TASK_EXECUTION_SUMMARY.txt** (298 lines)
   - Quick reference guide
   - High-level summary of each pattern
   - Integration landscape overview
   - Abstraction gaps at a glance
   - Consolidation scope and effort estimates

---

## Key Findings

### 4 Distinct Execution Patterns Found

| Pattern | Files | Lines | Status |
|---------|-------|-------|--------|
| **Oban Background Jobs** | 18 | 2,902 | High consolidation potential |
| **NATS Message Handlers** | 5 | ~1,400 | Medium consolidation potential |
| **Task Graph / TodoStore** | 90 | 13,114 | Already somewhat unified |
| **GenServer Agents** | 7+ | ~2,500 | Minor consolidation needed |
| **Total** | **120+** | **~20,000** | **20% reduction possible** |

### Consolidation Opportunities

**Highest Priority:**
- 15 Oban job files → 1 generic worker (83% reduction)
- 10 maintenance jobs → 1 template-driven system
- 3 NATS handlers → unified subscription pattern

**Estimated Impact:**
- Job files: 2,900 → 500 lines
- NATS code: 1,400 → 800 lines
- Total infrastructure reduction: ~4,400 lines (20%)

**Effort Estimate:** 7-11 weeks focused work

### Critical Gaps

1. **No unified task execution interface** - 4 different patterns
2. **No unified discovery mechanism** - can't enumerate all tasks
3. **No unified learning/observability** - only Oban feeds improvement loop
4. **Scattered configuration** - no central task registry
5. **Multiple orchestrators** - 5+ overlapping systems

---

## Execution Pattern Details

### 1. Oban Background Jobs

**Location:** `/singularity/lib/singularity/jobs/` (15 files)

**Pattern:**
```elixir
use Oban.Worker, queue: :default, max_attempts: 2
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  # Implementation
  :ok
end
```

**Key Jobs:**
- Metrics aggregation (5 min)
- Pattern mining & syncing (5 min - 1 hour)
- Agent evolution (1 hour)
- Cache maintenance (5 min - 6 hours)
- ML model training (on-demand)

**Infrastructure:**
- `JobOrchestrator` - Config-driven discovery and enqueue
- `JobType` behavior - Contract for all jobs

### 2. NATS Message Handlers

**Location:** `/singularity/lib/singularity/nats/` (3 files)

**Pattern:**
```elixir
use GenServer

def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
  Task.async(fn ->
    response = process_message(body)
    NatsClient.publish(reply_to, Jason.encode!(response))
  end)
  {:noreply, state}
end
```

**Key Handlers:**
- NatsExecutionRouter (execution.request.task)
- IntelligenceHubSubscriber (intelligence.hub.*.*)
- PatternValidatorSubscriber

### 3. Task Graph / TodoStore Execution

**Location:** `/singularity/lib/singularity/execution/` (90 files)

**Core Components:**
- TaskGraph.Orchestrator - Enqueue with dependencies
- TaskGraph.WorkerPool - Poll-based worker spawning
- TodoStore - PostgreSQL persistence
- 4 Execution Adapters (Shell, Docker, Lua, Http)

**Unique Feature:** Dependency graph support via `depends_on_ids`

### 4. GenServer Agent/Executor Execution

**Location:** `/singularity/lib/singularity/agents/` (7+ files)

**Key Agents:**
- CostOptimizedAgent - LLM selection
- SelfImprovingAgent - Learning
- RuntimeBootstrapper - Startup

**Pattern:** Synchronous `GenServer.call()` with no queuing

---

## How to Use This Inventory

### For Architecture Planning
1. Read `TASK_EXECUTION_SUMMARY.txt` for overview
2. Refer to `EXECUTION_PATTERN_ANALYSIS.md` comparison matrix
3. Use consolidation roadmap to plan phases

### For Implementation
1. Check `TASK_EXECUTION_INVENTORY.md` for code examples
2. Review execution flow diagrams
3. Follow phase-by-phase consolidation strategy

### For Debugging/Understanding
1. Check pattern description for your execution type
2. Find integration points section
3. Review execution flow diagram for that pattern

### For Adding New Tasks
1. Choose pattern (recommend Oban for background jobs)
2. Follow existing pattern in that category
3. Register in central config (current or future)
4. Add to learning system

---

## Integration Points Summary

### Current Task Invocation Methods

```
Application Code
    ├─ JobOrchestrator.enqueue(:job_type, args)         [Oban]
    ├─ NatsClient.publish(subject, message)             [NATS]
    ├─ TaskGraph.Orchestrator.enqueue(task)            [TodoStore]
    ├─ Agent.execute(agent_id, task)                   [GenServer]
    └─ ExecutionOrchestrator.execute(goal)             [Auto-detect]
```

### Current Configuration Points

- Oban jobs: `config.exs` `:job_types`
- NATS handlers: Hard-coded module `init()`
- TodoStore: Hard-coded in application code
- Agents: Hard-coded instantiation
- ExecutionOrchestrator: Auto-detection heuristics

---

## Abstraction Gaps Detail

### Gap 1: No Unified Task Interface
Each pattern has different:
- Invocation method
- Return type
- Result storage
- Retry mechanism

### Gap 2: No Unified Discovery
- Oban: ✓ Has `JobOrchestrator.get_job_types_info()`
- NATS: Manual subscriber lookup
- TodoStore: Ad-hoc task creation
- Agents: Manual instantiation
- No way to enumerate all tasks

### Gap 3: No Unified Learning
- Oban: Optional `JobOrchestrator.learn_from_job/1`
- Others: No learning integration
- Result: Other patterns invisible to improvement loop

### Gap 4: No Unified Timeouts
- Oban: None (relies on max_attempts)
- NATS: Manual via `Task.yield()`
- TodoStore: Adapter-specific (120s-300s)
- Agents: None
- Result: Inconsistent timeout behavior

### Gap 5: Scattered Configuration
- No central task registry
- Hard to test execution patterns
- Hard to discover available tasks
- Hard to manage scheduling

### Gap 6: Multiple Orchestrators
- ExecutionOrchestrator (unified attempt, 126 lines)
- SPARC.Orchestrator (template-based, 400+ lines)
- TaskGraph.Orchestrator (todo-based, 200+ lines)
- JobOrchestrator (job-based, 298 lines)
- MethodologyExecutor (SAFe-based, 200+ lines)

---

## Consolidation Strategy

### Phase 1: Create Unified Interface (1-2 weeks)
- Define `TaskExecutor` protocol/behavior
- Map each pattern to adapter
- Create shared types

### Phase 2: Implement Adapters (2-3 weeks)
- ObanAdapter
- NatsAdapter
- TodoStorageAdapter
- AgentAdapter

### Phase 3: Consolidate Jobs (1-2 weeks)
- Template-driven job system
- Generic workers
- Central configuration

### Phase 4: Unify Configuration (1 week)
- Central task registry
- Unified discovery
- Learning integration points

### Phase 5: Migrate Code (2-3 weeks)
- Update invocation points
- Test each pattern
- Documentation

**Total Effort:** 7-11 weeks

**Expected Savings:** 4,400+ lines of infrastructure code

---

## File References

### Oban Jobs
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/`
- 18 files, 2,902 lines total

### Task Graph Execution  
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/`
- 90 files, 13,114 lines total

### NATS Handlers
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/`
- 3 main files, ~1,400 lines

### Agents
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/`
- 7+ files, ~2,500 lines

### Orchestrators (Multiple Entry Points)
- `Singularity.Execution.ExecutionOrchestrator`
- `Singularity.Execution.SPARC.Orchestrator`
- `Singularity.Execution.TaskGraph.Orchestrator`
- `Singularity.Jobs.JobOrchestrator`
- `Singularity.Quality.MethodologyExecutor`

---

## Next Steps

1. **Review** these documents with team
2. **Prioritize** which patterns to consolidate first
3. **Plan** phases and assign ownership
4. **Execute** following provided roadmap
5. **Monitor** code reduction metrics
6. **Document** new unified patterns

---

## Related Documentation

- `CLAUDE.md` - Project overview and architecture
- `SYSTEM_FLOWS.md` - Mermaid diagrams of application flows
- `AGENTS.md` - Complete agent system documentation
- `PRODUCTION_FIXES_IMPLEMENTED.md` - Production readiness status

---

**Document Status:** Final Inventory (Ready for consolidation planning)
**Last Updated:** 2025-10-24
**Maintained By:** Claude Code
