# Async Task-Based API Pattern - Documentation Guide

## Overview

This guide documents how to properly tag, document, and implement **Async Request-Reply** pattern APIs (like Codex WHAM, Google Jules, etc.).

## Why This Matters

Async task-based APIs are fundamentally different from blocking APIs:
- **Blocking**: `POST /api/call` → Wait → Get response
- **Async**: `POST /api/tasks` → Return immediately → Poll for status

Without clear documentation, users mistake them for blocking calls and hang waiting for responses.

## Standard Pattern: Async Request-Reply (HTTP 202 Accepted)

```
Step 1: Submit
┌────────────────────────┐
│ POST /api/tasks        │
│ → 202 Accepted         │
│ ← Returns: task_id     │
└────────────────────────┘
         ↓
Step 2: Poll
┌────────────────────────┐
│ GET /api/tasks/{id}    │
│ → 200 OK               │
│ ← Returns: status      │
└────────────────────────┘
         ↓
Step 3: Extract Results
┌────────────────────────┐
│ Response contains:     │
│ - current_status       │
│ - output_items[]       │
│ - results/metadata     │
└────────────────────────┘
```

## HTTP Status Codes

| Code | Meaning | Context |
|------|---------|---------|
| **202** | Accepted | Task submitted, processing started |
| **200** | OK | Status available, task may not be done |
| **400** | Bad Request | Invalid parameters |
| **401** | Unauthorized | Auth failed (token expired) |
| **429** | Too Many Requests | Rate limited |
| **500** | Server Error | Server-side failure |

## Documentation Template

### Module Level

```elixir
defmodule MyApp.Providers.AsyncService do
  @moduledoc """
  AsyncService Task Client - Asynchronous Task-Based API.

  Implements the standard **Async Request-Reply Pattern** for long-running operations.

  ## Async Request-Reply Pattern

  This module follows the established pattern for async operations:

  **Step 1: Submit Task**
  ```
  POST /api/tasks
  → 202 Accepted (or 200 with task_id)
  → Returns: task_id
  ```

  **Step 2: Poll for Status**
  ```
  GET /api/tasks/{task_id}
  → Returns: current_status with results
  → Statuses: "queued", "in_progress", "completed", "failed"
  ```

  **Step 3: Extract Results**
  ```
  Response contains:
  - status_field
  - output_items or results array
  ```

  ## Status Codes

  - **200 OK** - Response available (check status field)
  - **202 Accepted** - Task submitted (processing started)
  - **401 Unauthorized** - Invalid token
  - **429 Too Many Requests** - Rate limited
  - **500 Internal Server Error** - Server error

  ## Usage

      iex> # Step 1: Submit task (returns immediately)
      iex> {:ok, task_id} = create_task(opts)

      iex> # Step 2: Poll for completion
      iex> {:ok, response} = poll_task(task_id)

  ## See Also

  - **AsyncAPI Specification**: https://www.asyncapi.com/
  - **Azure Async Pattern**: https://learn.microsoft.com/azure/architecture/patterns/async-request-reply
  - **RESTful Long-Running Tasks**: https://restfulapi.net/rest-api-design-for-long-running-tasks/
  """
end
```

### Function Level

```elixir
@doc """
Create a new task (Async Request-Reply Pattern - Step 1/2).

**Async Pattern:** Returns immediately with task ID.
Use `poll_task/2` to check completion.

**HTTP:** `POST /api/tasks` → 202 Accepted (task submitted)

## Returns

- `{:ok, task_id}` - Task submitted successfully ✓
- `{:error, reason}` - Submission failed

## Example

    iex> # Step 1: Submit task (returns immediately)
    iex> {:ok, task_id} = create_task(opts)

    iex> # Step 2: Poll for results
    iex> {:ok, response} = poll_task(task_id)
"""
def create_task(opts), do: ...

@doc """
Poll a task for completion (Async Request-Reply Pattern - Step 2/2).

**Async Pattern:** Polls until completion or timeout.
Call after `create_task/1` to wait for results.

**HTTP:** `GET /api/tasks/{task_id}` → 200 OK with status

## Returns

- `{:ok, response}` - Task completed with response ✓
- `{:error, reason}` - Polling failed or timed out

## Example

    iex> # Poll until completion (blocks)
    iex> {:ok, response} = poll_task(task_id)
"""
def poll_task(task_id, opts \\ []), do: ...
```

