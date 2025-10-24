# PostgreSQL Monthly Monitoring Tasks

**Purpose**: Keep PostgreSQL performance optimized and catch issues early
**Frequency**: First Friday of each month (10 minutes)
**Status**: Set up once, then run monthly

---

## Monthly Checklist (10 minutes)

### ✅ Task 1: Identify Slow Queries (3 minutes)

**When**: First Friday of month, any time

**Command**:
```sql
-- List top 20 slowest queries by total time
SELECT
  query,
  calls,
  ROUND((total_time / 1000)::numeric, 2) as total_seconds,
  ROUND((mean_time)::numeric, 2) as avg_ms,
  ROUND((max_time)::numeric, 2) as max_ms,
  ROUND((total_time / calls)::numeric, 2) as avg_total_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE '%information_schema%'
ORDER BY total_time DESC
LIMIT 20;
```

**What to look for**:
- Queries with `avg_ms > 100` (over 100ms on average) → Needs optimization
- Queries with `calls > 1000` and `avg_ms > 10` → Run frequently and slow → High priority
- New queries in the list → May indicate new slow code

**Action**:
- If `total_seconds > 10000` (>2.7 hours total): Create index or rewrite query
- If `avg_ms > 500`: Immediate attention needed
- If `avg_ms 100-500`: Monitor, consider optimizing

**Example Output**:
```
query                          | calls | total_seconds | avg_ms | max_ms
-------------------------------|-------|---------------|--------|--------
SELECT ... FROM code_chunks... | 50000 | 1250.5        | 25.0   | 450.0  ← High volume, slow
SELECT ... FROM graph_nodes... | 100   | 125.3         | 1253   | 5000   ← Very slow
UPDATE ... WHERE ...           | 500   | 50.2          | 100.4  | 200.0  ← Optimization needed
```

---

### ✅ Task 2: Check Cache Hit Ratio (2 minutes)

**When**: Right after Task 1

**Command**:
```sql
-- Overall cache performance (target: >99%)
SELECT
  ROUND(
    100.0 * (1 - COALESCE(sum(heap_blks_read), 0)::float /
    NULLIF(sum(heap_blks_read) + sum(heap_blks_hit), 0))::numeric,
    2
  ) as cache_hit_ratio_percent
FROM pg_statio_user_tables;
```

**Interpretation**:
- **>99%**: Excellent! Keep configuration as-is
- **95-99%**: Good, monitor for degradation
- **<95%**: Performance problem, likely need more RAM or better queries

**If <95%: Find problematic tables**:
```sql
-- Per-table cache hit ratio
SELECT
  schemaname,
  tablename,
  heap_blks_hit + heap_blks_read as total_accesses,
  heap_blks_hit as cache_hits,
  ROUND(
    100.0 * heap_blks_hit::float /
    NULLIF(heap_blks_hit + heap_blks_read, 0)::numeric,
    1
  ) as cache_hit_percent
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 10000
ORDER BY cache_hit_percent ASC
LIMIT 20;
```

**Action**:
- Cache hit <90% on large table: Missing index or query inefficiency
- Cache hit <50%: Serious issue, investigate immediately

**Example Output**:
```
Overall cache hit ratio: 99.42%  ← Excellent!

Per-table worst performers:
schemaname | tablename      | total_accesses | cache_hit_percent
------------|----------------|----------------|-------------------
public     | code_chunks    | 5000000        | 98.5%  ← Good
public     | graph_nodes    | 1000000        | 99.1%  ← Good
public     | oban_jobs      | 500000         | 99.9%  ← Excellent
```

---

### ✅ Task 3: Update Table Statistics (2 minutes)

**When**: Last (after Tasks 1-2)

**Commands**:
```sql
-- Update statistics on large tables
-- This helps query planner make better decisions
ANALYZE code_chunks;
ANALYZE graph_nodes;
ANALYZE knowledge_artifacts;
ANALYZE oban_jobs;
```

