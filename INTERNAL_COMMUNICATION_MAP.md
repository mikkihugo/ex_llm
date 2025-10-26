# Internal Communication Architecture Map

This document maps all internal communication patterns in Singularity and Nexus after NATS removal.

---

## Communication Patterns

### Pattern 1: Direct Function Calls (❌ BROKEN)

**Used By:** Agents, Architecture Engine, SPARC, Code Generation

```
Agent / Engine / SPARC
  ↓
LLM.Service.call(:complex, messages, task_type: :architect)
  ↓
build_request(messages, opts)
  ↓
dispatch_request(request, opts) [LINE 817]
  ↓
Logger.error("LLM service unavailable...")
  ↓
{:error, :unavailable} ❌
```

**Files Involved:**
- `/singularity/lib/singularity/llm/service.ex` (lines 437-560)
  - `call/3` - Main entry point
  - `call_with_prompt/3` - Convenience wrapper
  - `call_with_system/4` - With system prompt
  - `call_with_script/3` - Lua script support

**Affected Callers:**
- `/singularity/lib/singularity/agents/**/*` (all agent AI operations)
- `/singularity/lib/singularity/engines/architecture_engine.ex` (architecture analysis)
- `/singularity/lib/singularity/execution/sparc/orchestrator.ex` (SPARC workflows)
- `/singularity/lib/singularity/code_generation/generators/quality_code_generator.ex` (code gen)
- `/singularity/lib/singularity/workflows/llm_request.ex` (line 100, Pgflow workflow)

---

### Pattern 2: Oban Background Jobs (⚠️ PARTIALLY WORKING)

**Used By:** LLM Request Processing, Result Polling

#### 2A: Request Enqueue → Workflow Execute

```
Caller (direct)
  ↓
LlmRequestWorker.enqueue_llm_request(task_type, messages, opts)
  [LINE 37-69]
  ↓
args = %{
  "request_id" => UUID,
  "task_type" => task_type,
  "messages" => messages,
  "model" => model,
  "provider" => provider
}
  ↓
new(args) → Oban.insert()
  ↓
{:ok, request_id} ✅
  ↓
[Oban executes job asynchronously]
  ↓
LlmRequestWorker.perform(%Oban.Job{args: args})
  [LINE 72-128]
  ↓
Pgflow.Executor.execute(Singularity.Workflows.LlmRequest, args, timeout: 30000)
  ↓
Singularity.Workflows.LlmRequest.__workflow_steps__
  [STEPS 1-4]
  1. receive_request(input)
  2. select_model(state)
  3. call_llm_provider(state) ← CALLS BROKEN LLM.Service
  4. publish_result(state)
  ↓
Step 3 FAILS ❌
  ↓
LlmRequestWorker.perform catches error
  ↓
Singularity.Schemas.Execution.JobResult.record_failure(...)
  ↓
Oban retries up to max_attempts: 3
```

**Files Involved:**
- `/singularity/lib/singularity/jobs/llm_request_worker.ex`
  - `enqueue_llm_request/3` (line 37) - Enqueue entry point
  - `perform/1` (line 72) - Oban worker implementation
- `/singularity/lib/singularity/workflows/llm_request.ex`
  - `__workflow_steps__/0` (line 37) - Workflow definition
  - `receive_request/1` (line 50)
  - `select_model/1` (line 70)
  - `call_llm_provider/1` (line 93) ← BROKEN
  - `publish_result/1` (line 130)
- `/singularity/lib/singularity/schemas/execution/job_result.ex`
  - `record_success/1` (line 119)
  - `record_failure/1` (line 162)

#### 2B: Result Polling → Database Store

```
Oban Scheduler (every 5 seconds)
  ↓
Singularity.Jobs.LlmResultPoller.perform(%Oban.Job{})
  [LINE 36-53]
  ↓
PgmqClient.read_messages("ai_results", 10)
  [LINE 40]
  ↓
Repo.query!("SELECT msg_id, msg_body FROM pgmq.read($1, limit => $2)", ...)
  [/jobs/pgmq_client.ex LINE 56-60]
  ↓
[{message_id, body}, ...] or [] ✅
  ↓
Enum.each(messages, fn {message_id, body} → process_result(body, message_id) end)
  [LINE 42-44]
  ↓
process_result(body, message_id)
  [LINE 59-99]
  ↓
result = Jason.decode!(body)
  ↓
store_result(result)
  [LINE 101-124] ⚠️ TODO - ONLY LOGS
  ↓
PgmqClient.ack_message("ai_results", message_id)
  [LINE 75]
  ↓
Repo.query!("SELECT pgmq.delete($1, $2)", ...)
  [/jobs/pgmq_client.ex LINE 84-87]
  ↓
:ok ✅
```

