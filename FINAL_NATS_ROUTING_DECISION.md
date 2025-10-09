# Final NATS Routing Decision

## The Question
Should **LLM system prompts** and **package metadata** go through `knowledge_central`?

## Answer: YES! ✅

### Why Cache LLM System Prompts?

**LLM System Prompts = Configuration (Cacheable)**

```elixir
# System prompt for code generation (SAME every time)
system_prompt = KnowledgeCache.get("llm:codex:system-prompt:code-generation")
# Returns: "You are an expert programmer. Generate clean, production-ready code..."

# This prompt is used for 1000s of calls!
LLM.call(system_prompt, "generate async worker")
LLM.call(system_prompt, "generate auth handler")
LLM.call(system_prompt, "generate API endpoint")
# ^ Same system prompt, different user prompts
```

**Benefits:**
- ✅ System prompt is SAME for all code generation tasks
- ✅ Cache once, reuse 1000s of times
- ✅ Update once (in PostgreSQL), all nodes get new version via broadcast
- ✅ No network call to fetch system prompt every time

**Storage:**
```sql
-- In PostgreSQL knowledge_artifacts table
INSERT INTO knowledge_artifacts (id, artifact_type, content) VALUES
  ('llm:codex:system-prompt:code-generation', 'llm_config',
   '{"role": "system", "content": "You are an expert programmer..."}'),

  ('llm:claude:temperature', 'llm_config',
   '{"temperature": 0.7, "max_tokens": 4000}'),

  ('llm:gemini:model-settings', 'llm_config',
   '{"model": "gemini-2.0-flash", "safety": "high"}');
```

---

### Why Cache Package Metadata?

**Package Metadata = Registry Info (Rarely Changes)**

```elixir
# Package info from npm/cargo/hex (changes weekly at most)
package = KnowledgeCache.get("package:npm:react")
# Returns: %{
#   name: "react",
#   version: "18.2.0",
#   description: "JavaScript library for building UIs",
#   downloads: 18_000_000_000,
#   repository: "https://github.com/facebook/react"
# }

# Reused for:
# - Code generation ("use React hooks")
# - Dependency recommendations
# - Package selection
# - Documentation lookup
```

**Benefits:**
- ✅ Package metadata changes rarely (new version weekly)
- ✅ Same package queried 100s of times
- ✅ Avoid hitting npm/cargo registries every time
- ✅ Fast local cache instead of external API call

**How it updates:**
```rust
// knowledge_central_service periodically syncs registries
async fn sync_package_registries() {
    // Every 6 hours, fetch latest from npm/cargo/hex
    let packages = fetch_from_npm_registry().await?;

    // Update PostgreSQL
    for package in packages {
        store_package(package).await?;
    }

    // Broadcast updates to all caches
    nats.publish("knowledge.cache.update.package", packages).await?;
}
```

---

## Final Routing Table

### ✅ Through `knowledge_central` (Cacheable Static Knowledge)

| Type | Example ID | Why Cache? | Update Frequency |
|------|-----------|------------|------------------|
| **Patterns** | `pattern:elixir:async-worker` | Reused 100s of times | Weeks |
| **Templates** | `template:rust:axum-api` | Reused often | Weeks |
| **LLM System Prompts** | `llm:codex:system-prompt:code-gen` | Same for all calls | Days |
| **LLM Model Settings** | `llm:claude:temperature` | Same for all calls | Weeks |
| **Package Metadata** | `package:npm:react` | Reused for many queries | Hours/Days |
| **Framework Configs** | `framework:phoenix:detection-rules` | Stable | Months |
| **Quality Rules** | `quality:elixir:credo-rules` | Stable | Months |
| **Agent Workflows** | `agent:sparc:workflow-template` | Reused often | Weeks |

### ⚡ Direct NATS (Dynamic Per-Request Data)

| Type | NATS Subject | Why NOT Cache? |
|------|--------------|----------------|
| **LLM User Prompts** | `ai.llm.request` | Every prompt unique |
| **LLM Streaming** | `ai.llm.stream` | Real-time tokens |
| **Code Analysis** | `code.analysis.parse` | Every file different |
| **Agent Execution** | `agents.execute` | Stateful, side effects |
| **Telemetry** | `telemetry.metrics` | Time-series data |
| **File Uploads** | `files.upload` | Large, unique |

---

## Usage Examples

### ✅ CORRECT: Cache System Prompt + Package Info

```elixir
defmodule CodeGenerator do
  alias Singularity.{KnowledgeCache, NatsClient}

  def generate_code(user_request) do
    # 1. Get system prompt from cache (FAST - cached)
    system_prompt = KnowledgeCache.get("llm:codex:system-prompt:code-gen")
    # Cache hit! Returns in 0.01ms

    # 2. Get package info from cache (FAST - cached)
    react_info = KnowledgeCache.get("package:npm:react")
    # Cache hit! Returns in 0.01ms

    # 3. Build full prompt (dynamic)
    full_prompt = """
    #{system_prompt.content}

    Use package: #{react_info.name} v#{react_info.version}

    User request: #{user_request}
    """

    # 4. Call LLM (DIRECT - unique prompt)
    NatsClient.request("ai.llm.request", %{
      provider: :codex,
      messages: [
        %{role: "system", content: system_prompt.content},
        %{role: "user", content: user_request}
      ]
    })
  end
end
```

