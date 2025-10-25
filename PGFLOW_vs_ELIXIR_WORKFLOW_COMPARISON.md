# pgflow vs Singularity Elixir Workflow System - Detailed Comparison

**Date:** 2025-10-25
**Source:** Examined pgflow @ `/tmp/pgflow` (main branch)
**Analyzed:** pgflow's DSL, edge-worker, core, example-flows

## Executive Summary

| Aspect | pgflow | Singularity |
|--------|--------|------------|
| **Language** | TypeScript (Node.js) | Elixir (BEAM) |
| **Execution** | Polling + external worker | Direct function calls + Oban jobs |
| **Network** | Requires PostgreSQL + pgmq queue | Local memory or Oban job store |
| **Latency** | 10-100ms (polling + pgmq) | <1ms (direct calls) |
| **State Management** | PostgreSQL tables (runs, steps, step_states, step_tasks) | Elixir maps + Oban job records |
| **Type Safety** | TypeScript generics (compile-time) | Elixir pattern matching (runtime) |
| **Deployment** | Separate edge-worker service | Same Elixir application |
| **Scalability** | Multi-worker via polling | Multi-process via BEAM |

## Architecture Comparison

### pgflow Architecture (TypeScript, Polling-Based)

```
Flow Definition (DSL)
    ↓
PostgreSQL Tables (pgflow schema)
    ├─ flows (metadata)
    ├─ steps (step definitions)
    ├─ deps (step dependencies)
    ├─ runs (execution instances)
    ├─ step_states (step execution state)
    ├─ step_tasks (individual task records)
    └─ pgmq queue (message queue)
    ↓
Multiple Edge Workers (TypeScript, polling every ~100ms)
    ├─ StepTaskPoller (Phase 1: read messages, Phase 2: start tasks)
    ├─ ExecutionController (manage concurrent execution)
    ├─ BatchProcessor (batch task processing)
    ├─ StepTaskExecutor (run handler functions)
    └─ PgflowSqlClient (database interface)
```

**Key Characteristic**:
- All state persisted to PostgreSQL
- Polling-based coordination (100ms intervals)
- Multiple independent TypeScript workers
- Designed for true horizontal distribution

### Singularity Single-BEAM Architecture (Development)

```
Workflow Definition (Elixir Module)
    ↓
WorkflowExecutor
    ├─ Step execution loop (sequential)
    ├─ State accumulation (map → map → map)
    ├─ Retry logic (exponential backoff in memory)
    ├─ Timeout protection (Task.async/Task.yield)
    ├─ Error handling & logging
    └─ Result return
    ↓
Oban Job (Single instance)
    ├─ Job enqueue with arguments
    ├─ Automatic retry via Oban
    └─ Cron scheduling support
```

**Key Characteristic**: Single BEAM instance. State in memory. Direct function calls. Ideal for development.

### Singularity Multi-BEAM Architecture (Production)

```
┌─ Singularity Instance A ──┐  ┌─ Singularity Instance B ──┐  ┌─ Singularity Instance C ──┐
│ WorkflowExecutor          │  │ WorkflowExecutor          │  │ WorkflowExecutor          │
│ Oban Job Processor        │  │ Oban Job Processor        │  │ Oban Job Processor        │
│ (maxConcurrent: 10)       │  │ (maxConcurrent: 10)       │  │ (maxConcurrent: 10)       │
│ Instance.Registry         │  │ Instance.Registry         │  │ Instance.Registry         │
│ ResultAggregator          │  │ ResultAggregator          │  │ ResultAggregator          │
│ LearningSyncWorker        │  │ LearningSyncWorker        │  │ LearningSyncWorker        │
└────────┬─────────────────┘  └────────┬─────────────────┘  └────────┬─────────────────┘
         │                             │                             │
         │      All connect to same PostgreSQL Database              │
         └──────────────────┬──────────────────┬────────────────────┘
                            │                  │
                ┌───────────▼──────────────────▼───────────┐
                │   PostgreSQL (Coordination Hub)          │
                │                                          │
                │ ├─ oban_jobs (work distribution)       │
                │ ├─ oban_peers (instance registry)      │
                │ ├─ job_results (result tracking)       │
                │ ├─ pgmq:*.{results,learning} (sync)    │
                │ └─ instance_registry (health tracking)  │
                └───────────┬──────────────────────────────┘
                            │
                    ┌───────▼──────────┐
                    │  CentralCloud    │
                    │  (Learning Hub)  │
                    │                  │
                    │ Aggregates &     │
                    │ distributes      │
                    │ learnings        │
                    └──────────────────┘
```

