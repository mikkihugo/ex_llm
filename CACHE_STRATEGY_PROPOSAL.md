# Knowledge Cache: Multi-Tier Storage Strategy

## Current State (In-Memory Only)

**What we have:**
```rust
// rust/service/knowledge_cache/src/lib.rs
static GLOBAL_CACHE: Lazy<GlobalCache> =
    Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));
```

**Problem:**
- ❌ Lost on restart (no persistence)
- ❌ Only in-memory (limited by RAM)
- ❌ No JetStream (no NATS persistence)
- ❌ No PostgreSQL (no long-term storage)

---

## Proposed: 3-Tier Cache Strategy

```
┌─────────────────────────────────────────────────────────┐
│  Tier 1: Memory (Hot Cache)                             │
│  - HashMap (current)                                    │
│  - Ultra-fast: ~1μs                                     │
│  - Size: Latest 1000 used templates                     │
│  - TTL: In-use + LRU eviction                          │
└─────────────────────────────────────────────────────────┘
                       ↓ Miss
┌─────────────────────────────────────────────────────────┐
│  Tier 2: NATS JetStream (Warm Cache)                    │
│  - Persistent stream                                    │
│  - Fast: ~1-5ms                                         │
│  - Size: All templates (unlimited via retention)       │
│  - Replicated across NATS cluster                      │
└─────────────────────────────────────────────────────────┘
                       ↓ Miss
┌─────────────────────────────────────────────────────────┐
│  Tier 3: PostgreSQL (Cold Storage)                      │
│  - knowledge_artifacts table                            │
│  - Slower: ~10-50ms                                     │
│  - Size: Unlimited + versioned + searchable            │
│  - Source of truth                                      │
└─────────────────────────────────────────────────────────┘
```

---

## Tier 1: Memory (Hot Cache - Current)

### Implementation
```rust
use lru::LruCache;
use std::num::NonZeroUsize;

static HOT_CACHE: Lazy<Arc<Mutex<LruCache<String, KnowledgeAsset>>>> =
    Lazy::new(|| {
        let capacity = NonZeroUsize::new(1000).unwrap();
        Arc::new(Mutex::new(LruCache::new(capacity)))
    });
```

### Characteristics
- **Speed:** ~1μs (HashMap/LRU lookup)
- **Size:** 1000 most-used templates
- **Eviction:** LRU (Least Recently Used)
- **Persistence:** None (lost on restart)

### Use Case
- Ultra-fast access for hot templates
- Popular templates (used in last hour)
- Current session templates

---

## Tier 2: NATS JetStream (Warm Cache - NEW!)

### Why JetStream?

**✅ Perfect for this use case:**
1. **Persistent** - Survives restarts
2. **Fast** - 1-5ms access (faster than PostgreSQL)
3. **Distributed** - Replicated across NATS cluster
4. **Stream-based** - Perfect for cache updates
5. **Built-in** - Already using NATS

### Implementation

#### JetStream Stream Setup
```rust
// Create persistent stream for knowledge assets
let stream_config = jetstream::stream::Config {
    name: "KNOWLEDGE_CACHE".to_string(),
    subjects: vec!["knowledge.cache.>".to_string()],
    retention: jetstream::stream::RetentionPolicy::Limits,
    max_msgs: 100_000,      // Store up to 100k templates
    max_bytes: 10_737_418_240,  // 10GB
    max_age: Duration::from_secs(30 * 24 * 60 * 60),  // 30 days
    storage: jetstream::stream::StorageType::File,
    num_replicas: 3,        // 3x replication
    ..Default::default()
};

context.create_stream(stream_config).await?;
```

#### Publishing to JetStream
```rust
// Save template to JetStream
pub async fn save_to_jetstream(
    js: &jetstream::Context,
    asset: &KnowledgeAsset
) -> Result<()> {
    let subject = format!("knowledge.cache.template.{}", asset.id);
    let payload = serde_json::to_vec(asset)?;

    js.publish(subject, payload.into())
        .await?
        .await?;  // Wait for ack

    Ok(())
}
```

#### Loading from JetStream
```rust
// Get template from JetStream
pub async fn load_from_jetstream(
    js: &jetstream::Context,
    id: &str
) -> Result<Option<KnowledgeAsset>> {
    let subject = format!("knowledge.cache.template.{}", id);

    // Get last message for this template
    let stream = js.get_stream("KNOWLEDGE_CACHE").await?;

    match stream.get_last_raw_message_by_subject(&subject).await {
        Ok(msg) => {
            let asset: KnowledgeAsset = serde_json::from_slice(&msg.payload)?;
            Ok(Some(asset))
        }
        Err(_) => Ok(None),
    }
}
```

