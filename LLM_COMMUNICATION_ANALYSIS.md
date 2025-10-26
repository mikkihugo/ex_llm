# LLM Service & Internal Communication Analysis Report

## Executive Summary

After NATS removal, Singularity has **partially migrated** to a pgmq + Pgflow-based architecture, but **LLM.Service is now broken** and returns `{:error, :unavailable}`. The communication pattern is **inconsistent** - some parts use Pgflow workflows, others use direct calls.

**Status:** 🔴 **BROKEN** - LLM.Service needs complete refactoring to work with pgmq

---

## 1. LLM.Service Usage Map

### Current State: BROKEN ❌

**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/llm/service.ex` (lines 812-832)

```elixir
defp dispatch_request(request, opts) do
  # LLM service is unavailable without NATS/messaging infrastructure
  # AI server communication requires pgmq queue setup and consumer
  requested_model = Map.get(request, :model, "auto")
  _timeout = Keyword.get(opts, :timeout, 30_000)

  Logger.error("LLM service unavailable - AI server communication disabled",
    model: requested_model,
    provider: Map.get(request, :provider),
    complexity: Map.get(request, :complexity),
    task_type: Map.get(request, :task_type),
    reason: "NATS messaging layer removed - requires pgmq queue infrastructure"
  )

  {:error, :unavailable}
end
```

**Result:** ALL calls to `LLM.Service.call()` immediately return `{:error, :unavailable}`

### Where LLM.Service Is Called

1. **Singularity.Workflows.LlmRequest** (line 100+)
   - Tries to call `LLM.Service.call_with_prompt()`
   - Will receive error due to broken `dispatch_request`
   - File: `/singularity/lib/singularity/workflows/llm_request.ex`

2. **Agents** (documented in LLM.Service metadata)
   - All agent AI operations reference `LLM.Service.call()`
   - Currently broken

3. **Architecture Engine** (documented in LLM.Service metadata)
   - Architecture analysis calls `LLM.Service.call()`
   - Currently broken

4. **SPARC Orchestrator** (documented in LLM.Service metadata)
   - SPARC workflow execution calls `LLM.Service.call()`
   - Currently broken

5. **Code Generation** (documented in LLM.Service metadata)
   - QualityCodeGenerator calls `LLM.Service.call()`
   - Currently broken

---

## 2. New Communication Architecture: pgmq + Pgflow

### Architecture Overview

```
Singularity (Elixir)
  ├─ Oban Job: LlmRequestWorker
  │   └─ Enqueues to pgmq:ai_requests
  │
PostgreSQL (pgmq queues)
  ├─ Queue: ai_requests (Singularity → Nexus)
  └─ Queue: ai_results (Nexus → Singularity)
  
Nexus (Separate Elixir app)
  ├─ QueueConsumer GenServer
  │   ├─ Polls pgmq:ai_requests
  │   └─ Executes Pgflow workflows
  │       └─ Nexus.Workflows.LLMRequestWorkflow
  │           ├─ Step 1: Validate
  │           ├─ Step 2: Route (via Nexus.LLMRouter)
  │           │   └─ Calls ExLLM (ex_llm library)
  │           ├─ Step 3: Publish result to pgmq:ai_results
  │           └─ Step 4: Track metrics
  │
Singularity (Elixir)
  └─ Oban Job: LlmResultPoller
      ├─ Polls pgmq:ai_results
      └─ Stores results in database
