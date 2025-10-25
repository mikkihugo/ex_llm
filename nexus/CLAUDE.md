# Nexus Server - Architecture Guide

## Overview

**Nexus is a unified server combining core components:**

1. **PostgreSQL Database** - Stores HITL history, approval decisions, questions, metrics
2. **Remix UI Server** - Control panel dashboard for human approvals and system status

**Pending pgmq Integration (NATS Removed):**
- ~~LLM Router~~ - Pending: Routes Singularity agent requests via pgmq
- ~~HITL WebSocket Bridge~~ - Pending: Bridges approval/question requests to browser clients

**Status:** NATS messaging layer has been removed. Components 2-3 are suspended pending pgmq (PostgreSQL message queue) integration in Singularity backend.

## Component Separation

### 0. PostgreSQL Database (db.ts + Drizzle ORM)

**Purpose:** Persistent storage for HITL history, metrics, and decisions

**Location:** `src/db.ts` + `src/schema.ts` + `drizzle.config.ts`
**ORM:** Drizzle (lightweight, SQL-first, perfect for Bun)

**Responsibilities:**
- Connect to PostgreSQL `nexus` database
- Create and manage schema (approval_requests, question_requests, hitl_metrics tables)
- Log all approval/question requests
- Log human decisions and responses
- Record response time metrics

**Key Tables:**
```sql
-- Stores all approval requests with decision outcomes
approval_requests (
  id UUID PRIMARY KEY,
  file_path TEXT,
  diff TEXT,
  description TEXT,
  agent_id TEXT,
  approved BOOLEAN,
  timestamp TIMESTAMP,
  approved_at TIMESTAMP
)

-- Stores all question requests with responses
question_requests (
  id UUID PRIMARY KEY,
  question TEXT,
  context JSONB,
  agent_id TEXT,
  response TEXT,
  response_at TIMESTAMP,
  timestamp TIMESTAMP
)

-- Records metrics for analysis
hitl_metrics (
  id SERIAL PRIMARY KEY,
  request_type VARCHAR(50),
  request_id UUID,
  response_time_ms INTEGER,
  user_id TEXT,
  created_at TIMESTAMP
)
```

**Database Config:**
```
Database: nexus (set via NEXUS_DB env var, default: nexus)
Host: localhost (set via DB_HOST env var)
Port: 5432 (set via DB_PORT env var)
User: postgres (set via DB_USER env var)
```

**Methods:**
- `connect()` - Connect and initialize schema
- `logApprovalRequest(data)` - Store approval request
- `logApprovalDecision(data)` - Store human decision
- `logQuestionRequest(data)` - Store question request
- `logQuestionResponse(data)` - Store human response
- `recordMetric(data)` - Store performance metrics
- `close()` - Graceful shutdown

### 1. LLM Router (nats-handler.ts)

**Purpose:** Routes agent LLM requests from Singularity to appropriate AI providers

**Location:** `src/nats-handler.ts` (24 KB)

**Responsibilities:**
- Subscribe to `llm.request` NATS topic
- Analyze request complexity (simple, medium, complex)
- Select best model/provider based on task type
- Call AI provider via SDK
- Publish response back to NATS

**Key Files:**
- `src/nats-handler.ts` - Main router logic
- `src/model-registry.ts` - Model catalog and availability
- `src/providers/` - Provider implementations (Claude, Gemini, Copilot, Cursor, CodeX, OpenRouter, Google AI Jules)

**Task Types → Complexity:**
```
simple        → classifier, parser, simple_chat
medium        → coder, decomposition, planning, chat
complex       → architect, code_generation, qa, refactoring
```

**Model Selection:**
```
Complexity   Example Models (by cost)
simple       → Gemini Flash, GPT-4o-mini (~$0.001/call)
medium       → Claude Sonnet, GPT-4o (~$0.01-0.05/call)
complex      → Claude Opus, o1 (~$0.10+/call)
```

### 2. HITL WebSocket Bridge (approval-websocket-bridge.ts)

**Purpose:** Bridges NATS approval/question requests to WebSocket clients (browser)

**Location:** `src/approval-websocket-bridge.ts` (12 KB)

