# PostgreSQL 17 Extension MVP - Complete Usage Guide

## Overview

All 8 PostgreSQL 17 extensions are now integrated with MVP-level implementations. Each extension serves a specific purpose in the Singularity distributed AI agent system.

## Extension Usage Summary

| Extension | Purpose | MVP Implementation | Module |
|-----------|---------|-------------------|--------|
| **pgsodium** | Database-level encryption | ✅ Encrypt agent secrets, API keys, knowledge | `Singularity.Database.Encryption` |
| **pgx_ulid** | Distributed ID generation | ✅ Session IDs, correlation IDs, batch IDs | `Singularity.Database.DistributedIds` |
| **pgmq** | Durable message queue | ✅ Pattern sync, session updates, knowledge aggregation | `Singularity.Database.MessageQueue` |
| **wal2json** | Change Data Capture | ✅ Stream pattern changes to CentralCloud | `Singularity.Database.ChangeDataCapture` |
| **pg_net** | HTTP from SQL | ✅ Fetch package metadata from npm/cargo/hex/pypi | `Singularity.Database.RemoteDataFetcher` |
| **lantern** | Vector search | ✅ Pattern similarity matching and deduplication | `Singularity.Database.PatternSimilaritySearch` |
| **h3** | Geospatial indexing | ✅ Cluster agents by geographic region | `Singularity.Database.AgentGeospatialClustering` |
| **timescaledb_toolkit** | Time-series analytics | ✅ Aggregate metrics with pre-computed views | `Singularity.Database.MetricsAggregation` |

## Detailed Extension Usage

### 1. pgsodium - Database-Level Encryption

**What it does:** Encrypts sensitive data at database layer using XSalsa20-Poly1305 authenticated encryption.

**MVP Use Case:** Secure agent secrets, API keys for instance communication, sensitive metadata.

**Module:** `lib/singularity/database/encryption.ex`

**Functions:**
```elixir
# Encrypt sensitive data
{:ok, encrypted} = Encryption.encrypt("api_secret", agent_api_key)

# Decrypt (only PostgreSQL sees plaintext, never Elixir app)
{:ok, plaintext} = Encryption.decrypt("api_secret", encrypted_blob)

# Hash passwords (Argon2 via PostgreSQL crypt())
{:ok, hash} = Encryption.hash_password(password)

# Sign messages between instances (HMAC)
{:ok, signature} = Encryption.sign_message(secret, message)

# Verify signatures (prevent spoofing)
{:ok, true} = Encryption.verify_message(secret, message, signature)

# Generate secure tokens
{:ok, token} = Encryption.generate_token()
```

**Data Flow:**
```
Agent Secret
    ↓
Elixir calls PostgreSQL function
    ↓
pgsodium.crypto_secretbox_encrypt()
    ↓
Encrypted blob stored in DB
    ↓
Application never sees plaintext
```

---

### 2. pgx_ulid - Distributed ID Generation

**What it does:** Generates ULID (sortable, monotonic, distributed) identifiers for cross-instance tracking.

**MVP Use Case:** Session IDs, correlation IDs, batch IDs for pattern synchronization.

**Module:** `lib/singularity/database/distributed_ids.ex`

**Functions:**
```elixir
# Generate session ID
session_id = DistributedIds.generate_batch_id()

# Generate correlation ID (for request tracing)
correlation_id = DistributedIds.generate_correlation_id()

# Generate trace ID (distributed tracing)
trace_id = DistributedIds.generate_trace_id()

# Generate batch of IDs efficiently
ids = DistributedIds.generate_batch(100)

# Extract timestamp from ULID (useful for age calculations)
{:ok, ts_ms} = DistributedIds.ulid_timestamp(ulid)

# Check if ULID is recent (within N seconds)
true = DistributedIds.recent?(ulid, seconds: 300)

# Get age of ULID in seconds
age = DistributedIds.age_seconds(ulid)
```