### Characteristics
- **Speed:** ~1-5ms (network + disk)
- **Size:** 100k templates (configurable)
- **Retention:** 30 days (configurable)
- **Replicas:** 3x (for redundancy)
- **Persistence:** File-based storage

### Use Case
- Recently used templates (last week)
- Shared across all instances
- Survives restarts
- Faster than PostgreSQL

---

## Tier 3: PostgreSQL (Cold Storage - Long-term)

### Schema

```sql
-- knowledge_artifacts table (already exists?)
CREATE TABLE knowledge_artifacts (
    id SERIAL PRIMARY KEY,
    artifact_id TEXT NOT NULL UNIQUE,
    artifact_type TEXT NOT NULL,  -- 'template', 'pattern', 'prompt', etc.
    content_raw TEXT NOT NULL,    -- Original JSON
    content JSONB NOT NULL,       -- Parsed for queries
    metadata JSONB,
    embedding vector(1536),       -- pgvector for semantic search
    usage_count INTEGER DEFAULT 0,
    success_rate FLOAT DEFAULT 0.0,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1
);

CREATE INDEX idx_artifact_type ON knowledge_artifacts(artifact_type);
CREATE INDEX idx_artifact_id ON knowledge_artifacts(artifact_id);
CREATE INDEX idx_last_used ON knowledge_artifacts(last_used_at DESC);
CREATE INDEX idx_usage_count ON knowledge_artifacts(usage_count DESC);

-- Vector similarity search
CREATE INDEX idx_embedding ON knowledge_artifacts
    USING ivfflat (embedding vector_cosine_ops);
```

### Implementation

```rust
use sqlx::PgPool;

pub async fn save_to_postgres(
    pool: &PgPool,
    asset: &KnowledgeAsset
) -> Result<()> {
    sqlx::query!(
        r#"
        INSERT INTO knowledge_artifacts (
            artifact_id, artifact_type, content_raw, content, metadata, version
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (artifact_id) DO UPDATE
        SET
            content_raw = EXCLUDED.content_raw,
            content = EXCLUDED.content,
            metadata = EXCLUDED.metadata,
            version = EXCLUDED.version,
            updated_at = NOW()
        "#,
        asset.id,
        asset.asset_type,
        asset.data,
        serde_json::to_value(&asset)?,
        serde_json::to_value(&asset.metadata)?,
        asset.version
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn load_from_postgres(
    pool: &PgPool,
    id: &str
) -> Result<Option<KnowledgeAsset>> {
    let row = sqlx::query!(
        r#"
        SELECT artifact_id, artifact_type, content_raw, metadata, version
        FROM knowledge_artifacts
        WHERE artifact_id = $1
        "#,
        id
    )
    .fetch_optional(pool)
    .await?;

    match row {
        Some(r) => {
            // Track usage
            sqlx::query!(
                "UPDATE knowledge_artifacts
                 SET usage_count = usage_count + 1,
                     last_used_at = NOW()
                 WHERE artifact_id = $1",
                id
            )
            .execute(pool)
            .await?;

            Ok(Some(KnowledgeAsset {
                id: r.artifact_id,
                asset_type: r.artifact_type,
                data: r.content_raw,
                metadata: serde_json::from_value(r.metadata)?,
                version: r.version,
            }))
        }
        None => Ok(None),
    }
}
```

### Characteristics
- **Speed:** ~10-50ms (network + query)
- **Size:** Unlimited
- **Features:**
  - Versioning
  - Usage tracking
  - Semantic search (pgvector)
  - Full-text search
  - Analytics queries

### Use Case
- Long-term storage
- Historical versions
- Analytics (most used, success rates)
- Semantic search
- Backup/recovery

---

## Complete Cache Flow

### Read (with fallthrough)

