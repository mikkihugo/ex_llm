# Template Cache Architecture

High-performance template caching with **ETS + NATS JetStream KV** for AI agents and prompt engines.

## Performance

| Cache Level | Latency | Scope | Persistence |
|-------------|---------|-------|-------------|
| **ETS (L1)** | <1ms | Per-node | In-memory only |
| **NATS KV (L2)** | 1-2ms | Distributed | Optional |
| **PostgreSQL (L3)** | 10-30ms | Global | Persistent |

## Architecture

```
Agent/Prompt Engine
       ↓
   NATS Request
       ↓
TemplateService (Elixir)
       ↓
TemplateCache
   ├─ ETS lookup (<1ms)
   ├─ NATS KV lookup (1-2ms) [on ETS miss]
   └─ PostgreSQL query (10-30ms) [on all misses]
       ↓
   Cache Result
       ↓
   Return via NATS
```

## Setup

### 1. Create NATS KV Buckets

```bash
./scripts/setup-nats-templates.sh
```

This creates:
- `templates` - Main bucket (30min TTL, memory)
- `templates-hot` - Hot templates (1h TTL, memory, 3 replicas)
- `templates-cold` - Archive (24h TTL, file storage)

### 2. Warm the Cache (on startup)

```elixir
# Automatically done in application startup
Singularity.Knowledge.TemplateCache.warm_cache()
```

Loads all templates from PostgreSQL into ETS + NATS KV.

## Usage

### From Elixir

```elixir
# Get template (tries ETS → NATS KV → PostgreSQL)
{:ok, template} = Singularity.Knowledge.TemplateCache.get("framework", "phoenix")

# Invalidate template (clears all caches + broadcasts)
Singularity.Knowledge.TemplateCache.invalidate("framework", "phoenix")

# Get stats
stats = Singularity.Knowledge.TemplateCache.stats()
# => %{ets_hits: 1250, nats_hits: 45, db_hits: 12, misses: 3}
```

### From NATS (Rust, Go, Python, etc.)

```rust
// Rust example
use async_nats;
use serde_json::Value;

#[tokio::main]
async fn main() {
    let nc = async_nats::connect("nats://localhost:4222").await?;

    // Request Phoenix template
    let response = nc
        .request("template.get.framework.phoenix", "".into())
        .await?;

    let template: Value = serde_json::from_slice(&response.payload)?;
    println!("Got template: {}", template["name"]);
}
```

```bash
# CLI
nats request template.get.framework.phoenix ""
```

## NATS Subjects

### Get Template

```
template.get.{type}.{id}
```

Examples:
- `template.get.framework.phoenix` - Phoenix framework
- `template.get.language.rust` - Rust language
- `template.get.quality.elixir-production` - Elixir quality rules

### Search (TODO)

```
template.search.{query}
```

### Notifications (Subscribe)

```
template.updated.{type}.{id}  - Template was updated
template.invalidate.{type}.{id} - Cache invalidation
```

## Cache Invalidation

### Automatic

When templates are updated in PostgreSQL:

```elixir
# Update in database
changeset = KnowledgeArtifact.changeset(artifact, %{content: new_content})
Repo.update!(changeset)

# Broadcast update (TemplateCache subscribes to this)
Gnat.pub(gnat, "template.updated.framework.phoenix", "")
```

All nodes will automatically invalidate their ETS + NATS KV caches.

### Manual

```elixir
TemplateCache.invalidate("framework", "phoenix")
```

Removes from:
1. Local ETS
2. NATS KV
3. Broadcasts to all other nodes

## Monitoring

### Telemetry Events

```elixir
# Cache hits/misses
[:singularity, :template_cache, :ets_hit]
[:singularity, :template_cache, :nats_hit]
[:singularity, :template_cache, :db_hit]
[:singularity, :template_cache, :miss]

# NATS service requests
[:singularity, :template_service, :request]
# Metadata: %{status: :success | :error | :not_found, artifact_type: "framework"}
# Measurements: %{duration_us: 1250}
```

### Metrics

```elixir
# Get cache statistics
Singularity.Knowledge.TemplateCache.stats()

# Output:
%{
  ets_hits: 15234,
  nats_hits: 456,
  db_hits: 23,
  misses: 5,
  ets_cache_size: 127,
  timestamp: ~U[2025-10-06 23:00:00Z]
}
```

## Performance Tuning

### Adjust TTL

Edit `template_cache.ex`:

```elixir
@ttl_seconds 1800  # 30 minutes (default)
@ttl_seconds 3600  # 1 hour (longer cache)
@ttl_seconds 600   # 10 minutes (more fresh)
```

### Increase NATS KV Size

```bash
nats kv add templates --max-bucket-size=5GB  # Increase from 1GB
```

### Preload Hot Templates

```elixir
# In StartupWarmup
Singularity.Knowledge.TemplateCache.warm_cache()
```

## Troubleshooting

### Cache Not Working

Check NATS connection:
```bash
nats account info
```

Check KV buckets:
```bash
nats kv ls
nats kv info templates
```

### High Miss Rate

Check ETS cache size:
```elixir
:ets.info(:template_cache, :size)
```

Verify templates in PostgreSQL:
```sql
SELECT COUNT(*) FROM knowledge_artifacts;
```

### Stale Cache

Clear all caches:
```elixir
Singularity.Knowledge.TemplateCache.clear_all()
```

Rewarm:
```elixir
Singularity.Knowledge.TemplateCache.warm_cache()
```

## Integration with Prompt Engine (Rust)

Your Rust prompt engine can connect via NATS:

```rust
// prompt-engine/src/template_client.rs
use async_nats;
use serde_json::Value;

pub struct TemplateClient {
    nats: async_nats::Client,
}

impl TemplateClient {
    pub async fn new() -> Result<Self, Error> {
        let nats = async_nats::connect("nats://localhost:4222").await?;
        Ok(Self { nats })
    }

    pub async fn get_template(&self, type_: &str, id: &str) -> Result<Value, Error> {
        let subject = format!("template.get.{}.{}", type_, id);

        let response = self.nats
            .request(subject, "".into())
            .await?;

        let template = serde_json::from_slice(&response.payload)?;
        Ok(template)
    }
}
```

**No Rustler needed!** Prompt engine runs as separate process, connects via NATS.

## Benefits

✅ **Fast:** <1ms for cached templates (ETS)
✅ **Distributed:** NATS KV shared across all nodes
✅ **Language Agnostic:** Rust, Go, Python can all use NATS
✅ **Scalable:** Horizontal scaling with NATS
✅ **Persistent:** PostgreSQL source of truth
✅ **Observable:** Telemetry for all cache operations
✅ **Simple:** No Redis, no extra infrastructure

## Next Steps

- [ ] Implement semantic search via `template.search.*`
- [ ] Add template versioning in cache keys
- [ ] Implement hot/cold tier migration
- [ ] Add cache prewarming strategies
