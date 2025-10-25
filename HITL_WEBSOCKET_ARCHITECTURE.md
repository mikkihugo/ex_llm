# HITL WebSocket Architecture (Nexus Approval Bridge)

## Overview

Singularity now has a unified **Human-in-the-Loop (HITL)** system where agents request approvals and questions via NATS, which are delivered to the web UI via a WebSocket bridge.

**Key Change**: All human interactions (approvals, questions) now go through **Nexus web UI** instead of Google Chat.

## Architecture

### Message Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                       AGENT REQUESTS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Agent publishes to NATS:                                       │
│  - Topic: "approval.request" (for code changes)                 │
│  - Topic: "question.ask" (for clarifications)                   │
│  - Uses: NATS request-reply pattern with 30s timeout            │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ NATS Messaging
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│              APPROVAL WEBSOCKET BRIDGE (Nexus)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ApprovalWebSocketBridge (src/approval-websocket-bridge.ts):   │
│  - Subscribes to NATS topics                                    │
│  - Forwards messages to connected WebSocket clients             │
│  - Stores NATS reply subjects for responses                     │
│  - Publishes responses back to NATS                             │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ WebSocket
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                   BROWSER UI (Next.js)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  useApprovalWebSocket Hook (lib/use-approval-ws.ts):           │
│  - Connects to ws://localhost:3000/ws/approval                  │
│  - Receives approval/question requests                          │
│  - Manages request state and responses                          │
│                                                                  │
│  ApprovalCardsContainer (app/components/approval-cards.tsx):   │
│  - Displays ApprovalCard and QuestionCard components           │
│  - Human clicks Approve/Reject or answers question             │
│  - Sends response via WebSocket                                 │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ WebSocket Response
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│              BRIDGE PUBLISHES REPLY (NATS)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Bridge receives WebSocket message and:                         │
│  - Looks up stored NATS reply subject                           │
│  - Publishes response to that subject                           │
│  - Clears 30s timeout                                           │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ NATS Request-Reply
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                  AGENT RECEIVES RESPONSE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Agent's request-reply completes:                               │
│  - {:ok, :approved} - Human approved the change                 │
│  - {:ok, :rejected} - Human rejected the change                 │
│  - {:error, :timeout} - 30s timeout, no response                │
│                                                                  │
│  Agent proceeds with appropriate action:                        │
│  - apply_change() if approved                                   │
│  - skip_change() if rejected                                    │
│  - fallback_behavior() if timeout                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Singularity (Elixir) - Approval Service

**File**: `singularity/lib/singularity/hitl/approval_service.ex`

```elixir
# Request approval via NATS request-reply
case ApprovalService.request_approval(
  file_path: "lib/my_module.ex",
  diff: diff_text,
  description: "Add feature X"
) do
  {:ok, :approved} -> apply_change()
  {:ok, :rejected} -> skip_change()
  {:error, :timeout} -> fallback_behavior()
end

# Request a question
case ApprovalService.request_question(
  question: "Should we use async or sync?",
  context: %{...}
) do
  {:ok, response_text} -> process_answer(response_text)
  {:error, :timeout} -> use_default_answer()
end
```

**Key Features**:
- Uses NATS `Client.request()` with 30s timeout
- Non-blocking: agents don't hang if human doesn't respond
- Automatic timeout handling with fallback behavior

### 2. Nexus (Node.js) - WebSocket Bridge

**File**: `nexus/src/approval-websocket-bridge.ts`

```typescript
class ApprovalWebSocketBridge {
  // Subscribe to NATS topics
  await this.subscribeToApprovalRequests()  // approval.request
  await this.subscribeToQuestionRequests()  // question.ask

  // When message arrives:
  // 1. Store NATS reply subject + 30s timeout
  // 2. Broadcast to all connected WebSocket clients
  // 3. Wait for client response

  // When client responds via WebSocket:
  // 1. Publish response to stored NATS reply subject
  // 2. Clear timeout
  // 3. Remove request from client UI
}
```

**Key Features**:
- Subscribes to NATS topics for approval/question requests
- Maintains set of connected WebSocket clients
- Stores mapping of request IDs to NATS reply subjects
- Automatically times out if no human response after 30s

### 3. Nexus (React) - UI Hooks & Components

**Hook**: `nexus/lib/use-approval-ws.ts`

```typescript
const { requests, connected, error, respondToApproval, respondToQuestion } = useApprovalWebSocket();

// Auto-connects to ws://localhost:3000/ws/approval
// Manages request state and sending responses
// Auto-reconnects on disconnect
```

**Components**: `nexus/app/components/approval-cards.tsx`

```typescript
<ApprovalCard
  request={approval}
  onApprove={() => respondToApproval(id, true)}
  onReject={() => respondToApproval(id, false)}
/>

<QuestionCard
  request={question}
  onRespond={(response) => respondToQuestion(id, response)}
/>
```

## Message Formats