**Why**: Query planner uses statistics to decide:
- Which index to use
- Join order
- Parallel execution

**When to run extra ANALYZE**:
- After large data imports
- After PageRank calculation completes
- If you see query plans change unexpectedly
- If index usage changes

---

## Optional: Deep Dive Analysis (Monthly, pick one)

Rotate through these once a quarter:

### **Week 1: Index Usage Analysis**

Identify missing or unused indexes:

```sql
-- Unused indexes (wasting space, slowing writes)
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%pkey%'  -- Keep primary keys
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Action**: If index never used:
```sql
DROP INDEX CONCURRENTLY unused_index_name;  -- CONCURRENTLY: non-blocking
```

```sql
-- Indexes used only for writes (never for reads)
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_tup_read = 0
  AND idx_tup_fetch = 0
  AND indexrelname NOT LIKE '%pkey%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### **Week 2: Table Bloat Analysis**

Find tables with dead rows (from deletes/updates):

```sql
-- Tables with lots of dead space
SELECT
  schemaname,
  tablename,
  ROUND(100 * (CASE WHEN otta > 0
    THEN sml_ratio::numeric / otta
    ELSE 0 END), 2) AS ratio,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)::bigint) AS size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)::bigint -
    pg_relation_size(schemaname||'.'||tablename)::bigint) as indexes_size
FROM (
  SELECT
    schemaname,
    tablename,
    cc,
    abs((cc - pp) / cc::float) AS ratio,
    pg_relation_size(schemaname||'.'||tablename) AS tblbytes,
    floor(cc/8 - 7) AS otta,
    floor(pp / 2) AS sml_ratio
  FROM (
    SELECT
      schemaname,
      tablename,
      current_setting('block_size')::numeric AS bs,
      23 + ceil(avg_width, 8)::int AS cc,
      (SELECT count(*) FROM (SELECT * FROM
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
      ) WHERE tablename LIKE 'code_chunks') * 2 AS pp
    FROM pg_stats
    WHERE schemaname = 'public'
    GROUP BY schemaname, tablename
  ) AS x
) AS y
ORDER BY ratio DESC
LIMIT 10;
```

**Action**: If table >20% bloat:
```sql
-- Reclaim space (locks table briefly)
VACUUM FULL code_chunks;

-- Or non-blocking version:
REINDEX TABLE CONCURRENTLY code_chunks;
```

### **Week 3: Connection Pool Health**

Monitor active connections:

```sql
-- Current connections per database
SELECT
  datname,
  count(*) as connections,
  max(EXTRACT(EPOCH FROM (now() - query_start)))::int as longest_query_seconds
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname
ORDER BY connections DESC;
```

**Target**: `connections < 50` for singularity DB

**Action**: If connections > 100:
```sql
-- Find blocking connections
SELECT
  pid,
  usename,
  application_name,
  state,
  query,
  EXTRACT(EPOCH FROM (now() - query_start))::int as duration_seconds
FROM pg_stat_activity
WHERE state != 'idle'
  AND datname = 'singularity'
ORDER BY query_start;
```

### **Week 4: Vacuum and Autovacuum Health**

Check if autovacuum is working well:

```sql
-- Last vacuum times
SELECT
  schemaname,
  tablename,
  n_live_tup,
  n_dead_tup,
  ROUND(100 * n_dead_tup::float / NULLIF(n_live_tup, 0), 1) as dead_ratio,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
ORDER BY last_autovacuum DESC NULLS LAST
LIMIT 20;
```

**Look for**:
- Tables never vacuum'd → May need manual VACUUM
- High dead_ratio (>20%) → Autovacuum may be too aggressive
- old last_autovacuum → Autovacuum may be disabled or stuck

---

## Automated Monitoring Setup

### Create a monthly reminder task:

```bash
# Add to crontab (runs first Friday of month at 9 AM)
0 9 * * 5 [ $(date +%d) -le 7 ] && /path/to/check-postgres.sh
```

