# PostgreSQL Cache - Redis Alternative for Singularity

PostgreSQL-native caching using **UNLOGGED tables** - a Redis alternative built into PostgreSQL.

## Why PostgreSQL Cache?

### Benefits Over Redis

✅ **One Less Service** - No separate Redis/Valkey server needed
✅ **Shared Connection Pool** - Uses existing PostgreSQL connections
✅ **Full SQL Support** - Query cached data with SQL
✅ **ACID + Cache** - Atomic operations with both cache and data
✅ **JSONB Queries** - Filter/aggregate cached JSON data
✅ **Perfect for Internal Tools** - Simplifies deployment

### Performance

- ⚡ **Fast** - UNLOGGED tables skip WAL writes
- 🔄 **Volatile** - Lost on crash (like Redis)
- 📊 **Queryable** - Complex queries on cached data
- 🎯 **Hit Tracking** - Built-in access statistics

---

## Setup

### 1. Run Migration

```bash
cd singularity_app
mix ecto.migrate
```

This creates:
- `package_cache` UNLOGGED table
- `hot_packages` materialized view
- Helper functions (`cleanup_expired_cache`, `cache_stats`)
- Indexes for performance

### 2. Add CacheJanitor to Application Supervisor

```elixir
# lib/singularity/application.ex
children = [
  # ...
  Singularity.Cache.CacheJanitor,  # Add this
  # ...
]
```

The CacheJanitor automatically:
- Cleans up expired entries every 15 minutes
- Refreshes hot packages view every hour
- Prewarms cache every 6 hours

---

## Usage

### Elixir

```elixir
alias Singularity.Cache.PostgresCache

# Store in cache (1 hour TTL)
PostgresCache.put("npm:react:18.0.0", package_data, ttl: 3600)

# Retrieve from cache
{:ok, data} = PostgresCache.get("npm:react:18.0.0")

# Get or compute (fetch pattern)
data = PostgresCache.fetch("npm:react:18.0.0", fn ->
  # This only runs if cache miss
  fetch_from_registry()
end, ttl: 3600)

# Delete specific entry
PostgresCache.delete("npm:react:18.0.0")

# Delete by pattern
{:ok, count} = PostgresCache.delete_pattern("npm:%")

# Get statistics
stats = PostgresCache.stats()
# => %{
#   total_entries: 1234,
#   valid_entries: 1200,
#   expired_entries: 34,
#   total_size_mb: 45.6,
#   avg_hit_count: 12.3
# }

# Get top accessed items
top = PostgresCache.top_hits(10)

# Manual cleanup
{:ok, cleaned} = PostgresCache.cleanup_expired()

# Prewarm with hot packages
{:ok, count} = PostgresCache.prewarm_hot_packages()
```

### Rust

```rust
use singularity_storage_cache::PostgresCache;

// Create cache client
let cache = PostgresCache::new("postgresql://localhost/singularity").await?;

// Store in cache
let value = serde_json::json!({"package": "react", "version": "18.0.0"});
cache.put("npm:react:18.0.0", &value, 3600).await?;

// Retrieve from cache
if let Some(data) = cache.get("npm:react:18.0.0").await? {
    println!("Cache hit: {:?}", data);
}

// Fetch or compute
let data = cache.fetch("npm:react:18.0.0", || async {
    // Only runs on cache miss
    fetch_from_registry().await
}, 3600).await?;

// Statistics
let stats = cache.stats().await?;
println!("Cache size: {} MB", stats.total_size_mb);

// Cleanup
let cleaned = cache.cleanup_expired().await?;
```

---

## Advanced Features

### 1. Hot Packages Materialized View

Pre-cached popular packages for instant access:

```sql
-- Query hot packages (5000 most popular)
SELECT * FROM hot_packages
WHERE ecosystem = 'npm'
AND 'react' = ANY(tags)
LIMIT 10;

-- Manual refresh
REFRESH MATERIALIZED VIEW CONCURRENTLY hot_packages;
```

### 2. Query Cached Data

Unlike Redis, you can query cached data with SQL:

```sql
-- Find all cached npm packages
SELECT cache_key, package_data->>'version'
FROM package_cache
WHERE cache_key LIKE 'npm:%'
AND expires_at > NOW();

-- Most accessed packages
SELECT
  cache_key,
  hit_count,
  package_data->>'version' as version
FROM package_cache
WHERE expires_at > NOW()
ORDER BY hit_count DESC
LIMIT 20;

-- Cache by age
SELECT
  cache_key,
  AGE(expires_at) as time_left
FROM package_cache
WHERE expires_at > NOW()
ORDER BY expires_at ASC;
```

### 3. Cache Prewarming

