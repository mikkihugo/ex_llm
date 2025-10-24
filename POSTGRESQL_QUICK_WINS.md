# PostgreSQL Quick Wins - Ready to Implement Now

**Status**: Ready for implementation whenever needed
**Priority**: High-value, low-effort features

---

## 1. Window Functions for PageRank Tiers (15 mins)

**What**: Add percentile/ranking context to PageRank queries
**File**: `singularity/lib/singularity/graph/pagerank_queries.ex`
**Effort**: Add 1-2 new query functions

### Before (Current)
```elixir
# Just scores, no context
iex> PageRankQueries.find_top_modules("singularity", 10)
[
  %{name: "Service", pagerank_score: 3.14},
  %{name: "Manager", pagerank_score: 2.89},
  ...
]
```

### After (With Window Functions)
```elixir
# Add this function to pagerank_queries.ex:
def find_modules_with_percentiles(codebase_id, limit \\ 50) do
  from(n in GraphNode,
    where: n.codebase_id == ^codebase_id,
    select: %{
      name: n.name,
      file_path: n.file_path,
      pagerank_score: n.pagerank_score,

      # NEW: Ranking
      rank: over(
        row_number(),
        order_by: [desc: n.pagerank_score]
      ),

      # NEW: Percentile (1-100)
      percentile: over(
        ntile(100),
        order_by: [desc: n.pagerank_score]
      ),

      # NEW: Relative to average
      relative_to_avg: fragment(
        "ROUND((? / AVG(?) OVER ())::numeric, 2)",
        n.pagerank_score,
        n.pagerank_score
      ),

      # NEW: Gap from previous (shows cliffs)
      gap_from_previous: fragment(
        "ROUND((? - LAG(?) OVER (ORDER BY ? DESC))::numeric, 3)",
        n.pagerank_score,
        n.pagerank_score,
        n.pagerank_score
      )
    },
    limit: ^limit,
    order_by: [desc: n.pagerank_score]
  )
  |> Repo.all()
end

# Usage:
iex> PageRankQueries.find_modules_with_percentiles("singularity", 20)
[
  %{
    name: "Service",
    pagerank_score: 3.14,
    rank: 1,
    percentile: 95,  # Top 5%!
    relative_to_avg: 2.61,  # 2.61x average importance
    gap_from_previous: nil
  },
  %{
    name: "Manager",
    pagerank_score: 2.89,
    rank: 2,
    percentile: 94,
    relative_to_avg: 2.40,
    gap_from_previous: 0.250  # Only small gap
  },
  %{
    name: "Config",
    pagerank_score: 1.85,
    rank: 4,
    percentile: 90,
    relative_to_avg: 1.54,
    gap_from_previous: 0.660  # BIG GAP! Importance cliff detected
  },
  ...
]
```

**Benefits**:
- Automatically identify tier boundaries
- Spot "importance cliffs" (where to focus)
- Relative comparisons (not absolute)
- One query, instant value

**Ecto Query Tips**:
```elixir
# Use fragment/2 for window functions Ecto doesn't know about
fragment("function_name(...) OVER (...)")

# Use over/2 for common window functions
over(row_number(), order_by: [...])
over(ntile(100), order_by: [...])
```

---

## 2. Materialized View for Tier Distribution (5 mins)

**What**: Pre-calculate importance tiers (instant reports)
**File**: New migration
**Effort**: One-time setup, then refresh via pg_cron

### SQL to Create
```sql
-- Create once
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
  END as tier,
  NTILE(100) OVER (
    PARTITION BY codebase_id
    ORDER BY pagerank_score DESC
  ) as percentile
FROM graph_nodes
WHERE pagerank_score > 0;

CREATE INDEX idx_module_tiers
ON module_importance_tiers(codebase_id, tier);
```

### Refresh (Add to PageRank pg_cron function)
```sql
-- In pagerank_daily_refresh() SQL function:
REFRESH MATERIALIZED VIEW CONCURRENTLY module_importance_tiers;
```

### Usage (Instant!)
```elixir
# Add function to pagerank_queries.ex:
def get_tier_summary(codebase_id) do
  sql = """
  SELECT
    tier,
    COUNT(*) as module_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) as percent,
    ROUND(AVG(pagerank_score)::numeric, 2) as avg_score,
    MIN(pagerank_score) as min_score,
    MAX(pagerank_score) as max_score
  FROM module_importance_tiers
  WHERE codebase_id = $1
  GROUP BY tier
  ORDER BY
    CASE tier
      WHEN 'CRITICAL' THEN 1
      WHEN 'IMPORTANT' THEN 2
      WHEN 'MODERATE' THEN 3
      WHEN 'LOW' THEN 4
    END;
  """
  Repo.query!(sql, [codebase_id]) |> Map.fetch!(:rows)
end

# Query in 1ms instead of 2+ seconds!
iex> PageRankQueries.get_tier_summary("singularity")
[
  {"CRITICAL", 12, 3.2%, 6.21, 5.10},
  {"IMPORTANT", 38, 10.1%, 2.85, 2.01},
  {"MODERATE", 145, 38.7%, 0.74, 0.51},
  {"LOW", 200, 47.9%, 0.12, 0.01}
]
```

**Benefits**:
- Pre-calculated (no re-sorting each time)
- Indexed (lightning fast)
- Refreshes automatically after PageRank calculation
- Elixir can build nice dashboards from this

---

## 3. Detect Importance Cliffs (10 mins)

**What**: Find where big drops happen (refactoring targets)
**File**: `singularity/lib/singularity/graph/pagerank_queries.ex`
**Effort**: One SQL function