```rust
pub async fn get_template(
    id: &str,
    hot: &Arc<Mutex<LruCache<String, KnowledgeAsset>>>,
    js: &jetstream::Context,
    db: &PgPool
) -> Result<KnowledgeAsset> {
    // 1. Try hot cache (memory) - ~1μs
    {
        let mut cache = hot.lock().unwrap();
        if let Some(asset) = cache.get(id) {
            info!("HIT: memory cache");
            return Ok(asset.clone());
        }
    }

    // 2. Try JetStream (warm cache) - ~1-5ms
    if let Some(asset) = load_from_jetstream(js, id).await? {
        info!("HIT: JetStream cache");

        // Promote to hot cache
        hot.lock().unwrap().put(id.to_string(), asset.clone());

        return Ok(asset);
    }

    // 3. Try PostgreSQL (cold storage) - ~10-50ms
    if let Some(asset) = load_from_postgres(db, id).await? {
        info!("HIT: PostgreSQL");

        // Promote to JetStream
        save_to_jetstream(js, &asset).await?;

        // Promote to hot cache
        hot.lock().unwrap().put(id.to_string(), asset.clone());

        return Ok(asset);
    }

    Err(anyhow!("Template not found: {}", id))
}
```

### Write (write-through)

```rust
pub async fn save_template(
    asset: &KnowledgeAsset,
    hot: &Arc<Mutex<LruCache<String, KnowledgeAsset>>>,
    js: &jetstream::Context,
    db: &PgPool
) -> Result<()> {
    // 1. Save to PostgreSQL (source of truth)
    save_to_postgres(db, asset).await?;

    // 2. Save to JetStream (distribute)
    save_to_jetstream(js, asset).await?;

    // 3. Update hot cache
    hot.lock().unwrap().put(asset.id.clone(), asset.clone());

    // 4. Broadcast to other instances
    publish_cache_update(js, asset).await?;

    Ok(())
}
```

---

## Cache Eviction & TTL

### Hot Cache (Memory)
- **LRU eviction** - Least recently used
- **Size limit** - 1000 templates max
- **No TTL** - Stays until evicted

### Warm Cache (JetStream)
- **Time-based** - 30 day retention
- **Size limit** - 100k messages or 10GB
- **Replicated** - 3x redundancy

### Cold Storage (PostgreSQL)
- **No eviction** - Keep forever
- **Track usage** - `last_used_at`, `usage_count`
- **Archive old** - Optional: Move to cold storage after 1 year

---

## Benefits

### ✅ Multi-Tier Performance
- **Hot:** 1μs (memory)
- **Warm:** 1-5ms (JetStream)
- **Cold:** 10-50ms (PostgreSQL)

### ✅ Persistence
- Survives restarts (JetStream + PostgreSQL)
- No data loss
- Versioned history

### ✅ Distribution
- JetStream replicates across cluster
- All instances share cache
- Automatic synchronization

### ✅ Analytics
- Track usage (PostgreSQL)
- Success rates
- Semantic search
- Popular templates

### ✅ LRU Intelligence
- Keep hot templates in memory
- Promote frequently used
- Evict rarely used

---

## Implementation Plan

### Phase 1: JetStream Integration (High Priority)
1. Add JetStream to knowledge_cache
2. Create KNOWLEDGE_CACHE stream
3. Implement save/load functions
4. Add to cache flow

### Phase 2: PostgreSQL Integration
1. Create/verify knowledge_artifacts table
2. Implement save/load functions
3. Add usage tracking
4. Add to cache flow

### Phase 3: LRU Hot Cache
1. Replace HashMap with LRU
2. Add size limits
3. Add eviction policy

### Phase 4: Analytics
1. Usage tracking
2. Success rates
3. Popular templates dashboard

---

## Recommended Storage Decisions

### Store in JetStream? ✅ YES
- **Fast** (1-5ms vs 10-50ms PostgreSQL)
- **Persistent** (survives restarts)
- **Distributed** (replicated)
- **Built-in** (already using NATS)

### Store in PostgreSQL? ✅ YES
- **Source of truth** (long-term)
- **Versioning** (history)
- **Analytics** (usage tracking)
- **Semantic search** (pgvector)

### Keep Memory Cache? ✅ YES (with LRU)
- **Ultra-fast** (1μs)
- **Latest in-use** (LRU keeps hot)
- **Size-limited** (1000 templates)

---

## Summary

**Recommended: 3-Tier Cache**

1. **Memory (Hot)** - 1000 latest used (LRU), ~1μs
2. **JetStream (Warm)** - All templates, ~1-5ms, 30 days
3. **PostgreSQL (Cold)** - Forever, ~10-50ms, analytics

**Result: Fast, persistent, distributed, intelligent cache!** 🎉
