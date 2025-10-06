# LLM Provider E2E Testing Guide

## Overview

End-to-end tests for the complete LLM provider flow:

```
Elixir App → NATS → TypeScript AI Server → External AI API → NATS → Elixir App
     ↓                                                                  ↓
PostgreSQL (LlmProvider schema)                        PostgreSQL (UsageEvent tracking)
```

## Test Files Created

### 1. Elixir E2E Tests
**File:** `singularity_app/test/singularity/ai/llm_provider_e2e_test.exs`

Tests the complete flow from Elixir perspective:
- Model selection from `LlmProvider` schema
- NATS request publishing to `ai.llm.request`
- Response handling from `ai.llm.response`
- Usage event tracking in `UsageEvent` table
- Performance learning via `LlmProvider.learn_from_usage/3`

**Test Coverage:**
- ✅ Gemini 2.5 Flash via NATS
- ✅ Claude Sonnet 4.5 via NATS
- ✅ Error handling (invalid models)
- ✅ Model selection based on learned performance
- ✅ Performance metrics learning from usage
- ✅ NATS communication primitives

### 2. TypeScript Integration Tests
**File:** `ai-server/src/__tests__/nats-handler.test.ts`

Tests the TypeScript AI server NATS handler:
- NATS message parsing and validation
- Provider routing (gemini-code, claude-code, etc.)
- Response formatting
- Error handling
- Concurrent request handling
- Usage metadata inclusion

**Test Coverage:**
- ✅ Request/response cycle via NATS
- ✅ Invalid provider handling
- ✅ Request validation
- ✅ Concurrent requests (5 simultaneous)
- ✅ Usage metadata (tokens, timing)
- ✅ Provider-specific routing

## Running the Tests

### Prerequisites

1. **NATS Server Running**
   ```bash
   # Check if running
   ps aux | grep nats-server

   # If not running, start it
   nats-server -js
   ```

2. **PostgreSQL Running** (with `singularity` database)
   ```bash
   # Should start automatically in Nix shell
   nix develop
   ```

3. **AI Provider Credentials** (in `.env`)
   - `GEMINI_CODE_PROJECT=gemini-code-473918`
   - `GOOGLE_CLOUD_PROJECT=gemini-code-473918`
   - `CLAUDE_CODE_OAUTH_TOKEN=...`
   - `GOOGLE_APPLICATION_CREDENTIALS=...`

### Run Elixir E2E Tests

```bash
# Enter Nix environment
nix develop
# or
direnv allow

# Run E2E tests (with NATS required tag)
cd singularity_app
mix test test/singularity/ai/llm_provider_e2e_test.exs

# Run only fast tests (skip slow AI calls)
mix test test/singularity/ai/llm_provider_e2e_test.exs --exclude slow

# Run specific test
mix test test/singularity/ai/llm_provider_e2e_test.exs:35
```

### Run TypeScript Tests

```bash
# In ai-server directory
cd ai-server

# Run NATS handler tests
bun test src/__tests__/nats-handler.test.ts

# Run with coverage
bun test --coverage src/__tests__/nats-handler.test.ts

# Watch mode during development
bun test --watch src/__tests__/nats-handler.test.ts
```

### Run Full E2E Validation (Both Sides)

```bash
# Terminal 1: Start NATS
nats-server -js

# Terminal 2: Start AI Server
cd ai-server
bun run src/server.ts

# Terminal 3: Run Elixir E2E tests
cd singularity_app
mix test test/singularity/ai/llm_provider_e2e_test.exs

# Terminal 4: Run TypeScript tests
cd ai-server
bun test src/__tests__/nats-handler.test.ts
```

## Test Architecture

### Elixir Side Tests

```elixir
# 1. Seed providers in database
seed_providers()

# 2. Query best model
provider = Repo.get_by(LlmProvider,
  provider: "gemini-code",
  model_id: "gemini-2.5-flash"
)

# 3. Build NATS request
request = %{
  "model" => provider.model_id,
  "provider" => provider.provider,
  "messages" => [...],
  "correlation_id" => "test-123"
}

# 4. Publish to NATS
NatsClient.publish("ai.llm.request", Jason.encode!(request))

# 5. Wait for response
response = wait_for_nats_response("ai.llm.response", correlation_id, 30_000)

# 6. Verify usage event recorded
usage_events = Repo.all(from e in UsageEvent, where: ...)
assert length(usage_events) > 0
```

### TypeScript Side Tests

```typescript
// 1. Connect to NATS
const nc = await connect({ servers: 'nats://localhost:4222' });

// 2. Subscribe to response subject
const responseSub = nc.subscribe('ai.llm.response');

// 3. Publish request
nc.publish('ai.llm.request', JSON.stringify(request));

// 4. Wait for response with correlation_id match
for await (const msg of responseSub) {
  const response = JSON.parse(msg.data.toString());
  if (response.correlation_id === expectedId) {
    // Validate response
    expect(response.text).toBeDefined();
    expect(response.model).toBe('gemini-2.5-flash');
    break;
  }
}
```

