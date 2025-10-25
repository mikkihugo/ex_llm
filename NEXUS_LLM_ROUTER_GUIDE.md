# Nexus as LLM Router (LiteLLM Equivalent)

## Overview

**Nexus Bun Server** (`src/nats-handler.ts`) is the central **LLM Router** that:
- Receives all LLM requests via NATS
- Analyzes request complexity
- Checks provider availability
- Selects optimal model
- Routes to appropriate AI provider
- Returns response to caller

This is equivalent to **LiteLLM** but for Singularity's NATS-based architecture.

## Architecture

### Traditional Stack (External LLM Gateway)

```
┌─────────────────────────────────────────┐
│ Application                             │
└────────────┬────────────────────────────┘
             │ HTTP
             ↓
┌─────────────────────────────────────────┐
│ LiteLLM Proxy                           │
│ - Manages multiple providers            │
│ - Routes based on availability          │
│ - Tracks costs/usage                    │
└────────────┬────────────────────────────┘
             │ HTTP
             ↓
┌──────────────────────────────────────────────────────────┐
│ AI Providers (Claude, GPT, Gemini, etc)                  │
└──────────────────────────────────────────────────────────┘
```

### Singularity Stack (Nexus as Router)

```
┌──────────────────────────────────────────┐
│ Singularity Agents (Elixir/OTP)          │
│ ├─ Self-Improving Agent                  │
│ ├─ Architecture Agent                    │
│ ├─ Refactoring Agent                     │
│ └─ Chat Agent                            │
└────────────┬─────────────────────────────┘
             │ NATS llm.request
             ↓
┌──────────────────────────────────────────┐
│ Nexus LLM Router (Bun, src/nats-handler) │
│ ├─ Task complexity analysis              │
│ ├─ Provider availability checking        │
│ ├─ Model selection                       │
│ └─ Cost optimization                     │
└────────────┬─────────────────────────────┘
             │ Multiple Paths
      ┌──────┼──────┬──────────┐
      ↓      ↓      ↓          ↓
    Claude Gemini OpenAI Copilot
```

### Browser Chat Path

```
Browser UI (React)
    ↓ POST /api/chat
Next.js API Route
    ↓ NATS llm.request
Nexus Router (same handler!)
    ↓ Select provider/model
AI Provider
    ↓ NATS reply
API Route (SSE stream)
    ↓ useChat hook updates
Browser displays response
```

## Key Components

### 1. NATS Handler (`src/nats-handler.ts`)

**Responsibilities**:
- Listen on `llm.request` topic
- Parse and validate requests
- Analyze task complexity
- Select model/provider
- Handle errors and timeouts
- Publish responses

**Key Methods**:

```typescript
class NATSHandler {
  // Subscribe to NATS topic
  async subscribeToLLMRequests()

  // Main request processor
  async handleSingleLLMRequest(msg)

  // Resolve which provider to use
  private resolveModelSelection(request)

  // Make actual provider call
  private handleNonStreamingRequest(provider, model, messages, options)
}
```

### 2. Model Selection Matrix

Intelligent model selection based on:
- **Task Type**: general, architect, coder, qa
- **Complexity**: simple, medium, complex
- **Provider Hints**: User preferences
- **Capabilities**: reasoning, code, vision, speed

```typescript
const MODEL_SELECTION_MATRIX = {
  architect: {
    complex: [
      { provider: 'claude', model: 'opus' },
      { provider: 'openrouter', model: 'auto' },
      { provider: 'copilot', model: 'gpt-4o' }
    ]
  },
  coder: {
    simple: [
      { provider: 'copilot', model: 'gpt-5-mini' },
      { provider: 'gemini', model: 'gemini-2.5-flash' }
    ]
  },
  // ...
}
```

### 3. Complexity Analysis

Analyzes request to auto-select complexity level:

```typescript
analyzeTaskComplexity(text, {
  requiresCode: boolean,
  requiresReasoning: boolean,
  contextLength: number
})
// Returns: { complexity: 'simple' | 'medium' | 'complex' }
```

**Complexity Factors**:
- Keywords: "architecture", "design", "refactor" → complex
- Code generation needed → medium+
- Reasoning requirements → medium+
- Request length → affects complexity

