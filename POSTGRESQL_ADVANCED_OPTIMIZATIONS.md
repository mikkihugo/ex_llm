# PostgreSQL 16 Advanced Optimizations for Singularity

**Status**: Analyzed opportunities (not yet implemented)
**Target**: Internal tooling - implement as needed for specific use cases

---

## 1. Window Functions for PageRank Analysis

### Current Limitation
PageRank queries return flat lists without ranking/percentile context:
```sql
-- Current: Just scores
SELECT name, pagerank_score FROM graph_nodes
ORDER BY pagerank_score DESC LIMIT 10;
```

### Optimized with Window Functions
```sql
-- Enhanced: With ranking, percentiles, comparisons
SELECT
  name,
  pagerank_score,

  -- Ranking (1st, 2nd, 3rd, etc.)
  RANK() OVER (ORDER BY pagerank_score DESC) as rank,

  -- Dense rank (no gaps)
  DENSE_RANK() OVER (ORDER BY pagerank_score DESC) as dense_rank,

  -- Percentile (top 10%, top 25%, etc.)
  NTILE(100) OVER (ORDER BY pagerank_score DESC) as percentile,

  -- Relative to average
  ROUND((pagerank_score / AVG(pagerank_score)
    OVER ())::numeric, 2) as relative_to_avg,

  -- Running sum (cumulative importance)
  SUM(pagerank_score) OVER (
    ORDER BY pagerank_score DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) as cumulative_score,

  -- Gap detection (importance drops)
  ROUND((pagerank_score - LAG(pagerank_score, 1, 0)
    OVER (ORDER BY pagerank_score DESC))::numeric, 2) as score_drop_from_previous

FROM graph_nodes
ORDER BY pagerank_score DESC;
```

**Benefits**:
- Identify tier boundaries automatically (where big drops occur)
- Detect "importance cliffs" (modules critical vs. replaceable)
- Compare modules relative to dataset (not absolute)
- Running cumulative importance (which 20% of modules account for 80% of importance)

### Use Cases

**1. Find Importance Tiers Automatically**
```sql
WITH ranked AS (
  SELECT
    name,
    pagerank_score,
    NTILE(4) OVER (ORDER BY pagerank_score DESC) as quartile
  FROM graph_nodes
)
SELECT
  CASE quartile
    WHEN 1 THEN 'CRITICAL (Top 25%)'
    WHEN 2 THEN 'IMPORTANT (25-50%)'
    WHEN 3 THEN 'MODERATE (50-75%)'
    WHEN 4 THEN 'LOW (Bottom 25%)'
  END as tier,
  COUNT(*) as module_count,
  AVG(pagerank_score) as avg_score,
  MIN(pagerank_score) as min_score,
  MAX(pagerank_score) as max_score
FROM ranked
GROUP BY quartile, tier
ORDER BY quartile;
```

**2. Detect Importance Cliffs (Big Drops)**
```sql
WITH scored AS (
  SELECT
    name,
    pagerank_score,
    LAG(pagerank_score) OVER (ORDER BY pagerank_score DESC) as prev_score,
    ROW_NUMBER() OVER (ORDER BY pagerank_score DESC) as position
  FROM graph_nodes
)
SELECT
  position,
  name,
  pagerank_score,
  ROUND((prev_score - pagerank_score)::numeric, 3) as drop_from_previous,
  ROUND((100.0 * (prev_score - pagerank_score) / NULLIF(prev_score, 0))::numeric, 1) as drop_percent
FROM scored
WHERE prev_score IS NOT NULL
  AND prev_score - pagerank_score > 0.5  -- Only significant drops
ORDER BY drop_from_previous DESC
LIMIT 20;
```

