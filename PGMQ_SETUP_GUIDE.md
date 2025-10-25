# PostgreSQL Message Queue (pgmq) Setup Guide

Complete guide to setting up the pgmq-based orchestration replacing NATS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Singularity (Elixir/Oban)                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ LLM Request Worker: Enqueue request to pgmq             │ │
│ │ → Oban job execution → PgmqClient.send_message()        │ │
│ │ → INSERT INTO pgmq.ai_requests                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────┘
                                   │
                            PostgreSQL pgmq
                          ┌─────────────────────┐
                          │ ai_requests queue   │
                          │ ai_results queue    │
                          │ Other message queues│
                          └─────────────────────┘
                                   │
┌──────────────────────────────────┴──────────────────────────┐
│ AI Server (TypeScript/pgflow)                               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Workflow Processor: Poll pgmq for requests              │ │
│ │ → Read from pgmq:ai_requests                            │ │
│ │ → Execute pgflow workflows (LLM, Embedding, Agent)      │ │
│ │ → Write results to pgmq:ai_results                      │ │
│ └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────┘
                                   │
                            PostgreSQL pgmq
                          ┌─────────────────────┐
                          │ ai_results queue    │
                          └─────────────────────┘
                                   │
┌──────────────────────────────────┴──────────────────────────┐
│ Singularity (Elixir/Oban)                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ LLM Result Poller: Poll pgmq for results                │ │
│ │ → Oban job execution every 5 seconds                    │ │
│ │ → SELECT * FROM pgmq.read('ai_results')                 │ │
│ │ → Process and acknowledge messages                      │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 1. Database Setup

### 1.1 Create pgmq Extension

```bash
# Connect to singularity database
psql singularity

# Create pgmq extension
CREATE EXTENSION IF NOT EXISTS pgmq;

# Verify extension is installed
SELECT * FROM pg_extension WHERE extname = 'pgmq';
```

### 1.2 Verify pgmq is Installed

```bash
# Check if pgmq binary is available
which pgmq

# Check version
pgmq --version

# If not installed, install via Nix (should be in flake.nix):
# nix develop   # Restarts environment with pgmq available
```

## 2. Singularity (Elixir/Oban) Setup

### 2.1 PgmqClient Module

**Location:** `singularity/lib/singularity/jobs/pgmq_client.ex`

Core functions:
- `send_message(queue_name, message)` - Publish message to queue
- `read_messages(queue_name, limit)` - Read pending messages
- `ack_message(queue_name, message_id)` - Acknowledge/delete message
- `ensure_queue(queue_name)` - Create queue if needed
- `ensure_all_queues()` - Initialize all required queues

### 2.2 Oban Job Modules

#### LlmRequestWorker
**Location:** `singularity/lib/singularity/jobs/llm_request_worker.ex`

Enqueues LLM requests to pgmq for ai-server processing.

```elixir
# Usage
alias Singularity.Jobs.LlmRequestWorker

# Enqueue an LLM request
{:ok, request_id} = LlmRequestWorker.enqueue_llm_request(
  "architect",  # task_type
  [%{"role" => "user", "content" => "Design a system"}],  # messages
  model: "auto"  # options
)

# Result will be written to pgmq:ai_results by ai-server
```

#### LlmResultPoller
**Location:** `singularity/lib/singularity/jobs/llm_result_poller.ex`

Polls pgmq:ai_results for responses from ai-server.

```bash
# Configure in config/config.exs to run every 5 seconds:
config :oban,
  crons: [
    llm_result_poller: [
      schedule: "*/5 * * * * *",  # Every 5 seconds
      job: {Singularity.Jobs.LlmResultPoller, []}
    ]
  ]
```

#### CentralCloudUpdateWorker
**Location:** `singularity/lib/singularity/jobs/centralcloud_update_worker.ex`

Sends knowledge updates back to CentralCloud via pgmq.

```elixir
# Usage (automatic)
# Enqueued by Singularity.Integrations.CentralCloud.analyze_codebase/2
# Message format:
# {
#   "instance_id": "...",
#   "patterns": [...],
#   "insights": [...],
#   "timestamp": "2025-10-25T...",
#   "event_type": "knowledge_update"
# }
```

### 2.3 Configuration

**File:** `singularity/config/config.exs`