**Responsibilities:**
- Subscribe to `approval.request` and `question.ask` NATS topics
- Broadcast incoming requests to all connected WebSocket clients
- Receive responses from browser clients
- Publish responses back to NATS reply subject
- Handle 30-second timeout for unanswered requests

**Key Files:**
- `src/approval-websocket-bridge.ts` - Bridge logic
- `app/hooks/useApprovalWebSocket.ts` - React hook for client-side WebSocket

**Message Flow:**
```
Singularity Agent
    ↓ NATS (approval.request / question.ask)
HITL Bridge
    ↓ WebSocket message
Browser Client
    ↓ User clicks/types response
    ↓ WebSocket response
HITL Bridge
    ↓ NATS reply
Singularity Agent
```

**Approval Request Format:**
```json
{
  "id": "uuid",
  "file_path": "lib/module.ex",
  "diff": "actual diff text",
  "description": "Add feature X",
  "agent_id": "self-improving-agent",
  "timestamp": "2025-01-10T..."
}
```

**Approval Response Format:**
```json
{
  "approved": true,
  "request_id": "uuid",
  "timestamp": "2025-01-10T..."
}
```

### 3. Remix UI Server (server.ts + app/)

**Purpose:** Control panel for humans to approve/reject code changes and answer questions

**Location:** `src/server.ts` + `app/`

**Responsibilities:**
- Serve HTTP/WebSocket server via Express + Bun
- Render Remix routes for dashboard and approvals
- Upgrade HTTP connections to WebSocket (`/ws/approval`)
- Display approval/question cards to humans
- Capture human responses and send to bridge

**Key Files:**
- `src/server.ts` - Unified server initialization
- `app/routes/_index.tsx` - Dashboard tab
- `app/routes/approvals.tsx` - HITL control panel
- `app/routes/status.tsx` - System status
- `app/components/ApprovalCard.tsx` - Approval UI
- `app/components/QuestionCard.tsx` - Question UI
- `app/hooks/useApprovalWebSocket.ts` - WebSocket connection management

**Routes:**
- `GET /` - Dashboard (read-only system metrics)
- `GET /approvals` - HITL control panel (main interface for approvals/questions)
- `GET /status` - System status page
- WebSocket `/ws/approval` - Bidirectional approval/question communication

## Server Initialization Order

**File:** `src/server.ts`

The unified server initializes in strict order (see lines 40-90+):

```
0. PostgreSQL Database
   - Connect to PostgreSQL 'nexus' database
   - Create schema tables if needed
   - Initialize connection pool
   - Ready for logging HITL history

1. LLM Router (NATSHandler)
   - Connect to NATS
   - Subscribe to llm.request topic
   - Load model registry
   - Ready to route agent requests

2. HITL Bridge (ApprovalWebSocketBridge)
   - Connect to NATS
   - Subscribe to approval.request and question.ask topics
   - Prepare to forward to WebSocket clients

3. Remix UI (Express + Vite)
   - Load Remix build
   - Setup static files
   - Setup WebSocket upgrade handler for /ws/approval
   - Setup Remix request handler (must be last)

4. Start HTTP server (port 3000)
   - Ready to accept browser connections
   - Ready to accept WebSocket upgrades
```

Each component:
- Has explicit error handling
- Logs its initialization status
- Can fail independently (graceful degradation)
- Is registered for graceful shutdown

## Data Flow

### LLM Request Flow (Agent → Provider)

```
Agent publishes: NATS llm.request
                 {
                   "model": "auto",
                   "task_type": "architect",
                   "messages": [...]
                 }
                 ↓
LLM Router analyzes:
  - Task complexity
  - Model availability
  - Provider credentials
                 ↓
Router calls: Claude / Gemini / Copilot / etc.
                 ↓
Router publishes: NATS llm.response
                 {
                   "result": "...",
                   "model": "claude-opus"
                 }
                 ↓
Agent receives response
```

### HITL Request Flow (Agent → Browser → Agent)