### 4. Provider Management

Manages all AI providers through unified interface:

```typescript
private async callClaude(model, messages, options) { ... }
private async callGemini(model, messages, options) { ... }
private async callCodex(model, messages, options) { ... }
private async callCopilot(model, messages, options) { ... }
private async callOpenRouter(model, messages, options) { ... }
```

## Request Flow

### 1. Receive Request

```json
{
  "model": "auto",
  "task_type": "architect",
  "messages": [{"role": "user", "content": "..."}],
  "complexity": null,  // Will be auto-detected
  "capabilities": ["reasoning", "code"],
  "correlation_id": "uuid-here"
}
```

### 2. Task Complexity Analysis

```
Request text analyzed for:
├─ Keywords (architecture, design, refactor, etc)
├─ Code generation requirements
├─ Reasoning complexity
└─ Context length

Result: Complexity score (simple/medium/complex)
```

### 3. Model Selection

```typescript
// Get candidates for task + complexity
const candidates = getModelCandidates(
  taskType: 'architect',
  complexity: 'complex',
  providerHint: null,
  capabilities: ['reasoning', 'code']
)
// Returns: [
//   {provider: 'claude', model: 'opus'},
//   {provider: 'openrouter', model: 'auto'},
//   {provider: 'copilot', model: 'gpt-4o'}
// ]

// Filter to available providers
const available = candidates.filter(c => isProviderAvailable(c.provider))

// Select first available
const choice = available[0]  // {provider: 'claude', model: 'opus'}
```

### 4. Provider Call

```typescript
const result = await callClaude('opus', messages, options)
// Returns: { text: "...", tokens_used: 2450, cost_cents: 0 }
```

### 5. Return Response

```json
{
  "text": "response text here",
  "model": "claude:opus",
  "tokens_used": 2450,
  "cost_cents": 0,
  "timestamp": "2025-01-10T...",
  "correlation_id": "uuid-here"
}
```

## Request Sources

### 1. Singularity Agents

Direct NATS publish:

```elixir
alias Singularity.LLM.Service

# Simple call
Service.call(:complex, messages)

# With task type for intelligent selection
Service.call(:medium, messages, task_type: :architect)
```

**Example Agents**:
- Self-Improving Agent: "Improve my code"
- Architecture Agent: "Design component structure"
- Refactoring Agent: "Optimize performance"
- Chat Agent: "Answer user questions"

### 2. Browser Chat

Via Next.js API Route:

```typescript
// Browser sends
POST /api/chat
{ messages: [...] }

// Route publishes to NATS (same handler processes it!)
await nc.request('llm.request', {
  model: 'auto',
  task_type: 'general',
  messages: [...]
})
```

## Cost Optimization

### Per-Provider Costs

```typescript
calculateClaudeCost(tokens, model)
// claude subscription = FREE

calculateGeminiCost(tokens, model)
// gemini-2.5-flash: $0.075/1M tokens

calculateCodexCost(tokens, model)
// subscription-based = FREE

// Copilot, GitHub Models = FREE via subscription
```

### Cost Tracking

```typescript
// Record model usage with tokens
metrics.recordModelUsage('claude', 'opus', 2450)

// Retrieves cost from calculations
// Tracks in metrics for analytics
```

## Availability Checking

Before selecting a provider, check credentials:

```typescript
isProviderAvailable('claude')
// Checks: ANTHROPIC_API_KEY exists

isProviderAvailable('copilot')
// Checks: GITHUB_TOKEN exists

getMissingCredentials('gemini')
// Returns: ['GOOGLE_AUTH_TYPE'] if not set
```

**Graceful Degradation**:
- Provider unavailable → try next in list
- All providers unavailable → error
- Never calls provider without credentials

## Timeout & Error Handling

### Timeout (30 seconds)

```typescript
Promise.race([
  this.processLLMRequest(request),    // Main work
  this.createTimeoutPromise(30000)    // 30s timer
])

// If timeout:
.catch(err => {
  if (err instanceof TimeoutError) {
    return { error: 'Request timed out' }
  }
})
```

### Error Handling