**Key Characteristics**:
- Multiple BEAM instances for parallelism
- Coordinated via shared PostgreSQL (like pgflow!)
- Direct function calls within each instance (<1ms)
- Oban handles all job distribution (no custom polling needed)
- Learnings sync via pgmq UP/DOWN channels
- Fault-tolerant: instance crash reassigns jobs automatically

---

## Detailed Feature Comparison

### 1. Flow Definition

#### pgflow DSL

```typescript
// pgflow: Fluent chainable API
export const MyFlow = new Flow<{ value: number }>({
  slug: 'my_flow',
  maxAttempts: 3,
  baseDelay: 1000,
  timeout: 30000,
})
  .step(
    { slug: 'step1', maxAttempts: 3 },
    async (input, context) => ({
      result: input.run.value * 2,
    })
  )
  .step(
    { slug: 'step2', dependsOn: ['step1'], timeout: 5000 },
    async (input) => ({
      final: input.step1.result + 10,
    })
  );
```

**Characteristics:**
- Fluent builder pattern (each `.step()` returns new Flow instance)
- Type-safe step inputs/outputs via TypeScript generics
- Dependencies declared explicitly via `dependsOn`
- Per-step and per-flow configuration
- Handler receives `(input, context)` tuple
- Input includes `run` (flow input) + declared dependencies only

#### Singularity Elixir Workflow

```elixir
# Singularity: Direct function definitions
defmodule MyWorkflow do
  use Singularity.Workflow

  def __workflow_steps__ do
    [
      {:step1, &__MODULE__.step1/1},
      {:step2, &__MODULE__.step2/1}
    ]
  end

  def step1(input) do
    {:ok, Map.merge(input, %{result: input["value"] * 2})}
  end

  def step2(prev) do
    {:ok, Map.merge(prev, %{final: prev["result"] + 10})}
  end
end
```

**Characteristics:**
- Direct function definitions (simpler, less magical)
- Sequential step ordering via list (implicit dependencies)
- Each step receives all previous state (no dependency filtering)
- Returns `{:ok, state}` or `{:error, reason}` tuple
- State is accumulated map (grows as it flows)

**Trade-off Analysis:**
- ✅ pgflow: Type-safe dependencies, compile-time validation
- ✅ Singularity: Simpler syntax, direct function calls, less boilerplate
- pgflow requires understanding TypeScript generics and type inference
- Singularity trade-off: less type safety for more simplicity

### 2. Execution Model

#### pgflow Execution (Polling-Based)

```
Worker Start
    ↓
StepTaskPoller.poll() [every ~100ms]
    ↓
Phase 1: readMessages (from pgmq:queue_name)
    ├─ Query: pgflow.start_messages(queue_name, batch_size, visibility_timeout)
    ├─ Visibility timeout: message hidden for N seconds
    ├─ Returns: MessageRecord[] with msg_id, message, enqueued_at, etc.
    ↓
Phase 2: startTasks (call pgflow.start_tasks)
    ├─ Creates StepTaskRecord for each message
    ├─ Transitions step_state from 'ready' → 'running'
    ├─ Returns: StepTaskRecord[]
    ↓
ExecutionController (manage concurrent execution)
    ├─ Process up to maxConcurrent (default: 10) tasks
    ├─ For each task:
    │   ├─ StepTaskExecutor.execute()
    │   ├─ Calls step handler: handler(input, context)
    │   ├─ Catches exceptions
    │   ├─ Marks complete: completeTask(task, output)
    │   └─ OR marks failed: failTask(task, error)
    ↓
Worker Loop Continues
```

**State Flow:**
```
pgflow.runs
├─ run_id (UUID)
├─ flow_slug
├─ input (JSONB)
└─ created_at

pgflow.step_states
├─ step_slug
├─ run_id
├─ state ('ready' | 'running' | 'completed' | 'failed')
├─ output (JSONB, result of step)
└─ error (JSONB, error details)

pgflow.step_tasks
├─ run_id
├─ step_slug
├─ task_index (for map steps)
├─ input (JSONB, full resolved input)
├─ msg_id (reference to pgmq message)
└─ started_at, completed_at, ...
```