**Files Involved:**
- `/singularity/lib/singularity/jobs/llm_result_poller.ex`
  - `perform/1` (line 36) - Oban cron job
  - `process_result/2` (line 59) - Handle single result
  - `store_result/1` (line 101) ⚠️ TODO
- `/singularity/lib/singularity/jobs/pgmq_client.ex`
  - `read_messages/2` (line 54) - Query pgmq
  - `ack_message/2` (line 82) - Delete from queue

---

### Pattern 3: PostgreSQL Message Queue (⚠️ INCOMPLETE)

**Used By:** Cross-Application Communication (Singularity ↔ Nexus)

#### 3A: Enqueue Request to pgmq:ai_requests

```
Singularity.Jobs.LlmRequestWorker.perform()
  [LINE 72]
  ↓
Pgflow.Executor.execute(Singularity.Workflows.LlmRequest, args)
  [LINE 82]
  ↓
Singularity.Workflows.LlmRequest.call_llm_provider()
  [LINE 93-150]
  ↓
[INTENDED TO] Call Nexus LLM provider
  [BUT ACTUALLY] Calls broken LLM.Service ❌
  ↓
SHOULD INSTEAD enqueue to pgmq:ai_requests:
  
  PgmqClient.send_message("ai_requests", %{
    "request_id" => request_id,
    "task_type" => task_type,
    "messages" => messages,
    "model" => model,
    "provider" => provider
  })
  [/jobs/pgmq_client.ex LINE 24-46]
  ↓
Repo.query!("SELECT pgmq.send($1, $2)", [queue_name, json])
  ↓
{:ok, message_id} ✅
```

**Files Involved:**
- `/singularity/lib/singularity/jobs/pgmq_client.ex`
  - `send_message/2` (line 24) - Enqueue to pgmq

**Intended Recipient (NOT IMPLEMENTED):**
- `/nexus/lib/nexus/queue_consumer.ex` ❌ MISSING
  - Should poll pgmq:ai_requests
  - Should execute Nexus.Workflows.LLMRequestWorkflow
  - Should publish results to pgmq:ai_results

#### 3B: Process Request in Nexus Workflow

```
Nexus.QueueConsumer [MISSING ❌]
  (Should be: GenServer polling pgmq:ai_requests)
  ↓
READ from pgmq:ai_requests
  ↓
Pgflow.Executor.execute(Nexus.Workflows.LLMRequestWorkflow, args)
  [/nexus/workflows/llm_request_workflow.ex]
  ↓
Step 1: validate(input)
  [LINE 73-89]
  ↓
Step 2: route_llm(state)
  [LINE 131-179]
  ↓
Nexus.LLMRouter.route(router_request)
  [/nexus/lib/nexus/llm_router.ex LINE 60]
  ↓
select_model(complexity, task_type)
  [LINE 139] ✅
  ↓
Selects from:
  - :simple → "gemini-2.0-flash-exp"
  - :medium → varies (Claude Sonnet, GPT-4o)
  - :complex → varies (Codex, Claude Sonnet)
  ↓
call_provider(model, messages, opts)
  [LINE 191]
  ↓
ExLLM.chat(formatted_messages, [model: model] ++ opts)
  [LINE 196] ✅
  ↓
[HTTP to LLM provider - Claude, Gemini, OpenAI, etc.]
  ↓
{:ok, response} ✅
  ↓
Step 3: publish_result(state)
  [LINE 186-210] ⚠️ TODO - DOESN'T ACTUALLY PUBLISH
  ↓
[SHOULD CALL]
  PgmqClient.send_message("ai_results", result_message) ← NOT DONE
  ↓
Step 4: track_metrics(state)
  [LINE 221-248]
  ↓
Logger.info("LLM request metrics", ...)
  ↓
[SHOULD STORE metrics in DB] ← TODO
```