```

### Key Components

#### 1. **Singularity.Jobs.LlmRequestWorker** (NEW)
- **Purpose:** Enqueue LLM requests to pgmq
- **File:** `/singularity/lib/singularity/jobs/llm_request_worker.ex`
- **Behavior:** Oban worker + Pgflow executor
- **Flow:**
  ```
  enqueue_llm_request()
  → Oban.insert()
  → perform() [executed by Oban]
  → Pgflow.Executor.execute(Singularity.Workflows.LlmRequest)
  → JobResult.record_success/failure
  ```

#### 2. **Singularity.Workflows.LlmRequest** (NEW - BUT BROKEN)
- **Purpose:** Pgflow workflow for LLM processing
- **File:** `/singularity/lib/singularity/workflows/llm_request.ex`
- **Steps:**
  1. `receive_request` - Validate input
  2. `select_model` - Choose best model by complexity
  3. `call_llm_provider` - **CALLS LLM.Service.call_with_prompt() → BROKEN**
  4. `publish_result` - Return result
- **Problem:** Step 3 calls `LLM.Service` which is unavailable

#### 3. **Nexus.Workflows.LLMRequestWorkflow** (COMPLETE)
- **Purpose:** Process LLM requests in Nexus (separate app)
- **File:** `/nexus/lib/nexus/workflows/llm_request_workflow.ex`
- **Steps:**
  1. `validate` - Validate request parameters
  2. `route_llm` - **Calls Nexus.LLMRouter.route() → ExLLM provider call**
  3. `publish_result` - Publish back to pgmq:ai_results
  4. `track_metrics` - Store metrics
- **Status:** ✅ COMPLETE AND WORKING

#### 4. **Nexus.LLMRouter** (COMPLETE)
- **Purpose:** Route requests to appropriate LLM provider
- **File:** `/nexus/lib/nexus/llm_router.ex`
- **Providers:**
  - Gemini Flash (simple)
  - Claude Sonnet (medium)
  - GPT-4o / Codex (complex)
- **Integration:** Uses `ExLLM.chat()` from ex_llm library
- **Status:** ✅ COMPLETE AND WORKING

#### 5. **Nexus.QueueConsumer** (PARTIALLY COMPLETE)
- **Purpose:** Poll pgmq:ai_requests and execute workflows
- **File:** `/nexus/lib/nexus/application.ex` (launched from here)
- **Behavior:** GenServer polling pgmq
- **Status:** ⚠️ INCOMPLETE - consumer not found in glob results
  - Should listen to pgmq:ai_requests
  - Execute Nexus.Workflows.LLMRequestWorkflow
  - Publish results to pgmq:ai_results

#### 6. **Singularity.Jobs.LlmResultPoller** (PARTIAL)
- **Purpose:** Poll pgmq:ai_results and store results
- **File:** `/singularity/lib/singularity/jobs/llm_result_poller.ex`
- **Behavior:** Oban cron job (runs every 5 seconds)
- **Status:** ⚠️ INCOMPLETE - `store_result` has TODO
  - Line 111-113: TODO to insert into database table
  - Currently only logs results

#### 7. **Singularity.Jobs.PgmqClient** (COMPLETE)
- **Purpose:** Helper functions for pgmq operations
- **File:** `/singularity/lib/singularity/jobs/pgmq_client.ex`
- **Functions:**
  - `send_message(queue_name, message)`
  - `read_messages(queue_name, limit)`
  - `ack_message(queue_name, message_id)`
  - `ensure_queue(queue_name)`
- **Status:** ✅ COMPLETE

#### 8. **Singularity.Schemas.Execution.JobResult** (COMPLETE)
- **Purpose:** Store workflow execution results
- **File:** `/singularity/lib/singularity/schemas/execution/job_result.ex`
- **Functions:**
  - `record_success(opts)` - Store successful execution
  - `record_failure(opts)` - Store failed execution
  - `record_timeout(opts)` - Store timeout
- **Status:** ✅ COMPLETE

---

## 3. Current Internal Communication Patterns

### Pattern 1: Direct GenServer/Function Calls (❌ BROKEN)

**Problem:** LLM.Service returns `:unavailable`

```elixir
# ❌ BROKEN - dispatch_request returns {:error, :unavailable}
LLM.Service.call(:complex, messages, task_type: :architect)
→ {:error, :unavailable}
```

### Pattern 2: Oban Background Jobs → Pgflow Workflows

**Status:** ⚠️ PARTIALLY WORKING

```elixir
# ✅ Enqueuing works
LlmRequestWorker.enqueue_llm_request(task_type, messages)
→ {:ok, request_id}
→ Oban.insert(job)

