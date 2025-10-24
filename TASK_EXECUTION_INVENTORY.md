# Task & Job Execution Inventory

## Executive Summary

Singularity uses **4 distinct task execution patterns**, with approximately **90 execution-related modules** and **2,902 lines of job code**. Current architecture has scattered implementations without unified abstraction, creating significant consolidation opportunity.

## Part 1: Complete Task/Job Inventory

### 1. OBAN Jobs/Workers (18 files, 2,902 lines)

#### Singularity Jobs
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/`

**Core Infrastructure:**
- `job_orchestrator.ex` - Config-driven orchestration of all background jobs
- `job_type.ex` - Behavior contract for job implementations

**Periodic Jobs** (scheduled via Oban Cron):
1. `metrics_aggregation_worker.ex` - Aggregate agent metrics every 5 minutes
2. `pattern_sync_worker.ex` - Sync framework patterns every 5 minutes
3. `feedback_analysis_worker.ex` - Analyze feedback every 30 minutes
4. `agent_evolution_worker.ex` - Apply agent improvements every 1 hour
5. `cache_refresh_worker.ex` - Refresh hot packages cache every 1 hour
6. `cache_prewarm_worker.ex` - Prewarm cache with hot data every 6 hours
7. `cache_cleanup_worker.ex` - Clean up old cache entries on demand
8. `cache_maintenance_job.ex` - General cache maintenance
9. `knowledge_export_worker.ex` - Export learned patterns to Git
10. `pattern_miner_job.ex` - Mine code patterns from codebase
11. `domain_vocabulary_trainer_job.ex` - Train domain vocabulary models
12. `train_t5_model_job.ex` - Fine-tune T5 embeddings
13. `embedding_finetune_job.ex` - Fine-tune embedding model
14. `dead_code_daily_check.ex` - Daily dead code detection
15. `dead_code_weekly_summary.ex` - Weekly dead code summary

**Job Configuration Pattern:**
```elixir
use Oban.Worker, queue: :default, max_attempts: 2
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  # Implementation
end
```

**Execution Flow:**
```
Config (config.exs) → job_types enabled → JobOrchestrator.enqueue() 
  → Oban.insert(Repo, job) → Oban Queue → Oban.Worker.perform()
```

#### CentralCloud Jobs
Location: `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/jobs/`

1. `pattern_aggregation_job.ex` - Aggregate patterns from all instances (1 hour)
2. `package_sync_job.ex` - Sync package registry
3. `statistics_job.ex` - Compute statistics

### 2. NATS Message Handlers (GenServer-based)

#### Subscribers (receive → process → reply)
- `Singularity.NatsExecutionRouter` - Routes execution requests to SPARC.Orchestrator
- `Centralcloud.IntelligenceHubSubscriber` - Receives intelligence data from engines
- `Centralcloud.Nats.PatternValidatorSubscriber` - Validates patterns

**Message Handler Pattern:**
```elixir
use GenServer

def handle_info({:msg, %{topic: subject, body: body, reply_to: reply_to}}, state) do
  # Parse message
  # Process async via Task.async()
  # Publish reply via Singularity.NatsClient.publish(reply_to, response)
  {:noreply, state}
end
```

**Execution Flow:**
```
NATS Publisher → NatsClient.subscribe() → GenServer.handle_info() 
  → Task.async() → NatsClient.publish(reply_to, result)
```

### 3. Task Graph / Todo-Based Execution (13,114 lines)

Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/`

#### Core Components:
1. `TaskGraph.Orchestrator` - High-level API for enqueueing tasks with dependencies
2. `TaskGraph.WorkerPool` - GenServer that spawns Worker processes (polls for ready tasks)
3. `TaskGraph.Worker` - Individual worker process handling single todo
4. `Todos.TodoStore` - Persists todos with `depends_on_ids` to PostgreSQL
5. `Todos.TodoNatsInterface` - NATS query interface for todos
6. `Todos.TodoSwarmCoordinator` - Coordinates worker swarm

**Execution Adapters:**
- `TaskGraph.Adapters.Shell` - Safe shell command execution
- `TaskGraph.Adapters.Docker` - Sandboxed Docker execution
- `TaskGraph.Adapters.Lua` - Luerl sandbox for Lua scripts
- `TaskGraph.Adapters.Http` - HTTP requests

**Execution Flow:**
```
Orchestrator.enqueue(task) → TodoStore.create(depends_on_ids) 
  → WorkerPool polls (every 5s) → Detects ready tasks 
  → Spawns Worker processes → Worker executes via Adapters 
  → Stores result in TodoStore
```

#### Task Structure:
```elixir
%{
  id: "task-123",
  title: "Implement feature",
  role: :coder,                        # :coder, :tester, :critic, :researcher, :admin
  depends_on: ["task-122"],           # Dependency tracking
  context: %{...},
  status: :pending | :in_progress | :completed,
  result: %{...}
}
```

### 4. GenServer-Based Task Execution