**Timing:**
- Poll interval: ~100ms (configurable)
- Visibility timeout: 2-3 seconds (message invisible while being processed)
- If task takes >visibility_timeout, message visible again (duplicate processing risk)

#### Singularity Execution (Direct Calls)

```
Oban Job.perform(job)
    ↓
WorkflowExecutor.execute(workflow_module, input, opts)
    ├─ Start: workflow_id = Ecto.UUID.generate()
    ├─ Get steps: workflow_module.__workflow_steps__() → [{:step1, &step1/1}, ...]
    ├─ Initialize: attempt = 1, state = input
    │
    └─ Retry Loop (up to max_attempts):
        ├─ For each step in order:
        │   ├─ Wrap handler in Task.async (for timeout protection)
        │   ├─ Call: handler(prev_state) → {:ok, new_state} or {:error, reason}
        │   ├─ Log step completion
        │   └─ State = new_state (accumulate)
        ├─
        ├─ If any step errors:
        │   ├─ Log error with step context
        │   ├─ Calculate retry delay: 10^attempt * 1000ms
        │   │  (1s, 10s, 100s, 1000s for attempts 1-4)
        │   ├─ Sleep delay
        │   ├─ Increment attempt
        │   └─ Loop again
        ├─
        └─ If all steps succeed:
            └─ Return {:ok, final_state}

Return to Oban
    ├─ If success: mark job complete, log result
    └─ If failure: Oban auto-retry via its own backoff (exponential)
```

**State Management:**
- Input map: `%{"request_id" => "...", "task_type" => "architect", ...}`
- State flows through as map:
  ```elixir
  %{
    "request_id" => "...",
    "task_type" => "architect",
    "messages" => [...],
    "received_at" => DateTime,          # Added by step 1
    "selected_model" => "claude-opus",   # Added by step 2
    "response" => "...",                 # Added by step 3
    "tokens_used" => 1250,               # Added by step 3
    "cost_cents" => 50,                  # Added by step 3
  }
  ```

**Timing:**
- Retry backoff: 10^attempt * 1000ms (1s, 10s, 100s, 1000s)
- Timeout per step: 30000ms (configurable)
- No polling overhead: direct function call latency

**Summary:**
- pgflow: Polling-based, database-persisted state, suitable for distributed workers
- Singularity: Direct-call based, in-memory state, suitable for single BEAM instance

### 3. Type Safety

#### pgflow Type System

```typescript
// Generic type parameters track state across steps
export class Flow<
  TFlowInput extends AnyInput,           // Input type
  TContext extends Record<string, unknown>, // Custom context
  Steps extends AnySteps,                // Step outputs (growing map)
  StepDependencies extends AnyDeps,      // Step dependencies
  TEnv extends Env                       // Environment type
>

// Utility types
ExtractFlowInput<TFlow>                 // Flow's input type
ExtractFlowSteps<TFlow>                 // All step outputs
ExtractFlowDeps<TFlow>                  // All step dependencies
StepInput<TFlow, 'step2'>               // Input type for specific step
StepOutput<TFlow, 'step2'>              // Output type for specific step

// Step input includes ONLY declared dependencies:
StepInput<MyFlow, 'step2'> = {
  run: FlowInput,
  step1: StepOutput<'step1'>
  // NOT step0, step1_alt, etc. - only declared in dependsOn
}

// Type inference happens at compile time
const flow = new Flow(...)
  .step({ slug: 'step1' }, (input) => {
    // input type: { run: { value: number } }
    return { result: number };
  })
  .step({ slug: 'step2', dependsOn: ['step1'] }, (input) => {
    // input type: { run: { value: number }, step1: { result: number } }
    // step2 can ONLY access 'run' and 'step1'
    return { final: number };
  });
```

**Benefits:**
- ✅ Compile-time error if you reference undefined step in dependsOn
- ✅ Compile-time error if you access step not in dependsOn
- ✅ IDE autocomplete for available steps
- ✅ Full type inference through entire flow

**Drawbacks:**
- Complex generic syntax
- Requires understanding TypeScript type inference
- Harder to debug type errors

#### Singularity Type System

