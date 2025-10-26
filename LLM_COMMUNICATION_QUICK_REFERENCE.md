# LLM Service Communication - Quick Reference

## Status: 🔴 BROKEN

All LLM calls currently fail with `{:error, :unavailable}`. NATS was removed but pgmq replacement is incomplete.

## Key Findings

### What's Broken (5 Critical Issues)

1. **LLM.Service.dispatch_request** (lines 812-832)
   - Returns `{:error, :unavailable}` 
   - Impact: All direct LLM calls fail
   - Fix: Implement pgmq-based dispatch

2. **Nexus.QueueConsumer** (MISSING)
   - Should poll pgmq:ai_requests and execute workflows
   - Not implemented anywhere
   - Impact: Requests enqueued but never processed

3. **Nexus.Workflows.publish_result** (line 207, TODO)
   - Doesn't actually publish to pgmq
   - Returns success without queueing
   - Impact: Results never reach response queue

4. **Singularity.Workflows.LlmRequest** (line 100)
   - Calls broken LLM.Service
   - Pgflow workflow fails at step 3
   - Fix: Route through Nexus instead

5. **Singularity.LlmResultPoller.store_result** (lines 111-113, TODO)
   - Doesn't insert into database
   - Only logs results
   - Impact: Results lost, can't be consumed

## Current Architecture (Incomplete)

```
Singularity
  ├─ LLM.Service (BROKEN - returns :unavailable)
  └─ Oban Jobs
      ├─ LlmRequestWorker (enqueues to pgmq:ai_requests) ✅
      └─ LlmResultPoller (polls pgmq:ai_results) ⚠️ incomplete

pgmq (PostgreSQL Message Queue)
  ├─ ai_requests → [MISSING CONSUMER]
  └─ ai_results ← [NOT PUBLISHING]

Nexus (Separate Elixir App)
  ├─ LLMRouter (routes to providers) ✅
  ├─ Workflows.LLMRequestWorkflow (steps defined) ⚠️
  └─ QueueConsumer (MISSING)

ExLLM
  └─ calls actual LLM providers ✅
```

## Working Components ✅

- Pgflow.Executor (workflow execution)
- Nexus.LLMRouter (model selection + provider routing)
- PgmqClient (queue operations)
- JobResult schema (result storage)
- ExLLM (LLM provider calls)

## Incomplete Components ⚠️

- Nexus.Workflows.LLMRequestWorkflow.publish_result
- Singularity.Jobs.LlmResultPoller.store_result
- Nexus.QueueConsumer (entire component)

## Fix Priority

1. Implement Nexus.QueueConsumer (GenServer polling pgmq:ai_requests)
2. Complete Nexus.Workflows.publish_result (actually call pgmq)
3. Complete Singularity.LlmResultPoller.store_result (insert into DB)
4. Fix/deprecate LLM.Service.dispatch_request (route through Nexus)
5. Decide: sync vs async API for LLM calls

## Dependencies

- ✅ ex_pgflow (in Singularity and Nexus)
- ✅ ex_llm (in Nexus only)
- ✅ pgmq (in Nexus, works via Postgrex in Singularity)
- ✅ Oban (job scheduling)

## File Locations

| Component | File | Status |
|-----------|------|--------|
| LLM.Service | `/singularity/lib/singularity/llm/service.ex` | BROKEN |
| LlmRequestWorker | `/singularity/lib/singularity/jobs/llm_request_worker.ex` | ✅ |
| LlmResultPoller | `/singularity/lib/singularity/jobs/llm_result_poller.ex` | ⚠️ TODO |
| PgmqClient | `/singularity/lib/singularity/jobs/pgmq_client.ex` | ✅ |
| JobResult | `/singularity/lib/singularity/schemas/execution/job_result.ex` | ✅ |
| Singularity.Workflows.LlmRequest | `/singularity/lib/singularity/workflows/llm_request.ex` | BROKEN |
| Nexus.LLMRouter | `/nexus/lib/nexus/llm_router.ex` | ✅ |
| Nexus.Workflows.LLMRequestWorkflow | `/nexus/lib/nexus/workflows/llm_request_workflow.ex` | ⚠️ TODO |
| Nexus.QueueConsumer | MISSING | ❌ |

## Quick Assessment

**The New Architecture Idea is Sound:**
- pgmq for queue-based communication (good choice)
- Pgflow for workflow orchestration (working)
- ExLLM for provider abstraction (working)
- Separate Nexus app for LLM processing (good separation)

**But It's Only 60% Complete:**
- 5 critical gaps that prevent any LLM calls
- Some incomplete TODOs in key workflow steps
- Missing key GenServer (QueueConsumer) that ties it all together

