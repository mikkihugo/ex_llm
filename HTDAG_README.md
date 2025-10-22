# HTDAG Self-Evolution with NATS LLM Integration

This implementation enables the HTDAG (Hierarchical Task Directed Acyclic Graph) system to self-evolve using external LLM workers via NATS.

## What's New

### Core Components

1. **`Singularity.LLM.NatsOperation`** - DSPy-like operation interface for LLM calls
   - Request/Reply pattern via NATS
   - Optional token streaming
   - Built-in rate limiting and circuit breaking
   - Telemetry instrumentation

2. **`Singularity.Planning.HTDAGExecutor`** - Executes task DAGs with LLM integration
   - Automatic model selection based on task complexity
   - Timeout handling
   - Parallel execution support (future)

3. **`Singularity.Planning.HTDAGEvolution`** - Self-improvement through critique
   - LLM-based critique of execution results
   - Mutation proposals (model changes, parameter tuning)
   - Performance evaluation

4. **`HTDAGLLMWorker`** (TypeScript) - NATS worker for AI server
   - Handles `llm.req.*` subjects
   - Supports streaming and non-streaming
   - Integrated with existing AI server

### Integration Points

- **Existing**: `ai.llm.request` → AI Server (original path)
- **New**: `llm.req.<model_id>` → HTDAG LLM Worker (self-evolution path)

Both paths coexist. The HTDAG executor uses the new NATS-first path.

## Quick Start

```bash
# 1. Start NATS
nats-server -js -sd .nats -p 4222

# 2. Start AI Server (includes HTDAG worker)
cd llm-server
bun run dev

# 3. Test the integration
elixir test_htdag_nats.exs
```

## Usage Example

```elixir
# Create and execute a self-evolving HTDAG
alias Singularity.Planning.HTDAG

dag = HTDAG.decompose(%{
  description: "Build user authentication with JWT"
})

{:ok, result} = HTDAG.execute_with_nats(dag,
  run_id: "auth-build-1",
  stream: true,      # Enable token streaming
  evolve: true       # Enable self-improvement
)

# Result includes:
# - completed: number of completed tasks
# - failed: number of failed tasks
# - results: execution outputs per task
# - mutations_applied: improvements made
```

## NATS Message Flow

```
Elixir HTDAG Executor
  │
  ├─> NATS: llm.req.claude-sonnet-4.5
  │   {
  │     run_id: "run-123",
  │     node_id: "task-1",
  │     model_id: "claude-sonnet-4.5",
  │     input: {messages: [...]},
  │     params: {stream: true}
  │   }
  │
  ├─< NATS: llm.tokens.run-123.task-1 (streaming)
  │   {chunk: "Task ", seq: 1, done: false}
  │   {chunk: "decomposition...", seq: 2, done: false}
  │   {chunk: "", seq: 3, done: true}
  │
  └─< NATS: llm.resp.run-123.task-1 (final)
      {
        output: "Task decomposition:\n1. ...",
        usage: {total_tokens: 350},
        finish_reason: "stop"
      }
```

## Self-Evolution Flow

1. **Execute** - Run HTDAG tasks with LLM operations
2. **Collect Metrics** - Track tokens, latency, success rate
3. **Critique** - Use LLM to analyze performance
4. **Mutate** - Apply improvements (model selection, parameters)
5. **Repeat** - Execute again with improved configuration

Example mutations:

- Switch from `gemini-1.5-flash` to `claude-sonnet-4.5` for complex tasks
- Lower temperature from `0.7` to `0.3` for deterministic outputs
- Improve prompt templates based on successful patterns

## Documentation

- **[HTDAG_NATS_INTEGRATION.md](./HTDAG_NATS_INTEGRATION.md)** - Full architecture and API reference
- **[NATS_SUBJECTS.md](./NATS_SUBJECTS.md)** - NATS subject conventions

## Testing

```bash
# Basic test (mock execution)
elixir test_htdag_nats.exs

# Full integration test (requires NATS + AI server)
cd singularity
mix test test/singularity/planning/htdag_executor_test.exs
```

## What's Working

✅ NATS LLM operation module with rate limiting and circuit breaking  
✅ HTDAG executor with model selection  
✅ Evolution module with critique and mutations  
✅ AI server HTDAG worker for `llm.req.*` subjects  
✅ Streaming token support  
✅ Telemetry instrumentation  

## What's Next

⏳ Full integration testing with live NATS + AI server  
⏳ Worker pool management and health monitoring  
⏳ Caching layer for common decompositions  
⏳ Parallel task execution  
⏳ A/B testing framework for mutations  

## Architecture Notes

This is a **NATS-first, self-evolving** architecture where:

- All LLM calls go through NATS (no direct API calls)
- Tasks decompose themselves via LLM
- The system improves through critique loops
- Rate limiting and circuit breaking prevent runaway costs
- Telemetry tracks every operation for analysis

The minimal design allows launching with just:
1. NATS server
2. AI server with HTDAG worker
3. Claude CLI or any LLM provider

The system can then fix itself and improve over time.
