# Task Execution Patterns - Detailed Comparison

## 1. Execution Pattern Comparison Matrix

| Aspect | Oban Worker | NATS Handler | TodoStore | GenServer Agent |
|--------|-------------|--------------|-----------|-----------------|
| **Invocation** | JobOrchestrator.enqueue() | NatsClient.publish() | TaskGraph.Orchestrator.enqueue() | Agent.execute() / GenServer.call() |
| **Concurrency** | Async queue (Oban manages) | Fire & forget + async reply | Poll-based spawning (max 10) | Synchronous by default |
| **Scaling** | Horizontal (multiple Oban nodes) | Horizontal (NATS cluster) | Per-instance workers | Limited to 1 process per agent |
| **Dependencies** | None (independent jobs) | None (request-response) | Yes (depends_on_ids) | None (call stack dependent) |
| **Persistence** | PostgreSQL (Oban.Job table) | NATS JetStream (optional) | PostgreSQL (todos table) | Optional (GenServer state only) |
| **Result Storage** | Job record + code callback | NATS reply | todos table + result field | Return value or state update |
| **Retry Logic** | Max attempts (Oban) | Manual retry via NATS | Manual retry in WorkerPool | Exception handling only |
| **Scheduling** | Cron (Oban.Plugins.Cron) | Manual publish | N/A (on-demand only) | N/A (on-demand only) |
| **Learning Integration** | JobOrchestrator.learn_from_job/1 | None built-in | None built-in | None built-in |
| **Configuration** | Config.exs job_types | Hard-coded subjects | Hard-coded | Hard-coded |
| **Discovery** | JobOrchestrator.get_job_types_info() | Manual subscriber list | Manual task creation | Manual agent creation |
| **Timeout Handling** | Via max_attempts + manual | Task.async + Task.yield | Task.async in adapter | No automatic timeout |
| **Code Location** | `/jobs/*.ex` (18 files) | `/nats/*.ex` (3 main) | `/execution/todos/*.ex` + adapters | `/agents/*.ex` (7+ files) |

---

## 2. Job/Worker Module Inventory

### Oban Workers (18 modules, 2,902 lines)

#### Singularity (15 modules)
```
/jobs/
├── job_orchestrator.ex          (298 lines) - Config-driven job manager
├── job_type.ex                  (215 lines) - Job behavior contract
├── metrics_aggregation_worker.ex (59 lines) - Aggregate metrics (5 min)
├── pattern_sync_worker.ex       (~70 lines) - Sync patterns (5 min)
├── feedback_analysis_worker.ex  (~70 lines) - Analyze feedback (30 min)
├── agent_evolution_worker.ex    (~70 lines) - Evolve agents (1 hour)
├── cache_refresh_worker.ex      (~70 lines) - Refresh cache (1 hour)
├── cache_prewarm_worker.ex      (~70 lines) - Prewarm cache (6 hours)
├── cache_cleanup_worker.ex      (~70 lines) - Cleanup cache (on-demand)
├── cache_maintenance_job.ex     (~70 lines) - General maintenance
├── knowledge_export_worker.ex   (~70 lines) - Export patterns to Git
├── pattern_miner_job.ex         (~200 lines) - Mine code patterns
├── domain_vocabulary_trainer_job.ex (~200 lines) - Train vocabulary
├── train_t5_model_job.ex        (~200 lines) - Fine-tune T5
├── embedding_finetune_job.ex    (~150 lines) - Fine-tune embeddings
├── dead_code_daily_check.ex     (~100 lines) - Daily dead code check
└── dead_code_weekly_summary.ex  (~100 lines) - Weekly summary
```

#### CentralCloud (3 modules)
```
/jobs/
├── pattern_aggregation_job.ex   (~200 lines) - Aggregate all patterns (1 hour)
├── package_sync_job.ex          (~200 lines) - Sync packages
└── statistics_job.ex            (~150 lines) - Compute statistics
```

### NATS Handlers (3 modules)