## Services Using This Pattern

### ✅ OpenAI Codex WHAM
```
POST /wham/tasks → task_id
GET  /wham/tasks/{id} → current_assistant_turn
```

### ✅ Google Jules
```
POST /api/tasks → task_id
GET  /api/tasks/{id} → status + results
```

### ✅ Other Async Services
- GitHub Actions API
- Google Cloud Tasks
- AWS Lambda async invocations
- Batch processing services

## Implementation Checklist

### Module Documentation
- [ ] Explain async pattern in `@moduledoc`
- [ ] Show step-by-step flow
- [ ] Document HTTP status codes
- [ ] Link to AsyncAPI spec
- [ ] Show usage examples

### Function Documentation
- [ ] Add "Async Pattern - Step X/Y" header
- [ ] Explain what happens (returns immediately vs blocks)
- [ ] Document HTTP method and expected status
- [ ] Show step-by-step examples
- [ ] Explain return values clearly

### Code Structure
- [ ] `create_task/1` - Submit task (non-blocking)
- [ ] `poll_task/2` - Check status (blocking until done)
- [ ] `get_status/1` - Get status only (non-blocking)
- [ ] `list_tasks/1` - List user's tasks
- [ ] Error handling for rate limits, auth failures

### Testing
- [ ] Test immediate return from create_task
- [ ] Test polling with timeout
- [ ] Test error cases (auth, rate limits)
- [ ] Test response extraction

## Examples

### Codex WHAM (This Implementation)
See: `packages/ex_llm/lib/ex_llm/providers/codex/task_client.ex`

Key features:
- ✅ Clear async pattern documentation
- ✅ Step 1/2, Step 2/2 labeling
- ✅ HTTP status codes documented
- ✅ SQ/EQ protocol explanation
- ✅ References to standards

### Jules (When Implemented)
Should follow same pattern:
```elixir
defmodule ExLLM.Providers.Jules do
  @moduledoc """
  Google Jules Task Client - Async Request-Reply Pattern

  Step 1: POST /api/tasks → Returns task_id
  Step 2: GET /api/tasks/{id} → Returns status + code
  """

  def create_task(opts), do: ...     # Step 1: Submit
  def poll_task(task_id, opts), do: ...  # Step 2: Poll
end
```

## Key Takeaways

1. **Mark APIs clearly** - Use "Async Request-Reply Pattern - Step X/Y" in docs
2. **Show the flow** - Document both create and poll functions with examples
3. **Explain non-blocking** - Make it clear `create_task` returns immediately
4. **Reference standards** - Link to AsyncAPI, Azure patterns, RESTful best practices
5. **Consistent naming** - Use `create_task`, `poll_task`, `get_status` patterns
6. **Status codes** - Always document which HTTP codes are returned

## Standards

- **AsyncAPI**: https://www.asyncapi.com/
- **Azure Async Request-Reply**: https://learn.microsoft.com/azure/architecture/patterns/async-request-reply
- **RESTful Long-Running Tasks**: https://restfulapi.net/rest-api-design-for-long-running-tasks/
- **OpenAPI 3.0+**: Use `callbacks` for async operations
- **OpenAPI 3.1**: Use `webhooks` support

## Migration Path

When implementing Jules or similar service:

1. **Copy module structure** from `task_client.ex`
2. **Update service name** (Codex → Jules)
3. **Update endpoints** (WHAM → Google Jules URLs)
4. **Update auth** (TokenManager approach if needed)
5. **Update response parsing** (ResponseExtractor equivalent)
6. **Test async pattern** - Verify non-blocking behavior

Example:
```
CodexWHAM TaskClient
       ↓ (copy & adapt)
JulesAPI TaskClient
       ↓ (copy & adapt)
AnotherAsyncService TaskClient
```

## Summary

**Async task-based APIs need explicit documentation** because:
- Users expect blocking calls by default
- The async pattern is non-obvious without explanation
- Step-by-step examples are critical
- HTTP status codes are unusual (202 Accepted)

By following this pattern, you make it **immediately clear** that:
- `create_task` submits and returns immediately ✓
- `poll_task` waits for completion ✓
- Both follow standard async best practices ✓
- Implementation is consistent across services (Codex, Jules, etc.) ✓
