# Responses API & pgmq Integration

**Updated:** October 26, 2025  
**Scope:** Singularity ↔ Nexus queue pipeline for OpenAI Responses API calls

This document describes the canonical flow for LLM requests in Singularity. All
agents and tooling must use this path to guarantee observability, cost tracking,
and consistent error handling.

## High-Level Flow

```text
Agent → Singularity.LLM.Service → Singularity.Jobs.LlmRequestWorker
  → pgmq:ai_requests → Nexus.Workflows.LLMRequestWorkflow → OpenAI Responses API
  → pgmq:ai_results → Singularity.Jobs.LlmResultPoller → job_results table
```

1. **Service call.** `Singularity.LLM.Service` builds a request map, chooses a
   model/provider, and hands the work to `Singularity.Jobs.LlmRequestWorker`.
2. **Queue publication.** `LlmRequestWorker.enqueue_llm_request/3` persists an
   Oban job and publishes the payload to `pgmq.send('ai_requests', payload)`.
3. **Nexus execution.** Nexus consumes `ai_requests`, runs the
   `Nexus.Workflows.LLMRequestWorkflow`, and executes the OpenAI Responses API.
4. **Result publication.** Nexus enqueues the result envelope to
   `pgmq.send('ai_results', envelope)`.
5. **Persistence.** `Singularity.Jobs.LlmResultPoller` reads `ai_results`, stores
   each response in `Singularity.Schemas.Execution.JobResult`, and acknowledges
   the message.
6. **Consumption.** Agents either react to `JobResult` changes asynchronously or
   use the new helper `Singularity.Jobs.LlmResultPoller.await_responses_result/2`
   to wait for a specific `request_id`.

## Request Payload Schema

Fields captured in `LlmRequest.receive_request/1` and emitted to pgmq:

| Key | Required | Notes |
|-----|----------|-------|
| `request_id` | ✅ | UUID assigned by worker |
| `task_type` | ✅ | e.g. `"architect"`, `"coder"` |
| `messages` | ✅ | List of chat messages |
| `complexity` | ⚠️ | Auto-calculated when omitted |
| `model` / `provider` | ⚠️ | User hints, fallbacks provided |
| `api_version` | ✅ | Always `"responses"` |
| `max_tokens`, `temperature` | optional | Passed straight to Nexus |
| `previous_response_id`, `mcp_servers`, `store`, `tools` | optional | Forwarded untouched |

## Result Storage Schema

`Singularity.Jobs.LlmResultPoller` persists a `JobResult` with:

- `workflow` = `"Singularity.Workflows.LlmRequest"`
- `input.request_id` = original request ID
- `output.response` = Responses API payload returned by Nexus
- `output.model`, `output.usage`, `output.cost`, `output.latency_ms`
- `tokens_used`, `cost_cents`, `duration_ms`

Use the helper to retrieve results synchronously:

```elixir
with {:ok, request_id} <- Singularity.Jobs.LlmRequestWorker.enqueue_llm_request(task, messages, opts),
     {:ok, result} <- Singularity.Jobs.LlmResultPoller.await_responses_result(request_id) do
  result["response"]
end
```

## Operational Checklist

- Ensure pgmq queues exist (`Singularity.Jobs.PgmqClient.ensure_all_queues/0`).
- Keep Oban + ex_pgflow workers running (`LlmRequestWorker`, `LlmResultPoller`).
- Verify Nexus `LLMRequestWorkflow` consumers are connected to `ai_requests` and
  publishing to `ai_results`.
- Update new callers to depend on `Singularity.LLM.Service`; never publish to
  pgmq queues directly.
- Use `await_responses_result/2` sparingly (prefer async patterns) and always
  set sensible timeouts for long-running tasks.

## Troubleshooting

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| `{:error, :timeout}` from `await_responses_result/2` | Nexus workflow stalled or queue not drained | Check pgmq `ai_results`, ensure Nexus worker is running |
| Duplicate `request_id` constraint violation | Caller re-used an existing request | Let `LlmRequestWorker` assign IDs; do not reuse |
| Missing cost/usage metrics | Nexus workflow version outdated | Deploy latest Nexus workflow with Responses API support |

For deeper diagnostics, query `job_results` by `request_id` and inspect the
`output` field for the raw Responses payload.