```elixir
# Pattern matching provides runtime type safety
def select_model(prev) do
  complexity = get_complexity_for_task(prev.task_type)
  {model, provider} = select_best_model(complexity)

  {:ok, Map.merge(prev, %{
    selected_model: model,
    selected_provider: provider,
    complexity: complexity
  })}
end

# Dialyzer provides static type checking (optional)
@spec select_model(map()) :: {:ok, map()} | {:error, atom()}

# Runtime validation
case validate_query_format(query) do
  :ok -> {:ok, prev}
  {:error, reason} -> {:error, {:invalid_query, reason}}
end
```

**Benefits:**
- ✅ Pattern matching catches type errors at runtime
- ✅ Dialyzer for optional static analysis
- ✅ Simple, readable syntax
- ✅ Easy to understand and debug

**Drawbacks:**
- ❌ Type errors caught at runtime, not compile-time
- ❌ No compile-time dependency validation
- ❌ No IDE autocomplete for step outputs

**Comparison:**
- pgflow: Static types at cost of complexity
- Singularity: Runtime types for simplicity and readability

### 4. Dependency Handling

#### pgflow: Explicit Dependencies

```typescript
const flow = new Flow<{ items: number[] }>({ slug: 'example' })
  .step({ slug: 'process' }, (input) => {
    // input.run = { items: number[] }
    return { results: input.run.items.map(x => x * 2) };
  })
  .step({ slug: 'filter' }, (input) => {
    // input.run = { items: number[] }
    // input.process = { results: number[] }
    return { filtered: input.process.results.filter(x => x > 5) };
  })
  .step({ slug: 'summarize', dependsOn: ['filter'] }, (input) => {
    // input.run = { items: number[] }
    // input.filter = { filtered: number[] }
    // NOT input.process - not declared in dependsOn!
    return { summary: input.filter.filtered.length };
  });
```

**Advantages:**
- ✅ Explicit dependency graph
- ✅ Database stores DAG (directed acyclic graph)
- ✅ Can enable parallel execution of independent steps
- ✅ Clear what each step actually needs
- ✅ Reduces payload size (each step only gets what it needs)

**Use Case**: Distributed systems where you want to:
- Execute steps in parallel on different workers
- Skip steps if dependencies haven't completed
- Re-run specific steps without re-running dependencies

#### Singularity: Sequential with Full State

```elixir
def __workflow_steps__ do
  [
    {:receive_request, &__MODULE__.receive_request/1},
    {:select_model, &__MODULE__.select_model/1},
    {:call_llm_provider, &__MODULE__.call_llm_provider/1},
    {:publish_result, &__MODULE__.publish_result/1}
  ]
end

# receive_request receives input
# select_model receives: input + receive_request output
# call_llm_provider receives: input + all previous outputs
# publish_result receives: input + all previous outputs
```

**Advantages:**
- ✅ Simpler to understand (sequential)
- ✅ All context available (no passing through state)
- ✅ Easier to debug (all state visible)
- ✅ Faster for single-instance (no dependency resolution overhead)

**Limitations:**
- ❌ Cannot parallelize steps (sequential only)
- ❌ All steps must see all state (memory overhead for large states)
- ❌ Cannot skip steps based on conditions

**Trade-off**: Simplicity vs parallelization capability

### 5. Error Handling & Retry Strategy

#### pgflow Retry Strategy

```typescript
// Flow-level defaults
new Flow({ slug: 'my_flow', maxAttempts: 3, baseDelay: 1000, timeout: 30000 })

// Step-level overrides
.step({
  slug: 'critical_step',
  maxAttempts: 5,      // Retry this step 5 times
  baseDelay: 2000,     // Wait 2 seconds between retries
  timeout: 60000,      // 60 second timeout for this step
  startDelay: 5000     // Wait 5 seconds before starting
}, handler)

// Retry logic: (attempt, baseDelay) => delay
// Unclear from code, likely linear or exponential
```

**State on Failure:**
- Task marked as failed in `pgflow.step_tasks`
- `step_states` updated with `state='failed'` and `error` field
- Message stays in pgmq queue (visibility timeout expires)
- Next worker polling picks up the same message
- Full retry happens from beginning of flow (or just that step?)

#### Singularity Retry Strategy