**Files Involved:**
- `/nexus/lib/nexus/queue_consumer.ex` ❌ MISSING
- `/nexus/lib/nexus/workflows/llm_request_workflow.ex`
  - `__workflow_steps__/0` (line 52) - Workflow definition
  - `validate/1` (line 73) ✅
  - `route_llm/1` (line 131) ✅
  - `publish_result/1` (line 186) ⚠️ TODO
  - `track_metrics/1` (line 221) ⚠️ TODO
- `/nexus/lib/nexus/llm_router.ex`
  - `route/1` (line 60) ✅
  - `select_model/2` (line 139) ✅
  - `call_provider/3` (line 191) ✅

#### 3C: Poll Results from pgmq:ai_results

```
Singularity.Jobs.LlmResultPoller.perform()
  [LINE 36]
  ↓
POLLS pgmq:ai_results every 5 seconds (Oban cron)
  ↓
PgmqClient.read_messages("ai_results", 10)
  [LINE 40] ✅
  ↓
Repo.query!("SELECT msg_id, msg_body FROM pgmq.read($1, limit => $2)", ...)
  [/jobs/pgmq_client.ex LINE 56-60] ✅
  ↓
[{message_id, body}, ...] or [] ✅
  ↓
Enum.each(messages, fn {message_id, body} → process_result(...) end)
  [LINE 42]
  ↓
process_result(body, message_id)
  [LINE 59]
  ↓
result = Jason.decode!(body) ✅
  ↓
store_result(result)
  [LINE 101] ⚠️ TODO - ONLY LOGS, DOESN'T STORE
  ↓
[SHOULD INSERT INTO ai_results TABLE]
  INSERT INTO ai_results (request_id, response, model, tokens_used, cost_cents, processed_at)
  VALUES (result["request_id"], result["response"], ...)
  ↓
PgmqClient.ack_message("ai_results", message_id)
  [LINE 75] ✅
```

**Files Involved:**
- `/singularity/lib/singularity/jobs/llm_result_poller.ex`
  - `perform/1` (line 36) ✅
  - `process_result/2` (line 59) ✅
  - `store_result/1` (line 101) ⚠️ TODO

---

### Pattern 4: Execution Result Tracking (✅ COMPLETE)

**Used By:** Job Execution Monitoring

```
Singularity.Jobs.LlmRequestWorker.perform()
  [LINE 72]
  ↓
EXECUTE Pgflow workflow
  [LINE 82]
  ↓
{:ok, result} or {:error, reason}
  ↓
IF SUCCESS:
  Singularity.Schemas.Execution.JobResult.record_success(
    workflow: "Singularity.Workflows.LlmRequest",
    instance_id: Pgflow.Instance.Registry.instance_id(),
    job_id: job.id,
    input: args,
    output: result,
    tokens_used: result["tokens_used"],
    cost_cents: result["cost_cents"],
    duration_ms: duration_ms
  )
  [LINE 93-102]
  ↓
  Changeset.cast() + Changeset.validate_required() + Repo.insert()
  [/schemas/execution/job_result.ex LINE 207-224]
  ↓
  INSERT INTO job_results (
    workflow, instance_id, job_id, status, input, output,
    tokens_used, cost_cents, duration_ms, completed_at
  ) VALUES (...)
  ↓
  {:ok, job_result} ✅

IF FAILURE:
  Singularity.Schemas.Execution.JobResult.record_failure(
    workflow: "Singularity.Workflows.LlmRequest",
    instance_id: instance_id,
    job_id: job_id,
    input: args,
    error: inspect(reason),
    duration_ms: duration_ms
  )
  [LINE 116-123]
  ↓
  INSERT INTO job_results (..., status: 'failed', error: '...', ...)
  ↓
  {:ok, job_result} ✅
```

**Files Involved:**
- `/singularity/lib/singularity/jobs/llm_request_worker.ex`
  - `perform/1` (line 72) - Calls record_success/failure
- `/singularity/lib/singularity/schemas/execution/job_result.ex`
  - `record_success/1` (line 119) ✅
  - `record_failure/1` (line 162) ✅
  - `record_timeout/1` (line 200) ✅
  - `changeset/2` (line 207) ✅

