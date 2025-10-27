# Agent Coordination Router - Design Document

## Overview

**Problem:** Agents work in isolation. Complex goals require manual choreography. No learning of agent combinations.

**Solution:** Agent Coordination Router - intelligent agent assignment, parallel execution management, and workflow learning.

**Integration:** Bridges TaskGraphOrchestrator (existing) with Individual Agents (existing), adding routing intelligence layer.

---

## System Architecture

### Clean Separation of Concerns

```
┌─────────────────────────────────────────────────────────┐
│ User Goal / External Request                             │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │ SafeWorkPlanner (SAFe)   │ ← Planning/methodology
        │ [EXISTING]              │
        └────────────┬────────────┘
                     │
        ┌────────────▼──────────────────────┐
        │ TaskGraphOrchestrator              │ ← Goal decomposition
        │ • Decomposes goal → task DAG      │ ← Task dependency resolution
        │ • Validates graph                  │ ← [EXISTING]
        │ [EXISTING]                         │
        └────────────┬──────────────────────┘
                     │
                     │ Task: {id, goal, domain, complexity, ...}
                     │
        ┌────────────▼────────────────────────────────┐
        │ AgentCoordinationRouter [NEW - THIS PROJECT] │
        │                                              │
        │ For each task in DAG:                        │
        │  1. Query CapabilityRegistry                 │
        │  2. Score agents by fit                      │
        │  3. Assign to best agent(s)                  │
        │  4. Manage execution                         │
        │  5. Collect results & feedback               │
        │  6. Feed to WorkflowLearner                  │
        │                                              │
        │ Features:                                    │
        │ • Parallel execution (dependencies respected)│
        │ • Agent availability tracking                │
        │ • Cost optimization                          │
        │ • Failure recovery                           │
        │ • Real-time coordination metrics             │
        └────────────┬────────────────────────────────┘
                     │
            ┌────────┴──────────┬──────────────┐
            │                   │              │
    ┌───────▼──────┐  ┌────────▼────┐  ┌─────▼──────┐
    │ Refactoring  │  │ Quality      │  │ Chat       │
    │ Agent        │  │ Enforcer     │  │ Agent      │
    │ [EXISTING]   │  │ [EXISTING]   │  │ [EXISTING] │
    └──────────────┘  └─────────────┘  └────────────┘

    + 3 more agents (Architecture, Technology, Cost-Optimizer)
    + All report results back to CoordinationRouter
                     │
        ┌────────────▼──────────────────┐
        │ WorkflowLearner [NEW]          │
        │                                │
        │ • Tracks: agent combo → score  │
        │ • Learns success patterns      │
        │ • Updates routing priorities   │
        │ • Reports metrics              │
        └────────────┬──────────────────┘
                     │
        ┌────────────▼──────────────────┐
        │ Existing Dashboards/Metrics    │
        │ • Agent Performance Dashboard  │
        │ • Cost Analysis Dashboard      │
        │ • Task Execution Metrics       │
        │ [EXISTING]                     │
        └────────────────────────────────┘
```

---

## Component Design

### 1. AgentCoordinationRouter (Core)

**Responsibility:** Route tasks to agents, manage execution, collect results.

```elixir
# Routes a single task from the task graph
def route_task(task) do
  # 1. Find candidate agents
  candidates = CapabilityRegistry.top_agents_for_task(task, 5)

  # 2. Score based on:
  #    - Domain fit (50%)
  #    - I/O compatibility (20%)
  #    - Historical success (15%)
  #    - Availability (15%)
  best_agent = score_and_select(candidates, task)

  # 3. Execute task with agent
  {:ok, result} = execute_task(best_agent, task)

  # 4. Report back for learning
  WorkflowLearner.record_execution(best_agent, task, result)

  result
end

# Routes entire task DAG, respecting dependencies
def route_graph(task_graph) do
  # 1. Topological sort by dependencies
  ordered = topologically_sort(task_graph)

  # 2. Execute in parallel where possible
  execute_parallel(ordered)

  # 3. Collect all results
  {:ok, final_result}
end
```

**API:**
- `route_task(task)` → `{:ok, result}`
- `route_graph(task_dag)` → `{:ok, all_results}`
- `route_and_wait(task, timeout_ms)` → `{:ok, result}`
- `cancel_task(task_id)` → `:ok`