```
/nats/
├── nats_execution_router.ex     (245 lines) - Route execution requests
├── nats_server.ex               (~500 lines) - NATS connection management
└── nats_client.ex               (~300 lines) - NATS client library

/centralcloud/
├── intelligence_hub_subscriber.ex (~100 lines) - Process intelligence data
└── nats/pattern_validator_subscriber.ex (~100 lines) - Validate patterns
```

---

## 3. Execution/Task Infrastructure (90 files, 13,114 lines)

### Core Components

**TaskGraph (Dependency Resolution)**
```
execution/task_graph/
├── orchestrator.ex              (200+ lines) - High-level enqueue API
├── worker_pool.ex               (250+ lines) - Spawn workers, poll for ready tasks
├── worker.ex                    (300+ lines) - Individual worker process
├── toolkit.ex                   (300+ lines) - Policy-enforced tool execution
├── policy.ex                    (150+ lines) - Role-based security policies
└── adapters/
    ├── shell.ex                 (200+ lines) - Shell command execution
    ├── docker.ex                (250+ lines) - Docker container execution
    ├── lua.ex                   (200+ lines) - Lua sandbox execution
    └── http.ex                  (150+ lines) - HTTP request execution
```

**Todos Storage & Interface**
```
execution/todos/
├── supervisor.ex                (100+ lines) - Supervision tree
├── todo_store.ex                (300+ lines) - PostgreSQL persistence
├── todo.ex                      (100+ lines) - Schema definition
├── todo_nats_interface.ex       (150+ lines) - NATS query interface
├── todo_swarm_coordinator.ex    (200+ lines) - Legacy coordinator
└── todo_worker_agent.ex         (200+ lines) - Worker process
```

**Planning & Execution**
```
execution/planning/
├── task_graph_core.ex           (300+ lines) - Dependency resolution logic
├── task_graph_executor.ex       (200+ lines) - Execute task DAGs
├── lua_strategy_executor.ex     (250+ lines) - Execute Lua strategies
├── safe_work_planner.ex         (300+ lines) - Plan work safely
├── task_execution_strategy.ex   (200+ lines) - Strategy definitions
├── story_decomposer.ex          (250+ lines) - Decompose stories
└── (8 more schema/support files)
```

### Standalone Execution Engines

**Execution Orchestrators** (multiple entry points)
```
execution/
├── execution_orchestrator.ex    (126 lines) - Unified orchestrator (auto-detect strategy)

execution/sparc/
├── orchestrator.ex              (400+ lines) - Template-based execution
└── (template system)

quality/
├── methodology_executor.ex      (200+ lines) - Execute SAFe methodology

tools/
├── database_tools_executor.ex   (150+ lines) - Execute DB tools

code/
├── startup_code_ingestion.ex    (200+ lines) - Load code at startup
```

---

## 4. Agent Infrastructure (7+ modules)

```
agents/
├── agent.ex                     (400+ lines) - Base GenServer for all agents
├── cost_optimized_agent.ex      (300+ lines) - Cost-aware LLM selection
├── self_improving_agent.ex      (250+ lines) - Self-optimizing agent
├── runtime_bootstrapper.ex      (200+ lines) - Bootstrap agents at startup
├── agent_supervisor.ex          (150+ lines) - Agent supervision
├── quality_enforcer.ex          (200+ lines) - Quality enforcement
├── metrics_feeder.ex            (150+ lines) - Feed metrics for learning
├── documentation_upgrader.ex    (200+ lines) - Upgrade docs
├── documentation_pipeline.ex    (250+ lines) - Doc pipeline
├── dead_code_monitor.ex         (150+ lines) - Monitor dead code
└── real_workload_feeder.ex      (150+ lines) - Feed real workloads
```

---

## 5. Execution Flow Diagrams

### Pattern 1: Oban Worker Execution

```
Application Code
     │
     ├─ JobOrchestrator.enqueue(:job_type, args)
     │
     ├─ JobType.get_job_module(:job_type) → {:ok, module}
     │
     ├─ module.new(args) → %Oban.Job{args: args}
     │
     ├─ Oban.insert(Repo, job)
     │
     └─ Oban Queue Storage (PostgreSQL)
          │
          │ [Oban Executor polls queue]
          │
          ├─ Fetch ready jobs (state: :available)
          │
          ├─ Module.perform(%Oban.Job{args: args})
          │
          ├─ Return: :ok | {:error, reason} | {:reschedule, datetime}
          │
          ├─ Update job state: :completed | :discarded | :available (retry)
          │
          └─ JobOrchestrator.learn_from_job(job_type, result) [optional]
```