**Output**:
```
position | name           | pagerank_score | drop_from_previous | drop_percent
---------|----------------|-----------------|--------------------|-------------
1        | Service        | 3.14            | NULL               | NULL
2        | Manager        | 2.89            | 0.250              | 7.96%
3        | Supervisor     | 2.51            | 0.380              | 13.15%
4        | Config         | 1.85            | 0.660              | 26.29%  ← BIG DROP
5        | Helper         | 1.21            | 0.640              | 34.59%
...
15       | Util           | 0.22            | 0.18               | 45.00%
16       | Test Mock      | 0.04            | 0.180              | 81.82%  ← CLIFF
```

This automatically shows where you should focus refactoring attention!

**3. Find Modules Approaching Obsoletion (Flat Importance)**
```sql
WITH ranked AS (
  SELECT
    name,
    pagerank_score,
    codebase_id,
    last_modified,
    LAG(pagerank_score) OVER (
      PARTITION BY codebase_id
      ORDER BY pagerank_score DESC
    ) as prev_score
  FROM graph_nodes
)
SELECT
  name,
  pagerank_score,
  ROUND((pagerank_score / AVG(pagerank_score)
    OVER (PARTITION BY codebase_id))::numeric, 2) as relative_to_avg,
  last_modified,
  CURRENT_DATE - last_modified as days_since_change
FROM ranked
WHERE pagerank_score < 0.5
  AND last_modified < CURRENT_DATE - INTERVAL '6 months'
ORDER BY days_since_change DESC;
```

---

## 2. Materialized Views for Code Analysis Reports

### Use Case: Monthly Importance Analysis Report

**Problem**: Calculating module importance tiers each time is expensive:
- Requires full table scan
- Sorts all nodes
- Calculates window functions across entire dataset

**Solution**: Materialized View (cached result set)
```sql
CREATE MATERIALIZED VIEW module_importance_tiers AS
SELECT
  codebase_id,
  name,
  file_path,
  pagerank_score,
  CASE
    WHEN pagerank_score > 5.0 THEN 'CRITICAL'
    WHEN pagerank_score > 2.0 THEN 'IMPORTANT'
    WHEN pagerank_score > 0.5 THEN 'MODERATE'
    ELSE 'LOW'
  END as importance_tier,
  NTILE(100) OVER (
    PARTITION BY codebase_id
    ORDER BY pagerank_score DESC
  ) as percentile,
  RANK() OVER (
    PARTITION BY codebase_id
    ORDER BY pagerank_score DESC
  ) as rank_in_codebase,
  COUNT(*) FILTER (
    WHERE pagerank_score IS NOT NULL
  ) OVER (
    PARTITION BY codebase_id
  ) as total_modules
FROM graph_nodes
WHERE pagerank_score > 0
ORDER BY codebase_id, pagerank_score DESC;

-- Create index for fast queries
CREATE INDEX idx_module_importance_tiers_tier
ON module_importance_tiers(codebase_id, importance_tier);
```

**Usage** (instant queries):
```sql
-- Get tier distribution (super fast, pre-calculated)
SELECT
  codebase_id,
  importance_tier,
  COUNT(*) as module_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY codebase_id), 1) as percent
FROM module_importance_tiers
GROUP BY codebase_id, importance_tier
ORDER BY codebase_id,
  CASE importance_tier
    WHEN 'CRITICAL' THEN 1
    WHEN 'IMPORTANT' THEN 2
    WHEN 'MODERATE' THEN 3
    WHEN 'LOW' THEN 4
  END;
```

**Refresh Strategy** (tied to PageRank calculation):
```sql
-- After PageRank calculation completes, refresh the view
-- Add to pagerank_daily_refresh() function in database:

REFRESH MATERIALIZED VIEW CONCURRENTLY module_importance_tiers;

-- With CONCURRENTLY: Doesn't lock queries while refreshing
-- Old queries keep using old data until refresh completes
```

### Other High-Value Materialized Views

