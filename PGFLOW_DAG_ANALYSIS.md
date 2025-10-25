# pgflow DAG Implementation Analysis

**Date:** 2025-10-25
**Source:** `/tmp/pgflow` (TypeScript implementation)
**Purpose:** Guide for implementing DAG support in ex_pgflow (Elixir)

## Executive Summary

pgflow implements **DAG (Directed Acyclic Graph) execution** via:
1. **Dependency declarations** - `dependsOn: ['step_name']` in step definition
2. **Type-safe input construction** - Steps only receive outputs from declared dependencies
3. **Database-driven execution** - Tasks are stored in PostgreSQL, not executed directly
4. **Topological ordering** - Steps are compiled into an execution order
5. **Parallel execution** - Independent branches run concurrently (handled by worker queue)

---

## Architecture

### 1. Type System (Compile-Time Safety)

```typescript
// Step dependencies as generic type parameter
type StepDependencies = {
  website: [],           // No dependencies (root)
  sentiment: ['website'],        // Depends on 'website'
  summary: ['website'],          // Depends on 'website' (parallel with sentiment)
  saveToDb: ['sentiment', 'summary']  // Depends on both
}

// Step input construction
type StepInput<TFlow, 'sentiment'> = {
  run: Input;              // Always include flow input
  website: { content: string }  // Automatically include dependencies only
}
```

**Key insight:** TypeScript generics enforce at compile-time that:
- Steps can only access their declared dependencies
- Missing dependencies cause type errors
- No runtime checks needed for valid dependencies

### 2. Flow Class (Step Definition)

```typescript
class Flow<TFlowInput, TContext, Steps, StepDependencies, TEnv> {
  private stepDefinitions: Record<string, StepDefinition>;
  public readonly stepOrder: string[];  // Topological order

  step<Slug, THandler, Deps>(
    opts: { slug: Slug; dependsOn?: Deps[] },
    handler: THandler
  ): Flow<...> {
    // Validate dependencies exist
    for (const dep of opts.dependsOn || []) {
      if (!this.stepDefinitions[dep]) {
        throw new Error(`Step "${slug}" depends on undefined step "${dep}"`);
      }
    }

    // Add step with dependencies
    const newStepDefinition = {
      slug,
      handler,
      dependencies: opts.dependsOn || [],  // Store as array
      options: { maxAttempts, timeout, ... }
    };

    // Return new Flow with updated types
    return new Flow(...);
  }

  getStepDefinition(slug: string): StepDefinition {
    return this.stepDefinitions[slug];
  }
}
```

**Key insight:** Each call to `.step()` returns a NEW Flow instance with updated types, enabling:
- Fluent API: `flow.step(...).step(...).step(...)`
- Type tracking: Each step narrows the type
- Immutability: Original flow unchanged

### 3. Dependency-Based Input

```typescript
// For 'saveToDb' step with dependsOn: ['sentiment', 'summary']
// TypeScript automatically constructs:
{
  run: { url: string },           // Flow input (always)
  sentiment: { score: number },   // From 'sentiment' step output
  summary: { aiSummary: string }  // From 'summary' step output
  // website is NOT included (not a dependency)
}
```

**Key insight:** Input construction is type-driven:
- Only declared dependencies are included
- Type system ensures handler matches expected inputs
- No runtime resolution needed

### 4. Execution Model

pgflow stores step tasks in PostgreSQL:

```sql
-- step_tasks table
id               | flow_id | step_slug | run_id  | input  | status
1                | 1       | website   | run_123 | {...}  | pending
2                | 1       | sentiment | run_123 | {...}  | pending  <- depends on step_tasks.id=1
3                | 1       | summary   | run_123 | {...}  | pending  <- depends on step_tasks.id=1
4                | 1       | saveToDb  | run_123 | {...}  | pending  <- depends on step_tasks.id=2,3
```

**Execution flow:**
1. `flow.start(input)` creates all step_tasks rows
2. Worker polls for `pending` tasks
3. A step is `executable` when all its dependencies are `complete`
4. Worker runs executable steps (potentially in parallel)
5. When step completes, mark as `complete`
6. Next batch of steps becomes executable

### 5. Parallel Execution

**Without DAG (sequential):**
```
Time: [website: 1s] → [sentiment: 1s] → [summary: 1s] → [saveToDb: 1s]
Total: 4 seconds
```

