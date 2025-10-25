# Nexus - LLM Router & HITL Bridge

Elixir-based LLM router that consumes requests from pgmq and routes them to appropriate AI providers using [ex_llm](../packages/ex_llm).

## Overview

Nexus replaces the previous TypeScript/Bun implementation with a pure Elixir solution that:
- **Routes LLM requests** from Singularity agents to appropriate providers
- **Uses ex_llm** for unified provider access (Claude, GPT, Gemini, etc.)
- **Consumes from pgmq** (`llm_requests` queue)
- **Publishes results** back to pgmq (`llm_results` queue)

## Architecture

```
Singularity Agent
    ↓ publishes to pgmq
llm_requests queue
    ↓ consumed by
Nexus.QueueConsumer
    ↓ routes via
Nexus.LLMRouter (uses ex_llm)
    ↓ HTTP calls
AI Provider APIs (Claude, GPT, Gemini, etc.)
    ↓ results
Nexus.QueueConsumer
    ↓ publishes to pgmq
llm_results queue
    ↓ consumed by
Singularity Agent
```

## Components

### 1. LLM Router (`lib/nexus/llm_router.ex`)
- **Model selection** based on complexity (:simple, :medium, :complex)
- **Provider routing** via ex_llm
- **Intelligent defaults**:
  - Simple tasks → Gemini Flash (free, fast)
  - Medium tasks → Claude Sonnet or GPT-4o
  - Complex tasks → Claude Sonnet

### 2. Queue Consumer (`lib/nexus/queue_consumer.ex`)
- **Polls pgmq** for LLM requests (1 second interval, 10 messages/batch)
- **Routes requests** through LLMRouter
- **Publishes results** back to pgmq
- **Archives processed messages**

### 3. Application (`lib/nexus/application.ex`)
- **Starts QueueConsumer** in supervision tree
- **Configures polling** and database connection

## Configuration

### Environment Variables

```bash
# Required: Shared queue database
SHARED_QUEUE_DB_URL="postgresql://postgres:@localhost:5432/shared_queue"

# Required: AI provider API keys (set at least one)
ANTHROPIC_API_KEY="sk-ant-..."
OPENAI_API_KEY="sk-..."
GEMINI_API_KEY="..."
GROQ_API_KEY="gsk_..."

# Optional: Queue polling settings
NEXUS_POLL_INTERVAL_MS=1000  # Polling interval (default: 1000ms)
NEXUS_BATCH_SIZE=10          # Messages per batch (default: 10)
```

### Dependencies

- `ex_llm` - Unified LLM client (local fork at `packages/ex_llm`)
- `pgmq` - PostgreSQL message queue
- `jason` - JSON encoding/decoding
- `postgrex` - PostgreSQL driver

## Development

### Setup

```bash
# Install dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test

# Start application
iex -S mix
```

### Running with Overmind

```bash
# Start all services (includes Nexus)
overmind start

# Or start just Nexus
overmind start nexus
```

## Message Format

### Input Message (llm_requests queue)

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "agent_id": "self-improving-agent",
  "complexity": "complex",
  "task_type": "architect",
  "messages": [
    {"role": "user", "content": "Design a new feature"}
  ],
  "max_tokens": 4000,
  "temperature": 0.7,
  "timestamp": "2025-10-25T22:00:00Z"
}
```

### Output Message (llm_results queue)

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "agent_id": "self-improving-agent",
  "response": "Here's the architectural design...",
  "model": "claude-3-5-sonnet-20241022",
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 800,
    "total_tokens": 950
  },
  "cost": 0.0285,
  "timestamp": "2025-10-25T22:00:05Z"
}
```

## Model Selection

Nexus intelligently selects models based on task complexity and type:

| Complexity | Task Type | Model | Reasoning |
|------------|-----------|-------|-----------|
| `:simple` | any | Gemini Flash | Free, fast for simple tasks |
| `:medium` | `:coder` | Claude Sonnet | Excellent code generation |
| `:medium` | `:planning` | GPT-4o | Strong planning capabilities |
| `:complex` | `:architect` | Claude Sonnet | Best for architecture design |
| `:complex` | `:code_generation` | Claude Sonnet | Complex code generation |

## Comparison with Previous TypeScript Implementation

| Feature | TypeScript (Removed) | Elixir (New) |
|---------|---------------------|--------------|
| Language | TypeScript/Bun | Elixir |
| LLM Client | Custom providers | ex_llm (unified) |
| Concurrency | Node.js event loop | BEAM processes |
| Fault Tolerance | Manual error handling | OTP supervision |
| Hot Reloading | No | Yes (BEAM) |
| Dependencies | ~50 npm packages | 5 Hex packages |
| Lines of Code | ~3,000 | ~500 |

## Future Enhancements

- [ ] HITL approval workflow integration
- [ ] Response streaming support
- [ ] Cost tracking and budget limits
- [ ] Provider health monitoring
- [ ] Dynamic model selection based on cost/performance
- [ ] Multi-provider fallback chains

## License

Same as parent Singularity project.
