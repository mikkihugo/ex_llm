# Central Services Comparison

## 📊 Side-by-Side Comparison

### **knowledge_central_service** vs **package_analysis_suite**

| Feature | knowledge_central_service | package_analysis_suite |
|---------|--------------------------|------------------------|
| **Purpose** | Internal knowledge distribution | External package indexing |
| **What It Stores** | Your patterns, templates, prompts | npm/cargo/hex/pypi metadata |
| **Storage** | In-memory (RAM) | redb (disk) + PostgreSQL |
| **Persistence** | Volatile (lost on restart) | Persistent (survives restart) |
| **Size** | Small (~MB) | Large (~GB) |
| **Speed** | Ultra-fast (~1μs) | Fast (~100μs) |
| **NATS** | 85% done (subscriber ✅, publisher 🟡) | 100% done (full daemon) |
| **Lines of Code** | 214 | ~5000+ |
| **Binary** | NIF (loaded in BEAM) | Standalone daemon |
| **Status** | Ready to activate | Fully active |

---

## 🎯 Purpose Comparison

### **knowledge_central_service** - Internal Knowledge
**"YOUR stuff, shared across nodes"**

```
What it manages:
├── Patterns       (Elixir Phoenix pattern, Rust async pattern)
├── Templates      (Code generation templates)
├── Prompts        (AI system prompts)
└── Intelligence   (ML models, heuristics)

Storage: In-memory distributed cache
Access: Near-instant (in RAM)
Scope: Your codebase knowledge
```

**Example Use Case:**
```elixir
# Node 1: Save a new pattern
KnowledgeCentral.save_asset(%{
  id: "phoenix-liveview-pattern",
  asset_type: "pattern",
  data: ~s({"uses": ["Phoenix.LiveView"], "structure": "..."}),
  version: 1
})

# Node 2: Instantly sees the pattern (via NATS broadcast)
pattern = KnowledgeCentral.load_asset("phoenix-liveview-pattern")
# => Fast! Already in local cache
```

---

### **package_analysis_suite** - External Package Knowledge
**"World's packages, indexed and searchable"**

```
What it manages:
├── npm packages      (react, express, etc.)
├── cargo crates      (tokio, serde, etc.)
├── hex packages      (phoenix, ecto, etc.)
└── pypi packages     (django, fastapi, etc.)

Storage: redb (embedded DB on disk) + PostgreSQL cache
Access: Fast (~100μs from disk)
Scope: External registry knowledge
```

**Example Use Case:**
```elixir
# Search for async runtime in cargo
PackageRegistry.search("async runtime", ecosystem: :cargo)
# => [
#   %{name: "tokio", version: "1.35.0", stars: 25000},
#   %{name: "async-std", version: "1.12.0", stars: 8000}
# ]

# Get package metadata + code snippets
PackageRegistry.get("tokio", "1.35.0")
# => %{
#   documentation: "...",
#   code_snippets: ["async fn main() {...}"],
#   dependencies: [...]
# }
```

---

## 🏗️ Architecture Comparison

### **knowledge_central_service**

```
┌────────────────────────────────────────────────┐
│  Node 1                    Node 2              │
├────────────────────────────────────────────────┤
│  In-Memory Cache     ←───→  In-Memory Cache    │
│  (Rust NIF)                  (Rust NIF)        │
│       │                          │             │
│       └──────── NATS Pub/Sub ────┘             │
│         knowledge.cache.update.*               │
└────────────────────────────────────────────────┘

Flow:
1. save_asset() → writes to local cache
2. broadcast via NATS → all nodes update
3. load_asset() → instant read from RAM
```

**Characteristics:**
- ✅ Distributed (multi-node sync)
- ✅ In-memory (ultra-fast)
- ❌ Volatile (no persistence)
- ✅ Low latency (~1μs)
- ✅ Small footprint

---

### **package_analysis_suite**

```
┌─────────────────────────────────────────────────┐
│  External APIs (npm, crates.io, hex.pm)         │
│         ↓ Download tarballs                     │
├─────────────────────────────────────────────────┤
│  Rust Service (package-registry-service)        │
│  ├─ Parse with tree-sitter                      │
│  ├─ Extract code snippets                       │
│  └─ Store in redb (embedded DB)                 │
│         ↓ NATS: packages.registry.*             │
├─────────────────────────────────────────────────┤
│  JetStream KV (1h TTL cache)                    │
│         ↓ On cache miss                         │
├─────────────────────────────────────────────────┤
│  PostgreSQL (source of truth)                   │
└─────────────────────────────────────────────────┘

Flow:
1. collect("tokio") → downloads from crates.io
2. parse → extracts APIs, functions
3. store → redb + PostgreSQL
4. search() → queries local cache
```

**Characteristics:**
- ✅ Persistent (survives restarts)
- ✅ Scalable (handles thousands of packages)
- ❌ Heavier (GB of data)
- ✅ Medium latency (~100μs)
- ✅ Historical data

---

## 💾 Storage Comparison

### **knowledge_central_service**

```rust
// In-memory HashMap
static GLOBAL_CACHE: Lazy<GlobalCache> = 
    Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

// No disk I/O, pure RAM
```

**Data Size:** ~1-100 MB
- 100 patterns × ~10KB each = ~1MB
- 500 templates × ~5KB each = ~2.5MB
- 50 prompts × ~2KB each = ~100KB

**Total:** Small, easily fits in RAM

---

### **package_analysis_suite**

```rust
// Embedded database on disk
let db = redb::Database::create("priv/package_cache.redb")?;

// + PostgreSQL for source of truth
```

