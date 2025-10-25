# Human-in-the-Loop (HITL) Agent Integration Guide

## Overview

Agents in Singularity can request human approvals and clarifications through the **ApprovalService**. These requests flow through NATS to the Nexus web UI, where humans can respond in real-time.

## Architecture

```
Agent (Elixir)
    ↓ ApprovalService.request_approval()
NATS llm.request (request-reply with 30s timeout)
    ↓
Nexus ApprovalWebSocketBridge
    ↓
Browser WebSocket (real-time UI)
    ↓
Human approves/rejects or answers question
    ↓
WebSocket → Bridge → NATS reply
    ↓
Agent receives {:ok, :approved} / {:error, :timeout}
```

## Using ApprovalService in Agents

### 1. Basic Approval Request

For code changes that need human review:

```elixir
defmodule Singularity.Agents.MyAgent do
  alias Singularity.HITL.ApprovalService

  def apply_code_change(file_path, new_code) do
    # Generate a diff for human review
    {:ok, diff} = generate_diff(file_path, new_code)

    # Request approval with details
    case ApprovalService.request_approval(
      file_path: file_path,
      diff: diff,
      description: "Refactor: Extract common logic into helper function"
    ) do
      {:ok, :approved} ->
        File.write!(file_path, new_code)
        {:ok, :applied}

      {:ok, :rejected} ->
        Logger.info("Code change rejected by human")
        {:ok, :rejected}

      {:error, :timeout} ->
        Logger.warn("No human response - using conservative approach")
        {:ok, :skipped}
    end
  end
end
```

### 2. Question/Clarification Request

For architectural decisions:

```elixir
defmodule Singularity.Agents.ArchitectureAgent do
  alias Singularity.HITL.ApprovalService

  def decide_architecture_pattern() do
    # Ask human for guidance
    case ApprovalService.request_question(
      question: "Should we adopt Hexagonal Architecture or keep current layered approach?",
      context: %{
        "current_pattern" => "layered",
        "modules_affected" => 15,
        "refactoring_effort" => "3-5 days",
        "expected_benefit" => "Better testability and independence"
      }
    ) do
      {:ok, response} ->
        Logger.info("Human decision: #{response}")
        process_architectural_decision(response)

      {:error, :timeout} ->
        Logger.warn("No guidance - sticking with current approach")
        {:ok, :unchanged}
    end
  end
end
```

### 3. Multi-Step Workflow with HITL

For complex operations requiring multiple approvals:

```elixir
defmodule Singularity.Agents.RefactoringAgent do
  alias Singularity.HITL.ApprovalService

  def refactor_module(module_path) do
    # Step 1: Analyze and propose changes
    {:ok, changes} = analyze_refactoring_opportunities(module_path)

    # Step 2: Get human approval for changes
    case ApprovalService.request_approval(
      file_path: module_path,
      diff: changes.diff,
      description: "Extract #{changes.extracted_functions} functions, Reduce cyclomatic complexity from #{changes.before_complexity} to #{changes.after_complexity}"
    ) do
      {:ok, :approved} ->
        # Step 3: Apply changes
        :ok = apply_changes(module_path, changes)

        # Step 4: Run tests and get feedback
        case ApprovalService.request_question(
          question: "Tests all pass! Should we also remove these #{length(changes.unused_functions)} unused helper functions?",
          context: %{
            "unused" => changes.unused_functions,
            "impact" => "Low - only used in specs"
          }
        ) do
          {:ok, "yes"} ->
            :ok = remove_unused_functions(module_path, changes.unused_functions)
            {:ok, :refactored_and_cleaned}

          {:ok, response} ->
            Logger.info("Human preference: #{response}")
            {:ok, :refactored}

          {:error, :timeout} ->
            # Default: keep unused functions if no response
            {:ok, :refactored}
        end

      {:ok, :rejected} ->
        {:ok, :rejected}

      {:error, :timeout} ->
        # Fallback: don't refactor if no approval
        {:ok, :skipped}
    end
  end
end
```

## Complete Integration Pattern