### Pattern 2: NATS Message Handler Execution

```
Publisher
     │
     ├─ NatsClient.publish("subject", message, reply_to: "reply.topic")
     │
     └─ NATS Server
          │
          ├─ Route to subscribers on "subject"
          │
          └─ GenServer Handler
               │
               ├─ handle_info({:msg, %{subject, body, reply_to}}, state)
               │
               ├─ Task.async(fn → process_message(body) end)
               │
               ├─ NatsClient.publish(reply_to, response)
               │
               └─ {:noreply, state}
```

### Pattern 3: TodoStore Execution (Most Complex)

```
Application Code
     │
     ├─ TaskGraph.Orchestrator.enqueue(task)
     │
     ├─ TodoStore.create(%{
     │    id: "task-1",
     │    role: :coder,
     │    depends_on: ["task-0"],
     │    context: %{...}
     │  })
     │
     └─ PostgreSQL (todos table)
          │
          │ [TaskGraph.WorkerPool polls every 5 seconds]
          │
          ├─ Query: WHERE status = 'pending' AND all dependencies completed
          │
          ├─ For each ready task: spawn TaskGraph.Worker
          │
          └─ TaskGraph.Worker Process
               │
               ├─ Select adapter based on role:
               │  ├─ :coder → Shell adapter (write code, git)
               │  ├─ :tester → Docker adapter (run tests)
               │  ├─ :critic → Lua adapter (validate)
               │  └─ :admin → Shell or Docker (deployment)
               │
               ├─ Execute via Adapter
               │  └─ Shell.exec/2 | Docker.exec/2 | Lua.exec/2 | Http.exec/2
               │
               ├─ Capture result
               │
               ├─ TodoStore.update(id, %{
               │    status: :completed,
               │    result: %{stdout, stderr, exit},
               │    completed_at: now
               │  })
               │
               ├─ WorkerPool.worker_completed(worker_id, task_id, result)
               │
               └─ Next poll detects dependents → spawns for them
```

### Pattern 4: GenServer Agent Execution

```
Application Code
     │
     ├─ Agent.start_link(id: "agent_1", specialization: :coder)
     │
     ├─ GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
     │
     └─ Agent Process (registered in process registry)
          │
          ├─ Application calls: Agent.execute(agent_id, task)
          │
          ├─ GenServer.call(via_tuple(agent_id), {:execute, task})
          │
          ├─ handle_call({:execute, task}, from, state)
          │
          ├─ Execute task (synchronously blocks caller)
          │  ├─ LLM calls (via Singularity.LLM.Service via NATS)
          │  ├─ Code generation
          │  ├─ Analysis
          │  └─ Other work
          │
          ├─ {:reply, result, updated_state}
          │
          └─ Return to caller with result
```

---

## 6. Job Scheduling Configuration

### Current Configuration (config.exs pattern)

```elixir
config :singularity, :job_types,
  metrics_aggregation: %{
    module: Singularity.Jobs.MetricsAggregationWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    schedule: "*/5 * * * *",  # Every 5 minutes
    description: "Aggregate agent metrics"
  },
  pattern_miner: %{
    module: Singularity.Jobs.PatternMinerJob,
    enabled: true,
    queue: :pattern_mining,
    max_attempts: 3,
    priority: 2,
    schedule: "0 2 * * *",  # Daily at 2 AM
    description: "Mine code patterns"
  },
  # ... more job configurations
end
```

### Oban Cron Configuration

```elixir
config :oban, plugins: [
  {Oban.Plugins.Cron, crontab: [
    {"*/5 * * * *", Singularity.Jobs.MetricsAggregationWorker},
    {"0 */1 * * *", Singularity.Jobs.AgentEvolutionWorker},
    {"0 2 * * *", Singularity.Jobs.PatternMinerJob},
    # ... more scheduled jobs
  ]}
]
```