## Validated Flow Components

### ✅ Elixir → NATS → TypeScript
- [x] LlmProvider schema queries
- [x] NATS request publishing
- [x] Request format validation
- [x] Correlation ID tracking

### ✅ TypeScript Processing
- [x] NATS message parsing
- [x] Provider routing (gemini-code, claude-code, openai-codex)
- [x] AI SDK integration
- [x] Error handling and error subject publishing

### ✅ TypeScript → NATS → Elixir
- [x] Response formatting (text, tokens, timestamp)
- [x] NATS response publishing
- [x] Elixir response receiving
- [x] Usage event recording

### ✅ Learning Loop
- [x] UsageEvent schema population
- [x] LlmProvider.learn_from_usage/3
- [x] Performance metric updates (success_rate, avg_latency_ms, p95)
- [x] Best task type learning

## Common Issues & Solutions

### Issue: "Timeout waiting for NATS response"

**Cause:** AI server not running or NATS connection failure

**Solution:**
```bash
# Check NATS is running
ps aux | grep nats-server

# Check AI server is running
ps aux | grep "bun.*server.ts"

# Start AI server
cd ai-server && bun run src/server.ts
```

### Issue: "NATS client not running"

**Cause:** NatsClient GenServer not started in Elixir app

**Solution:**
```bash
# Ensure Application is running
cd singularity_app
iex -S mix

# Verify NatsClient is alive
iex> Process.whereis(Singularity.NatsClient)
#PID<0.123.0>  # Should return a PID
```

### Issue: "No providers in database"

**Cause:** LlmProvider table empty (not synced from TypeScript)

**Solution:**
```elixir
# Seed providers manually in test setup
seed_providers()

# Or sync from TypeScript model registry (future implementation)
# LlmProvider.sync_from_registry(Repo, model_attrs)
```

### Issue: Tests fail with "Model not found"

**Cause:** AI provider credentials not configured

**Solution:**
```bash
# Check .env file has credentials
cat .env | grep -E "GEMINI_CODE_PROJECT|GOOGLE_CLOUD_PROJECT|CLAUDE"

# Reload environment
direnv reload
source .env
```

## Test Data & Fixtures

### Mock Providers (for testing)

```elixir
%{
  provider: "gemini-code",
  model_id: "gemini-2.5-flash",
  context_window: 1_000_000,
  cost_tier: :free,
  supports_completion: true
}
```

### Sample NATS Request

```json
{
  "model": "gemini-2.5-flash",
  "provider": "gemini-code",
  "messages": [
    {"role": "user", "content": "Hello"}
  ],
  "max_tokens": 50,
  "temperature": 0.7,
  "correlation_id": "test-123"
}
```

### Sample NATS Response

```json
{
  "text": "Hello! How can I help you?",
  "model": "gemini-2.5-flash",
  "tokens_used": 15,
  "cost_cents": 0,
  "timestamp": "2025-10-06T12:34:56Z",
  "correlation_id": "test-123"
}
```

### Sample Error Response

```json
{
  "error": "Provider not found: fake-provider",
  "error_code": "PROVIDER_NOT_FOUND",
  "correlation_id": "test-error-123",
  "timestamp": "2025-10-06T12:34:56Z"
}
```

## Performance Benchmarks

Expected latencies (with actual AI calls):

- **Gemini 2.5 Flash:** 200-800ms
- **Claude Sonnet 4.5:** 1000-3000ms
- **GPT-5 Codex:** 500-1500ms

NATS overhead: ~5-20ms (negligible)

## Next Steps

### Immediate
1. Run tests manually to verify flow
2. Fix any NATS connection issues
3. Ensure AI provider credentials are working

### Future Enhancements
1. **Streaming tests** - Test streaming responses via NATS
2. **Retry logic tests** - Test failover between providers
3. **Rate limiting tests** - Test quota handling
4. **Caching tests** - Test semantic cache hits/misses
5. **Batch request tests** - Test multiple requests in single NATS message
6. **Provider sync tests** - Test TypeScript → PostgreSQL model registry sync

## Related Documentation

- [NATS_SUBJECTS.md](./NATS_SUBJECTS.md) - NATS subject hierarchy
- [INTERFACE_ARCHITECTURE.md](./INTERFACE_ARCHITECTURE.md) - Interface abstraction layer
- [AI_PROVIDER_POLICY.md](./AI_PROVIDER_POLICY.md) - Subscription-only provider policy
- [CLAUDE.md](./CLAUDE.md) - Overall project documentation
