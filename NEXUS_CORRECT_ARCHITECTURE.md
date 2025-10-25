# Nexus: Correct Architecture (Clarification)

## Quick Summary

**Nexus has TWO distinct responsibilities** - NOT general AI chat:

1. **Nexus Bun Server** = **LLM Router** (for autonomous agents)
   - Listens to `llm.request` on NATS
   - Routes requests from agents → AI providers
   - Equivalent to LiteLLM

2. **Nexus Next.js Browser** = **HITL Control Panel** (for humans)
   - Shows agent approval/question requests
   - Humans approve code changes or answer questions
   - **Can be LLM-assisted** (AI suggests answers for human review)
   - But humans always decide

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ SINGULARITY (Autonomous Agents)                             │
├─────────────────────────────────────────────────────────────┤
│ SelfImprovingAgent, ArchitectureAgent, RefactoringAgent...  │
│                                                              │
│ ┌──────────────────────┐                                    │
│ │ LLM Router Requests  │                                    │
│ │ (normal AI tasks)    │                                    │
│ └──────────┬───────────┘                                    │
│            │ NATS llm.request                               │
│            ↓                                                │
│ ┌──────────────────────────────────────────────────────┐   │
│ │ NEXUS BUN SERVER (LLM Router = LiteLLM equivalent)   │   │
│ │                                                      │   │
│ │  - Analyze task complexity                          │   │
│ │  - Check provider availability (Claude, Gemini...)  │   │
│ │  - Select optimal model                             │   │
│ │  - Route to AI provider                             │   │
│ │  - Return response                                  │   │
│ └──────────────────────────────────────────────────────┘   │
│            ↑                                                │
│            │ NATS llm.response                              │
│            │                                                │
│ ┌──────────────────────┐                                    │
│ │ HITL Approval Request│                                    │
│ │ (human review)       │                                    │
│ └──────────┬───────────┘                                    │
│            │ NATS approval.request / question.ask           │
└────────────┼─────────────────────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS WEBSOCKET BRIDGE (NATS ↔ Browser)                     │
│ - Subscribe to approval.request, question.ask               │
│ - Forward to browser via WebSocket                          │
│ - Receive human decisions                                  │
│ - Reply back via NATS                                      │
└──────────┬──────────────────────────────────────────────────┘
           │ WebSocket
           ↓
┌─────────────────────────────────────────────────────────────┐
│ NEXUS NEXT.JS BROWSER (HITL Control Panel - NOT Chat)       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Dashboard Tab: System overview and metrics                  │
│                                                              │
│ Approvals & Questions Tab: HITL interface                   │
│ ├─ ApprovalCard: Show code diff, Approve/Reject buttons     │
│ ├─ QuestionCard: Show question, answer input                │
│ │  └─ Optional: 💡 button for LLM suggestion               │
│ │     (Human reviews AI suggestion, then decides)           │
│ │                                                           │
│ └─ NO general chat! NOT a chat interface!                   │
│                                                              │
│ System Status Tab: Detailed health checks                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## What is Nexus?

### ✅ Nexus IS:

1. **LLM Router (Bun Server)**
   - Central hub for all LLM routing
   - Analyzes task complexity
   - Selects providers and models
   - Handles availability checking
   - Tracks costs
   - Equivalent to LiteLLM

2. **HITL Control Panel (Next.js)**
   - Interface for human decision-making
   - Shows agent approval/question requests
   - Humans approve code changes
   - Humans answer agent questions
   - **Optionally AI-assisted** (suggestions for review)

### ❌ Nexus is NOT:

1. ❌ A general AI chat interface for users
2. ❌ A chat application
3. ❌ A replacement for Claude Desktop or Copilot Chat
4. ❌ A place for humans to chat with AI

---

## Request Types

### 1. Agent LLM Request (Agent → Nexus Router → AI Provider)

**Flow**:
```
Agent needs LLM response
  ↓ NATS llm.request (request-reply)
Nexus Router
  ├ Analyze complexity
  ├ Select provider/model
  └ Call Claude, Gemini, Copilot, etc
  ↓ NATS reply
Agent gets response
```

**Example**:
```elixir
# In agent
case Singularity.LLM.Service.call(:complex, messages, task_type: :architect) do
  {:ok, response} -> use_response(response)
  {:error, _} -> fallback()
end
```

### 2. HITL Approval Request (Agent → Nexus Bridge → Human)

**Flow**:
```
Agent wants approval for code change
  ↓ NATS approval.request (request-reply, 30s timeout)
Nexus Bridge
  └ Forward to browser via WebSocket
  ↓ Browser shows ApprovalCard
Human approves/rejects
  ↓ WebSocket → Bridge
  ↓ NATS reply
Agent gets decision
```

**Example**:
```elixir
# In agent
case ApprovalService.request_approval(
  file_path: "lib/code.ex",
  diff: diff,
  description: "Refactor: Extract helper function"
) do
  {:ok, :approved} -> apply_changes()
  {:ok, :rejected} -> skip_changes()
  {:error, :timeout} -> fallback()
end
```

### 3. HITL Question Request (Agent → Nexus Bridge → Human)