Here's the complete pattern for agent methods:

```elixir
@spec my_operation() :: {:ok, term()} | {:error, term()}
def my_operation do
  # 1. Prepare work
  {:ok, proposal} = prepare_work()

  # 2. Request approval/decision
  case ApprovalService.request_approval(
    file_path: proposal.path,
    diff: proposal.diff,
    description: proposal.description,
    agent_id: "my-agent"  # Optional: helps humans understand the source
  ) do
    # 3a. APPROVED - Execute the change
    {:ok, :approved} ->
      {:ok, result} = execute(proposal)
      log_success(result)
      {:ok, result}

    # 3b. REJECTED - Handle rejection gracefully
    {:ok, :rejected} ->
      log_rejection(proposal)
      {:ok, :rejected}

    # 3c. TIMEOUT - Use safe fallback
    {:error, :timeout} ->
      log_timeout(proposal)
      use_conservative_approach()

    # 3d. OTHER ERROR - Log and fail safely
    {:error, reason} ->
      Logger.error("Approval service error: #{inspect(reason)}")
      {:error, :approval_failed}
  end
end
```

## Approval Request Options

### ApprovalService.request_approval/1

Required fields:
- `file_path` (string) - Path to the file being modified
- `diff` (string) - Unified diff or plain text diff
- `description` (string) - Human-readable explanation of the change

Optional fields:
- `agent_id` (string) - Agent identifier (default: "system")

Example:
```elixir
ApprovalService.request_approval(
  file_path: "lib/my_module.ex",
  diff: "- old_function\n+ new_function",
  description: "Performance: Replace recursive with tail-recursive implementation",
  agent_id: "performance-agent"
)
```

### ApprovalService.request_question/1

Required fields:
- `question` (string) - The question for the human

Optional fields:
- `context` (map) - Relevant context information (default: %{})
- `agent_id` (string) - Agent identifier (default: "system")

Example:
```elixir
ApprovalService.request_question(
  question: "Should we extract this validation logic?",
  context: %{
    "module" => "Validation",
    "lines" => "45-78",
    "duplication_count" => 3
  },
  agent_id: "refactoring-agent"
)
```

## Timeout Behavior

The 30-second timeout ensures agents don't block indefinitely:

```elixir
# Agent calls with request-reply, 30s timeout
case ApprovalService.request_approval(...) do
  # If human responds within 30s
  {:ok, :approved} -> ...

  # If 30s passes with no response
  {:error, :timeout} ->
    # Agent should have a safe fallback
    # Option 1: Skip the change (conservative)
    # Option 2: Log for manual review
    # Option 3: Continue with default behavior
end
```

**Key Point**: Agents should **always** have a fallback for timeout. Never assume human will respond.

## Best Practices

### 1. Clear Descriptions

❌ Bad:
```elixir
description: "Update code"
```

✅ Good:
```elixir
description: "Performance: Replace O(n²) sort with O(n log n) quicksort in SearchIndexer.rebuild()"
```

### 2. Actionable Questions

❌ Bad:
```elixir
question: "Is this good?"
```

✅ Good:
```elixir
question: "We found 5 unused helper functions. Should we remove them to reduce API surface?",
context: %{
  "functions" => ["_internal_sort", "_cache_key", ...],
  "impact" => "These are private, only used internally"
}
```

### 3. Safe Fallbacks

❌ Bad:
```elixir
case ApprovalService.request_approval(...) do
  {:ok, :approved} -> apply_changes()
  # No timeout handling!
end
```

✅ Good:
```elixir
case ApprovalService.request_approval(...) do
  {:ok, :approved} -> apply_changes()
  {:ok, :rejected} -> log_and_skip()
  {:error, :timeout} -> use_conservative_approach()
  {:error, reason} -> handle_error(reason)
end
```

### 4. Consistent Agent ID

Use a meaningful agent_id so humans know who's asking:

```elixir
# In your agent module
@agent_id "self-improving-agent"

def request_approval(params) do
  ApprovalService.request_approval(
    Keyword.merge(params, agent_id: @agent_id)
  )
end
```