**Agent Processors:**
- `Singularity.Agents.Agent` - GenServer base for all agents
- `Singularity.Agents.CostOptimizedAgent` - Cost-aware LLM selection
- `Singularity.Agents.SelfImprovingAgent` - Self-optimizing agent
- `Singularity.Agents.RuntimeBootstrapper` - Bootstrap agents at startup
- `Singularity.Execution.Todos.TodoWorkerAgent` - Process individual todos

**Executor Engines:**
- `Singularity.Execution.Planning.TaskGraphExecutor` - Execute task DAGs
- `Singularity.Execution.Planning.LuaStrategyExecutor` - Execute Lua strategies
- `Singularity.Quality.MethodologyExecutor` - Execute SAFe methodology
- `Singularity.Code.Startup.StartupCodeIngestion` - Load code at startup
- `Singularity.Tools.DatabaseToolsExecutor` - Execute DB tools
- `Singularity.SPARC.Orchestrator` - Template-based execution

**Execution Pattern:**
```elixir
use GenServer

def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

def execute(task), do: GenServer.call(__MODULE__, {:execute, task})

@impl true
def handle_call({:execute, task}, _from, state) do
  result = do_execute(task)
  {:reply, result, state}
end
```

---

## Part 2: Execution Patterns & Signatures

### Pattern 1: Oban Worker

**Definition:**
```elixir
defmodule Singularity.Jobs.MetricsAggregationWorker do
  use Oban.Worker, queue: :default, max_attempts: 2

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # args are automatically converted to map
    # Return: :ok | {:error, reason} | {:reschedule, datetime}
  end

  # Helper: Create job struct
  def new(args) do
    %Oban.Job{args: args}  # Will be inserted by JobOrchestrator
  end
end
```

**Invocation:**
```elixir
# Via JobOrchestrator (recommended)
{:ok, job} = JobOrchestrator.enqueue(:metrics_aggregation, %{period: :last_hour})

# Direct (not recommended - bypasses config)
%{args: args}
|> Singularity.Jobs.MetricsAggregationWorker.new()
|> Oban.insert(Repo)
```

### Pattern 2: NATS Message Handler (GenServer)

**Definition:**
```elixir
defmodule Singularity.NatsExecutionRouter do
  use GenServer
  
  def init(_opts) do
    Singularity.NatsClient.subscribe("execution.request.task")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    # Non-blocking: spawn async task
    Task.async(fn ->
      response = process_message(body)
      Singularity.NatsClient.publish(reply_to, Jason.encode!(response))
    end)
    {:noreply, state}
  end
end
```

**Invocation:**
```elixir
# Publisher sends:
NatsClient.publish("execution.request.task", Jason.encode!(request), reply_to: "response.topic.xyz")

# Handler responds:
NatsClient.publish(reply_to, Jason.encode!(response))
```

### Pattern 3: Task Graph / Todo Execution

**Definition:**
```elixir
# Create task with dependencies
task = %{
  id: "deploy",
  title: "Deploy to production",
  role: :admin,
  depends_on: ["test", "build"],
  context: %{version: "1.0.0"}
}

# Enqueue with automatic dependency resolution
{:ok, task_id} = TaskGraph.Orchestrator.enqueue(task)

# Check status
{:ok, status} = TaskGraph.Orchestrator.get_status(task_id)

# Get result
{:ok, result} = TaskGraph.Orchestrator.get_result(task_id)
```

**Execution Flow:**
```
TodoStore.create(task) 
  ↓ [TaskGraph.WorkerPool polls every 5s]
Detects ready tasks (dependencies resolved)
  ↓ [Spawns up to 10 workers]
TaskGraph.Worker process spawned
  ↓ [Selects appropriate adapter based on role/context]
Adapter execution (Shell, Docker, Lua, Http)
  ↓
Result stored in TodoStore
  ↓ [Worker reports back to WorkerPool]
WorkerPool updates status → next poll detects dependents → spawns next workers
```

### Pattern 4: GenServer Agent/Executor

**Definition:**
```elixir
defmodule Singularity.Agents.CostOptimizedAgent do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end

  def process_task(agent_id, task) do
    GenServer.call(via_tuple(agent_id), {:process_task, task})
  end

  @impl true
  def handle_call({:process_task, task}, _from, state) do
    # Process task synchronously
    result = execute_task(task)
    {:reply, result, state}
  end
end
```

**Invocation:**
```elixir
{:ok, _pid} = CostOptimizedAgent.start_link(id: "agent_1")
result = CostOptimizedAgent.process_task("agent_1", task)
```

---

## Part 3: Current Integration Points

### Where Tasks Are Enqueued:

1. **Via JobOrchestrator** (RECOMMENDED for Oban):
   - `Singularity.Jobs.JobOrchestrator.enqueue(:job_type, args, opts)`
   - Config-driven, discoverable, centralized

2. **Via Oban.insert directly** (NOT RECOMMENDED):
   - Bypasses JobOrchestrator config
   - Found in: `train_t5_model_job.ex`, `domain_vocabulary_trainer_job.ex`