```elixir
def execute(workflow_module, input, opts \\ []) do
  max_attempts = Keyword.get(opts, :max_attempts, 3)
  timeout = Keyword.get(opts, :timeout, 30000)

  # Retry loop with exponential backoff
  attempt = 1
  state = input

  loop do
    try do
      # Execute all steps sequentially
      final_state = execute_steps(workflow_module, state)
      {:ok, final_state}
    catch error ->
      if attempt < max_attempts do
        delay_ms = 10^attempt * 1000  # 1s, 10s, 100s, 1000s
        :timer.sleep(delay_ms)
        attempt += 1
        retry_loop
      else
        {:error, reason}
      end
    end
  end
end

# Example: 3 attempts with backoff
# Attempt 1: immediate
# Attempt 2: after 10 seconds
# Attempt 3: after 100 seconds
# Total possible delay: 110 seconds
```

**State on Failure:**
- If step fails: entire workflow retries from step 1
- All previous work lost (re-executed)
- Exponential backoff prevents thundering herd

**Advantage**: Simple and transparent
**Disadvantage**: Redundant re-execution of successful steps

**pgflow Advantage**: Step-level granularity (can retry just failed step?)
**Singularity Advantage**: Exponential backoff reduces load under pressure

### 6. Concurrent Execution

#### pgflow: Concurrent Execution Built-In

```typescript
// Multiple workers polling same queue
// ExecutionController manages up to maxConcurrent tasks

const config = {
  maxConcurrent: 10,           // Process up to 10 tasks in parallel
  batchSize: 10,               // Fetch 10 messages per poll
  maxPollSeconds: 2,           // Poll for up to 2 seconds per batch
  pollIntervalMs: 100,         // Poll every 100ms
  visibilityTimeout: 2,        // Hide message for 2 seconds while processing
}

// Execution:
// Worker 1: Polls → Gets task 1-5 → Process in parallel
// Worker 2: Polls → Gets task 6-10 → Process in parallel
// Worker 3: Polls → Gets task 1-5 again if Worker 1 crashes
```

**Architecture:**
- Multiple independent workers (can run on different servers)
- All coordinate via PostgreSQL
- No direct communication between workers
- Failure of one worker doesn't affect others

#### Singularity: Sequential within Job, Parallel via Oban

```elixir
# Single workflow execution is sequential
def execute(workflow_module, input, opts) do
  # Step 1, Step 2, Step 3 run one after another
  # Cannot parallelize within single workflow
end

# But multiple workflows can run in parallel via Oban queues
Oban.insert(LlmRequestWorker.new(%{"request_id" => "a"}))
Oban.insert(LlmRequestWorker.new(%{"request_id" => "b"}))
Oban.insert(LlmRequestWorker.new(%{"request_id" => "c"}))

# Oban processes multiple jobs concurrently:
# Job 1: execute(LlmRequest, input_a)
# Job 2: execute(LlmRequest, input_b)
# Job 3: execute(LlmRequest, input_c)
```

**Architecture:**
- Single BEAM instance (all on same server)
- Oban scheduler manages job queues
- BEAM processes jobs concurrently (lightweight threads)
- No need for external coordination

**Comparison:**
- pgflow: Distributed parallelism (multiple servers)
- Singularity: Local parallelism (single BEAM, multiple queues)

### 7. Deployment Model

#### pgflow Deployment

```
PostgreSQL Database (shared state store)
    ├─ pgflow schema (tables)
    └─ pgmq queue (messages)

Edge Worker Service (TypeScript/Node.js)
    ├─ Process A (listening to queue)
    ├─ Process B (listening to queue)
    └─ Process C (listening to queue)

All workers coordinate via PostgreSQL
Multiple workers can run on different servers
Database is single point of coordination (and potential bottleneck)
```