```
Agent publishes: NATS approval.request (request-reply)
                 {
                   "id": "uuid",
                   "file_path": "...",
                   "diff": "..."
                 }
                 ↓
HITL Bridge receives → broadcasts to WebSocket clients
                 ↓
Browser displays: ApprovalCard component
                 ↓
Human clicks: Approve / Reject button
                 ↓
Browser publishes: WebSocket message
                 {
                   "type": "approval_response",
                   "id": "uuid",
                   "approved": true
                 }
                 ↓
HITL Bridge receives → publishes to NATS reply subject
                 ↓
Agent receives: Approval decision
```

## Environment Variables

**Optional (defaults provided):**
```
NATS_URL=nats://localhost:4222    # NATS server address
PORT=3000                          # HTTP server port
NODE_ENV=development               # development or production
```

**Required Credentials (for LLM providers):**
- `ANTHROPIC_API_KEY` - Claude API access
- `GEMINI_API_KEY` - Gemini API access
- `OPENAI_API_KEY` - OpenAI API access
- `GITHUB_TOKEN` - GitHub Copilot access

## Testing

**Test Scripts:**
```bash
bun run test:approval   # Test approval flow (requires browser)
bun run test:question   # Test question flow (requires browser)
bun run test:hitl       # Full end-to-end test
```

**Manual Testing:**
1. Start NATS: `nats-server -js`
2. Start Nexus: `bun run dev`
3. Open browser: `http://localhost:3000/approvals`
4. Run test: `bun run test:approval`
5. Click button in browser
6. Verify response in terminal

## Architecture Principles

### Single Responsibility
- **LLM Router** - Only routes to AI providers
- **HITL Bridge** - Only connects NATS ↔ WebSocket
- **Remix UI** - Only renders UI, delegates logic to bridge

### Clear Separation
- Components initialize independently
- Failures in one don't crash others
- Each logs its status explicitly
- Graceful shutdown for all three

### Configuration-Driven
- Model selection via `MODEL_SELECTION_MATRIX`
- Provider implementations via `src/providers/`
- NATS topics via `approval.request`, `llm.request`, etc.
- UI routes via `app/routes/`

## Modifying Components

### Adding a New AI Provider

1. Create `src/providers/new-provider.ts`
2. Implement provider interface
3. Add to `MODEL_SELECTION_MATRIX` in `src/nats-handler.ts`
4. Set env variable for credentials
5. Test with `bun run test:approval`

### Adding a New HITL Request Type

1. Define message schema in `src/approval-websocket-bridge.ts`
2. Create component in `app/components/NewCard.tsx`
3. Add to `ApprovalCardsContainer.tsx`
4. Update `src/approval-websocket-bridge.ts` to subscribe to new NATS topic
5. Test with custom test script

### Adding a New Dashboard Metric

1. Add query to `app/routes/status.tsx`
2. Create component to display metric
3. Use Remix loader for data fetching
4. Style with Tailwind

## Debugging

### Check LLM Router
```bash
# Watch NATS llm.request topic
nats sub llm.request --raw

# Watch NATS llm.response topic
nats sub llm.response --raw
```

### Check HITL Bridge
```bash
# Watch NATS approval.request topic
nats sub approval.request --raw

# Check WebSocket connections
# DevTools → Network → WS tab → /ws/approval
```

### Check Remix UI
```bash
# Browser DevTools
# F12 → Console for JavaScript errors
# F12 → Network for HTTP/WebSocket messages
```

## Performance Notes

- **Bundle:** ~85 KB (gzipped) - lightweight compared to Next.js (200KB+)
- **Build:** 2-3 seconds
- **Dev startup:** <1 second
- **WebSocket roundtrip:** <100ms to NATS and back

## Status Summary

| Component | Status | Location |
|-----------|--------|----------|
| LLM Router | ✅ Complete | `src/nats-handler.ts` |
| HITL Bridge | ✅ Complete | `src/approval-websocket-bridge.ts` |
| Remix UI | ✅ Complete | `app/` + `src/server.ts` |
| Server Init | ✅ Complete | `src/server.ts` |
| Tests | ✅ Complete | `scripts/` |

---

**Architecture is clear, separation is explicit, and each component can be modified independently!**