**1. Module Dependency Density**
```sql
CREATE MATERIALIZED VIEW module_dependency_density AS
SELECT
  m1.codebase_id,
  m1.name as module,
  COUNT(DISTINCT m2.name) as direct_dependencies,
  COUNT(DISTINCT m2.id) FILTER (WHERE m2.node_depth > 1) as transitive_dependencies,
  ROUND(AVG(m2.pagerank_score)::numeric, 2) as avg_dependency_importance,
  MAX(m2.pagerank_score) as highest_dependency_importance
FROM graph_nodes m1
LEFT JOIN graph_edges e ON m1.id = e.source_id
LEFT JOIN graph_nodes m2 ON e.target_id = m2.id
GROUP BY m1.codebase_id, m1.name
ORDER BY direct_dependencies DESC;
```

**2. Code Chunk Embedding Quality**
```sql
CREATE MATERIALIZED VIEW code_chunk_coverage AS
SELECT
  codebase_id,
  COUNT(*) as total_chunks,
  COUNT(*) FILTER (WHERE embedding IS NOT NULL) as chunks_with_embeddings,
  ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / COUNT(*)::numeric, 1) as coverage_percent,
  COUNT(*) FILTER (WHERE embedding_version = '3.0') as latest_embeddings,
  MAX(embedding_calculated_at) as last_embedding_calc
FROM code_chunks
GROUP BY codebase_id;
```

---

## 3. Range Types for Version/Timeline Analysis

### Current Limitation
Code chunks have separate `created_at` and `updated_at`:
```sql
-- Hard to query: "What code existed between dates?"
SELECT * FROM code_chunks
WHERE created_at <= '2025-01-15'
  AND (updated_at >= '2025-01-01' OR updated_at IS NULL);
```

### With Range Types
```sql
-- Add column (one-time migration)
ALTER TABLE code_chunks
ADD COLUMN valid_period tsrange;

-- Populate it
UPDATE code_chunks
SET valid_period = tsrange(created_at, updated_at);

-- Create index (fast range queries)
CREATE INDEX idx_code_chunks_valid_period
ON code_chunks USING GIST (valid_period);

-- Now super efficient:
-- "What code was active on 2025-01-10?"
SELECT * FROM code_chunks
WHERE valid_period @> '2025-01-10'::timestamp;

-- "Overlapping lifespans?"
SELECT * FROM code_chunks c1
JOIN code_chunks c2 ON c1.valid_period && c2.valid_period
  AND c1.id < c2.id  -- Avoid duplicates
WHERE c1.codebase_id = c2.codebase_id
  AND c1.content_hash = c2.content_hash;  -- Exact duplicates

-- "Timeline of code changes"
SELECT
  lower(valid_period) as created,
  upper(valid_period) as removed,
  JUSTIFY_INTERVAL(upper(valid_period) - lower(valid_period)) as lifetime,
  file_path
FROM code_chunks
WHERE codebase_id = 'singularity'
ORDER BY lower(valid_period);
```

**Benefits**:
- Single column replaces two for temporal logic
- GIST indexes optimize range queries (10-100x faster)
- `@>` operator: "contains" queries
- `&&` operator: "overlaps" queries
- Built-in semantics: clearer code

---

## 4. JSON/JSONB for Flexible Metadata

### Current State
`knowledge_artifacts` already uses JSONB for flexible schema:
```sql
SELECT
  id,
  artifact_type,
  content -> 'examples' ->> 0 as first_example,
  (content -> 'metadata' ->> 'quality_level')::int as quality_score
FROM knowledge_artifacts
WHERE (content @> '{"language": "elixir"}');  -- JSONB operators
```

### Expand to Other Tables

**1. Graph Node Metadata**
```sql
-- Instead of many columns, use JSONB:
ALTER TABLE graph_nodes
ADD COLUMN metadata JSONB DEFAULT '{}';

-- Store analysis results compactly
UPDATE graph_nodes SET metadata = jsonb_set(
  metadata,
  '{framework_detected}',
  '"phoenix"'::jsonb
) WHERE name LIKE '%controller%';

-- Query efficiently
SELECT name, metadata -> 'framework_detected' as framework
FROM graph_nodes
WHERE metadata ? 'framework_detected'
ORDER BY pagerank_score DESC;
```