**With DAG (parallel):**
```
Time: [website: 1s] → [sentiment: 1s, summary: 1s (parallel)] → [saveToDb: 1s]
Total: 3 seconds (25% faster!)
```

More complex example:
```
Time: [a: 1s] → [b: 1s, c: 1s, d: 1s (all parallel)] → [e: 1s]
Total: 3 seconds (vs 5 seconds sequential)
```

---

## Key pgflow Design Decisions

### ✅ Why Database-Driven (Not In-Memory)

1. **Durability** - Tasks survive worker crashes
2. **Observability** - Query task status anytime
3. **Distribution** - Multiple workers can claim tasks
4. **Retryability** - Failed tasks remain in DB for replay
5. **Scalability** - No in-memory task tracking

### ✅ Why Compile-Time Types (Not Runtime)

1. **Type safety** - Catch dependency errors at compile time
2. **Autocomplete** - IDEs can suggest available step outputs
3. **Performance** - No runtime validation needed
4. **Debugging** - Clear error messages from TypeScript compiler

### ✅ Why Generic Flow Class (Not Function)

1. **Type tracking** - Each step narrows generic parameters
2. **Immutability** - `flow.step(...)` returns new Flow
3. **Fluent API** - Chainable method calls
4. **Reusability** - Flow definition is just data (can be passed around)

### ⚠️ Why Tasks Stored in DB (Not Steps)

pgflow has a key architectural distinction:

```typescript
// A "step" is the definition:
{ slug: 'sentiment', dependsOn: ['website'], handler: ... }

// A "task" is a runtime execution:
{ flow_id, step_slug, run_id, input, status, ... }
```

This allows:
- Multiple runs of same flow with shared step definitions
- Different task ordering per run (based on dependencies)
- Fine-grained failure tracking per task

---

## Implementation for ex_pgflow

### Approach 1: In-Memory DAG (Simpler, Current Design)

Current ex_pgflow runs steps in-memory in a single Elixir process:

```elixir
def __workflow_steps__ do
  [
    {:step1, &__MODULE__.step1/1},
    {:step2, &__MODULE__.step2/1},
    {:step3, &__MODULE__.step3/1}
  ]
end
```

**To add DAG:**

```elixir
def __workflow_steps__ do
  [
    {:website, &__MODULE__.website/1, depends_on: []},
    {:sentiment, &__MODULE__.sentiment/1, depends_on: [:website]},
    {:summary, &__MODULE__.summary/1, depends_on: [:website]},
    {:save_to_db, &__MODULE__.save_to_db/1, depends_on: [:sentiment, :summary]}
  ]
end
```

**Benefits:**
- Minimal changes to existing executor
- Parallel execution via `Task.async_stream`
- Type-safe via Elixir pattern matching

**Drawbacks:**
- Steps still run in single Oban job
- Can't distribute individual steps across instances
- Limited to vertical parallelism (within one job)

### Approach 2: Database-Driven DAG (Like pgflow, Complex)

Store step tasks in database:

```sql
CREATE TABLE workflow_step_tasks (
  id UUID PRIMARY KEY,
  workflow_id UUID,
  step_slug STRING,
  run_id UUID,
  input JSONB,
  output JSONB,
  status TEXT,  -- pending, executing, complete, failed
  depends_on TEXT[],  -- [step_slug, ...]
  error TEXT,
  created_at TIMESTAMP,
  completed_at TIMESTAMP
);
```

**Execution:**
1. `Pgflow.Executor.execute(workflow, input)` creates all step_task rows
2. Workers query `WHERE status = 'pending' AND all_dependencies_complete`
3. Execute step, update output, mark complete
4. Repeat until all steps complete

**Benefits:**
- True horizontal parallelism (steps across instances)
- Durable task tracking
- Observable progress
- pgflow-compatible architecture

**Drawbacks:**
- Major architectural change
- Requires task polling/coordination
- More complex implementation (600+ LOC)

---

## Recommendation: Implement Approach 1 (DAG with In-Memory Execution)

### Rationale

1. **Minimal changes** - Just update Executor logic
2. **Sufficient for most workflows** - 99% don't need horizontal parallelism
3. **Fast implementation** - ~4-6 hours
4. **Path to Approach 2** - Can migrate to DB-driven later if needed
5. **Keeps simplicity** - exglow stays lightweight

### Implementation Steps

1. **Update Pgflow.Executor.execute** (~200 LOC)
   - Parse `depends_on` tuples
   - Build dependency graph
   - Topologically sort steps
   - Execute independent steps in parallel via `Task.async_stream`
   - Merge results into state