### Approval Request (Elixir → NATS)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "file_path": "lib/singularity/agents/self_improving.ex",
  "diff": "@@ -10,5 +10,7 @@\n  def process_code(code) do\n-   Parser.parse(code)\n+   with {:ok, ast} <- Parser.parse(code),\n+        {:ok, typed} <- TypeChecker.check(ast) do\n+     typed\n+   end\n  end",
  "description": "Add type checking before returning parsed AST",
  "agent_id": "self-improving-agent",
  "timestamp": "2025-01-10T15:30:45.123Z"
}
```

### Approval Response (Browser → WebSocket → NATS)

```json
{
  "type": "approval_response",
  "approved": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-01-10T15:30:52.456Z"
}
```

### Question Request (Elixir → NATS)

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440111",
  "question": "Should we refactor error handling to use pattern matching or keep try-rescue blocks?",
  "context": {
    "module": "Singularity.Execution.ErrorHandling",
    "lines": 45,
    "current_style": "try-rescue",
    "error_types": ["RuntimeError", "FunctionClauseError", "MatchError"]
  },
  "agent_id": "refactoring-agent",
  "timestamp": "2025-01-10T15:31:00.000Z"
}
```

### Question Response (Browser → WebSocket → NATS)

```json
{
  "type": "question_response",
  "response": "Use pattern matching - it's more idiomatic in Elixir and keeps functions pure",
  "request_id": "660e8400-e29b-41d4-a716-446655440111",
  "timestamp": "2025-01-10T15:31:15.789Z"
}
```

## Integration with Agents

All agents can request approvals/questions using the unified pattern:

```elixir
# Self-Improving Agent
case ApprovalService.request_approval(
  file_path: code_path,
  diff: generated_diff,
  description: "Improve code quality based on feedback"
) do
  {:ok, :approved} -> commit_changes()
  {:ok, :rejected} -> log_rejection_feedback()
  {:error, :timeout} -> skip_this_improvement()
end

# Architecture Agent
case ApprovalService.request_question(
  question: "Should we adopt this architecture pattern?",
  context: %{"pattern" => "hexagonal", "usage" => "5 modules"}
) do
  {:ok, response} -> incorporate_decision(response)
  {:error, :timeout} -> use_conservative_approach()
end
```

## Configuration

### Nexus WebSocket Server

In `nexus/src/server.ts`:

```typescript
// 1. Import bridge
import { initializeApprovalBridge, getApprovalBridge } from './approval-websocket-bridge';

// 2. Initialize on startup
initializeApprovalBridge()
  .then(() => console.log('Approval bridge started'))
  .catch(error => console.error('Bridge failed:', error));

// 3. Handle WebSocket upgrade at /ws/approval
if (url.pathname === '/ws/approval' && req.headers.get('upgrade') === 'websocket') {
  const success = Bun.upgrade(req, { data: { type: 'approval' } });
  return success;
}

// 4. WebSocket message handlers (builtin)
websocket: {
  message(ws, message) { bridge.handleClientResponse(JSON.parse(message)); },
  open(ws) { bridge.addClient(ws); },
  close(ws) { /* auto-cleanup */ }
}
```

### Nexus Environment Variables

No special variables needed - uses default NATS_URL:

```bash
NATS_URL=nats://localhost:4222  # Or override if needed
```

## Testing the Flow

### 1. Start all services

```bash
# Terminal 1: Start NATS
nats-server -js

# Terminal 2: Start PostgreSQL & Singularity
nix develop && cd singularity && mix phx.server

# Terminal 3: Start Nexus
cd nexus && npm run dev
```

### 2. Trigger an approval request from Elixir

```elixir
# In iex
iex> Singularity.HITL.ApprovalService.request_approval(
  file_path: "test.ex",
  diff: "- old\n+ new",
  description: "Test approval"
)
```

### 3. Observe in browser

- Navigate to http://localhost:3000
- Approval card should appear in the chat panel
- Click "Approve" or "Reject"
- Response immediately sent back to agent

### 4. See result in iex

The request-reply completes with:
```elixir
{:ok, :approved}  # or {:ok, :rejected} or {:error, :timeout}
```

## Timeout Behavior

- **30-second timeout**: If no human response received within 30 seconds
- **Agent receives**: `{:error, :timeout}`
- **Agent decides**: Fallback behavior (usually skip the change, log, continue)
- **Request removed from UI**: Timeout clears the pending request

This ensures agents never block indefinitely waiting for human input.

## Benefits of This Architecture

✅ **Unified Interface** - All HITL interactions through Nexus web UI
✅ **No External Dependencies** - No Google Chat, Slack, or email needed
✅ **NATS Native** - Leverages existing NATS infrastructure
✅ **Real-time WebSocket** - Instant delivery to browser
✅ **Timeout Safety** - 30s timeout prevents infinite hangs
✅ **Scalable** - Supports multiple concurrent approval requests
✅ **Type-Safe** - Elixir + TypeScript + React fully typed

## Future Enhancements

- [ ] Approval history/audit log
- [ ] Batch approval (approve/reject multiple at once)
- [ ] Priority levels (urgent, normal, low)
- [ ] Approval delegation (route to specific team member)
- [ ] Notification webhooks (notify on new approval)
- [ ] Decision analytics (which approvals were accepted vs rejected)

---

**Related Files**:
- `singularity/lib/singularity/hitl/approval_service.ex` - NATS request-reply
- `nexus/src/approval-websocket-bridge.ts` - Bridge implementation
- `nexus/src/server.ts` - WebSocket server integration
- `nexus/lib/use-approval-ws.ts` - React hook
- `nexus/app/components/approval-cards.tsx` - UI components
- `nexus/app/components/chat-panel.tsx` - Chat integration