### Create monitoring script (save as `check-postgres.sh`):

```bash
#!/bin/bash
# PostgreSQL monthly check script

DATABASE="singularity"
LOGFILE="/tmp/postgres-monthly-check.log"

{
  echo "PostgreSQL Monthly Monitoring - $(date)"
  echo "================================================"
  echo ""

  echo "1. SLOW QUERY CHECK"
  psql -d "$DATABASE" -c "
  SELECT
    query,
    calls,
    ROUND((total_time / 1000)::numeric, 2) as total_seconds,
    ROUND((mean_time)::numeric, 2) as avg_ms
  FROM pg_stat_statements
  WHERE query NOT LIKE '%pg_stat_statements%'
  ORDER BY total_time DESC
  LIMIT 10;"
  echo ""

  echo "2. CACHE HIT RATIO"
  psql -d "$DATABASE" -c "
  SELECT ROUND(100.0 * (1 - COALESCE(sum(heap_blks_read), 0)::float /
    NULLIF(sum(heap_blks_read) + sum(heap_blks_hit), 0))::numeric, 2)
    as cache_hit_ratio_percent
  FROM pg_statio_user_tables;"
  echo ""

  echo "3. UPDATING STATISTICS"
  psql -d "$DATABASE" -c "ANALYZE code_chunks; ANALYZE graph_nodes;"
  echo "✅ Statistics updated"

} | tee -a "$LOGFILE"

echo "✅ Monthly check complete. Log: $LOGFILE"
```

---

## Alert Thresholds

Set up alerts (optional, but helpful):

| Metric | Warning | Critical |
|--------|---------|----------|
| Query avg_ms | >100ms | >500ms |
| Query total_time | >10000s | >50000s |
| Cache hit ratio | <97% | <90% |
| Dead tuples | >25% | >50% |
| Table size | >10GB | >100GB |
| Index size | >5GB | >20GB |
| Connections | >75 | >150 |
| Query duration | >5min | >30min |

---

## Example Monthly Report

**Example output from running all tasks**:

```
PostgreSQL Monthly Monitoring - 2025-11-01
================================================

1. SLOW QUERY CHECK
Top 3 slowest:
  - UPDATE oban_jobs SET ...: 1250.5s total, 25.0ms avg ← Good
  - SELECT FROM code_chunks: 125.3s total, 1253ms avg ← Needs optimization
  - SELECT FROM graph_nodes: 50.2s total, 100.4ms avg ← Monitor

Recommendation: Index code_chunks on (codebase_id, embedding_calculated_at)

2. CACHE HIT RATIO
Cache hit ratio: 99.42% ✅ Excellent!

Per-table analysis:
  - code_chunks: 98.5% (good)
  - graph_nodes: 99.1% (good)
  - oban_jobs: 99.9% (excellent)

No action needed.

3. STATISTICS UPDATE
✅ ANALYZED: code_chunks, graph_nodes
Statistics refreshed successfully.

Overall Status: ✅ HEALTHY
- No critical issues
- All thresholds normal
- System performing well
```

---

## Quick Reference

### Most Common Monthly Actions

```sql
-- 1. Find slow queries
SELECT query, mean_time, calls FROM pg_stat_statements
ORDER BY total_time DESC LIMIT 10;

-- 2. Check cache
SELECT ROUND(100.0 * (1 - sum(heap_blks_read)::float /
  NULLIF(sum(heap_blks_read) + sum(heap_blks_hit), 0))::numeric, 2)
FROM pg_statio_user_tables;

-- 3. Update stats
ANALYZE code_chunks; ANALYZE graph_nodes;

-- 4. Find unused indexes
SELECT indexname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0;

-- 5. Check table bloat
SELECT tablename, n_dead_tup, ROUND(100 * n_dead_tup::float /
  NULLIF(n_live_tup, 0), 1) FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;
```

---

**Total Time**: ~10 minutes per month
**Benefit**: Catch issues before they impact performance
**Last Updated**: October 25, 2025