**Flow**:
```
Agent wants human guidance
  ↓ NATS question.ask (request-reply, 30s timeout)
Nexus Bridge
  └ Forward to browser via WebSocket
  ↓ Browser shows QuestionCard with optional 💡 LLM suggestion
Human reviews (optionally with AI help), then answers
  ↓ WebSocket → Bridge
  ↓ NATS reply
Agent gets answer
```

**Example**:
```elixir
# In agent
case ApprovalService.request_question(
  question: "Should we use async pattern here?",
  context: %{"module" => "IO operations", "loops" => 3}
) do
  {:ok, response} -> process_decision(response)
  {:error, :timeout} -> use_default()
end
```

---

## LLM-Assisted HITL (Optional Feature)

The browser's QuestionCard **can** use LLM assistance:

```
Human sees question: "Should we refactor this?"
  ↓ Human clicks 💡 button
  ↓ Browser calls /api/suggest-answer (future)
Nexus routes to AI provider
  ↓ AI suggests: "Yes, because X and Y"
  ↓ Suggestion shown in green box
Human reviews suggestion
  ↓ Can use it, edit it, or ignore it
  ↓ Human decides final answer
  ↓ Send answer back to agent
```

**Key**: Humans always decide. AI just assists with suggestions.

---

## Component Breakdown

### Nexus Bun Server (`src/nats-handler.ts`)

**Purpose**: LLM Router (LiteLLM equivalent)

```
NATS llm.request → Analyze → Select Model → Call Provider → NATS reply
```

**Handles**:
- Task complexity analysis
- Provider availability checking
- Model selection
- Cost tracking
- Error handling with 30s timeout

**Used By**:
- Singularity agents (direct NATS)
- Browser `/api/chat` (if general chat UI existed - currently not)

### Nexus WebSocket Bridge (`src/approval-websocket-bridge.ts`)

**Purpose**: Bridge between NATS HITL requests and browser

```
NATS approval.request → Broadcast to browser → Human approves → NATS reply
```

**Handles**:
- Subscribe to `approval.request` and `question.ask`
- Forward to all connected WebSocket clients
- Store NATS reply subjects
- Handle 30s timeout
- Route human responses back to NATS

### Nexus Next.js App (`app/`)

**Purpose**: HITL Control Panel (NOT general chat)

**Tabs**:

1. **Dashboard**
   - System status overview
   - Metrics and health checks

2. **Approvals & Questions** ← THIS IS THE HITL INTERFACE
   - ApprovalCard: Show code diff, human approves/rejects
   - QuestionCard: Show question, human answers
   - Optional: LLM suggests answers for human review

3. **System Status**
   - Detailed system information
   - Health checks per service

**Not**:
- General chat with AI
- User chat interface
- Message history for conversations

---

## Files Involved

### Nexus Bun Server
- `src/nats-handler.ts` - LLM Router
- `src/server.ts` - HTTP + WebSocket server
- `src/approval-websocket-bridge.ts` - HITL bridge
- `src/providers/` - AI provider implementations

### Nexus Next.js
- `app/page.tsx` - Main control panel (3 tabs)
- `app/components/chat-panel.tsx` - Now called ControlPanel (HITL only)
- `app/components/approval-cards.tsx` - Approval/question UI
- `lib/use-approval-ws.ts` - WebSocket hook for HITL
- `lib/use-chat.ts` - Unused (no general chat UI)
- `app/api/chat/route.ts` - Unused (no general chat UI)

---

## API Endpoints

| Endpoint | Purpose | Used By |
|----------|---------|---------|
| `/v1/models` | List available models | External tools |
| `/v1/chat/completions` | OpenAI-compatible LLM | External tools |
| `/health` | Server health | Monitoring |
| `/metrics` | Request metrics | Monitoring |
| `/ws/approval` | WebSocket for HITL | Browser (HITL) |
| `/api/chat` | **NOT CURRENTLY USED** (no chat UI) | Could be used for suggestions |

---

## NATS Topics

| Topic | Direction | Purpose | Timeout |
|-------|-----------|---------|---------|
| `llm.request` | Agent → Nexus → Provider | LLM routing | 30s |
| `approval.request` | Agent → Nexus → Browser → Agent | Code approval | 30s |
| `question.ask` | Agent → Nexus → Browser → Agent | Guidance questions | 30s |

---

## Clear the Confusion

### ❌ What I Was Wrong About:

"Browser is a chat interface where users chat with AI"

### ✅ Correct Approach:

Browser is a **HITL Control Panel** where:
- Agents request approval for changes
- Agents ask for guidance
- Humans review and decide
- **Optionally** humans get AI suggestions (for their review)

---

## Summary

```
┌─────────────────────────────┐
│ Singularity Agents (NATS)   │
├─────────────────────────────┤
│ ├─ LLM requests  → Nexus Router → Claude/Gemini/Copilot
│ └─ HITL requests → Nexus Bridge → Browser (human decides)
└─────────────────────────────┘

┌──────────────────────────────┐
│ Nexus Browser (Control Panel)│
├──────────────────────────────┤
│ ├─ Dashboard (read-only)
│ ├─ Approvals & Questions (human interaction)
│ └─ System Status (read-only)
│
│ NOT a chat interface!
│ Only HITL approvals/questions!
└──────────────────────────────┘
```

---

**Bottom Line**:
- Nexus Bun = "LiteLLM" for agents
- Nexus Browser = "HITL Control Panel" for humans
- NOT a chat app
- Can be AI-assisted, but humans decide