### Implementation
```elixir
# Add to pagerank_queries.ex:
def find_importance_cliffs(codebase_id, min_drop \\ 0.5) do
  sql = """
  WITH scored AS (
    SELECT
      name,
      file_path,
      pagerank_score,
      LAG(pagerank_score) OVER (ORDER BY pagerank_score DESC) as prev_score,
      ROW_NUMBER() OVER (ORDER BY pagerank_score DESC) as position
    FROM graph_nodes
    WHERE codebase_id = $1
  )
  SELECT
    position,
    name,
    file_path,
    ROUND(pagerank_score::numeric, 3) as score,
    ROUND((prev_score - pagerank_score)::numeric, 3) as drop,
    ROUND((100.0 * (prev_score - pagerank_score) /
      NULLIF(prev_score, 0))::numeric, 1) as drop_percent
  FROM scored
  WHERE prev_score IS NOT NULL
    AND prev_score - pagerank_score > $2
  ORDER BY drop DESC
  LIMIT 20;
  """
  Repo.query!(sql, [codebase_id, min_drop])
  |> Enum.map(fn [pos, name, path, score, drop, pct] ->
    %{
      position: pos,
      module: name,
      file_path: path,
      score: score,
      drop_from_previous: drop,
      drop_percent: pct
    }
  end)
end

# Usage - shows where to focus refactoring!
iex> PageRankQueries.find_importance_cliffs("singularity", 0.5)
[
  %{position: 3, module: "Config", score: 1.85, drop: 0.660, drop_percent: 26.3%},
  %{position: 4, module: "Helper", score: 1.21, drop: 0.640, drop_percent: 34.6%},
  ...
]
```

**Benefits**:
- Shows natural tier boundaries
- Identifies refactoring targets
- Highlights "dead zones" (unused code)
- Pure SQL, instant results

---

## 4. Timeline Analysis with Range Types (Optional, Future)

**What**: Query "what code existed on date X?"
**Effort**: Medium (schema change)
**When**: After code evolution tracking is important

### Simple Version (Now)
```sql
-- View historical queries without schema changes
SELECT
  file_path,
  created_at as created,
  updated_at as removed,
  JUSTIFY_INTERVAL(updated_at - created_at) as lifetime
FROM code_chunks
WHERE codebase_id = 'singularity'
ORDER BY created_at DESC;
```

### Optimized Version (Later)
```sql
-- One-time setup:
ALTER TABLE code_chunks
ADD COLUMN valid_period tsrange;

UPDATE code_chunks
SET valid_period = tsrange(created_at, updated_at);

CREATE INDEX idx_code_chunks_valid_period
ON code_chunks USING GIST (valid_period);

-- Then: super fast temporal queries
SELECT COUNT(*) FROM code_chunks
WHERE valid_period @> '2025-01-15'::timestamp;  -- 100x faster!
```

---

## 5. Monthly Monitoring Tasks (Setup Once, Run Monthly)

### Already Set Up, Just Review Monthly:

**1. Slow Query Detection**
```sql
-- Run monthly to find optimization opportunities
SELECT
  query,
  calls,
  ROUND((total_time / 1000)::numeric, 2) as total_seconds,
  ROUND((mean_time)::numeric, 2) as avg_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_time DESC
LIMIT 20;
```

**2. Cache Hit Ratio**
```sql
-- Target: >99% means excellent performance
SELECT
  ROUND(
    100.0 * (1 - COALESCE(sum(heap_blks_read), 0)::float /
    NULLIF(sum(heap_blks_read) + sum(heap_blks_hit), 0))::numeric,
    2
  ) as cache_hit_ratio_percent
FROM pg_statio_user_tables;
```

**3. Table Stats Update**
```sql
-- Run after PageRank refresh to keep planner accurate
ANALYZE code_chunks;
ANALYZE graph_nodes;
ANALYZE knowledge_artifacts;
```

---

## Implementation Order

### **Week 1: Window Functions** (15 mins)
1. Add `find_modules_with_percentiles/2` to `pagerank_queries.ex`
2. Test in iex
3. Optional: Add to dashboards

### **Week 2: Materialized View** (30 mins)
1. Create migration for `module_importance_tiers`
2. Add to pg_cron refresh function
3. Add `get_tier_summary/1` to `pagerank_queries.ex`
4. Use in reports

### **Ongoing: Monthly Monitoring** (10 mins/month)
1. First Friday of month: Run slow query check
2. Check cache hit ratio
3. Run ANALYZE on large tables

### **Future: Range Types** (when needed)
- Implement when code evolution tracking becomes important
- Not urgent, but available when ready

---

## Quick Implementation Checklist

- [ ] **Window Functions**
  - [ ] Add `find_modules_with_percentiles/2` function
  - [ ] Test with real PageRank data
  - [ ] Add to documentation

- [ ] **Materialized View**
  - [ ] Create migration
  - [ ] Update pg_cron refresh function
  - [ ] Add `get_tier_summary/1` function
  - [ ] Create index on (codebase_id, tier)

- [ ] **Importance Cliffs**
  - [ ] Add `find_importance_cliffs/2` function
  - [ ] Test with actual data
  - [ ] Document tier boundaries found

- [ ] **Monthly Monitoring**
  - [ ] Add reminder to calendar (1st of month)
  - [ ] Bookmark slow query SQL
  - [ ] Bookmark cache ratio SQL
  - [ ] Schedule ANALYZE after PageRank calc

---

## Expected Performance Impact

| Feature | Query Time | Benefit |
|---------|-----------|---------|
| Window Functions | <100ms | Percentile rankings, cliff detection |
| Materialized View | 1-5ms | Pre-calculated tier reports |
| Importance Cliffs | <50ms | Identify refactoring targets |
| Range Types (future) | 10-50ms | Fast timeline queries |

**Total Impact**: Dashboard response time from 3-5 seconds → 100-500ms

---

**Next Steps**: Pick whichever feature you want first and implement!