```typescript
// Validation errors
if (!isValidLLMRequest(data)) {
  throw new ValidationError('Invalid request format')
}

// Provider errors
if (!isProviderAvailable(provider)) {
  throw new ProviderError(`${provider} not available`)
}

// Execution errors
try {
  const result = await provider.call(...)
} catch (err) {
  throw new ProviderError(provider, err.message)
}
```

## Integration with Vercel AI SDK

Router leverages **Vercel AI SDK** for provider abstraction:

```typescript
import { generateText } from 'ai'
import { claudeCode } from 'ai-sdk-provider-claude-code'

// Call Claude via AI SDK
const result = await generateText({
  model: claudeCode('opus'),
  messages: [...]
})
```

**Benefits**:
- Unified interface across all providers
- Automatic streaming support
- Token counting
- Error handling

## Monitoring & Observability

### Metrics

```typescript
// Record every request
metrics.recordRequest('nats_llm_request', duration, isError)

// Track model usage
metrics.recordModelUsage(provider, model, tokensUsed)

// Retrieve for dashboards
getMetrics()
// Returns: {
//   requests_total: 1250,
//   requests_error: 15,
//   model_usage: {...},
//   provider_usage: {...}
// }
```

### Logging

```typescript
logger.info('[NATS] LLM request completed', {
  model: response.model,
  duration: '245ms',
  tokens: 2450,
  correlationId: request.correlation_id
})
```

## Deployment

### Single Instance

One Nexus server handles all routing:

```
Singularity, Genesis, Browser
     ↓        ↓         ↓
   All → NATS llm.request → Nexus Router
         (pub/sub queue)
```

### Multi-Instance (Future)

Multiple Nexus routers for load distribution:

```
Singularity, Genesis, Browser
     ↓        ↓         ↓
   All → NATS llm.request → Router 1
                          → Router 2
                          → Router 3
        (load balanced)
```

## Comparison: Nexus vs LiteLLM

| Feature | LiteLLM | Nexus Router |
|---------|---------|--------------|
| **Communication** | HTTP | NATS |
| **Providers** | 100+ | 5+ (Claude, Gemini, Copilot, etc) |
| **Model Selection** | Static routing | Intelligent analysis |
| **Complexity Analysis** | Manual | Automatic |
| **Cost Tracking** | Per-call | Per-request + metrics |
| **Integration** | REST API | NATS pub/sub |
| **Availability** | Polling | Credential checking |
| **Use Case** | External gateway | Internal routing |

## Best Practices

### 1. Always Specify Task Type

```elixir
# Good: Router can make intelligent decisions
Service.call(:medium, messages, task_type: :architect)

# Okay: Uses defaults
Service.call(:complex, messages)

# Bad: No task info
Service.call(:medium, messages)  # Assumes 'general'
```

### 2. Handle Timeouts

```elixir
case Service.call(...) do
  {:ok, response} -> process(response)
  {:error, :timeout} -> use_fallback()  # Always have fallback!
  {:error, reason} -> handle_error(reason)
end
```

### 3. Use Appropriate Complexity

```elixir
:simple   # <= Quick questions, classifications, parsing
:medium   # <= Normal tasks, coding, planning
:complex  # <= Architecture, design, refactoring, reasoning
```

### 4. Provide Capabilities Hints

```elixir
Service.call(:medium, messages,
  task_type: :coder,
  capabilities: [:code, :speed]  # Prefer fast coding models
)
```

## Future Enhancements

- [ ] Provider-specific fallback chains
- [ ] A/B testing different models
- [ ] Automatic cost optimization
- [ ] Request batching for efficiency
- [ ] Custom model fine-tuning
- [ ] Rate limiting per source
- [ ] Request caching

---

**Related Files**:
- `nexus/src/nats-handler.ts` - Router implementation
- `nexus/src/server.ts` - Server setup
- `nexus/app/api/chat/route.ts` - Browser integration
- `singularity/lib/singularity/llm/service.ex` - Elixir client

**See Also**:
- `NEXUS_ARCHITECTURE_COMPLETE.md` - Full system architecture
- `IMPLEMENTATION_SUMMARY_JAN2025.md` - All changes