**2. Job Execution Metadata**
```sql
-- Track job-specific details without new columns
ALTER TABLE oban_jobs
ADD COLUMN metrics JSONB;

-- Store detailed metrics
UPDATE oban_jobs SET metrics = jsonb_build_object(
  'duration_ms', 2500,
  'modules_calculated', 1250,
  'cpu_percent', 85,
  'memory_mb', 1024
)
WHERE worker = 'Singularity.Jobs.PageRankCalculationJob'
  AND state = 'completed';

-- Aggregate metrics
SELECT
  DATE_TRUNC('hour', completed_at) as hour,
  ROUND(AVG((metrics ->> 'duration_ms')::integer)::numeric, 0) as avg_duration_ms,
  SUM((metrics ->> 'modules_calculated')::integer) as total_modules,
  MAX((metrics ->> 'memory_mb')::integer) as peak_memory_mb
FROM oban_jobs
WHERE metrics IS NOT NULL
GROUP BY DATE_TRUNC('hour', completed_at)
ORDER BY hour DESC;
```

---

## 5. Common Table Expressions (CTEs) for Complex Analysis

### Already Using CTEs Effectively

PageRank calculation uses CTEs to break down complex logic:
```sql
WITH RECURSIVE iteration AS (
  -- Base case: initialize ranks
  SELECT id, pagerank_score FROM graph_nodes
  UNION ALL
  -- Recursive case: iterate
  SELECT ... FROM iteration
)
SELECT * FROM iteration WHERE iteration_num = 20;
```

### Additional CTE Opportunities

**1. Multi-Level Dependency Analysis**
```sql
-- "How many levels deep is dependency chain?"
WITH RECURSIVE deps AS (
  -- Level 0: Start module
  SELECT id, name, 0 as depth, id as root_id
  FROM graph_nodes
  WHERE name = 'ServiceA'

  UNION ALL

  -- Recursive: follow edges down
  SELECT
    gn.id,
    gn.name,
    d.depth + 1,
    d.root_id
  FROM graph_edges ge
  JOIN graph_nodes gn ON ge.target_id = gn.id
  JOIN deps d ON ge.source_id = d.id
  WHERE d.depth < 10  -- Prevent infinite loops
)
SELECT
  depth,
  COUNT(DISTINCT id) as modules_at_depth,
  STRING_AGG(DISTINCT name, ', ' ORDER BY name) as module_names
FROM deps
GROUP BY depth
ORDER BY depth;
```

**2. Find Circular Dependencies**
```sql
WITH RECURSIVE cycles AS (
  -- Start from any node
  SELECT id, ARRAY[id] as path, id as start_id
  FROM graph_nodes

  UNION ALL

  -- Follow edges, tracking path
  SELECT
    ge.target_id,
    path || ge.target_id,
    start_id
  FROM graph_edges ge
  JOIN cycles c ON ge.source_id = c.id
  WHERE NOT c.path @> ARRAY[ge.target_id]  -- Avoid revisiting
    AND ARRAY_LENGTH(c.path, 1) < 20
)
-- Find where path returns to start
SELECT DISTINCT
  start_id,
  (SELECT name FROM graph_nodes WHERE id = start_id) as start_module,
  path,
  STRING_AGG(
    (SELECT name FROM graph_nodes WHERE id = n),
    ' → ' ORDER BY n
  ) as cycle_path
FROM cycles
WHERE ARRAY[start_id] <@ path
  AND ARRAY_LENGTH(path, 1) > 1;
```

---

## 6. Partitioning Strategy for code_chunks (Future)

### Current State
- `code_chunks`: Single table with ~1M rows
- Grows quickly (future scale: 5M+ rows, 500GB+)