**Data Flow:**
```
Agent spawns
    ↓
Generate ULID via PostgreSQL
    ↓
ULID = timestamp (48-bit) + randomness (80-bit)
    ↓
Sortable: ULIDs from same millisecond are ordered by randomness
    ↓
CentralCloud uses ULID to order cross-instance events
```

**Why ULID over UUID:**
- Sortable (can ORDER BY ULID chronologically)
- Monotonic (same millisecond = ordered by randomness)
- Contains timestamp (extract time without separate column)
- Smaller than UUID v4 (128 bits)

---

### 3. pgmq - Durable Message Queue

**What it does:** ACID-backed message queuing using PostgreSQL, survives crashes.

**MVP Use Case:** Pattern learning, session persistence, knowledge aggregation queues.

**Module:** `lib/singularity/database/message_queue.ex`

**Functions:**
```elixir
# Initialize queue
{:ok, "queue-name"} = MessageQueue.create_queue("cc-instance-patterns")

# Send message
{:ok, msg_id} = MessageQueue.send("cc-instance-patterns", %{"pattern" => data})

# Receive message (30-sec visibility timeout, auto-hidden while processing)
{:ok, {msg_id, message}} = MessageQueue.receive_message("cc-instance-patterns")

# Process batch
count = MessageQueue.process_batch("cc-instance-patterns", &handle_pattern/1, limit: 100)

# Acknowledge (mark as processed)
{:ok, :deleted} = MessageQueue.acknowledge("cc-instance-patterns", msg_id)

# Nack (put back in queue if handler failed)
{:ok, :requeued} = MessageQueue.nack("cc-instance-patterns", msg_id)

# Get queue stats
{:ok, %{total_messages: 50, in_flight: 5, available: 45}} = MessageQueue.queue_stats("cc-instance-patterns")

# Check if queue is backed up
true = MessageQueue.queue_backed_up?("cc-instance-patterns", threshold: 1000)
```

**Queues:**
- `cdc-learned-patterns` - Pattern changes from CDC
- `cdc-agent-sessions` - Session updates
- `cdc-metrics-events` - Metric records

**Data Flow:**
```
Agent learns pattern
    ↓
PostgreSQL trigger enqueues to pgmq
    ↓
Message persisted (ACID)
    ↓
Consumer polls and processes
    ↓
On success: acknowledge (delete from queue)
On failure: nack (visibility timeout reset, message requeued)
```

---

### 4. wal2json - Change Data Capture (CDC)

**What it does:** Streams all database changes in JSON format using PostgreSQL's logical decoding.

**MVP Use Case:** Real-time replication to CentralCloud without polling.

**Module:** `lib/singularity/database/change_data_capture.ex`

**Functions:**
```elixir
# Initialize CDC slot (run once at startup)
{:ok, :created} = ChangeDataCapture.init_slot()

# Get pending changes (INSERT/UPDATE/DELETE events)
{:ok, changes} = ChangeDataCapture.get_changes()

# Get changes since specific LSN (Log Sequence Number)
{:ok, changes} = ChangeDataCapture.get_changes_since("0/12345678")

# Confirm processed (advance slot, free WAL storage)
:ok = ChangeDataCapture.confirm_processed(lsn)

# Get CDC slot status (lag, memory usage)
{:ok, status} = ChangeDataCapture.slot_status()
# => %{name: "singularity_centralcloud_cdc", lag_mb: 5, slot_size: "12 MB"}

# Drop slot (clean shutdown)
{:ok, :dropped} = ChangeDataCapture.drop_slot()
```

**Change Event Structure:**
```elixir
%{
  lsn: "0/12345678",              # Log Sequence Number (WAL position)
  kind: "insert",                 # insert, update, delete
  schema: "public",
  table: "learned_patterns",
  columns: ["id", "code_snippet", "embedding"],
  values: [123, "async task", [0.1, 0.2, ...]],
  before_values: nil,             # Only for UPDATE
  timestamp: ~U[2025-10-25 ...]
}
```