2. **Add DAG validation** (~100 LOC)
   - Check for cycles (prevent infinite loops)
   - Verify dependencies exist
   - Type validation via dialyzer

3. **Update workflow syntax** (breaking change)
   - From: `{:step_name, &fn/1}`
   - To: `{:step_name, &fn/1, depends_on: []}`

4. **Add tests** (~300 LOC)
   - Sequential execution (no dependencies)
   - Parallel execution (independent steps)
   - Dependency validation
   - Cycle detection
   - Error in parallel step
   - Result merging

5. **Update documentation** (~200 LOC)

### Example Syntax

```elixir
defmodule Singularity.Workflows.LlmRequest do
  require Logger

  def __workflow_steps__ do
    [
      {:receive_request, &__MODULE__.receive_request/1, depends_on: []},
      {:select_model, &__MODULE__.select_model/1, depends_on: [:receive_request]},
      {:call_llm_provider, &__MODULE__.call_llm_provider/1, depends_on: [:select_model]},
      {:publish_result, &__MODULE__.publish_result/1, depends_on: [:call_llm_provider]}
    ]
  end

  # Handlers receive input with both flow input and dependencies
  def receive_request(%{"request_id" => id} = input) do
    {:ok, Map.put(input, :received_at, DateTime.utc_now())}
  end

  def select_model(state) do
    # state includes: flow input + all dependencies outputs
    {:ok, Map.put(state, :selected_model, "claude-opus")}
  end

  def call_llm_provider(state) do
    {:ok, Map.put(state, :response, "...")}
  end

  def publish_result(state) do
    {:ok, state}
  end
end
```

### Complex Example (Parallel Steps)

```elixir
def __workflow_steps__ do
  [
    # Step 1: Fetch data (no dependencies)
    {:fetch_data, &__MODULE__.fetch_data/1, depends_on: []},

    # Steps 2a, 2b, 2c: Run in parallel (all depend on fetch_data)
    {:analyze_sentiment, &__MODULE__.analyze_sentiment/1, depends_on: [:fetch_data]},
    {:analyze_topics, &__MODULE__.analyze_topics/1, depends_on: [:fetch_data]},
    {:extract_entities, &__MODULE__.extract_entities/1, depends_on: [:fetch_data]},

    # Step 3: Combine results (depends on all parallel steps)
    {:merge_analysis, &__MODULE__.merge_analysis/1,
     depends_on: [:analyze_sentiment, :analyze_topics, :extract_entities]},

    # Step 4: Save (depends on merge)
    {:save_results, &__MODULE__.save_results/1, depends_on: [:merge_analysis]}
  ]
end
```

---

## Next Steps

1. **Decide on Approach:** Approach 1 (in-memory DAG) recommended
2. **Plan integration:** Update Pgflow.Executor, define new syntax
3. **Implement:** ~600-800 LOC total
4. **Test:** Unit tests + integration tests
5. **Document:** Examples and patterns
6. **Migrate workflows:** Update existing workflows to use DAG (optional, backward compatible)

---

## References

- **pgflow DSL:** `/tmp/pgflow/pkgs/dsl/src/dsl.ts` (620 LOC)
- **pgflow Example:** `/tmp/pgflow/pkgs/dsl/src/example-flow.ts` (website analysis flow)
- **pgflow Executor:** `/tmp/pgflow/pkgs/edge-worker/src/flow/StepTaskExecutor.ts`
- **pgflow Types:** Heavy use of TypeScript generics for compile-time safety

---

## Comparison Table

| Aspect | Approach 1 (In-Memory) | Approach 2 (DB-Driven) | pgflow |
|--------|---|---|---|
| **Parallel execution** | ✅ Within one job | ✅ Across instances | ✅ Across workers |
| **Task durability** | ❌ Lost on crash | ✅ Persisted | ✅ Persisted |
| **Complexity** | Low (~400 LOC) | High (~1000+ LOC) | High (multi-package) |
| **Implementation time** | 4-6 hours | 2-3 days | N/A |
| **Suitable for Singularity** | ✅ Yes | ⚠️ Maybe later | ✅ Inspiration |
| **Horizontal scaling** | ❌ No | ✅ Yes | ✅ Yes |
| **Backward compatible** | ⚠️ Breaking change | ✅ Yes | N/A |

**Recommendation:** Start with Approach 1, graduate to Approach 2 if needed at scale.