---

## Communication Paths Summary

### Request Flow (How LLM requests SHOULD flow)

```
1. Agent/Engine calls LLM.Service.call(:complex, messages)
   ↓ CURRENTLY: Returns {:error, :unavailable} ❌
   ↓ SHOULD: Enqueue to LlmRequestWorker

2. LlmRequestWorker.enqueue_llm_request()
   ↓ WORKS: Enqueues Oban job ✅

3. Oban executes LlmRequestWorker.perform()
   ↓ WORKS: Pgflow executes workflow ✅
   ↓ BROKEN: Workflow calls LLM.Service ❌
   ↓ SHOULD: Enqueue to pgmq:ai_requests

4. [MISSING] Nexus.QueueConsumer polls pgmq:ai_requests
   ↓ NOT IMPLEMENTED ❌

5. [IF IMPLEMENTED] Nexus.Workflows.LLMRequestWorkflow executes
   ↓ STEPS DEFINED: ✅
   ↓ STEP 3 publish_result: TODO ⚠️

6. [IF PUBLISHED] Nexus routes through LLMRouter → ExLLM → LLM Provider
   ↓ LLMRouter: ✅
   ↓ ExLLM: ✅
   ↓ LLM Provider HTTP: ✅

7. Results published back to pgmq:ai_results
   ↓ CURRENTLY: Not implemented ❌

8. LlmResultPoller polls pgmq:ai_results
   ↓ POLLING: ✅
   ↓ STORING: TODO ⚠️

9. Results available in job_results table
   ↓ Schema: ✅
   ↓ Storage: Blocked by step 8
```

---

## Component Status Matrix

| Component | Status | File | Issue |
|-----------|--------|------|-------|
| LLM.Service.call() | ❌ BROKEN | llm/service.ex:437 | dispatch_request returns :unavailable |
| LlmRequestWorker.enqueue | ✅ WORKS | jobs/llm_request_worker.ex:37 | None |
| LlmRequestWorker.perform | ⚠️ PARTIAL | jobs/llm_request_worker.ex:72 | Calls broken workflow |
| Singularity.Workflows.LlmRequest | ❌ BROKEN | workflows/llm_request.ex:37 | Step 3 calls broken LLM.Service |
| Nexus.QueueConsumer | ❌ MISSING | queue_consumer.ex | Not implemented |
| Nexus.LLMRouter | ✅ WORKS | ../nexus/lib/nexus/llm_router.ex:60 | None |
| Nexus.Workflows | ⚠️ PARTIAL | ../nexus/lib/nexus/workflows/llm_request_workflow.ex | publish_result & track_metrics TODO |
| PgmqClient | ✅ WORKS | jobs/pgmq_client.ex | None |
| LlmResultPoller | ⚠️ PARTIAL | jobs/llm_result_poller.ex:36 | store_result not implemented |
| JobResult schema | ✅ WORKS | schemas/execution/job_result.ex | None |

---

## Key Insights

1. **Architecture is Sound** - pgmq + Pgflow is a good design
2. **Mostly Implemented** - ~70% of infrastructure exists
3. **Critical Gaps** - 5 specific blockers prevent any LLM calls
4. **Missing GenServer** - Nexus.QueueConsumer is the linchpin
5. **Incomplete TODOs** - 2 critical workflow steps not implemented

---

## Files Requiring Changes

| Priority | Component | File | Action |
|----------|-----------|------|--------|
| 🔴 Critical | Nexus.QueueConsumer | Create: queue_consumer.ex | Implement GenServer |
| 🔴 Critical | LLM.Service.dispatch_request | llm/service.ex:817 | Implement pgmq dispatch |
| 🔴 Critical | Nexus publish_result | workflows/llm_request_workflow.ex:207 | Implement pgmq publish |
| 🔴 Critical | LlmResultPoller.store_result | jobs/llm_result_poller.ex:111 | Implement DB insert |
| 🟠 Important | Singularity.Workflows.LlmRequest | workflows/llm_request.ex:100 | Stop calling LLM.Service |
| 🟠 Important | Decide API | llm/service.ex | Sync vs async approach |