**Data Flow:**
```
Agent learns pattern
    ↓
INSERT into learned_patterns table
    ↓
PostgreSQL WAL (Write-Ahead Log)
    ↓
wal2json logical decoder
    ↓
CDC slot captures JSON events
    ↓
get_changes() retrieves pending changes
    ↓
NATS sends to CentralCloud
    ↓
confirm_processed() advances slot (frees WAL)
```

**Benefits over polling:**
- Zero latency (changes streamed immediately)
- No SELECT * queries (low CPU)
- Persistent (survives restarts via slot)
- Minimal WAL overhead

---

### 5. pg_net - HTTP from SQL

**What it does:** Make HTTP requests directly from PostgreSQL without external libraries.

**MVP Use Case:** Fetch package registry data (npm, cargo, hex, pypi) and cache it.

**Module:** `lib/singularity/database/remote_data_fetcher.ex`

**Functions:**
```elixir
# Fetch and cache package metadata
{:ok, pkg} = RemoteDataFetcher.fetch_npm("react")
{:ok, pkg} = RemoteDataFetcher.fetch_cargo("tokio")
{:ok, pkg} = RemoteDataFetcher.fetch_hex("phoenix")
{:ok, pkg} = RemoteDataFetcher.fetch_pypi("django")

# Get cached metadata (no network call)
{:ok, pkg} = RemoteDataFetcher.get_cached("npm", "react")

# Check if cached data is fresh (< 24h)
true = RemoteDataFetcher.is_fresh?("cargo", "tokio")

# Refresh expired cache entries
{:ok, 42} = RemoteDataFetcher.refresh_expired_cache(limit: 100)

# Get cache statistics
{:ok, stats} = RemoteDataFetcher.cache_stats()
```

**Cached Package Data:**
```elixir
%{
  name: "react",
  ecosystem: "npm",
  version: "18.2.0",
  description: "A JavaScript library for building UI",
  homepage: "https://react.dev",
  repository: "https://github.com/facebook/react",
  downloads: 25000000,  # per month
  updated_at: ~U[2025-10-20 ...]
}
```

**Data Flow:**
```
Elixir: RemoteDataFetcher.fetch_npm("react")
    ↓
PostgreSQL pg_net.http_get("https://registry.npmjs.org/react")
    ↓
HTTP request (async, non-blocking)
    ↓
Response stored in package_registry table
    ↓
pg_net returns cached JSON
    ↓
Elixir parses response
```

**Registries Supported:**
- npm: `registry.npmjs.org/package`
- Cargo: `crates.io/api/v1/crates/package`
- Hex: `hex.pm/api/packages/package`
- PyPI: `pypi.org/pypi/package/json`

---

### 6. lantern - Vector Search (Similarity Matching)

**What it does:** HNSW (Hierarchical Navigable Small World) indexing for fast k-nearest neighbor search on embeddings.

**MVP Use Case:** Find similar code patterns, detect duplicates, recommend patterns.

**Module:** `lib/singularity/database/pattern_similarity_search.ex`

**Functions:**
```elixir
# Search for patterns similar to code snippet
{:ok, similar} = PatternSimilaritySearch.search_patterns(
  "async task with error handling",
  limit: 5,
  distance_threshold: 0.3
)

# Search within specific agent
{:ok, similar} = PatternSimilaritySearch.search_agent_patterns(
  agent_id,
  "retry logic",
  limit: 10
)

# Find duplicate patterns (>95% similarity)
{:ok, duplicates} = PatternSimilaritySearch.find_duplicate_patterns(min_similarity: 0.95)

# Get neighbors of a pattern
{:ok, neighbors} = PatternSimilaritySearch.get_pattern_neighbors(pattern_id, limit: 5)

# Get index statistics
{:ok, stats} = PatternSimilaritySearch.index_stats()

# Rebuild index after bulk import
{:ok, :rebuilt} = PatternSimilaritySearch.rebuild_index()
```