---

### 2. ExecutionCoordinator (Parallel Execution)

**Responsibility:** Manage parallel agent execution, handle dependencies, timeout/failure recovery.

```elixir
# Manages task-to-agent execution lifecycle
defstruct [
  :task_id,
  :assigned_agent,
  :status,           # :pending | :executing | :completed | :failed
  :start_time,
  :end_time,
  :result,
  :error,
  :retry_count
]

# Execute respecting task graph dependencies
def execute_task_graph(tasks) do
  # 1. Find tasks with no dependencies (can start immediately)
  # 2. Spawn async task for each agent assignment
  # 3. Wait for dependencies before executing dependent tasks
  # 4. Handle failures: retry with different agent or escalate
  # 5. Collect final results
end

# Handle agent failures gracefully
def handle_agent_failure(task, failed_agent, reason) do
  case reason do
    :timeout ->
      # Try next-best agent from candidates
      retry_with_next_agent(task, failed_agent)

    :overloaded ->
      # Wait and retry same agent
      backoff_and_retry(task, failed_agent)

    :incompatible ->
      # Task/agent mismatch, use different agent
      escalate_to_senior_agent(task, failed_agent)
  end
end
```

**API:**
- `start_execution(tasks)` → `execution_id`
- `monitor_execution(execution_id)` → Stream of status updates
- `pause_execution(execution_id)` → `:ok`
- `resume_execution(execution_id)` → `:ok`

---

### 3. WorkflowLearner (Pattern Learning)

**Responsibility:** Learn which agent combinations work best, improve routing.

```elixir
# Record successful execution for learning
defstruct [
  :workflow_id,
  :tasks,                        # List of tasks executed
  :agent_assignments,            # Map: task_id → agent_name
  :result,                        # Overall success/failure
  :total_cost,                    # Total tokens used
  :total_time,                    # Wall-clock time
  :success_rate,                  # % of tasks that succeeded
  :score                          # Overall workflow quality score
]

# Learn from execution
def record_workflow(workflow) do
  # 1. Calculate workflow success score
  score = calculate_workflow_score(workflow)

  # 2. Store in WorkflowPatternStore
  WorkflowPatternStore.save(workflow)

  # 3. Update agent routing scores
  update_agent_routing_scores(workflow)

  # 4. If high-success workflow, mark as "pattern"
  if score > 0.9, do: promote_to_pattern(workflow)
end

# Query learned patterns
def similar_workflows(current_workflow) do
  # Find workflows with similar task structure
  # Return: ordered list of successful patterns to try
end

# Get routing recommendations based on history
def get_routing_recommendation(task) do
  # "For this task type, agents X, Y, Z worked well
  #  in 85%, 72%, 68% of cases respectively"
  # Return: {agent, historical_success_rate}
end
```

**Database Schema:**

```sql
-- Track workflow executions
CREATE TABLE workflow_executions (
  id UUID PRIMARY KEY,
  goal TEXT,
  tasks JSONB,                    -- Task definitions
  agent_assignments JSONB,        -- {task_id: agent_name}
  result JSONB,                   -- {success, total_cost, time}
  success_rate FLOAT,
  workflow_score FLOAT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Index for quick lookup
CREATE INDEX idx_workflow_task_structure
  ON workflow_executions
  USING GIN(tasks);

-- Track agent pair success
CREATE TABLE agent_pair_success (
  agent_1 TEXT,
  agent_2 TEXT,
  co_executed_count INT,         -- Times executed together
  success_count INT,              -- Times succeeded
  success_rate FLOAT,
  avg_cost FLOAT,
  avg_time FLOAT,
  updated_at TIMESTAMP
);
```

---

### 4. CapabilityRegistry (Agent Inventory)

**Already designed above - quick summary:**

```elixir
# Agents register at startup
CapabilityRegistry.register(:refactoring_agent, %{
  domains: [:code_quality, :refactoring],
  input_types: [:code, :codebase],
  output_types: [:code, :documentation],
  complexity_level: :medium,
  estimated_cost: 500,
  success_rate: 0.92
})

# Router queries for task routing
CapabilityRegistry.top_agents_for_task(task, 5)
CapabilityRegistry.best_agent_for_task(task)
```

---

## Data Flow - Complete Example

**Scenario:** User goal "Improve code quality and test coverage"

