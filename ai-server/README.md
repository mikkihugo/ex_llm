# AI Server - PostgreSQL-Native AI Orchestration

Replace NATS-based AI provider routing with PostgreSQL-native workflows using pgflow.

## Architecture

```
Singularity (Elixir/Oban)
    ↓ Enqueue LLM request
PostgreSQL pgmq:ai_requests
    ↓
AI Server (TypeScript/pgflow)
    ↓ Poll pgmq, execute workflow
Execute LLM Provider (Claude, Gemini, OpenAI)
    ↓ Store result
PostgreSQL pgmq:ai_results
    ↓
Singularity (Elixir/Oban)
    ↓ Poll results
Process Response
```

## Quick Start

### 1. Setup Environment

```bash
# Install dependencies
bun install

# Setup database (from singularity-incubation root)
cd ../singularity
mix ecto.setup

# Ensure pgmq extension is installed
psql singularity -c "CREATE EXTENSION IF NOT EXISTS pgmq"
```

### 2. Start Services

```bash
# Terminal 1: Start Singularity (Elixir)
cd singularity
mix phx.server

# Terminal 2: Start AI Server (TypeScript/pgflow)
cd ai-server
bun run dev
```

### 3. Test LLM Routing

```bash
# In Singularity iex console
iex(1)> alias Singularity.Jobs.LlmRequestWorker
iex(2)> LlmRequestWorker.enqueue_llm_request(:architect, [%{"role" => "user", "content" => "Design a search engine"}])
{:ok, "uuid-here"}

# Check ai-server logs - should show the request being processed
# Check pgmq:ai_results - ai-server will publish result there
# LlmResultPoller will read and store result
```

## Workflows

### LLM Request Workflow

Handles routing to Claude, Gemini, OpenAI based on:
- **Task Complexity**: simple (classifier, parser) → medium (coder, planning) → complex (architect, code_generation)
- **Model Selection**: Gemini Flash (simple), Claude Sonnet (medium), Claude Opus (complex)
- **Cost Optimization**: Tracks tokens, cost per request

**Steps:**
1. Receive request from pgmq:ai_requests
2. Analyze task type and determine complexity
3. Select best model/provider based on availability
4. Call LLM provider API
5. Publish result to pgmq:ai_results

**Configuration:**
- Model selection matrix in `selectBestModel()`
- Task complexity mapping in `getComplexityForTask()`
- Provider credentials via environment variables

### Embedding Workflow

Generates semantic embeddings for code and text.

**Steps:**
1. Receive query from pgmq:embedding_requests
2. Generate embedding (call Singularity NxService or external API)
3. Publish embedding vector to pgmq:embedding_results

### Agent Coordination Workflow

Routes messages between Singularity agents for inter-agent communication.

**Steps:**
1. Receive coordination message from pgmq:agent_messages
2. Route message to target agent
3. Publish response to pgmq:agent_responses

## pgmq Queues

| Queue | Direction | Content | Consumer |
|-------|-----------|---------|----------|
| `ai_requests` | Singularity → AI Server | LLM request (task_type, messages, model) | pgflow llmRequestWorkflow |
| `ai_results` | AI Server → Singularity | LLM response (text, model, tokens, cost) | LlmResultPoller Oban job |
| `embedding_requests` | Singularity → AI Server | Embedding request (query, model) | pgflow embeddingWorkflow |
| `embedding_results` | AI Server → Singularity | Embedding vector (dimensions, array) | Embedding consumer |
| `agent_messages` | Singularity → AI Server | Agent message (source, target, type) | pgflow agentCoordinationWorkflow |
| `agent_responses` | AI Server → Singularity | Agent response | Agent consumer |

## Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://postgres@localhost:5432/singularity
PORT=3001

# LLM Provider Credentials
ANTHROPIC_API_KEY=sk-...          # Claude API
GEMINI_API_KEY=...                # Gemini API
OPENAI_API_KEY=sk-...             # OpenAI API

# Node environment
NODE_ENV=development              # development or production
```

### Model Selection

Customize model selection in `src/index.ts` → `selectBestModel()`:

```typescript
function selectBestModel(complexity: string) {
  switch (complexity) {
    case "simple":
      return { model: "gemini-1.5-flash", provider: "gemini" };
    case "medium":
      return { model: "claude-sonnet-4.5", provider: "anthropic" };
    case "complex":
      return { model: "claude-opus", provider: "anthropic" };
  }
}
```

## Development

### Run in Development Mode

```bash
bun run dev
```

Watches source files and restarts on changes.

### Production Build

```bash
bun run build
bun run start
```

### Testing

Test LLM requests from Singularity:

```elixir
# In iex console
iex> import Singularity.Jobs.LlmRequestWorker
iex> enqueue_llm_request("architect", [%{"role" => "user", "content" => "Design a system"}])

# Check logs in AI Server terminal
# Should see: "Received LLM request" → "Selected model" → "Processing LLM request"
```

## Architecture Decisions

### Why pgflow + pgmq?

1. **Single Source of Truth**: PostgreSQL handles all state
2. **No Network Overhead**: Direct database queries (vs NATS network calls)
3. **Built-in Durability**: Messages persist in pgmq until acknowledged
4. **Automatic Retry**: pgmq handles message expiration and retry
5. **PostgreSQL Native**: Works with existing infrastructure

### Why TypeScript for AI Server?

1. **LLM SDKs**: Better TypeScript support (Claude SDK, Anthropic SDK)
2. **Async/Await**: Natural fit for IO-heavy operations
3. **Bun Runtime**: Lightweight, fast startup (vs Node.js)
4. **pgflow**: Currently TypeScript-only (Elixir side uses Oban)

### Future Improvements

- [ ] Implement actual LLM provider calls in `callProvider()`
- [ ] Add monitoring/metrics for LLM performance
- [ ] Implement request priority levels
- [ ] Add rate limiting per provider
- [ ] Implement request batching for embeddings
- [ ] Add caching for repeated queries
- [ ] Implement fallback providers

## Troubleshooting

### No messages in pgmq:ai_requests

Check that Singularity is running and LlmRequestWorker is enqueuing jobs:

```bash
# In Singularity iex
iex> Oban.Web.get_jobs(:default) |> Enum.take(5)
# Should see LlmRequestWorker jobs
```

### AI Server not processing messages

Check database connection:

```bash
# Test pgmq connection
psql singularity -c "SELECT * FROM pgmq.read('ai_requests', limit => 1)"
```

### LLM API calls failing

Verify environment variables:

```bash
echo $ANTHROPIC_API_KEY
echo $GEMINI_API_KEY
echo $OPENAI_API_KEY
```

## Related Files

- **Singularity Jobs**: `singularity/lib/singularity/jobs/`
  - `pgmq_client.ex` - pgmq helper functions
  - `llm_request_worker.ex` - Enqueue LLM requests
  - `llm_result_poller.ex` - Poll for LLM results
  - `centralcloud_update_worker.ex` - Send updates to CentralCloud

- **Workflows**: `ai-server/src/workflows.ts`
  - `llmRequestWorkflow` - LLM routing
  - `embeddingWorkflow` - Embedding generation
  - `agentCoordinationWorkflow` - Agent messaging

## Architecture Overview (from CLAUDE.md)

See `CLAUDE.md` for complete architecture including:
- Hybrid orchestration (Oban + pgflow)
- PostgreSQL as message queue
- Multi-instance learning via CentralCloud
- LLM routing by complexity
- Cost optimization strategies