**Search Result:**
```elixir
%{
  id: 123,
  code_snippet: "async fn handle() { ... }",
  pattern_type: "async_handler",
  agent_id: 1,
  distance: 0.15,           # L2 distance (lower = more similar)
  similarity_score: 0.925   # Normalized 0-1 (higher = more similar)
}
```

**Data Flow:**
```
Query: "async task with error handling"
    ↓
Get embedding (1536-dim Qodo-Embed vector)
    ↓
Lantern HNSW search for k-nearest neighbors
    ↓
L2 distance metric (Euclidean distance)
    ↓
Return top N patterns ranked by distance
```

**Lantern vs pgvector:**
| Feature | Lantern | pgvector |
|---------|---------|----------|
| Index Type | HNSW | IVFFlat, HNSW |
| Distance Metrics | L2, cosine | L2, inner product, cosine |
| Performance | Optimized | Good |
| Use Case | MVP similarity search | Production-scale |

---

### 7. h3 - Geospatial Indexing

**What it does:** Hexagonal hierarchical geospatial indexing for clustering agents by geographic region.

**MVP Use Case:** Multi-instance agent clustering, location-based workload balancing, cross-instance knowledge sharing.

**Module:** `lib/singularity/database/agent_geospatial_clustering.ex`

**Functions:**
```elixir
# Set agent location (auto-calculates H3 cell)
{:ok, h3_cell} = AgentGeospatialClustering.set_agent_location(agent_id, 37.7749, -122.4194)

# Find nearby agents (same cell or neighbors)
{:ok, nearby} = AgentGeospatialClustering.find_nearby_agents(agent_id, radius: :neighbors)

# Get all agents in specific hex cell
{:ok, agents} = AgentGeospatialClustering.get_agents_in_hex("891e1000000ffff")

# Cluster agents by region
{:ok, clusters} = AgentGeospatialClustering.cluster_agents_by_region()

# Get H3 cell children (zoom in)
{:ok, children} = AgentGeospatialClustering.get_cell_children(parent_h3, resolution: 8)

# Get H3 cell parent (zoom out)
{:ok, parent} = AgentGeospatialClustering.get_cell_parent(h3_cell, resolution: 5)

# Get cell neighbors (adjacent cells)
{:ok, neighbors} = AgentGeospatialClustering.get_cell_neighbors(h3_cell)

# Get distance between agents
{:ok, distance} = AgentGeospatialClustering.get_h3_distance(agent_1_id, agent_2_id)

# Get regional statistics
{:ok, stats} = AgentGeospatialClustering.get_regional_stats()
```

**Cluster Result:**
```elixir
%{
  h3_cell: "891e1000000ffff",      # Hexagonal cell ID
  agent_count: 5,
  center_latitude: 37.7749,
  center_longitude: -122.4194,
  agent_names: ["agent-1", "agent-2", ...]
}
```

**H3 Resolution Levels:**
| Level | Size | Use Case |
|-------|------|----------|
| 0 | ~10,000 km | Continents |
| 6 | ~1.2 km | Neighborhoods (MVP default) |
| 8 | ~462 m | City blocks |
| 9 | ~154 m | House-level precision |
| 15 | ~10 cm | Precise measurement |

**Data Flow:**
```
Agent location: lat=37.7749, lon=-122.4194
    ↓
H3 encode (resolution 6)
    ↓
Cell ID: "891e1000000ffff"
    ↓
Find neighbors: 7 adjacent hex cells
    ↓
Query agents in same cell + neighbors
    ↓
Route requests to nearest agent
```

**Use Cases:**
- **Latency optimization:** Route requests to nearest agent
- **Knowledge sharing:** Share patterns with nearby agents
- **Workload balancing:** Distribute tasks across regions
- **Colocation detection:** Find agents in same location for local clustering