```
1. USER INPUT
   Goal: "Improve code quality and test coverage"

2. SAFE WORK PLANNER
   Input: Goal
   Output: SAFe sprints, work items, methodology

3. TASK GRAPH ORCHESTRATOR
   Input: SAFe work items
   Output: Task DAG

   Tasks:
   {
     1: {id: 1, goal: "Analyze code quality", domain: :code_quality,
         input: :codebase, output: :analysis},
     2: {id: 2, goal: "Identify test gaps", domain: :testing,
         input: :codebase, output: :analysis, depends_on: [1]},
     3: {id: 3, goal: "Write missing tests", domain: :testing,
         input: :code, output: :code, depends_on: [2]},
     4: {id: 4, goal: "Refactor for testability", domain: :refactoring,
         input: :code, output: :code, depends_on: [2]},
     5: {id: 5, goal: "Validate improvements", domain: :monitoring,
         input: :metrics, output: :analysis, depends_on: [3, 4]}
   }

4. AGENT COORDINATION ROUTER
   Input: Task DAG

   For task 1 (Analyze code quality):
   - Query: agents_for_domain(:code_quality)
   - Candidates: [quality_enforcer, architect, chat]
   - Score: quality_enforcer: 0.95, architect: 0.78, chat: 0.65
   - Assign: quality_enforcer

   For task 2 (Identify test gaps):
   - Query: agents_for_domain(:testing)
   - Candidates: [refactoring_agent, quality_enforcer]
   - Score: refactoring_agent: 0.92, quality_enforcer: 0.68
   - Assign: refactoring_agent
   - Wait for task 1 (dependency)

   For tasks 3, 4 (parallel - no mutual deps):
   - Task 3: assign to refactoring_agent
   - Task 4: assign to refactoring_agent
   - Both execute in parallel

   For task 5 (Validate):
   - Wait for tasks 3, 4
   - Assign to quality_enforcer
   - Validate all improvements

5. AGENTS EXECUTE
   quality_enforcer:    Task 1 → Code quality analysis
   refactoring_agent:   Tasks 2, 3, 4 → Test coverage + refactoring

   Results:
   {
     1: {quality_score: 6.2, issues: [...]},
     2: {coverage_gap: 0.23, untested_functions: [...]},
     3: {new_tests: 45, coverage: 0.78},
     4: {refactored_modules: 12},
     5: {final_quality_score: 7.8, improvement: +1.6}
   }

6. WORKFLOW LEARNER
   Input: All task results + agent assignments

   Record:
   - Workflow ID: uuid
   - Tasks executed: [1, 2, 3, 4, 5]
   - Agent assignments:
     * Task 1 → quality_enforcer (success: ✓)
     * Task 2 → refactoring_agent (success: ✓)
     * Task 3 → refactoring_agent (success: ✓)
     * Task 4 → refactoring_agent (success: ✓)
     * Task 5 → quality_enforcer (success: ✓)
   - Overall score: 0.94 (all tasks succeeded, improvement > target)
   - Cost: 2847 tokens
   - Time: 8.3 minutes

   Learning updates:
   - quality_enforcer success rate: +0.02 (was 0.92, now 0.94)
   - Agent pair (refactoring, refactoring) for (test_gap, test_writing): success_rate: 0.93
   - Agent pair (quality_enforcer, refactoring) for (initial_analysis, implementation): success_rate: 0.89

7. DASHBOARD UPDATE
   - Agent Performance Dashboard: Updated metrics
   - Workflow Patterns: New high-success pattern saved
   - Cost Analysis: Token usage tracked
```

---

## Integration Points

### With TaskGraphOrchestrator

**Current Flow:**
```
Goal → TaskGraphOrchestrator → Task DAG → Execute (hardcoded?)
```

**New Flow:**
```
Goal → TaskGraphOrchestrator → Task DAG → AgentCoordinationRouter → Agents → Results
```

**Integration Point:**
```elixir
# In TaskGraphOrchestrator.execute_graph/2
def execute_graph(graph, opts) do
  # Old: hardcoded execution
  # execute_tasks_directly(graph)

  # New: route through agents
  AgentCoordinationRouter.route_graph(graph, opts)
end
```

### With Existing Agents