3. **Via TaskGraph.Orchestrator**:
   - `Singularity.Execution.TaskGraph.Orchestrator.enqueue(task)`
   - For todo/dependency-driven work

4. **Via NATS Messages**:
   - Publisher → NatsClient.publish() → Subscriber handles
   - Found in: NatsExecutionRouter, IntelligenceHubSubscriber

5. **Via GenServer direct calls**:
   - `Agent.execute()`, `Executor.execute()`
   - Synchronous, no queuing

### Where Adapters Are Used:

1. **Shell Adapter** - Run shell commands safely
   - Used by: TaskGraph.Worker, testing, data collection
   - Returns: `{:ok, %{stdout, stderr, exit}}` or `{:error, reason}`

2. **Docker Adapter** - Run isolated containers
   - Used by: TaskGraph.Worker for test execution
   - Requires: CPU/memory limits

3. **Lua Adapter** - Run validation scripts
   - Used by: Quality validators, rule engines
   - Returns: Lua function result

4. **Http Adapter** - Make HTTP requests
   - Used by: External integrations
   - Returns: Response/error

---

## Part 4: Abstraction Gaps (Consolidation Opportunity)

### Current State: 4 Different Execution Models

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Code                          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
    Pattern 1:           Pattern 2:            Pattern 3:        Pattern 4:
    Oban Worker         NATS Handler        TodoStore Executor   GenServer Agent
    
    JobOrchestrator      NatsClient          TaskGraph.Orchestra  Agent.execute()
         ↓                   ↓                      ↓                   ↓
    Oban.insert()      GenServer.handle    TodoStore.create()   GenServer.call()
         ↓                   ↓                      ↓                   ↓
    Oban Queue          Task.async()        WorkerPool polls      Synchronous
         ↓                   ↓                      ↓
    Oban.Worker      NatsClient.publish    Adapters (Shell/
         │                   │              Docker/Lua/Http)
         └───────────────────┴──────────────────────┘
                      │
                      ▼
         Actual Execution (agent logic, LLM calls, etc)
```

### Missing Abstraction: Unified Task Execution Interface

No common interface:
- Oban workers have `perform(job)` contract
- NATS handlers have `handle_info(msg, state)` pattern
- TodoStore executors use adapters directly
- GenServer agents use `handle_call/3`

Different invocation patterns:
- JobOrchestrator.enqueue() → config-driven
- NatsClient.publish() → message-driven
- TaskGraph.Orchestrator.enqueue() → todo-driven
- Agent.execute() → direct call

Different result handling:
- Oban: `:ok`, `{:error, reason}`, `{:reschedule, datetime}`
- NATS: Reply via NatsClient.publish()
- TodoStore: Result stored in DB, checked via poll
- Agent: Direct return value

---

## Part 5: Scope of Consolidation

### Files to Unify (Rough estimate):

**Oban Workers:** 15 job files → 1 generic worker module
**NATS Handlers:** 3 subscriber files → Unified handler pattern
**TodoStore Executors:** WorkerPool + adapters (5 files) → Already somewhat unified
**GenServer Agents:** 7+ agent files → Unified agent base

### Lines of Code:
- Jobs: 2,902 lines → ~500 lines (with consolidation)
- Execution: 13,114 lines → ~8,000 lines (adapters are necessary)
- Agents: ~3,000 lines → ~1,500 lines (common base)

**Total Consolidation Potential: ~20% reduction in infrastructure code**

### Benefits of Consolidation:

1. **Single Execution Interface**: One way to execute any task
2. **Config-Driven**: All tasks discoverable via config
3. **Observability**: Unified logging, tracing, metrics
4. **Testability**: Mock execution adapters, not multiple patterns
5. **Learning**: Agents learn from any execution pattern
6. **Monitoring**: Single dashboard for all task types

### Implementation Strategy:

1. Create `Singularity.Execution.TaskExecutor` protocol/behavior
2. Implement adapters for each pattern:
   - ObanAdapter
   - NatsAdapter
   - TodoStorageAdapter
   - GenServerAdapter
3. Consolidate invocation: `TaskExecutor.execute(task, executor: :oban)`
4. Unified result tracking and learning loop

---

## Files Reference

### Oban Jobs
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/`
- 18 files, 2,902 lines total

### Task Graph Execution
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/`
- 90 files, 13,114 lines total
- Key: `task_graph/`, `planning/`, `todos/`

### NATS Handlers
- `Singularity.NatsExecutionRouter` - Main router
- `Centralcloud.IntelligenceHubSubscriber` - CentralCloud subscriber
- `/singularity/lib/singularity/nats/` - NATS infrastructure

### Agents
- `/singularity/lib/singularity/agents/` - All agent implementations

### Orchestrators (multiple entry points)
- `Singularity.Execution.ExecutionOrchestrator` - Unified orchestrator
- `Singularity.Execution.SPARC.Orchestrator` - Template-based
- `Singularity.Execution.TaskGraph.Orchestrator` - Todo-based
- `Singularity.Jobs.JobOrchestrator` - Oban-based
- `Singularity.Quality.MethodologyExecutor` - Methodology-based
