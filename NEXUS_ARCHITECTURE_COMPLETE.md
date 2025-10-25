# Nexus Complete Architecture

## System Overview

**Nexus** is a dual-purpose system serving as both:
1. **Unified Web Control Panel** (Next.js) - UI for humans
2. **LLM Router & HITL Bridge** (Bun Server) - Backend for AI & approval flows

The system enables tight integration between **Singularity agents** (autonomous AI) and **human decision-making** through the web UI.

## Complete Data Flow

### Chat Flow: Browser → Singularity → Response

```
┌─────────────────────────────────────────────────────────────┐
│ BROWSER (Next.js UI)                                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User types message → useChat hook                          │
│         ↓                                                    │
│  POST /api/chat with messages                               │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS API ROUTE (app/api/chat/route.ts)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Receive messages from browser                           │
│  2. Build LLMRequest (model: auto, task_type: general)      │
│  3. Publish to NATS llm.request (request-reply)             │
│  4. Wait 30s for response                                   │
│  5. Stream response as SSE                                  │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ NATS
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS BOUN SERVER (src/nats-handler.ts)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Subscribe to llm.request                                │
│  2. Receive LLMRequest from Nexus API                       │
│  3. Analyze task complexity                                 │
│  4. Select best provider (Claude, Gemini, Copilot, etc)     │
│  5. Call AI provider via AI SDK                             │
│  6. Return LLMResponse                                      │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ NATS reply
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS API ROUTE (continued)                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Convert response to SSE format:                            │
│  {                                                          │
│    type: "text",                                            │
│    content: "...response text..."                           │
│  }                                                          │
│  {                                                          │
│    type: "usage",                                           │
│    tokens: 2450,                                            │
│    model: "claude:sonnet",                                  │
│    cost_cents: 0                                            │
│  }                                                          │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ SSE Stream
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ BROWSER (useChat hook)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Parse SSE stream in real-time:                             │
│  - Accumulate text chunks                                   │
│  - Update UI with streaming message                         │
│  - Show usage stats when done                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### HITL Flow: Agent → Approval → Browser → Response

```
┌─────────────────────────────────────────────────────────────┐
│ AGENT (Elixir in Singularity)                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ApprovalService.request_approval(                          │
│    file_path: "...",                                        │
│    diff: "...",                                             │
│    description: "..."                                       │
│  )                                                          │
│                                                              │
│  NATS request-reply (30s timeout):                          │
│  - Awaits approval response                                 │
│  - Returns {:ok, :approved|:rejected} or {:error, :timeout}│
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ NATS request-reply
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS APPROVAL BRIDGE (src/approval-websocket-bridge.ts)    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Subscribe to approval.request & question.ask NATS       │
│  2. When message arrives:                                   │
│     - Store NATS reply subject                              │
│     - Set 30s timeout                                       │
│     - Broadcast to all connected WebSocket clients          │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ WebSocket Broadcast
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ BROWSER (ws://localhost:3000/ws/approval)                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. useApprovalWebSocket hook receives request              │
│  2. Renders ApprovalCard or QuestionCard                    │
│  3. Shows:                                                  │
│     - Code diff for review                                  │
│     - Agent who requested approval                          │
│     - Clear Approve/Reject buttons                          │
│                                                              │
│  4. Human clicks Approve or Reject                          │
│  5. WebSocket sends response:                               │
│     {                                                       │
│       type: "approval_response",                            │
│       approved: true,                                       │
│       request_id: "...",                                    │
│       timestamp: "..."                                      │
│     }                                                       │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ WebSocket Response
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS APPROVAL BRIDGE (continued)                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Receive WebSocket response                              │
│  2. Look up stored NATS reply subject for request_id        │
│  3. Publish response to NATS reply subject                  │
│  4. Clear 30s timeout                                       │
│  5. Remove from pending requests                            │
│                                                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ NATS reply
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ AGENT (Elixir) - Request-Reply Completes                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  case ApprovalService.request_approval(...) do              │
│    {:ok, :approved} -> apply_changes()                      │
│    {:ok, :rejected} -> skip_changes()                       │
│    {:error, :timeout} -> fallback_behavior()                │
│  end                                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### Nexus Bun Server (`src/server.ts`)

**HTTP Server** (port 3000 or configured):

```typescript
Bun.serve({
  port: PORT,
  fetch(req) {
    // OpenAI-compatible endpoints for external use
    GET  /health              → Server health + NATS status
    GET  /metrics             → Request statistics
    GET  /v1/models           → List all available models
    POST /v1/chat/completions → OpenAI-compatible chat API

    // NATS request-reply (internal Singularity use)
    // nats-handler.ts listens on llm.request
  },
  websocket: {
    // WebSocket handlers for browser clients
    open(ws) { /* connect to approval bridge */ },
    message(ws, msg) { /* handle response from browser */ },
    close(ws) { /* cleanup */ }
  }
})
```

### Nexus Next.js App (`app/`)

**React Components**:

1. **Chat Interface** (`components/chat-panel.tsx`)
   - Message display with streaming
   - User input with send button
   - Approval/question cards embedded

2. **Approval Cards** (`components/approval-cards.tsx`)
   - `ApprovalCard` - Shows diff, Approve/Reject buttons
   - `QuestionCard` - Shows question, text input for answer
   - Real-time response via WebSocket

3. **System Status** (`components/system-status.tsx`)
   - Singularity, Genesis, CentralCloud status
   - Health checks and metrics

**React Hooks**:

1. **useChat** (`lib/use-chat.ts`)
   - Manages chat state and streaming
   - Parses SSE response from `/api/chat`
   - Real-time message updates
   - Usage stats (tokens, cost, model)

2. **useApprovalWebSocket** (`lib/use-approval-ws.ts`)
   - Connects to WebSocket bridge
   - Manages approval/question requests
   - Sends responses back via WebSocket
   - Auto-reconnect on disconnect

**API Routes** (`app/api/`):

1. **`/api/chat`** - Chat endpoint
   - Publishes to NATS `llm.request`
   - Streams response as SSE
   - Handles timeout and errors

2. **`/api/health/[service]`** - Health checks
   - Checks service status (Singularity, Genesis, etc)
   - Returns health + latency

3. **`/api/system-status/[system]`** - System status
   - Get full system info and metrics

### Approval WebSocket Bridge (`src/approval-websocket-bridge.ts`)

**Responsibilities**:

1. **NATS Subscription**
   - Subscribe to `approval.request` topic
   - Subscribe to `question.ask` topic
   - Listen for agent approval/question requests

2. **WebSocket Management**
   - Accept connections at `/ws/approval`
   - Broadcast incoming NATS messages to all browsers
   - Store client set for cleanup

3. **Request-Reply Coordination**
   - Store NATS reply subject + 30s timeout per request
   - When browser responds, publish to stored NATS subject
   - Clear timeout and remove from pending

**Key Methods**:

```typescript
// Start bridge
await initializeApprovalBridge()

// Called by Bun WebSocket handler
bridge.addClient(ws)              // New browser connected
bridge.handleClientResponse(msg)  // Browser sent response

// Internal
subscribeToApprovalRequests()     // Listen to NATS
subscribeToQuestionRequests()     // Listen to NATS
broadcastToClients(msg)           // Send to all browsers
publishResponse(subject, data)    // Reply to NATS
```

## Key Integrations

### 1. Singularity Agents → Nexus Chat

```
Agent asks LLM:
  Singularity.LLM.Service.call(:complex, messages, task_type: :architect)
            ↓
  Via NATS to llm.request
            ↓
  Nexus Bun server receives, selects provider, calls AI
            ↓
  Response back to agent
```

### 2. Singularity Agents → Nexus HITL

```
Agent requests approval:
  ApprovalService.request_approval(file_path, diff, description)
            ↓
  Via NATS to approval.request (request-reply)
            ↓
  Nexus bridge receives, broadcasts to browser
            ↓
  Human approves in UI
            ↓
  Browser sends response via WebSocket
            ↓
  Bridge publishes to NATS reply
            ↓
  Agent gets {:ok, :approved} or {:error, :timeout}
```

### 3. Browser Chat → Singularity LLM

```
User chats in browser:
  useChat sends to /api/chat
            ↓
  Nexus API publishes to NATS llm.request
            ↓
  Nexus Bun handler receives, calls provider
            ↓
  Response via NATS reply
            ↓
  API converts to SSE
            ↓
  Browser displays streaming response
```

## Environment & Configuration

### Required Environment Variables

```bash
# NATS connection (for both Bun server and bridges)
NATS_URL=nats://localhost:4222

# For AI providers (if using external LLMs)
ANTHROPIC_API_KEY=...
OPENAI_API_KEY=...
GOOGLE_AUTH_TYPE=...
GITHUB_TOKEN=...
```

### Port Configuration

```
Port 3000  → Nexus Bun HTTP server
           → Next.js dev server (same port when deployed)
Port 4222  → NATS server (must be running)
Port 5432  → PostgreSQL (Singularity)
```

### Optional Overrides

```bash
PORT=3001          # Change Nexus HTTP port
NATS_URL=...       # Custom NATS server
```

## Deployment Architecture

### Development

```
Machine
├── nats-server (port 4222)
├── PostgreSQL (port 5432)
├── Singularity (Elixir, port 4000)
└── Nexus (Bun + Next.js, port 3000)
    ├── Bun server (API + WebSocket)
    └── Next.js dev server (React UI)
```

### Production (Recommended)

```
Infrastructure:
├── NatsServer (JetStream enabled)
├── PostgreSQL (managed database)
├── Singularity (compiled Elixir release)
└── Nexus
    ├── Bun server (API + WebSocket)
    ├── Next.js static (Vercel, Netlify, or self-hosted)
    └── CDN (optional)
```

## Security Considerations

### Authentication

- **Bun Server**: Simple bearer token auth for `/v1/*` endpoints (internal use only)
- **WebSocket Bridge**: No auth (assumes trusted network)
- **NATS**: Can be secured with credentials if needed

### Data Flow

- All approval/question data flows through NATS (message queue)
- No direct database writes for HITL requests
- SSE responses are never cached (real-time only)

### Timeout Safety

- 30-second timeout ensures agents don't block indefinitely
- Agents must implement fallback behavior
- No risk of orphaned approval requests (timeouts cleaned up)

## Performance Characteristics

### Chat Streaming

- **Latency**: 100-500ms to first token (depends on provider)
- **Throughput**: 50+ concurrent chats
- **Memory**: ~5MB per active connection

### HITL Approvals

- **Latency**: <100ms for delivery to browser
- **Throughput**: 100+ concurrent approval requests
- **Storage**: O(1) per approval (stored only during 30s window)

### NATS

- **Latency**: <5ms for request-reply
- **Throughput**: 1000+ msg/s on single Bun instance
- **Memory**: Minimal (messages are ephemeral)

## Testing Strategy

### Unit Tests

```typescript
// Test useChat SSE parsing
// Test useApprovalWebSocket connection/reconnect
// Test approval card rendering
```

### Integration Tests

```elixir
# Test ApprovalService.request_approval
# Test agent HITL flow
# Test timeout handling
```

### End-to-End Tests

```
1. Start all services
2. User sends chat → see response
3. Agent requests approval → see in UI
4. Human approves → agent receives response
5. Timeout after 30s
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Chat not responding | NATS down | Start nats-server -js |
| Approvals not showing | Bridge not running | Check Nexus console logs |
| WebSocket error | Connection refused | NATS URL wrong or server down |
| Timeout always | NATS latency | Check NATS health |
| Memory leak | Unclosed WebSocket | Browser tab closed? |

## Future Enhancements

- [ ] Approval history and audit log
- [ ] Batch approval UI (approve multiple at once)
- [ ] Priority levels for approval requests
- [ ] Approval delegation (route to specific person)
- [ ] Chat with code context (codebase-aware)
- [ ] Multi-user approval workflows
- [ ] Approval analytics dashboard

---

**Related Documentation**:
- `HITL_WEBSOCKET_ARCHITECTURE.md` - Low-level NATS/WebSocket details
- `HITL_AGENT_INTEGRATION.md` - How agents use HITL
- `WEB_MIGRATION_SUMMARY.md` - Migration from old Phoenix
- `NEXTJS_SETUP.md` - Next.js app structure