**Performance:**
- System prompt fetch: **0.01ms** (cached)
- Package info fetch: **0.01ms** (cached)
- LLM call: **500-2000ms** (network, generation time)

**Total:** ~500ms (vs 600ms if we had to fetch system prompt and package info via NATS)

### ❌ WRONG: Cache User Prompts

```elixir
# DON'T DO THIS!
defmodule BadExample do
  def generate_code(user_request) do
    # ❌ WRONG - Trying to cache unique user prompts
    cached_prompt = KnowledgeCache.get("llm:prompt:#{user_request}")
    # Cache miss EVERY time! (every request is unique)

    # This defeats the purpose of caching
  end
end
```

---

## Knowledge Central Architecture

```rust
// knowledge_central_service/src/main.rs

async fn handle_query(asset_id: String) -> Result<Asset> {
    let parts: Vec<&str> = asset_id.split(':').collect();

    match parts[0] {
        // Direct PostgreSQL
        "pattern" | "template" | "quality" | "agent" => {
            query_postgres(&asset_id).await
        }

        // LLM configs (NOT calls!)
        "llm" => {
            // Only configs/settings, not actual prompts
            match parts.get(2) {
                Some(&"system-prompt") | Some(&"temperature") |
                Some(&"settings") | Some(&"model-config") => {
                    query_postgres(&asset_id).await
                }
                _ => Err(anyhow!("LLM calls go direct, not through cache"))
            }
        }

        // Package metadata
        "package" => {
            // Check cache/DB first
            match query_postgres(&asset_id).await {
                Ok(asset) => Ok(asset),
                Err(_) => {
                    // Fetch from registry API if not in cache
                    let package = fetch_from_registry(&parts[1], &parts[2]).await?;
                    store_and_broadcast(package).await
                }
            }
        }

        _ => Err(anyhow!("Unknown asset type"))
    }
}
```

---

## Update Flows

### System Prompt Update
```
1. Admin updates system prompt:
   PostgreSQL.update("llm:codex:system-prompt:code-gen", new_content)

2. knowledge_central broadcasts:
   NATS.publish("knowledge.cache.update.llm", updated_asset)

3. All NIF caches update automatically:
   GLOBAL_CACHE.write().insert(asset_id, new_content)

4. Next LLM call uses new system prompt:
   KnowledgeCache.get("llm:codex:system-prompt:code-gen")
   → Returns new version instantly!
```

### Package Metadata Update
```
1. Background job (every 6 hours):
   sync_package_registries()

2. Fetch from npm/cargo/hex APIs:
   packages = fetch_from_registry().await

3. Update PostgreSQL + broadcast:
   for package in packages {
       store(package)
       NATS.publish("knowledge.cache.update.package", package)
   }

4. All caches updated automatically
```

---

## Storage Estimate

### What Goes in PostgreSQL (knowledge_artifacts table)

```
Patterns:           ~1,000 entries × 10KB  = 10MB
Templates:          ~500 entries × 20KB    = 10MB
LLM Configs:        ~100 entries × 2KB     = 0.2MB
Package Metadata:   ~10,000 entries × 5KB  = 50MB
Framework Configs:  ~50 entries × 10KB     = 0.5MB
Quality Rules:      ~100 entries × 5KB     = 0.5MB

TOTAL: ~71MB (tiny!)
```

### What Goes in NIF Cache (per node)

```
Hot patterns:      ~100 entries × 10KB  = 1MB
Hot templates:     ~50 entries × 20KB   = 1MB
LLM configs:       ~20 entries × 2KB    = 0.04MB
Hot packages:      ~500 entries × 5KB   = 2.5MB

TOTAL per node: ~4.5MB (negligible!)
```

---

## Summary

### ✅ YES - Route Through `knowledge_central`:
1. **LLM system prompts** - Same prompt used for 1000s of calls
2. **LLM model settings** - Temperature, max tokens, etc.
3. **Package metadata** - npm/cargo/hex registry info
4. **Patterns & Templates** - Code patterns, scaffolding
5. **Framework configs** - Detection rules, best practices
6. **Quality rules** - Linting, quality gates

### ⚡ NO - Direct NATS:
1. **LLM user prompts** - Every prompt unique
2. **LLM streaming** - Real-time tokens
3. **Code analysis** - Every file different
4. **Agent execution** - Stateful operations

**Key Rule:**
- **Reusable knowledge** → Cache
- **Unique requests** → Direct

**Result:** 1000x faster for configs/metadata, no slowdown for dynamic requests!