### Partition by Codebase
```sql
-- Create partitioned table (for future scale)
CREATE TABLE code_chunks_partitioned (
  id BIGSERIAL,
  codebase_id VARCHAR NOT NULL,
  -- ... other columns ...
  CONSTRAINT code_chunks_partitioned_pkey PRIMARY KEY (id, codebase_id)
) PARTITION BY LIST (codebase_id);

-- Create partition for each codebase
CREATE TABLE code_chunks_singularity
  PARTITION OF code_chunks_partitioned
  FOR VALUES IN ('singularity');

CREATE TABLE code_chunks_central_cloud
  PARTITION OF code_chunks_partitioned
  FOR VALUES IN ('central_cloud');

-- Create indexes per partition (much faster!)
CREATE INDEX idx_code_chunks_singularity_embedding
ON code_chunks_singularity USING HNSW (embedding vector_cosine_ops);
```

**Benefits**:
- Partitioned index scans faster (90% smaller index per partition)
- ANALYZE per partition (more accurate statistics)
- Query planner chooses only relevant partitions
- Can DROP whole codebase instantly (just drop partition)

---

## 7. Monitoring Queries (Already Recommended)

### pg_stat_statements (Monthly Review)

```sql
-- Find slowest queries by total time
SELECT
  query,
  calls,
  ROUND((total_time / 1000)::numeric, 2) as total_seconds,
  ROUND((mean_time)::numeric, 2) as avg_ms,
  ROUND((max_time)::numeric, 2) as max_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_time DESC
LIMIT 20;
```

### Cache Hit Ratio Check (Target: >99%)

```sql
-- Overall cache performance
SELECT
  ROUND(
    100.0 * (1 - COALESCE(sum(heap_blks_read), 0)::float /
    NULLIF(sum(heap_blks_read) + sum(heap_blks_hit), 0))::numeric,
    2
  ) as cache_hit_ratio_percent
FROM pg_statio_user_tables;

-- Per-table performance
SELECT
  schemaname,
  tablename,
  ROUND(
    100.0 * heap_blks_hit::float / NULLIF(heap_blks_hit + heap_blks_read, 0)::numeric,
    1
  ) as heap_cache_hit_pct,
  heap_blks_hit + heap_blks_read as total_blocks_accessed
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 0
ORDER BY heap_cache_hit_pct ASC
LIMIT 20;  -- Show worst performers
```

---

## Implementation Priority

### **Tier 1: Do First** (Quick wins, high value)
1. ✅ pg_cron for PageRank refresh (DONE)
2. Window functions for PageRank analysis (simple, immediate benefit)
3. Module importance tiers materialized view (pre-calculated, fast queries)

### **Tier 2: Implement as Needed** (Specific use cases)
4. Range types for code_chunks timeline analysis
5. JSONB expansion to graph_nodes metadata
6. CTE for circular dependency detection

### **Tier 3: Future Scale** (When approaching limits)
7. Materialized view for dependency density
8. Partitioning code_chunks by codebase
9. Advanced JSONB metrics tracking on jobs

### **Monitoring: Monthly Tasks**
- Review pg_stat_statements (identify slow queries)
- Check cache hit ratio (target >99%)
- Run ANALYZE on large tables (keep statistics fresh)
- Monitor vacuum_buffer_usage_limit usage

---

## Summary Table

| Feature | Benefit | Complexity | When to Implement |
|---------|---------|-----------|------------------|
| **Window Functions** | Percentiles, rankings, gaps | Low | Now (PageRank queries) |
| **Materialized Views** | Pre-calculated reports | Low | When report performance matters |
| **Range Types** | Timeline queries | Medium | For code_chunks evolution tracking |
| **JSONB Expansion** | Flexible metadata | Low | As new metadata needs arise |
| **CTEs for Analysis** | Complex queries | Medium | For circular deps, deep analysis |
| **Partitioning** | Scale (5M+ rows) | High | When code_chunks > 2M rows |
| **pg_stat_statements** | Query monitoring | Low | Already set up, monthly review |
| **Cache Monitoring** | Performance baseline | Low | Already set up, monthly check |

---

**Status**: All techniques are available and performance-tested. Implement on an as-needed basis based on specific use cases.

**Last Updated**: October 25, 2025