**Advantages:**
- ✅ Horizontally scalable (add more workers)
- ✅ Each worker is stateless
- ✅ Fault-tolerant (worker crash doesn't lose state)
- ✅ Can run across multiple machines/datacenters

**Disadvantages:**
- ❌ Requires separate TypeScript service
- ❌ Database is bottleneck for high-throughput
- ❌ Network latency (10-50ms per round trip)
- ❌ Complexity of coordinating multiple services

#### Singularity Deployment

```
Single Elixir Application
    ├─ Oban Scheduler
    ├─ Job Queues
    │   ├─ :default
    │   ├─ :metrics
    │   ├─ :training
    │   └─ :pattern_mining
    ├─ WorkflowExecutor
    └─ Integration Services
        ├─ LLM.Service
        ├─ Embedding.NxService
        └─ Agent code
```

**Advantages:**
- ✅ Single service (easier to deploy)
- ✅ Direct function calls (no network overhead)
- ✅ Full access to Elixir codebase
- ✅ Sub-millisecond latency
- ✅ Integrated logging and observability

**Disadvantages:**
- ❌ Limited to single server (not horizontally scalable)
- ❌ All state in BEAM memory
- ❌ Server crash loses in-flight jobs (unless persisted)
- ❌ Not suitable for extreme load (single machine limits)

**Mitigation**: Oban provides job persistence in PostgreSQL, can recover on restart

---

## Feature Matrix

| Feature | pgflow | Singularity (Single BEAM) | Singularity (Multi-BEAM) |
|---------|--------|-----------|-----------|
| **Flow Definition** | Fluent DSL (TypeScript) | Direct functions (Elixir) | Direct functions (Elixir) |
| **Type Safety** | Compile-time (TypeScript generics) | Runtime (pattern matching) | Runtime (pattern matching) |
| **Dependencies** | Explicit (DAG) | Implicit (sequential) | Implicit (sequential) |
| **Execution** | Polling-based (100ms) | Direct function calls | Direct function calls |
| **State Storage** | PostgreSQL tables | In-memory | In-memory + PostgreSQL |
| **Coordination** | pgmq queue + polling | Oban (single) | Oban + PostgreSQL |
| **Concurrency** | Multi-worker (distributed) | BEAM processes (local) | BEAM processes (multi-instance) |
| **Instance Discovery** | — | Static | Dynamic (Instance.Registry) |
| **Fault Tolerance** | Yes (stale timeout) | No (single instance) | Yes (automatic reassignment) |
| **Retry Strategy** | Per-step configurable | Exponential backoff (all steps) | Exponential backoff (all steps) |
| **Timeout Protection** | Yes | Yes (Task.async) | Yes (Task.async) |
| **Error Handling** | Database error column | {:error, reason} return | {:error, reason} return |
| **Deployment** | Separate TypeScript service | Same Elixir app | Same Elixir app (N instances) |
| **Latency** | 10-100ms (polling) | <1ms (direct calls) | <1ms (direct calls) |
| **Scalability** | Horizontal (TypeScript workers) | Vertical (single BEAM) | Horizontal (BEAM instances) |
| **Learning Aggregation** | Not built-in | Not needed (single) | Via CentralCloud (UP/DOWN) |
| **Complexity** | High (coordination, schema) | Low (single service) | Medium (distributed + sync) |

---

## When to Use Which

### Use pgflow When:
- ✅ Multiple services need to coordinate
- ✅ Geographically distributed workers
- ✅ Extreme scale (100s of workers)
- ✅ Strong need for granular per-step retry
- ✅ Each step might take very long
- ✅ Want true distributed execution

### Use Singularity Elixir Workflow When:
- ✅ Single BEAM instance is sufficient
- ✅ Need <1ms latency
- ✅ Workflows are sequential with few steps
- ✅ Want tight integration with Elixir code
- ✅ Prefer simplicity over distributed complexity
- ✅ Multi-instance via CentralCloud syncing

---

## Key Insights & Recommendations

### 1. **Sequential vs DAG**
- **pgflow**: True DAG enables parallelization
- **Singularity**: Sequential is simpler, good enough for most workflows
- **Recommendation**: Sequential is right for Singularity's use case (agent workflows, LLM requests)

### 2. **Type Safety Trade-off**
- **pgflow**: Compile-time checking at cost of complexity
- **Singularity**: Runtime checking for readability
- **Recommendation**: Singularity's approach fits Elixir philosophy (pragmatism over purity)

### 3. **Retry Strategy**
- **pgflow**: Unclear from code, likely linear per-step
- **Singularity**: Exponential backoff (10^attempt * 1000ms) prevents overload
- **Recommendation**: Singularity's exponential backoff is more robust

### 4. **Polling vs Direct Calls**
- **pgflow**: 100ms polling interval = min ~100ms latency
- **Singularity**: Direct calls = <1ms latency
- **Recommendation**: For local workflows, direct calls are superior

### 5. **Deployment Simplicity**
- **pgflow**: Requires separate TypeScript service + DB + workers
- **Singularity**: Single Elixir service
- **Recommendation**: Singularity's approach reduces operational complexity

---

## Migration Path (if needed)

If Singularity ever needs pgflow-like capabilities:

1. **Parallel execution**: Add `parallel_steps` list to workflow, execute via `Task.async_stream`
2. **Distributed**: Add pgmq polling layer in Elixir, replicate pgflow's two-phase approach
3. **Explicit dependencies**: Extend DSL to accept `depends_on` like pgflow
4. **Step-level retry**: Add per-step options to step tuples

But for current needs, Elixir workflow system is superior.

---

## Code Quality Observations

### pgflow Strengths:
- ✅ Sophisticated type system
- ✅ Well-organized package structure
- ✅ Comprehensive error handling
- ✅ Two-phase polling (reduces race conditions)
- ✅ Extensive test coverage

### Singularity Strengths:
- ✅ Simpler, more readable
- ✅ No DSL complexity
- ✅ Direct integration with Elixir ecosystem
- ✅ Exponential backoff built-in
- ✅ Smaller, more understandable code

### Architecture Lesson
pgflow's "two-phase polling" (readMessages → startTasks) is clever:
- **Phase 1**: Fetch messages from queue without locking
- **Phase 2**: Start tasks for messages, acquire locks
- **Benefit**: Reduces race conditions of single-phase polling

Singularity doesn't need this because execution is immediate (no workers competing for same message).

---

## Conclusion

**Singularity's Elixir workflow system is superior** for all deployment scenarios:

### Single-BEAM Development (Simple)
1. **Simplicity**: No separate service, no complex polling coordination
2. **Performance**: Sub-millisecond latency vs 10-100ms with polling
3. **Integration**: Direct access to all Elixir code (LLM.Service, embeddings, agents)
4. **Type Safety**: Pattern matching + Dialyzer sufficient for safety without complexity
5. **Reliability**: Exponential backoff + Oban persistence provides durability

### Multi-BEAM Production (Distributed)
1. **Scalability**: Add N instances, all coordinate via PostgreSQL (like pgflow!)
2. **Performance**: <1ms latency per workflow (vs pgflow's 10-100ms polling)
3. **Intelligence**: CentralCloud aggregates learnings across instances
4. **Fault Tolerance**: Instance crash → jobs automatically reassigned
5. **Simpler Coordination**: Oban handles all distribution (no custom polling layer)
6. **Same Language**: All instances in Elixir (vs pgflow requiring TypeScript service)

### Comparison to pgflow

| Aspect | pgflow | Singularity Multi-BEAM |
|--------|--------|----------------------|
| **Horizontal scaling** | ✅ Yes | ✅ Yes |
| **Polling overhead** | ❌ 100ms min latency | ✅ <1ms per execution |
| **Custom polling code** | ✅ Needs implementation | ✅ Built-in (Oban) |
| **Language diversity** | TypeScript edge-workers | All Elixir |
| **Distributed coordination** | pgmq + polling | PostgreSQL + Oban |
| **Learning aggregation** | ❌ Not included | ✅ Via CentralCloud |
| **Code complexity** | High (DAG + coordination) | Medium (distributed setup) |
| **Development simplicity** | Low (separate service) | High (same app) |

### Architecture Evolution

```
Phase 1 (Current):
  Single Singularity instance
  → Perfect for development
  → All jobs on one BEAM
  → Sub-millisecond latency

Phase 2 (Production):
  Multiple Singularity instances (A, B, C)
  → Load balanced via Oban (PostgreSQL)
  → All share same database
  → CentralCloud aggregates learnings
  → Fault-tolerant (job reassignment on crash)

Phase 3 (Extreme Scale, if needed):
  If single PostgreSQL becomes bottleneck:
  → Add read replicas
  → Use pgflow's DAG system for true parallelism
  → But for typical use: Multi-BEAM is sufficient
```

**Recommendation**: Keep current Elixir workflow system. It scales from:
- ✅ **Single instance** (development)
- → **Multiple instances** (production)
- → **With CentralCloud** (distributed learning)

No need for pgflow. Oban + PostgreSQL + BEAM provides everything pgflow does, with better latency and single-language simplicity.

