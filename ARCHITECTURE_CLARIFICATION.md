# Architecture Clarification: Local vs Remote Cache

## The Confusion

When I said "local engines" vs "remote cache", I was **WRONG**. Let me clarify:

---

## ✅ **Correct Architecture**

### **Everything Runs Locally (Same Machine)**

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR MACHINE (localhost)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Elixir App (singularity_app)                      │    │
│  │  - NIFs (Rust libraries loaded in BEAM)            │    │
│  │  - Phoenix web server                               │    │
│  │  - Agent orchestration                              │    │
│  └────────────────┬───────────────────────────────────┘    │
│                   │                                          │
│                   │ NATS (local message bus)                │
│                   │                                          │
│  ┌────────────────▼───────────────────────────────────┐    │
│  │  Rust Services (separate processes, same machine)  │    │
│  │  - package-registry-service (NATS daemon)          │    │
│  │  - prompt-intelligence-service (if standalone)     │    │
│  └────────────────┬───────────────────────────────────┘    │
│                   │                                          │
│  ┌────────────────▼───────────────────────────────────┐    │
│  │  NATS Server (localhost:4222)                      │    │
│  │  - JetStream KV (distributed cache)                │    │
│  │  - Message routing                                  │    │
│  └────────────────┬───────────────────────────────────┘    │
│                   │                                          │
│  ┌────────────────▼───────────────────────────────────┐    │
│  │  PostgreSQL (localhost:5432)                       │    │
│  │  - Source of truth                                  │    │
│  │  - pgvector for embeddings                         │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## **Two Types of "Cache"**

### 1. **JetStream KV = NATS Distributed Cache**

**What it is:**
- In-memory key-value store inside NATS
- Still on localhost, just managed by NATS
- TTL=1h (auto-expires after 1 hour)

**Why use it?**
- Faster than PostgreSQL queries
- Shared across multiple Rust/Elixir processes
- Reduces DB load

**Example Flow:**
```
Elixir: "Give me package 'tokio'"
   ↓ NATS request: packages.storage.get
Rust Service: Check JetStream KV
   ↓ Cache HIT? Return immediately
   ↓ Cache MISS? Query PostgreSQL
PostgreSQL: Return package data
Rust Service: Store in JetStream KV (1h TTL)
   ↓ Return to Elixir
Elixir: Got package data
```

### 2. **redb = Rust Embedded Database**

**What it is:**
- File-based embedded DB (like SQLite)
- Stored on disk: `priv/package_cache.redb`
- Persistent across restarts

**Why use it?**
- Package metadata storage (external packages)
- Faster than PostgreSQL for package lookups
- No network overhead (direct file access)

**Example:**
```
package-registry-indexer collect --package tokio
   ↓ Download from crates.io
   ↓ Extract code snippets
   ↓ Store in redb file
   ↓ Done

Later:
Elixir: "Search packages for 'async runtime'"
   ↓ Query redb file directly
   ↓ Get results
```

---

## **Terminology Fix**

### ❌ **What I Said (WRONG):**
- "Local engines" vs "remote cache"

### ✅ **What I Should Say:**

| Component | Location | Type |
|-----------|----------|------|
| **Elixir App** | localhost (BEAM VM) | Application |
| **NIFs** | localhost (loaded in BEAM) | Rust libraries |
| **Rust Services** | localhost (separate processes) | Services |
| **NATS** | localhost:4222 | Message broker |
| **JetStream KV** | localhost (in NATS) | In-memory cache |
| **redb** | localhost (disk file) | Embedded DB |
| **PostgreSQL** | localhost:5432 | Database |

**Everything is local!** No remote services (except external APIs like npm/cargo registries).

---

## **Cache Hierarchy**

```
Query for package metadata:
  1. JetStream KV (fastest - in memory)
       ↓ miss
  2. redb (fast - disk file)
       ↓ miss
  3. PostgreSQL (slow - network socket + query)
       ↓ miss
  4. External Registry API (slowest - internet)
```

---

## **Why Use Multiple Storage Layers?**

### **PostgreSQL:**
- Source of truth
- ACID guarantees
- Complex queries (joins, aggregations)
- pgvector for semantic search

### **redb:**
- Fast package metadata lookups
- Persistent across restarts
- No PostgreSQL overhead for simple reads

### **JetStream KV:**
- Hot data cache (recently accessed)
- Shared across processes
- Auto-expiry (TTL=1h)
- Reduces both PostgreSQL AND redb load

---

## **Summary**

**Q:** "local engines? you mean remote cache?"

**A:** NO - everything is **local** (same machine):
- ✅ Elixir app - local
- ✅ Rust services - local (via NATS)
- ✅ NATS JetStream KV - local (in-memory cache)
- ✅ redb - local (disk file)
- ✅ PostgreSQL - local

**The only "remote" calls are:**
- External package registries (npm, crates.io, hex.pm)
- AI provider APIs (Claude, Gemini, etc.)

**JetStream KV is NOT a remote cache** - it's a local in-memory cache managed by NATS on localhost.