```elixir
# Ensure pgmq queues are initialized on startup
config :singularity,
  pgmq_queues: [
    "ai_requests",
    "ai_results",
    "embedding_requests",
    "embedding_results",
    "agent_messages",
    "agent_responses",
    "centralcloud_updates"
  ]
```

### 2.4 Initialization (on Application Start)

Add to your application supervisor or startup code:

```elixir
# Initialize pgmq queues on startup
Singularity.Jobs.PgmqClient.ensure_all_queues()

Logger.info("✅ pgmq queues initialized")
```

## 3. AI Server (TypeScript/pgflow) Setup

### 3.1 Installation

```bash
cd ai-server
bun install
```

### 3.2 Configuration

**File:** `ai-server/src/index.ts`

```typescript
// Environment variables (set in shell or .env)
const DATABASE_URL = process.env.DATABASE_URL
  || "postgresql://postgres@localhost:5432/singularity";
const NODE_ENV = process.env.NODE_ENV || "development";

// LLM Provider credentials
process.env.ANTHROPIC_API_KEY   // Claude
process.env.GEMINI_API_KEY      // Gemini
process.env.OPENAI_API_KEY      // OpenAI
```

### 3.3 Start AI Server

```bash
# Development
bun run dev

# Production
bun run build
bun run start
```

### 3.4 Workflows

**File:** `ai-server/src/workflows.ts`

Three workflows handle different task types:

#### 1. llmRequestWorkflow
- Receives: `ai_requests` queue
- Processes: LLM request routing and API calls
- Publishes: `ai_results` queue
- Models: Gemini Flash (simple), Claude Sonnet (medium), Claude Opus (complex)

#### 2. embeddingWorkflow
- Receives: `embedding_requests` queue
- Processes: Semantic embedding generation
- Publishes: `embedding_results` queue
- Models: Qodo, Jina v3

#### 3. agentCoordinationWorkflow
- Receives: `agent_messages` queue
- Processes: Inter-agent message routing
- Publishes: `agent_responses` queue

## 4. Message Formats

### LLM Request

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "architect",
  "messages": [
    {
      "role": "user",
      "content": "Design a scalable API architecture"
    }
  ],
  "model": "auto",
  "provider": "auto",
  "enqueued_at": "2025-10-25T11:00:00Z"
}
```

### LLM Result

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "response": "Here's an architecture design...",
  "model": "claude-opus",
  "tokens_used": 1250,
  "cost_cents": 50,
  "timestamp": "2025-10-25T11:00:05Z"
}
```

### Embedding Request

```json
{
  "query_id": "550e8400-e29b-41d4-a716-446655440001",
  "query": "async request handling",
  "model": "qodo",
  "received_at": "2025-10-25T11:00:00Z"
}
```

### Embedding Result

```json
{
  "query_id": "550e8400-e29b-41d4-a716-446655440001",
  "embedding": [0.123, 0.456, ..., 0.789],
  "embedding_dim": 2560,
  "timestamp": "2025-10-25T11:00:05Z"
}
```

## 5. Testing

### Test LLM Request Flow

```bash
# Terminal 1: Start Singularity
cd singularity
mix phx.server

# Terminal 2: Start AI Server
cd ai-server
bun run dev

# Terminal 3: Test in iex
cd singularity
iex -S mix

# In iex console:
iex(1)> alias Singularity.Jobs.LlmRequestWorker
iex(2)> {:ok, request_id} = LlmRequestWorker.enqueue_llm_request("architect", [%{"role" => "user", "content" => "Design a cache"}])
{:ok, "550e8400-..."}

# Check AI Server logs - should show request processing
# Check pgmq:ai_results - should contain response after a few seconds
```

### Monitor pgmq Queues

```bash
# Check queue size
psql singularity -c "SELECT COUNT(*) FROM pgmq.ai_requests;"

# Read messages without consuming
psql singularity -c "SELECT msg_id, msg_body FROM pgmq.read('ai_requests', limit => 5);"

# View all queues and counts
psql singularity -c "
SELECT
  queue_name,
  COUNT(*) as pending_messages
FROM pgmq.queue_stats()
GROUP BY queue_name
ORDER BY pending_messages DESC;
"
```

## 6. Monitoring & Debugging

### AI Server Health

```bash
# Check if AI Server is polling pgmq
# Look for logs: "Polling ai_requests queue"
# Should appear every 1 second

tail -f logs/ai-server.log | grep "Polling"
```

