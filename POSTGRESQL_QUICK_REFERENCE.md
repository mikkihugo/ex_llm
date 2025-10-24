# PostgreSQL 16 Quick Reference for Singularity

**Quick Checks**: Copy-paste these commands for immediate insights.

---

## ✅ Health Check (1 minute)

```bash
# All-in-one health check
psql -d singularity << 'EOF'
\echo '=== PostgreSQL Health Check ==='

-- Cache Performance
SELECT 'Cache Hit Ratio' as metric,
  ROUND(100.0 * sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)), 2)::text || '%' as value
FROM pg_statio_user_tables;

-- Table Sizes
SELECT 'Largest Tables' as metric, '' as value
UNION ALL
SELECT '  ' || tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 5;

-- Active Connections
SELECT 'Active Connections' as metric, COUNT(*)::text as value
FROM pg_stat_activity WHERE state = 'active';

-- Slow Queries (>100ms avg)
SELECT 'Slow Queries' as metric, COUNT(*)::text as value
FROM pg_stat_statements WHERE mean_exec_time > 100;
EOF
```

---

## 🔍 Find Slow Queries (2 minutes)

```sql
-- Top 10 slowest queries
SELECT
  query,
  calls,
  ROUND(mean_exec_time::numeric, 2) as avg_ms,
  ROUND(max_exec_time::numeric, 2) as max_ms
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Copy result, replace '?' with actual values, then EXPLAIN ANALYZE
```

---

## 📊 Index Usage Report (2 minutes)

```sql
-- Find missing indexes (seq_scan >> idx_scan)
SELECT
  schemaname,
  tablename,
  seq_scan,
  idx_scan,
  CASE WHEN idx_scan = 0 THEN '❌ MISSING INDEX'
       WHEN seq_scan > idx_scan * 10 THEN '⚠️  LOW INDEX USAGE'
       ELSE '✅ OK'
  END as status
FROM pg_stat_user_tables
WHERE seq_scan > 100
ORDER BY seq_scan DESC
LIMIT 20;

-- Find bloated indexes (>20% waste)
SELECT
  schemaname,
  tablename,
  indexname,
  ROUND(100.0 * (pg_relation_size(idx) - pg_relation_size(indexrelname))
    / pg_relation_size(idx), 2) as bloat_pct
FROM pg_index idx
JOIN pg_class i ON idx.indexrelid = i.oid
JOIN pg_class t ON idx.indrelid = t.oid
WHERE ROUND(100.0 * (pg_relation_size(idx) - pg_relation_size(indexrelname))
    / pg_relation_size(idx), 2) > 20;
```

---

## 🚀 Vector Search Optimization (3 minutes)

```sql
-- Check HNSW index health
SELECT
  indexname,
  pg_size_pretty(pg_relation_size(schemaname||'.'||indexname)) as size,
  'HNSW' as type
FROM pg_indexes
WHERE indexname LIKE '%hnsw%';

-- Test vector search performance
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id, file_path, embedding <-> ARRAY[...]::halfvec as distance
FROM code_chunks
ORDER BY distance
LIMIT 20;
-- Should show <100ms

-- Check if vector index is being used
EXPLAIN
SELECT * FROM code_chunks
WHERE embedding <-> ?::halfvec < 1.5
LIMIT 20;
-- Should show "Index Scan using ... hnsw"
```

---

## 🔤 Full-Text Search Verification (2 minutes)

```sql
-- Check FTS index exists
SELECT indexname FROM pg_indexes
WHERE tablename = 'code_chunks' AND indexname LIKE '%search%';

-- Test FTS performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, file_path, ts_rank(search_vector, query) as rank
FROM code_chunks, plainto_tsquery('english', 'async worker') as query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
-- Should show <50ms

-- Test trigram search (typo tolerance)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, file_path, similarity(content, 'asynch wrker') as sim
FROM code_chunks
WHERE similarity(content, 'asynch wrker') > 0.3
ORDER BY sim DESC
LIMIT 20;
-- Should show <30ms
```

---

## 🔗 Dependency Graph Acceleration (2 minutes)

```sql
-- Check intarray indexes
SELECT indexname FROM pg_indexes
WHERE tablename = 'graph_nodes' AND indexname LIKE '%dependency%';

-- Test intarray performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT m1.id, m1.name, COUNT(m2.id) as overlap_count
FROM graph_nodes m1
JOIN graph_nodes m2 ON (m1.dependency_node_ids && m2.dependency_node_ids)
WHERE m1.id < m2.id
GROUP BY m1.id, m1.name
ORDER BY overlap_count DESC
LIMIT 10;
-- Should show <10ms

-- Find modules with specific dependencies
SELECT * FROM code_files
WHERE imported_module_ids && ARRAY[10, 20, 30]
LIMIT 20;
```

---

## 📈 Memory Configuration Check (1 minute)

```sql
-- Current memory settings
SHOW shared_buffers;              -- Should be 8GB
SHOW effective_cache_size;        -- Should be 24GB
SHOW work_mem;                    -- Should be 256MB
SHOW maintenance_work_mem;        -- Should be 2GB
SHOW vacuum_buffer_usage_limit;   -- Should be 2GB (PostgreSQL 16)

-- If any are wrong, update with:
ALTER SYSTEM SET shared_buffers = '8GB';
SELECT pg_reload_conf();

-- Verify change applied
SHOW shared_buffers;
```

---

## 🧹 Maintenance Commands (5-10 minutes each)