---

### 8. timescaledb_toolkit - Time-Series Analytics

**What it does:** Pre-computed aggregates (5min, 1hour, 1day) of metrics with compression for old data.

**MVP Use Case:** Agent performance dashboards, metrics trending, SLO monitoring.

**Module:** `lib/singularity/database/metrics_aggregation.ex`

**Functions:**
```elixir
# Record metric event
:ok = MetricsAggregation.record_metric(:agent_cpu, 45.2, %{agent_id: 1})

# Get raw metrics (last N seconds)
{:ok, metrics} = MetricsAggregation.get_metrics(:agent_cpu, last: 3600)

# Get time-bucketed aggregates (5min, 1hour, 1day)
{:ok, buckets} = MetricsAggregation.get_time_buckets(:agent_cpu, window: 300, last: 86400)

# Get percentile distribution
{:ok, p95} = MetricsAggregation.get_percentile(:task_duration_ms, 95)

# Get rate of change (growth rate)
{:ok, rate} = MetricsAggregation.get_rate(:patterns_learned, window: 3600)

# Get agent performance dashboard
{:ok, dashboard} = MetricsAggregation.get_agent_dashboard(agent_id)

# Compress old metrics (>30 days)
{:ok, chunk_count} = MetricsAggregation.compress_old_metrics(days: 30)

# Get table statistics
{:ok, stats} = MetricsAggregation.get_table_stats()
```

**Dashboard Result:**
```elixir
%{
  agent_id: 1,
  cpu: %{average: 42.5, peak: 85.3},
  memory_mb: 256.7,
  patterns_per_hour: 12,
  tasks_per_hour: 87,
  failures_per_hour: 2,
  error_rate_percent: 2.3
}
```

**Metrics Tracked:**
- `agent_cpu` - CPU usage (%)
- `agent_memory_mb` - Memory usage (MB)
- `pattern_learned` - Patterns learned/hour
- `task_completed` - Tasks completed/hour
- `task_failed` - Task failures/hour
- `task_duration_ms` - Task execution time (ms)

**Data Flow:**
```
Metric event: agent_cpu = 45.2
    ↓
Record in metrics_events (hypertable)
    ↓
TimescaleDB time-bucketing (automatic)
    ↓
Pre-computed aggregates:
  - 5-minute buckets (metrics_5min view)
  - 1-hour buckets (metrics_1h view)
  - 1-day buckets (metrics_1d view)
    ↓
Dashboard queries use pre-computed views (instant)
    ↓
Compress chunks >30 days (1/10th size)
```

**Benefits:**
- **Instant dashboards:** Pre-computed aggregates (no SELECT AVG())
- **Space efficiency:** Compression reduces 30-day data to 10% size
- **Time-series optimized:** Hypertable auto-partitioning by time
- **SLO tracking:** Percentiles for latency/error monitoring

---

## Database Migrations

New migration created: `20251025000005_add_pg17_extension_tables.exs`

**Tables Created:**
1. `package_registry` - pg_net package caching
2. `metrics_events` - timescaledb_toolkit hypertable
3. `code_embeddings` - lantern vector index
4. `agents` columns added - h3 location fields

**Continuous Aggregates Created:**
1. `metrics_5min` - 5-minute aggregates
2. `metrics_1h` - 1-hour aggregates
3. `metrics_1d` - 1-day aggregates

---

## Integration Points

### CDC → NATS → CentralCloud

```elixir
# Singularity startup
ChangeDataCapture.init_slot()

# Periodic consumer (every 5 seconds)
changes = ChangeDataCapture.get_changes()
Enum.each(changes, fn change ->
  if change.table == "learned_patterns" do
    # Enqueue to pgmq
    MessageQueue.send("cdc-learned-patterns", change)
  end
end)
ChangeDataCapture.confirm_processed(last_lsn)

# Separate NATS publisher
Enum.each(MessageQueue.process_batch("cdc-learned-patterns", &publish_to_nats/1), fn _ -> end)
```