# ❌ Workflow execution broken
Oban executes LlmRequestWorker.perform()
→ Pgflow.Executor.execute(Singularity.Workflows.LlmRequest)
→ Step 3 calls LLM.Service.call_with_prompt()
→ ❌ RETURNS {:error, :unavailable}
```

### Pattern 3: pgmq Queue-Based Communication (⚠️ INCOMPLETE)

**Flow:**
```
Singularity.Jobs.LlmRequestWorker
  ↓ enqueue_llm_request()
pgmq:ai_requests
  ↓ [MISSING: Nexus.QueueConsumer to read from here]
Nexus.Workflows.LLMRequestWorkflow
  ↓ route_llm() → Nexus.LLMRouter
ExLLM.chat()
  ↓ HTTP to LLM provider
LLM response
  ↓ publish_result()
pgmq:ai_results
  ↓ Singularity.Jobs.LlmResultPoller (Oban cron)
⚠️ TODO: store_result() not implemented
```

### Pattern 4: Execution Result Tracking (✅ COMPLETE)

```elixir
Singularity.Schemas.Execution.JobResult.record_success(
  workflow: "Singularity.Workflows.LlmRequest",
  instance_id: Pgflow.Instance.Registry.instance_id(),
  job_id: job_id,
  input: input,
  output: result,
  tokens_used: tokens,
  cost_cents: cost,
  duration_ms: elapsed_ms
)
→ Persists to job_results table
```

---

## 4. Broken References After NATS Removal

### 1. **LLM.Service.dispatch_request** ❌

- **File:** `/singularity/lib/singularity/llm/service.ex` lines 812-832
- **Issue:** Always returns `{:error, :unavailable}`
- **Reason:** NATS client removed, pgmq integration not complete
- **Impact:** ALL LLM calls fail

### 2. **Singularity.Workflows.LlmRequest** ❌

- **File:** `/singularity/lib/singularity/workflows/llm_request.ex` line 100
- **Issue:** Calls `LLM.Service.call_with_prompt()` which returns error
- **Impact:** Pgflow workflow fails at step 3
- **Should Instead:** Use Pgflow to enqueue to pgmq, not call LLM.Service directly

### 3. **Nexus.Workflows.LLMRequestWorkflow.publish_result** ⚠️

- **File:** `/nexus/lib/nexus/workflows/llm_request_workflow.ex` lines 186-210
- **Issue:** Has TODO comment (line 207) - "Use pgmq Elixir client"
- **Current Behavior:** Returns `{:ok, published: true}` without actually publishing
- **Impact:** Results don't reach pgmq:ai_results queue

### 4. **Singularity.Jobs.LlmResultPoller.store_result** ⚠️

- **File:** `/singularity/lib/singularity/jobs/llm_result_poller.ex` lines 101-124
- **Issue:** Has TODO comment (line 111) - doesn't insert into database
- **Current Behavior:** Only logs results
- **Impact:** Results lost, agents can't consume them

### 5. **Missing: Nexus.QueueConsumer Implementation** ❌

- **Location:** Should be in `/nexus/lib/nexus/queue_consumer.ex`
- **Issue:** Not found in codebase
- **Purpose:** Poll pgmq:ai_requests and execute workflows
- **Impact:** Requests enqueued to pgmq are never processed

---

## 5. Dependencies & Integrations

### ex_pgflow Integration

**Status:** ✅ PARTIALLY INTEGRATED

Files:
- `/packages/ex_pgflow/lib/pgflow/` - Workflow framework (from moonrepo)
- `singularity/mix.exs:123` - Dependency: `{:ex_pgflow, path: "../packages/ex_pgflow"}`
- `nexus/mix.exs:29` - Dependency: `{:ex_pgflow, path: "../packages/ex_pgflow"}`

Usage:
- ✅ `Pgflow.Executor.execute(workflow, input)` - Workflow execution
- ✅ `Pgflow.Instance.Registry.instance_id()` - Instance tracking
- ❌ Workflow steps use `&__MODULE__.step_name/1` pattern (OK for simple cases, but no advanced features)

### ex_llm Integration

**Status:** ✅ INTEGRATED IN NEXUS ONLY

Files:
- `/packages/ex_llm/` - LLM client library (from moonrepo)
- `nexus/mix.exs:26` - Dependency: `{:ex_llm, path: "../packages/ex_llm"}`
- `singularity/mix.exs` - ❌ NO DEPENDENCY ON ex_llm

Usage in Nexus:
- ✅ `ExLLM.chat(formatted_messages, [model: model] ++ opts)`
- ✅ Supports multiple providers (Claude, Gemini, GPT-4o, Groq)
- ✅ Calls actual LLM HTTP APIs directly

**Issue:** Singularity doesn't use ex_llm at all - LLM.Service was supposed to be the abstraction, but it's now broken.

### pgmq Integration

**Status:** ⚠️ PARTIALLY INTEGRATED

Files:
- `/singularity/lib/singularity/jobs/pgmq_client.ex` - Helper functions
- `nexus/mix.exs:35` - Dependency: `{:pgmq, "~> 0.4.0"}`
- `singularity/mix.exs` - ❌ NO EXPLICIT pgmq DEPENDENCY (works through Postgrex)

Functions:
- ✅ `send_message/2` - Works
- ✅ `read_messages/2` - Works
- ✅ `ack_message/2` - Works
- ✅ `ensure_queue/1` - Works

**Issue:** Nexus.Workflows.LLMRequestWorkflow.publish_result doesn't actually use pgmq (TODO comment)

---

## 6. Recommendations for Cleanup & Fix

### Critical (Breaks LLM Functionality)

1. **Fix LLM.Service.dispatch_request** ❌
   ```elixir
   # OPTION A: Use pgmq + blocking poll
   def dispatch_request(request, opts) do
     case PgmqClient.send_message("ai_requests", request) do
       {:ok, message_id} ->
         # Poll pgmq:ai_results for response (blocking with timeout)
         poll_for_result(message_id, opts)
       {:error, reason} ->
         {:error, reason}
     end
   end
   
   # OPTION B: Use Oban job enqueue + async callbacks (better)
   def dispatch_request(request, opts) do
     case LlmRequestWorker.enqueue_llm_request(request.task_type, request.messages, opts) do
       {:ok, request_id} ->
         # Return immediately, caller polls for results later
         {:ok, %{request_id: request_id, status: :enqueued}}
       {:error, reason} ->
         {:error, reason}
     end
   end
   ```

2. **Implement Nexus.QueueConsumer** ❌
   ```elixir
   # Should be: /nexus/lib/nexus/queue_consumer.ex
   # GenServer that:
   # - Polls pgmq:ai_requests every N seconds
   # - Executes Nexus.Workflows.LLMRequestWorkflow
   # - Publishes results to pgmq:ai_results
   ```

3. **Complete Nexus.Workflows.LLMRequestWorkflow.publish_result** ⚠️
   ```elixir
   def publish_result(state) do
     result = state["route_llm"]
     # Actually call PgmqClient.send_message("ai_results", result_message)
   end
   ```

4. **Complete Singularity.Jobs.LlmResultPoller.store_result** ⚠️
   ```elixir
   defp store_result(result) do
     # Actually insert into database:
     # INSERT INTO ai_results (request_id, response, model, tokens_used, cost_cents)
     # VALUES (result["request_id"], result["response"], result["model"], ...)
   end
   ```

### Important (Architectural Cleanup)

5. **Decide: Sync vs Async LLM calls**
   - Current architecture is async (enqueue, poll results)
   - But LLM.Service API suggests sync calls
   - Choose: 
     - **Sync + blocking:** Keep LLM.Service API, add result polling inside
     - **Async:** Change all callers to enqueue + poll, remove LLM.Service

6. **Add ex_llm to Singularity.MixProject**
   - Currently only in Nexus
   - If Singularity calls LLMs directly, needs dependency
   - Or stay with async approach (Nexus does the LLM calls)

7. **Remove LLM.Service if async approach chosen**
   - If all calls go through Oban/Pgflow, LLM.Service becomes obsolete
   - Replace direct calls with `LlmRequestWorker.enqueue_llm_request()`

### Nice-to-Have (Code Quality)

8. **Add tests for pgmq communication**
   - Queue operations
   - Workflow execution
   - Result polling

9. **Monitor queue depths**
   - Add metrics for pgmq:ai_requests backlog
   - Add metrics for pgmq:ai_results backlog
   - Track processing latency

10. **Documentation**
    - Document the async LLM call pattern
    - Update LLM.Service docs or deprecate it
    - Add examples for enqueue + poll pattern

---

## 7. Communication Pattern Summary

### What Works ✅

| Component | Purpose | Status | Notes |
|-----------|---------|--------|-------|
| PgmqClient | Queue operations | ✅ | Helper functions implemented |
| JobResult schema | Result storage | ✅ | Table + insert/query functions |
| Nexus.LLMRouter | Provider routing | ✅ | Uses ExLLM, supports multiple providers |
| Nexus.Workflows.LLMRequestWorkflow | Workflow definition | ⚠️ | Steps defined but publish_result incomplete |
| Pgflow.Executor | Workflow execution | ✅ | Framework working |
| Oban | Job scheduling | ✅ | Running, jobs execute |

### What's Broken ❌

| Component | Problem | Impact | Fix |
|-----------|---------|--------|-----|
| LLM.Service.dispatch_request | Returns `:unavailable` | All LLM calls fail | Implement pgmq-based dispatch |
| Singularity.Workflows.LlmRequest | Calls broken LLM.Service | Pgflow workflows fail | Don't call LLM.Service, use Oban jobs |
| Nexus.QueueConsumer | Not implemented | Requests never processed | Implement GenServer to poll pgmq |
| LlmResultPoller.store_result | TODO - not implemented | Results lost | Insert into database |
| Nexus.Workflows.publish_result | TODO - not implemented | Results never queued | Call PgmqClient.send_message |

---

## 8. Architectural Comparison

### Before (NATS)
```
Elixir (Singularity)
  ↓ NATS request
AI Server (TypeScript)
  ↓ HTTP
LLM Provider
  ↓ HTTP
AI Server
  ↓ NATS response
Elixir (Singularity)
```

### After (Current - Broken)
```
Elixir (Singularity) → LLM.Service → dispatch_request()
↓
{:error, :unavailable} ❌
```

### After (Intended - pgmq)
```
Elixir (Singularity)
  ↓ Oban job
pgmq:ai_requests
  ↓ [MISSING: Nexus.QueueConsumer]
Elixir (Nexus)
  ↓ Pgflow workflow
Nexus.LLMRouter
  ↓ ExLLM
LLM Provider
  ↓
Nexus.LLMRouter
  ↓ pgmq:ai_results
pgmq:ai_results
  ↓ Oban cron job
Singularity (store result)
```

---

## 9. Next Steps (Priority Order)

1. **Implement Nexus.QueueConsumer** - Without this, nothing works
2. **Fix LLM.Service or deprecate it** - Choose sync vs async approach
3. **Complete pgmq integrations** - publish_result, store_result
4. **Add tests** - Verify queue-based communication
5. **Documentation** - Update LLM service docs