### Singularity Health

```bash
# Monitor Oban jobs
iex(1)> Oban.Job.select() |> Singularity.Repo.all() |> Enum.take(5)

# Monitor LLM requests
iex(2)> alias Singularity.Jobs.LlmRequestWorker
iex(3)> alias Singularity.Repo
iex(4)> Repo.query!("SELECT COUNT(*) FROM pgmq.ai_requests") |> Enum.at(0)
```

### Database Debugging

```bash
# Check if pgmq is working
psql singularity

# List all pgmq functions
\df pgmq.*

# Send test message
SELECT pgmq.send('ai_requests', '{"test": "message"}');

# Read test message
SELECT msg_id, msg_body FROM pgmq.read('ai_requests', limit => 1);
```

## 7. Troubleshooting

### "pgmq extension not found"

```bash
# Check if pgmq is available in Nix environment
which pgmq

# If not found, restart nix develop
nix flake update
direnv allow
exit
nix develop
```

### "Could not connect to database"

```bash
# Verify PostgreSQL is running
psql postgres -c "SELECT 1"

# Check DATABASE_URL
echo $DATABASE_URL

# Test connection
psql "$DATABASE_URL" -c "SELECT 1"
```

### Messages not being processed

```bash
# Check if AI Server is running
ps aux | grep "ai-server"

# Check for errors in AI Server logs
bun run dev  # Will show errors in terminal

# Verify pgmq queue has messages
psql singularity -c "SELECT COUNT(*) FROM pgmq.ai_requests;"

# Check if Oban jobs are queuing
iex(1)> Oban.Web.get_jobs(:default, state: "available") |> length()
```

### Slow message processing

```bash
# Check AI Server latency by monitoring timestamps
psql singularity -c "
SELECT
  (msg_body->>'enqueued_at')::timestamp as enqueued,
  NOW() as now,
  EXTRACT(EPOCH FROM (NOW() - (msg_body->>'enqueued_at')::timestamp)) as seconds_pending
FROM pgmq.read('ai_requests', limit => 1);
"

# Monitor AI Server's request rate
tail -f logs/ai-server.log | grep "Processing LLM"
```

## 8. Production Deployment

### Environment Variables

```bash
# Required
export DATABASE_URL="postgresql://user:password@host:5432/singularity"
export ANTHROPIC_API_KEY="sk-..."
export GEMINI_API_KEY="..."
export NODE_ENV="production"

# Optional
export PORT=3001
export SINGULARITY_INSTANCE_ID="prod-instance-1"
```

### Scaling

**pgmq Queue Performance:**
- Handles 1000+ messages/second per queue
- Consider separate PostgreSQL instance for very high load

**AI Server Scaling:**
- Run multiple ai-server instances (each polls independently)
- Each instance processes concurrently

**Singularity Scaling:**
- Oban jobs scale with configured concurrency
- Adjust queue concurrency in config.exs

## 9. Related Files

**Singularity (Elixir/Oban):**
- `lib/singularity/jobs/pgmq_client.ex` - Core pgmq API
- `lib/singularity/jobs/llm_request_worker.ex` - Enqueue requests
- `lib/singularity/jobs/llm_result_poller.ex` - Poll results
- `lib/singularity/jobs/centralcloud_update_worker.ex` - Knowledge sync
- `lib/singularity/integrations/central_cloud.ex` - CentralCloud integration

**AI Server (TypeScript/pgflow):**
- `ai-server/src/index.ts` - Main entry point
- `ai-server/src/workflows.ts` - pgflow workflows
- `ai-server/package.json` - Dependencies

**Configuration:**
- `config/config.exs` - Oban queues and crons
- `.envrc` - Environment variables

## 10. Next Steps

1. ✅ Set up pgmq extension in PostgreSQL
2. ✅ Start Singularity with Oban jobs
3. ✅ Start AI Server with pgflow workflows
4. ✅ Test LLM request flow end-to-end
5. ✅ Monitor pgmq queues for performance
6. ⏳ Add result persistence to database
7. ⏳ Implement provider credential management
8. ⏳ Add comprehensive monitoring/alerts
9. ⏳ Scale to multi-instance deployment
10. ⏳ Optimize for high-throughput scenarios

---

**Last Updated:** 2025-10-25
**Status:** Active Development
**Version:** 1.0