---

## 7. Abstraction Layer Gaps

### Gap 1: No Unified Task Interface

**Problem:**
- Oban: `perform(%Oban.Job{})` → `:ok | {:error, reason}`
- NATS: `handle_info(msg, state)` → `NatsClient.publish(reply_to, response)`
- TodoStore: Task stored in DB, checked via poll → result in DB
- Agent: Synchronous `GenServer.call()` → direct return

**Impact:** Cannot treat all task types uniformly. Learning system must handle 4 different patterns.

### Gap 2: No Unified Discovery

**Problem:**
- Oban: `JobOrchestrator.get_job_types_info()` ✓ (has config-driven discovery)
- NATS: Must manually check `NatsClient` subscribe calls
- TodoStore: No discovery (ad-hoc task creation)
- Agent: Must manually instantiate

**Impact:** Cannot enumerate all executable tasks in system. Hard to monitor.

### Gap 3: No Unified Learning/Observability

**Problem:**
- Oban: Optional `JobOrchestrator.learn_from_job/1` callback
- NATS: No learning integration
- TodoStore: No learning integration
- Agent: No learning integration

**Impact:** Only Oban jobs feed improvement loop. Other patterns invisible to learning system.

### Gap 4: No Unified Timeouts

**Problem:**
- Oban: No automatic timeout (relies on max_attempts)
- NATS: Manual timeout via `Task.yield(task, timeout)`
- TodoStore: Adapter-specific timeouts (Shell: 120s, Docker: 300s, Lua: 5s)
- Agent: No timeout

**Impact:** Inconsistent timeout behavior across task types.

---

## 8. Integration Consolidation Roadmap

### Phase 1: Create Unified Interface

```elixir
defprotocol Singularity.TaskExecutor do
  @doc "Execute a task and return result"
  def execute(task, opts)
  
  @doc "Get task status"
  def get_status(task_id)
  
  @doc "Get task result"
  def get_result(task_id)
  
  @doc "List active tasks"
  def list_tasks()
end
```

### Phase 2: Implement Adapters

```elixir
defmodule Singularity.TaskExecutor.ObanAdapter do
  # Wraps Oban execution
end

defmodule Singularity.TaskExecutor.NatsAdapter do
  # Wraps NATS message execution
end

defmodule Singularity.TaskExecutor.TodoStoreAdapter do
  # Wraps TodoStore execution
end

defmodule Singularity.TaskExecutor.AgentAdapter do
  # Wraps Agent execution
end
```

### Phase 3: Consolidate Job Modules

Reduce 15 individual job modules to:

```elixir
defmodule Singularity.Jobs.GenericWorker do
  use Oban.Worker, queue: :default, max_attempts: 2
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_type" => type}} = job) do
    JobRegistry.get_handler(type).execute(job.args)
  end
end
```

### Phase 4: Unified Configuration

```elixir
config :singularity, :task_registry, [
  # All task types discoverable in one place
  metrics_aggregation: {...},
  pattern_miner: {...},
  # etc.
]
```

---

## 9. Files Ready for Consolidation (Summary)

### High Priority (Scattered, Similar Code)

**Oban Jobs (15 files):**
- 10 periodic maintenance jobs (~70 lines each) → Template-driven
- 3 training jobs (~150-200 lines each) → Generic training runner
- 2 analysis jobs (~100 lines each) → Generic analyzer

**NATS Handlers (3 files):**
- Unify subscriber pattern
- Centralize message routing

### Medium Priority (Need Adapter Pattern)

**Execution Engines (5+ files):**
- `ExecutionOrchestrator` - Already tries to unify
- `SPARC.Orchestrator` - Template-based (keep separate)
- `TaskGraphExecutor` - Task DAG specific (keep separate)
- `MethodologyExecutor` - Methodology specific (keep separate)

### Low Priority (Already Unified)

**TodoStore (5 files):**
- Already has coherent adapter pattern
- WorkerPool + adapters is clean design

**Agents (7+ files):**
- Some unification in base `Agent` module
- Could consolidate some common patterns
