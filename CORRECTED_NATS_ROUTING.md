# Corrected NATS Routing Strategy

## Routing Decision Matrix

### Route Through `knowledge_central_service` ✅

**These are cacheable, infrequently changing knowledge:**

| Type | Examples | Why Cache? |
|------|----------|------------|
| **Patterns** | Code patterns, architecture patterns | Rarely change, reused often |
| **Templates** | Code templates, scaffolding | Rarely change, reused often |
| **Intelligence Modules** | Quality rules, linting configs | Updated occasionally |
| **Framework Knowledge** | Detected frameworks, best practices | Stable once detected |
| **Package Metadata** | npm/cargo/hex registry info | Changes weekly at most |
| **Analysis Configs** | Clippy rules, Credo settings | Rarely change |
| **Agent Workflows** | SPARC templates, SAFe processes | Rarely change |
| **System Configs** | Feature flags, endpoints | Change rarely |

**Benefits of routing through central:**
- ✅ **Cache once, use 1000x** - Patterns reused across many generations
- ✅ **Broadcast updates** - When pattern updated, all nodes get it
- ✅ **Offline resilience** - Can work with cached patterns if central down

---

### Direct NATS (Bypass Cache) ⚡

**These are dynamic, request-specific, or streaming:**

| Type | Route To | Why NOT Cache? |
|------|----------|----------------|
| **LLM Calls** | `ai.llm.request` (AI server) | Every prompt is unique, can't cache |
| **LLM Streaming** | `ai.llm.stream` | Real-time token streaming |
| **Code Analysis** | `code.analysis.*` | Every file is different |
| **Agent Execution** | `agents.spawn`, `agents.execute` | Dynamic, stateful operations |
| **Real-time Telemetry** | `telemetry.*` | Time-series data, append-only |
| **Large Files** | `files.upload`, `files.download` | > 10MB, streaming needed |

**Why bypass cache:**
- ❌ **Unique per request** - LLM prompt "generate async worker" is different from "generate auth handler"
- ❌ **Stateful** - Agent execution has side effects
- ❌ **Streaming** - Can't cache partial responses
- ❌ **Too large** - Files exceed cache memory limits

---

## Corrected Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                   Elixir Application                            │
│                                                                  │
│  ┌──────────────────────────┐  ┌───────────────────────────┐  │
│  │ Knowledge Requests       │  │ Dynamic Requests          │  │
│  │ (cacheable)              │  │ (unique per call)         │  │
│  │                          │  │                           │  │
│  │ • Get pattern            │  │ • LLM.call(prompt)        │  │
│  │ • Get template           │  │ • Analysis.parse(file)    │  │
│  │ • Get framework config   │  │ • Agent.execute(task)     │  │
│  │                          │  │                           │  │
│  │ ↓ KnowledgeCache         │  │ ↓ NatsClient (direct)     │  │
│  └────────────┬─────────────┘  └─────────────┬─────────────┘  │
└───────────────┼──────────────────────────────┼─────────────────┘
                │                              │
                │ (cached)                     │ (direct)
                ▼                              ▼
┌───────────────────────────┐   ┌──────────────────────────────┐
│ knowledge_central_service │   │    NATS Server               │
│ (Hub for knowledge)       │   │                              │
│                           │   │  • ai.llm.request            │
│ • PostgreSQL              │   │  • code.analysis.*           │
│ • Cache + broadcast       │   │  • agents.*                  │
└───────────────────────────┘   └──────────────────────────────┘
```

---

## Why LLM Calls Go Direct

### ❌ DON'T Cache LLM Calls

**Problem with caching LLM:**
```elixir
# These are all DIFFERENT prompts - can't cache!
LLM.call("Generate async worker")
LLM.call("Generate auth handler")
LLM.call("Explain this code: ...")
LLM.call("Refactor to use GenServer")
```

**Each call is unique:**
- Different prompt = different response
- Caching would waste memory
- Cache hit rate ~0% (every prompt is unique)

### ✅ DO Cache LLM Configs

**But LLM configs CAN be cached:**
```elixir
# These are SAME config - cache!
KnowledgeCache.get("llm:claude:system-prompt")
KnowledgeCache.get("llm:codex:temperature-setting")
KnowledgeCache.get("llm:gemini:max-tokens")
```

**Configs are stable:**
- System prompts rarely change
- Model settings are constant
- Cache hit rate ~99%

---

## Correct Routing Examples

### ✅ Route Through Knowledge Central

```elixir
# Pattern for code generation (reused often)
pattern = KnowledgeCache.get("pattern:elixir:async-worker")
# → NIF cache hit (0.01ms) or
# → NATS to central → PostgreSQL → cache + broadcast

# Template for scaffolding (reused often)
template = KnowledgeCache.get("template:rust:axum-api")
# → Cached locally, instant return

# Framework detection config (stable)
config = KnowledgeCache.get("framework:elixir:phoenix:detection-rules")
# → Cached, rarely changes
```

### ✅ Direct NATS (Bypass Cache)

```elixir
# LLM call (every prompt is unique)
response = NatsClient.request("ai.llm.request", %{
  provider: :codex,
  prompt: "Generate async worker for user authentication",
  # ^ This exact prompt has never been seen before!
})
# → Direct to AI server, NO caching

# Code analysis (every file is different)
NatsClient.request("code.analysis.parse", %{
  file: "lib/my_module.ex",
  # ^ This specific file content is unique
})
# → Direct to analysis service

# Agent execution (stateful operation)
NatsClient.request("agents.execute", %{
  agent_id: "sparc-123",
  task: %{...}
  # ^ Execution has side effects, can't cache
})
# → Direct to agent service
```

---

## Summary Table

| What | Where | Cache? | Why |
|------|-------|--------|-----|
| **Code pattern "async-worker"** | `KnowledgeCache` | ✅ Yes | Reused 100s of times |
| **LLM prompt "generate async..."** | `NatsClient → ai.llm` | ❌ No | Unique, never reused |
| **Framework config "Phoenix"** | `KnowledgeCache` | ✅ Yes | Stable, reused often |
| **Parse file "my_module.ex"** | `NatsClient → analysis` | ❌ No | Every file different |
| **Template "GenServer"** | `KnowledgeCache` | ✅ Yes | Reused often |
| **Agent task execution** | `NatsClient → agents` | ❌ No | Stateful, has side effects |
| **LLM system prompt** | `KnowledgeCache` | ✅ Yes | Rarely changes |
| **LLM streaming response** | `NatsClient → ai.llm.stream` | ❌ No | Real-time, can't cache |

---

## Key Insight

**Cache = Static Knowledge**
- Patterns, templates, configs
- Reused many times
- Rarely change
- **Route through knowledge_central**

**Direct = Dynamic Requests**
- Every request is unique
- Stateful or streaming
- Can't be reused
- **Direct NATS call**

---

## Updated Recommendation

### ✅ Route Through `knowledge_central_service`:
1. Patterns (code, architecture, design)
2. Templates (scaffolding, boilerplate)
3. Intelligence modules (quality rules, linting)
4. Framework knowledge (detection rules, best practices)
5. Package metadata (registry info)
6. System configs (feature flags, endpoints)
7. **LLM configs only** (system prompts, model settings)

### ⚡ Direct NATS (Performance-Critical):
1. **LLM calls** (every prompt unique)
2. **LLM streaming** (token-by-token)
3. Code analysis (every file unique)
4. Agent execution (stateful)
5. Real-time telemetry
6. Large file transfers

**Bottom Line:** Cache **static knowledge**, route **dynamic requests** directly!