**Data Size:** ~1-10 GB
- npm: 2 million+ packages
- cargo: 150k+ crates
- hex: 15k+ packages
- pypi: 500k+ packages

**Total:** Large, needs disk storage

---

## 🚀 Performance Comparison

### **Read Performance**

| Operation | knowledge_central_service | package_analysis_suite |
|-----------|--------------------------|------------------------|
| Load from cache | ~1μs (RAM) | ~100μs (redb) or ~1ms (PostgreSQL) |
| Search | N/A (simple key lookup) | ~10-50ms (full-text + semantic) |
| Stats | ~10μs (count HashMap) | ~100ms (query DB) |

### **Write Performance**

| Operation | knowledge_central_service | package_analysis_suite |
|-----------|--------------------------|------------------------|
| Save asset | ~5μs (HashMap insert) | ~1ms (redb write) |
| Broadcast | ~1ms (NATS publish) | ~1ms (NATS publish) |
| Full sync | ~10ms (all nodes) | ~100ms (DB + cache) |

---

## 🔄 NATS Integration

### **knowledge_central_service**

**NATS Subjects:**
```
knowledge.cache.update.{asset_id}    # Broadcast cache updates
```

**Current State:**
- ✅ Subscriber implemented (100%)
- 🟡 Publisher stubbed (logs only, needs actual NATS publish)

**Code:**
```rust
// Subscriber (WORKS)
async fn run_nats_subscriber(nats_url: String, cache: GlobalCache) {
    let client = async_nats::connect(&nats_url).await?;
    let mut subscriber = client.subscribe("knowledge.cache.update.>").await?;
    
    while let Some(msg) = subscriber.next().await {
        let update = serde_json::from_slice(&msg.payload)?;
        cache.insert(update.id.clone(), update);  // Update local cache
    }
}

// Publisher (TODO)
async fn broadcast_cache_update(asset: &KnowledgeAsset) -> Result<()> {
    // TODO: Add actual NATS publish here
    info!("Broadcasting cache update for asset: {}", asset.id);
    Ok(())
}
```

---

### **package_analysis_suite**

**NATS Subjects:**
```
packages.registry.search              # Search packages
packages.registry.collect.npm         # Collect npm
packages.registry.collect.cargo       # Collect cargo
packages.storage.get                  # Get metadata
packages.storage.store                # Store metadata
packages.analysis.*                   # Analysis results
```

**Current State:**
- ✅ Full NATS service daemon (100%)
- ✅ Publisher + Subscriber both implemented
- ✅ Request/Reply pattern

---

## 📋 Completeness Status

### **knowledge_central_service: 85%**

| Component | Status | %  |
|-----------|--------|-----|
| Global cache | ✅ | 100% |
| NIF functions | ✅ | 100% |
| NATS subscriber | ✅ | 100% |
| NATS publisher | 🟡 | 10% (logs only) |
| Elixir wrapper | ❌ | 0% |

**Missing:**
1. Implement NATS publish in `broadcast_cache_update` (30 min)
2. Create Elixir wrapper module (30 min)
3. Compile NIF and test (30 min)

---

### **package_analysis_suite: 100%**

| Component | Status | % |
|-----------|--------|---|
| Collectors (npm/cargo/hex) | ✅ | 100% |
| Code snippet extraction | ✅ | 100% |
| redb storage | ✅ | 100% |
| NATS service | ✅ | 100% |
| Elixir integration | ✅ | 100% |

**Status:** Fully active and running

---

## 🎯 When to Use Which?

### **Use knowledge_central_service when:**
- ✅ Sharing patterns across nodes
- ✅ Distributing code templates
- ✅ Caching AI prompts
- ✅ Need ultra-fast access (~1μs)
- ✅ Data fits in memory (< 1GB)
- ✅ Don't need persistence (can rebuild)

### **Use package_analysis_suite when:**
- ✅ Searching external packages
- ✅ Finding similar libraries
- ✅ Getting package documentation
- ✅ Extracting code examples
- ✅ Need historical data
- ✅ Large dataset (GB+)

---

## 💡 How They Complement Each Other

**Example Workflow:**

```elixir
# 1. User asks: "How do I build an async web server in Rust?"

# 2. Search external packages
packages = PackageAnalysisSuite.search("async web server", ecosystem: :cargo)
# => ["tokio", "actix-web", "axum"]

# 3. Load internal pattern
pattern = KnowledgeCentral.load_asset("rust-actix-web-pattern")
# => %{structure: "...", best_practices: "..."}

# 4. Combine: External package + Internal pattern → Generated code
code = Generator.generate(package: "actix-web", pattern: pattern)
```

---

## ✅ Summary

| Aspect | knowledge_central_service | package_analysis_suite |
|--------|--------------------------|------------------------|
| **What** | YOUR knowledge | WORLD's packages |
| **Where** | RAM (in-memory) | Disk (redb + PostgreSQL) |
| **Speed** | Ultra-fast (~1μs) | Fast (~100μs) |
| **Size** | Small (MB) | Large (GB) |
| **Persistence** | No (volatile) | Yes (survives restart) |
| **NATS** | 85% done | 100% done |
| **Completeness** | 85% | 100% |
| **Effort to finish** | ~1-2 hours | Already done |

**Both are central services, different purposes:**
- `knowledge_central_service` = Fast distributed cache for YOUR patterns
- `package_analysis_suite` = Persistent index of WORLD's packages

**Together they form complete knowledge infrastructure!**