## Testing HITL Approvals

### Manual Testing

1. Start all services:
```bash
nats-server -js
cd singularity && mix phx.server
cd nexus && npm run dev
```

2. Trigger from agent:
```elixir
iex> Singularity.Agents.MyAgent.apply_change(...)
# Look for approval request in http://localhost:3000
```

3. Approve/reject in browser

4. Agent receives response:
```elixir
{:ok, :approved}  # or {:ok, :rejected} or {:error, :timeout}
```

### Unit Testing

Mock the ApprovalService for testing:

```elixir
defmodule MyAgentTest do
  use ExUnit.Case

  test "applies changes when approved" do
    # Mock ApprovalService to return approval
    with_approval_mock({:ok, :approved}, fn ->
      assert {:ok, :applied} = MyAgent.apply_change(...)
    end)
  end

  test "uses fallback when timeout" do
    # Mock to simulate timeout
    with_approval_mock({:error, :timeout}, fn ->
      assert {:ok, :skipped} = MyAgent.apply_change(...)
    end)
  end

  defp with_approval_mock(response, test_fn) do
    # Mock Singularity.HITL.ApprovalService.request_approval
    Mox.stub(ApprovalServiceMock, :request_approval, fn _opts ->
      response
    end)

    test_fn.()
  end
end
```

## Common Patterns

### Pattern 1: Approval with Automatic Retry

```elixir
def apply_with_retry(proposal, max_retries \\ 3) do
  case ApprovalService.request_approval(proposal) do
    {:ok, :approved} -> apply_changes(proposal)
    {:ok, :rejected} -> {:ok, :rejected}
    {:error, :timeout} ->
      if max_retries > 0 do
        Logger.warn("Timeout, retrying in 5s...")
        Process.sleep(5000)
        apply_with_retry(proposal, max_retries - 1)
      else
        {:error, :max_retries_exceeded}
      end
  end
end
```

### Pattern 2: Approval with Escalation

```elixir
def apply_with_escalation(proposal) do
  case ApprovalService.request_approval(proposal) do
    {:ok, :approved} -> apply_changes(proposal)
    {:ok, :rejected} -> log_rejection(proposal)
    {:error, :timeout} ->
      # Escalate to email/team channel instead of failing
      :ok = notify_team_email(proposal)
      {:ok, :escalated}
  end
end
```

### Pattern 3: Conditional Approval

```elixir
def maybe_request_approval(proposal) do
  if high_risk?(proposal) do
    # High-risk changes always need approval
    ApprovalService.request_approval(proposal)
  else
    # Low-risk changes auto-approved
    {:ok, :auto_approved}
  end
end
```

## Integration Checklist

- [ ] Add `alias Singularity.HITL.ApprovalService` to your agent
- [ ] Identify code paths that need human approval
- [ ] Write clear descriptions for each approval request
- [ ] Implement safe fallback for timeout
- [ ] Test approval flow in browser
- [ ] Test timeout handling
- [ ] Document agent's HITL behavior

## Troubleshooting

### Approvals not appearing in UI?

1. Check NATS is connected:
   ```bash
   nats-server status  # Should show "Server is running"
   ```

2. Check bridge is running:
   ```bash
   # Should see in Nexus console: "Approval bridge started"
   ```

3. Check browser WebSocket:
   ```javascript
   // In browser console
   ws.readyState  // Should be 1 (OPEN)
   ```

### Timeout occurring immediately?

- NATS server not running
- ApprovalService timeout too short (default 30s is reasonable)
- Agent not waiting for response

### Response not reaching agent?

- Check browser console for errors
- Verify NATS reply subject is being captured
- Check Nexus server logs for publishing errors

---

**Related Files**:
- `singularity/lib/singularity/hitl/approval_service.ex` - ApprovalService implementation
- `nexus/src/approval-websocket-bridge.ts` - NATS bridge
- `nexus/lib/use-approval-ws.ts` - React hook
- `nexus/app/components/approval-cards.tsx` - UI components