### Pattern Learning Loop

```elixir
# Agent learns pattern
pattern_embedding = embed_pattern(code_snippet)

# Store in DB (triggers CDC)
Repo.insert!(%LearnedPattern{
  code_snippet: code_snippet,
  embedding: pattern_embedding,
  agent_id: agent_id
})

# CDC captures INSERT
# → ChangeDataCapture.get_changes() returns it
# → Enqueued to cdc-learned-patterns pgmq
# → Published to NATS
# → CentralCloud receives and adds to knowledge base

# Meanwhile, new patterns are checked for duplicates
{:ok, duplicates} = PatternSimilaritySearch.find_duplicate_patterns(min_similarity: 0.95)
# Alert agent to deduplicate
```

### Agent Performance Monitoring

```elixir
# Agent reports CPU
MetricsAggregation.record_metric(:agent_cpu, 45.2, %{agent_id: agent_id})

# Dashboard query (instant, pre-computed)
{:ok, dashboard} = MetricsAggregation.get_agent_dashboard(agent_id)
# Shows last hour average CPU, patterns learned, tasks completed, error rate

# Older data is automatically compressed
MetricsAggregation.compress_old_metrics(days: 30)
```

### Multi-Instance Workload Balancing

```elixir
# CentralCloud knows agent locations
{:ok, clusters} = AgentGeospatialClustering.cluster_agents_by_region()

# Route new pattern learning task to nearest agent
nearby = find_nearest_agents(location: {lat, lon}, limit: 5)

# Share knowledge within region (low latency)
regional_patterns = get_patterns_in_hex(agent_h3_cell)
```

---

## Summary: All Extensions Used ✅

| Extension | Modules | Tables | Queries | Status |
|-----------|---------|--------|---------|--------|
| pgsodium | Encryption | — | encrypt/decrypt/hash/sign | ✅ Implemented |
| pgx_ulid | DistributedIds | — | gen_ulid/ulid_to_timestamp | ✅ Implemented |
| pgmq | MessageQueue | — | pgmq.send/read/delete | ✅ Implemented |
| wal2json | ChangeDataCapture | — | logical decoding | ✅ Implemented |
| pg_net | RemoteDataFetcher | package_registry | net.http_get() | ✅ Implemented |
| lantern | PatternSimilaritySearch | code_embeddings | l2_distance/HNSW | ✅ Implemented |
| h3 | AgentGeospatialClustering | agents columns | h3_latlng_to_cell/grid_ring | ✅ Implemented |
| timescaledb_toolkit | MetricsAggregation | metrics_events | time_bucket/percentile_cont | ✅ Implemented |

---

## Next Steps (Optional Improvements)

1. **Real-time CDC consumer** - GenServer polling ChangeDataCapture.get_changes() every 5s
2. **Pattern deduplication worker** - Automated Oban job finding/merging duplicates
3. **Metrics alerting** - Oban job checking percentiles against SLO thresholds
4. **Geographic workload balancing** - Route tasks to nearest agent region
5. **Package registry sync** - Periodic refresh of expired cache entries
6. **Lantern index tuning** - Monitor index size, rebuild after bulk imports

## Files Added

**Modules:**
- `lib/singularity/database/change_data_capture.ex` (wal2json)
- `lib/singularity/database/remote_data_fetcher.ex` (pg_net)
- `lib/singularity/database/pattern_similarity_search.ex` (lantern)
- `lib/singularity/database/agent_geospatial_clustering.ex` (h3)
- `lib/singularity/database/metrics_aggregation.ex` (timescaledb_toolkit)

**Migrations:**
- `priv/repo/migrations/20251025000005_add_pg17_extension_tables.exs`

All extensions now have working MVP implementations ready for production use!