**No changes needed.** Agents already:
- Have well-defined inputs/outputs
- Accept standardized task format
- Report execution results
- Handle errors gracefully

**New:** Just need to register capabilities at startup:

```elixir
# In each agent's init/start
def start_link(opts) do
  # ... existing agent setup ...

  # NEW: Register with coordinator
  CapabilityRegistry.register(:refactoring_agent, %{
    role: :refactoring,
    domains: [:code_quality, :refactoring, :testing],
    input_types: [:code, :codebase],
    output_types: [:code, :documentation],
    complexity_level: :medium,
    estimated_cost: 500,
    success_rate: 0.92
  })

  {:ok, pid}
end
```

### With Existing Dashboards

**No breaking changes.** New data just flows into existing systems:

- **Agent Performance Dashboard** ← Updated from WorkflowLearner metrics
- **Cost Analysis Dashboard** ← Token usage from ExecutionCoordinator
- **Task Execution Metrics** ← Execution times from ExecutionCoordinator

---

## Avoiding Duplication

| System | Purpose | Owns What |
|--------|---------|-----------|
| **TaskGraphOrchestrator** | Decompose goal → DAG, validate structure | Task graph creation, dependency resolution |
| **AgentCoordinationRouter** | Route tasks to agents, execute in parallel | Task-to-agent assignment, execution mgmt |
| **SafeWorkPlanner** | SAFe methodology, planning | Methodology/sprints structure |

**Clear boundaries:**
- TaskGraph owns "what tasks to do"
- AgentCoordinator owns "who does each task"
- SafeWorkPlanner owns "planning methodology"

---

## Implementation Phases

### Phase 1: Foundation (Files Created Today)
- `agent_capability.ex` - Capability struct ✓
- `capability_registry.ex` - Registry GenServer ✓

### Phase 2: Core Routing (Next)
- `agent_router.ex` - Route task → agent logic
- `execution_coordinator.ex` - Manage parallel execution
- `coordination_supervisor.ex` - OTP supervision

### Phase 3: Learning & Improvement
- `workflow_learner.ex` - Track patterns
- `workflow_pattern_store.ex` - Persist patterns
- Database migrations for workflow tracking

### Phase 4: Integration & Optimization
- Hook into TaskGraphOrchestrator
- Agent startup registration
- Dashboard metrics integration
- Cost optimization rules

### Phase 5: Testing & Polish
- Unit tests for all components
- Integration tests with real agents
- Performance benchmarks
- Documentation

---

## Success Metrics

**What we'll measure:**

1. **Agent Utilization**
   - % of agents' time spent on tasks (vs idle)
   - Cost per task type
   - Success rate per agent

2. **Workflow Efficiency**
   - Total time to complete complex goals
   - Cost optimization (vs naive routing)
   - Parallel execution gains

3. **Learning Progress**
   - # of discovered high-success patterns
   - Success rate improvement over time
   - Agent pair co-execution patterns

4. **System Reliability**
   - Task success rate (with retries)
   - Failure recovery latency
   - Cascading failure prevention

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| TaskGraph integration breaks existing flow | Integration tests, feature flag, gradual rollout |
| Agent overload | Availability tracking, queueing, timeout handling |
| Circular dependencies in learning | Cycle detection in WorkflowLearner |
| Database growth (workflow tracking) | Automated cleanup, archival policy |
| Routing decisions are wrong | Fallback to previous agent, manual override |

---

## Open Questions

1. **How to handle agent specialization conflicts?**
   - Multiple agents can do same task
   - Which score highest? All equally?
   - Should we try N agents in parallel?

2. **Failure recovery strategy?**
   - Retry same agent (backoff)?
   - Try next-best agent?
   - Escalate to senior agent?
   - Give up and report failure?

3. **Learning confidence threshold?**
   - When is pattern success rate "valid"?
   - Need 10 samples? 100? Per-agent?

4. **Cost vs Quality tradeoff?**
   - Always pick cheapest agent?
   - Weigh cost + quality?
   - User-configurable priority?

---

## Timeline

- **Phase 1:** 0.5 days (today)
- **Phase 2:** 1.5 days
- **Phase 3:** 1.5 days
- **Phase 4:** 1 day
- **Phase 5:** 1.5 days

**Total: 6 days of development**

---

**Next Step:** Approve architecture, then implement Phase 2 (Agent Router core logic).
