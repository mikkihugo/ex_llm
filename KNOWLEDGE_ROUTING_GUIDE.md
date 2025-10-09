# Knowledge System Routing Guide

## Decision Tree: Cache vs Central?

### Rule of Thumb:
- **READS** → `KnowledgeCache` (local NIF, FAST)
- **WRITES** → `KnowledgeCentral` (via NATS, authoritative)
- **ADMIN** → `KnowledgeCentral` (management operations)

---

## READ Operations → KnowledgeCache ✅

**Go to local NIF cache first:**

```elixir
# ✅ Use KnowledgeCache for reads
KnowledgeCache.get_pattern("async-worker")
KnowledgeCache.get_template("elixir-genserver")
KnowledgeCache.get_intelligence_module("code-quality")
KnowledgeCache.search_patterns(%{language: "elixir"})
```

**Why?**
- Ultra-fast (local NIF, no network)
- Cache handles central fetch if miss
- 95%+ hit rate for hot data

**Internal flow:**
```
get_pattern("async")
  → NIF cache check
  → HIT? Return (microseconds)
  → MISS? NIF calls central via NATS → cache → return
```

---

## WRITE Operations → KnowledgeCentral ✅

**Go directly to central service:**

```elixir
# ✅ Use KnowledgeCentral for writes
KnowledgeCentral.create_pattern(%{
  name: "async-worker",
  language: "elixir",
  code: "...",
  metadata: %{}
})

KnowledgeCentral.update_pattern("async-worker", %{
  code: "improved version..."
})

KnowledgeCentral.delete_pattern("old-pattern")
```

**Why?**
- Central is single source of truth
- Central handles PostgreSQL persistence
- Central broadcasts updates to ALL caches
- Prevents race conditions/conflicts

**Internal flow:**
```
update_pattern(...)
  → NATS to central service
  → Central writes PostgreSQL
  → Central broadcasts "cache.update" to ALL nodes
  → All NIFs update their local cache
  → Write returns
```

---

## ADMIN Operations → KnowledgeCentral ✅

**Metadata, versioning, bulk operations:**

```elixir
# ✅ Use KnowledgeCentral for admin
KnowledgeCentral.list_all_patterns()
KnowledgeCentral.get_pattern_versions("async-worker")
KnowledgeCentral.bulk_import(patterns_json)
KnowledgeCentral.sync_from_git_repo()
KnowledgeCentral.get_stats()  # cache hits, miss rate, etc.
```

**Why?**
- Central has full database view
- Cache only stores hot subset
- Admin ops are infrequent (not latency-sensitive)

---

## Detailed Routing Table

| Operation | Route To | Reason |
|-----------|----------|--------|
| **Get pattern by name** | `KnowledgeCache` | Fast read, cache handles miss |
| **Search patterns** | `KnowledgeCache` | Fast read, cache handles miss |
| **Get template** | `KnowledgeCache` | Fast read, cache handles miss |
| **Load intelligence module** | `KnowledgeCache` | Fast read, cache handles miss |
| **Create new pattern** | `KnowledgeCentral` | Write operation, needs persistence |
| **Update existing pattern** | `KnowledgeCentral` | Write operation, broadcasts to caches |
| **Delete pattern** | `KnowledgeCentral` | Write operation, broadcasts to caches |
| **List all patterns** | `KnowledgeCentral` | Admin, needs full DB view |
| **Bulk import** | `KnowledgeCentral` | Admin, large operation |
| **Version history** | `KnowledgeCentral` | Admin, versioning metadata |
| **Cache stats** | `KnowledgeCache` | Local metrics |
| **Global stats** | `KnowledgeCentral` | Aggregates from all nodes |

---

## Code Examples

### ✅ CORRECT Usage

```elixir
defmodule MyAgent do
  alias Singularity.KnowledgeCache
  alias Singularity.KnowledgeCentral

  # ✅ READ - Use cache
  def load_pattern_for_generation(name) do
    case KnowledgeCache.get_pattern(name) do
      {:ok, pattern} -> generate_code(pattern)
      {:error, :not_found} -> {:error, "Pattern not found"}
    end
  end

  # ✅ WRITE - Use central
  def save_learned_pattern(name, code) do
    KnowledgeCentral.create_pattern(%{
      name: name,
      code: code,
      source: "ai-learned",
      confidence: 0.95
    })
  end

  # ✅ SEARCH - Use cache (cache handles NATS if needed)
  def find_similar_patterns(query) do
    KnowledgeCache.search_patterns(%{
      query: query,
      language: "elixir",
      limit: 10
    })
  end

  # ✅ ADMIN - Use central
  def sync_patterns_from_git() do
    KnowledgeCentral.sync_from_git_repo()
  end
end
```

### ❌ INCORRECT Usage

```elixir
# ❌ WRONG - Don't write to cache directly
def save_pattern(name, code) do
  KnowledgeCache.save_asset(%{name: name, code: code})
  # Problem: Other nodes won't see this!
  # Cache is LOCAL only
end

# ❌ WRONG - Don't read from central for hot data
def get_pattern_slow(name) do
  KnowledgeCentral.query_pattern(name)
  # Problem: Network call every time (slow!)
  # Use KnowledgeCache instead
end

# ❌ WRONG - Don't bypass cache for reads
def search_patterns_slow(query) do
  Repo.all(from p in Pattern, where: ...)
  # Problem: Bypasses cache, slow PostgreSQL query
  # Use KnowledgeCache.search_patterns
end
```

---

## Cache Update Flow (How writes update caches)

```
1. App writes to central:
   KnowledgeCentral.update_pattern("async-worker", new_data)

2. Central service receives via NATS:
   → Write to PostgreSQL (authoritative)
   → Broadcast to all caches:
     NATS.publish("knowledge.cache.update", %{
       id: "pattern:async-worker",
       data: new_data,
       version: 2
     })

3. All NIF caches listen (background thread):
   → Receive broadcast
   → Update local cache
   → Log: "Cache updated: pattern:async-worker v2"

4. Next read from ANY node gets fresh data:
   KnowledgeCache.get_pattern("async-worker")
   → Cache hit! (already updated via broadcast)
   → Returns instantly with v2
```

---

## Special Cases

### Bulk Reads (100+ patterns)
```elixir
# Use central directly (cache not optimized for bulk)
KnowledgeCentral.bulk_query(pattern_ids)
```

### Real-time Collaboration
```elixir
# Subscribe to live updates
KnowledgeCentral.subscribe_to_updates("pattern:*")
# Central streams updates as they happen
```

### Offline Mode
```elixir
# Cache serves stale data if central unavailable
case KnowledgeCache.get_pattern("async-worker") do
  {:ok, pattern, :stale} ->
    Logger.warn("Using stale cache (central unavailable)")
    {:ok, pattern}
  {:ok, pattern} ->
    {:ok, pattern}
end
```

---

## Summary

| You Want To... | Call This | Why |
|----------------|-----------|-----|
| **Get data fast** | `KnowledgeCache.get_*` | Local NIF, no network |
| **Save new data** | `KnowledgeCentral.create_*` | Persists + broadcasts |
| **Update data** | `KnowledgeCentral.update_*` | Persists + broadcasts |
| **Search data** | `KnowledgeCache.search_*` | Fast local + NATS fallback |
| **Admin tasks** | `KnowledgeCentral.*` | Full DB access |
| **Bulk operations** | `KnowledgeCentral.bulk_*` | Not cache-optimized |

**Golden Rule:**
- **Reading?** → Cache first (it calls central if needed)
- **Writing?** → Central (it updates all caches)
- **Managing?** → Central (admin operations)