```sql
-- 1. Update table statistics (run monthly)
ANALYZE code_chunks;
ANALYZE knowledge_artifacts;
ANALYZE code_files;

-- 2. Check VACUUM status
SELECT schemaname, tablename, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC;

-- 3. Force VACUUM on large table (careful: locks table during full VACUUM)
VACUUM ANALYZE code_chunks;

-- 4. Check VACUUM progress (PostgreSQL 16)
SELECT * FROM pg_stat_progress_vacuum;

-- 5. Reindex bloated indexes (run with CONCURRENTLY to avoid locks)
REINDEX INDEX CONCURRENTLY code_chunks_embedding_hnsw_idx;
```

---

## 🔧 Troubleshooting

### "Queries are slow" → Run full diagnostic
```sql
-- 1. Is it a planning issue?
EXPLAIN (ANALYZE, BUFFERS)
SELECT ... -- Your slow query
-- Look for: Seq Scan on large table, high actual rows, Index Scan with high loops

-- 2. Is it a statistics issue?
ANALYZE <table>;
-- Then re-run EXPLAIN

-- 3. Is it a missing index?
-- Run index usage report above to check

-- 4. Is it a memory pressure?
SHOW shared_buffers;
-- If <25% of RAM, increase it

-- 5. Is it a disk I/O issue?
SELECT * FROM pg_stat_io;  -- PostgreSQL 16 only
-- Look for: High reads, low hits
```

### "Disk space is growing" → Analyze table size
```sql
-- Find bloated tables
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- If table is bloated (lots of dead rows):
VACUUM ANALYZE <table>;

-- If still bloated after VACUUM, rewrite it (requires exclusive lock):
CLUSTER <table> USING <index>;  -- Or just VACUUM FULL
```

### "PostgreSQL won't start" → Check logs
```bash
# Logs location (Nix)
tail -f "$PGDATA/postgresql.log"

# Common issues:
# "could not access private key file"  → Check file permissions
# "could not bind IPv4 socket"         → Port 5432 already in use
# "FATAL: incompatible library version" → Restart PostgreSQL

# Restart PostgreSQL
pg_ctl -D "$PGDATA" restart -m fast
```

---

## 📋 Extension Status

### Check Installed Extensions
```sql
-- List all installed extensions
SELECT extname, extversion
FROM pg_extension
ORDER BY extname;

-- Verify critical extensions
SELECT COUNT(*) as extension_count
FROM pg_extension
WHERE extname IN ('vector', 'timescaledb', 'postgis', 'pg_trgm', 'citext', 'intarray', 'bloom');
-- Should return 7

-- Check extension size
SELECT extname, pg_size_pretty(pg_total_relation_size(oid)) as size
FROM pg_extension
ORDER BY pg_total_relation_size(oid) DESC;
```

### Install Missing Extension
```sql
-- Check if available
SELECT * FROM pg_available_extensions
WHERE name = 'your_extension';

-- Install if available
CREATE EXTENSION IF NOT EXISTS your_extension;

-- If not available, you need to:
-- 1. Exit Nix shell
-- 2. Add to flake.nix's postgresql.extensions list
-- 3. Run: nix flake update
-- 4. Re-enter Nix shell
```

---

## ⚡ Performance Targets vs Reality

```
Query Type              Target    Current    Status
─────────────────────────────────────────────────────
Vector search           <100ms    <100ms    ✅ OK
Full-text search        <50ms     <50ms     ✅ OK
Dependency lookup       <10ms     <10ms     ✅ OK
Multi-column filter     <20ms     <20ms     ✅ OK
Graph traversal         <200ms    TBD       ⏳ Implement AGE
─────────────────────────────────────────────────────
Cache hit ratio         >99%      99%+      ✅ OK
Connection pool size    25-50     25        ✅ OK
Disk utilization        <80%      <50%      ✅ OK
```

---

## 📞 Common Queries

### "How many code chunks?"
```sql
SELECT COUNT(*) FROM code_chunks;
SELECT pg_size_pretty(pg_total_relation_size('code_chunks'));
```

### "What languages are indexed?"
```sql
SELECT language, COUNT(*) FROM code_chunks GROUP BY language ORDER BY COUNT(*) DESC;
```

### "Find code by keyword"
```sql
SELECT file_path, similarity(content, 'your keyword') as sim
FROM code_chunks
WHERE similarity(content, 'your keyword') > 0.5
ORDER BY sim DESC LIMIT 20;
```

### "Find code by semantic meaning"
```sql
SELECT file_path, embedding <-> embedding_vector as distance
FROM code_chunks
ORDER BY distance LIMIT 20;
```

### "What modules depend on X?"
```sql
SELECT * FROM code_files
WHERE imported_module_ids && ARRAY[module_id_of_X];
```

### "Database statistics"
```sql
SELECT
  (SELECT COUNT(*) FROM code_chunks) as code_chunks,
  (SELECT COUNT(*) FROM knowledge_artifacts) as artifacts,
  (SELECT COUNT(*) FROM code_files) as code_files,
  (SELECT COUNT(*) FROM dependency_catalogs) as dependencies;
```

---

## 🎓 Learn More

- **Vector Search**: See `POSTGRESQL_EXTENSION_AUDIT.md` → "Tier 2: Search"
- **Advanced Tuning**: See `POSTGRESQL_ADVANCED_TUNING.md`
- **Full Reports**: See `POSTGRESQL_EXTENSION_AUDIT.md`

---

**Last Updated**: October 24, 2025