```elixir
# Prewarm cache on startup
defmodule MyApp.CacheWarmer do
  use GenServer

  def init(_) do
    # Load hot packages into cache
    PostgresCache.prewarm_hot_packages()

    # Or custom prewarming
    popular_packages()
    |> Enum.each(fn pkg ->
      data = fetch_package(pkg)
      PostgresCache.put(cache_key(pkg), data, ttl: 86400)
    end)

    {:ok, %{}}
  end
end
```

### 4. Cache Patterns

```elixir
# Pattern: Ecosystem prefix
"npm:*"
"cargo:*"
"hex:*"

# Pattern: Query results
"search:npm:react"
"search:cargo:tokio"

# Pattern: User sessions
"session:user_123"

# Pattern: API responses
"api:/packages/npm/react"
```

---

## Monitoring

### Cache Statistics

```elixir
# Get stats via GenServer
stats = Singularity.Cache.CacheJanitor.get_stats()
# => %{
#   cache_stats: %{total_entries: 1234, ...},
#   top_hits: [%{cache_key: "npm:react:18.0.0", hit_count: 456}, ...],
#   last_cleanup: ~U[2025-01-09 12:00:00Z],
#   last_refresh: ~U[2025-01-09 11:00:00Z]
# }
```

### Direct SQL

```sql
-- Cache statistics
SELECT * FROM cache_stats();

-- Buffer cache usage (what's in RAM)
SELECT
  c.relname,
  count(*) * 8192 / 1024 / 1024 AS cached_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = c.relfilenode
WHERE c.relname IN ('package_cache', 'hot_packages')
GROUP BY c.relname;

-- Check pg_prewarm status
SELECT * FROM pg_prewarm('package_cache');
```

---

## Configuration

### PostgreSQL Settings

Recommended `postgresql.conf` settings for caching:

```ini
# Increase shared buffers for cache
shared_buffers = 2GB

# Enable pg_prewarm for auto-loading on restart
shared_preload_libraries = 'pg_prewarm'

# Increase work_mem for materialized view refreshes
work_mem = 256MB

# Optional: Enable pg_cron for automatic maintenance
shared_preload_libraries = 'pg_prewarm,pg_cron'
```

### Automatic Maintenance with pg_cron

```sql
-- Install pg_cron
CREATE EXTENSION pg_cron;

-- Schedule cache cleanup (every 15 minutes)
SELECT cron.schedule(
  'cleanup-cache',
  '*/15 * * * *',
  $$SELECT cleanup_expired_cache()$$
);

-- Schedule materialized view refresh (every hour)
SELECT cron.schedule(
  'refresh-hot-packages',
  '0 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY hot_packages$$
);

-- View scheduled jobs
SELECT * FROM cron.job;
```

---

## Performance Tips

### 1. Use Appropriate TTLs

```elixir
# Short-lived (5 minutes) - Frequently changing data
PostgresCache.put(key, value, ttl: 300)

# Medium (1 hour) - Package metadata
PostgresCache.put(key, value, ttl: 3600)

# Long (24 hours) - Hot packages, rarely changing
PostgresCache.put(key, value, ttl: 86400)
```

### 2. Batch Operations

```elixir
# Instead of individual puts
packages = fetch_many_packages()

Enum.each(packages, fn pkg ->
  PostgresCache.put(cache_key(pkg), pkg, ttl: 3600)
end)
```

### 3. Use Materialized Views

For frequently accessed queries, use materialized views instead of cache:

```sql
CREATE MATERIALIZED VIEW cached_query AS
SELECT ... complex query ...
WITH DATA;
```

---

## Comparison

| Feature | PostgreSQL Cache | Redis | NATS KV |
|---------|-----------------|-------|---------|
| Setup | ✅ Already there | ⚠️ New service | ⚠️ New service |
| Speed (write) | ⚡⚡ Fast | ⚡⚡⚡ Faster | ⚡⚡ Fast |
| Speed (read) | ⚡⚡⚡ Very fast | ⚡⚡⚡ Very fast | ⚡⚡ Fast |
| Query support | ✅ Full SQL | ❌ Key-value | ❌ Key-value |
| Data types | ✅ JSONB, arrays | ✅ Strings, sets | ✅ Bytes |
| Persistence | ❌ Volatile | ❌ Volatile | ✅ Durable |
| Distributed | ❌ Single server | ✅ Cluster | ✅ Cluster |
| Best for | Internal tools | High-traffic apps | Distributed state |

---

## Summary

PostgreSQL UNLOGGED tables provide a **Redis-like cache** with:

✅ **No additional services** - One less thing to manage
✅ **Full SQL queries** - Complex filtering on cached data
✅ **Shared connections** - No separate pool needed
✅ **Perfect for Singularity** - Internal tooling doesn't need Redis

**Use it for:**
- Package metadata caching
- Query result caching
- Session storage
- API response caching
- Any volatile data that benefits from SQL

**Avoid it for:**
- Pub/sub messaging (use NATS)
- Distributed cache across multiple servers (use NATS KV or Redis cluster)
- Very high write throughput (use Redis)
