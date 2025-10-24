# Graph Queries Strategy - PostgreSQL-Native Implementation

**Status**: ⏳ IN PROGRESS
**Approach**: Use PostgreSQL native features instead of AGE (not available on ARM64)
**Expected Impact**: 100x faster code navigation queries

---

## Why Graph Queries Matter

**Current Problem**:
- PageRank tells us module importance, but not relationships
- "What calls this function?" takes full table scan
- "What will break if I change this?" requires manual analysis
- "What's the impact of this change?" unknown

**Solution**:
- Graph queries answer structural questions instantly
- Impact analysis becomes automatic
- Refactoring becomes safe and measurable

---

## Implementation Strategy (PostgreSQL Native)

### 1. **Recursive CTE Queries** (Primary)
Native PostgreSQL for graph traversal without AGE.

```sql
-- Forward call graph (all dependencies of a module)
WITH RECURSIVE dependencies AS (
  SELECT source_id, target_id
  FROM call_graph_edges
  WHERE source_id = $1

  UNION ALL

  SELECT d.source_id, e.target_id
  FROM dependencies d
  JOIN call_graph_edges e ON d.target_id = e.source_id
)
SELECT DISTINCT target_id FROM dependencies;

-- Reverse call graph (all modules that call this one)
WITH RECURSIVE callers AS (
  SELECT source_id, target_id
  FROM call_graph_edges
  WHERE target_id = $1

  UNION ALL

  SELECT e.source_id, c.target_id
  FROM callers c
  JOIN call_graph_edges e ON c.source_id = e.target_id
)
SELECT DISTINCT source_id FROM callers;
```

### 2. **Path Finding** (Shortest path between modules)
```sql
WITH RECURSIVE paths AS (
  SELECT source_id, target_id, ARRAY[source_id, target_id] as path, 1 as depth
  FROM call_graph_edges
  WHERE source_id = $1

  UNION ALL

  SELECT p.source_id, e.target_id, p.path || e.target_id, p.depth + 1
  FROM paths p
  JOIN call_graph_edges e ON p.target_id = e.source_id
  WHERE NOT e.target_id = ANY(p.path)  -- Avoid cycles
    AND p.depth < 10  -- Limit depth
)
SELECT path, depth FROM paths WHERE target_id = $2 ORDER BY depth LIMIT 1;
```

### 3. **Circular Dependency Detection**
```sql
WITH RECURSIVE visited AS (
  SELECT source_id, target_id, ARRAY[source_id] as path
  FROM call_graph_edges

  UNION ALL

  SELECT v.source_id, e.target_id, v.path || e.target_id
  FROM visited v
  JOIN call_graph_edges e ON v.target_id = e.source_id
  WHERE NOT e.target_id = ANY(v.path)  -- Haven't visited this node
)
SELECT source_id, target_id, path
FROM visited
WHERE target_id = ANY(path)  -- Found a cycle
ORDER BY array_length(path, 1);
```

### 4. **Impact Analysis** (What breaks if we change this module?)
```sql
WITH RECURSIVE affected AS (
  SELECT source_id, target_id, 1 as depth
  FROM call_graph_edges
  WHERE target_id = $1  -- Module being changed

  UNION ALL

  SELECT e.source_id, c.target_id, c.depth + 1
  FROM affected c
  JOIN call_graph_edges e ON c.source_id = e.source_id
  WHERE c.depth < 5  -- Limit depth
)
SELECT DISTINCT target_id, depth, pagerank_score
FROM affected
JOIN graph_nodes ON graph_nodes.id = target_id
ORDER BY depth, pagerank_score DESC;
```

---

## Elixir Implementation

### Module: `CodeGraph.Queries`

```elixir
defmodule Singularity.CodeGraph.Queries do
  @moduledoc """
  Graph queries for code structure analysis.

  Uses recursive CTEs for fast traversal of call graphs.
  """

  alias Singularity.Repo
  import Ecto.Query

  # Forward dependencies: all modules this calls
  def forward_dependencies(module_id, max_depth \\ 10) do
    query = """
    WITH RECURSIVE dependencies AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE source_id = $1

      UNION ALL

      SELECT d.source_id, e.target_id, d.depth + 1
      FROM dependencies d
      JOIN call_graph_edges e ON d.target_id = e.source_id
      WHERE d.depth < $2
    )
    SELECT DISTINCT target_id, depth FROM dependencies
    ORDER BY depth, target_id;
    """

    Repo.query!(query, [module_id, max_depth])
  end

  # Reverse callers: all modules that call this one
  def reverse_callers(module_id, max_depth \\ 10) do
    query = """
    WITH RECURSIVE callers AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE target_id = $1

      UNION ALL

      SELECT e.source_id, c.target_id, c.depth + 1
      FROM callers c
      JOIN call_graph_edges e ON c.source_id = e.target_id
      WHERE c.depth < $2
    )
    SELECT DISTINCT source_id, depth FROM callers
    ORDER BY depth, source_id;
    """

    Repo.query!(query, [module_id, max_depth])
  end

  # Shortest path between two modules
  def shortest_path(from_module_id, to_module_id, max_depth \\ 10) do
    query = """
    WITH RECURSIVE paths AS (
      SELECT source_id, target_id, ARRAY[source_id, target_id] as path, 1 as depth
      FROM call_graph_edges
      WHERE source_id = $1

      UNION ALL

      SELECT p.source_id, e.target_id, p.path || e.target_id, p.depth + 1
      FROM paths p
      JOIN call_graph_edges e ON p.target_id = e.source_id
      WHERE NOT e.target_id = ANY(p.path) AND p.depth < $3
    )
    SELECT path, depth FROM paths
    WHERE target_id = $2
    ORDER BY depth
    LIMIT 1;
    """

    case Repo.query(query, [from_module_id, to_module_id, max_depth]) do
      {:ok, %{rows: [[path, depth]]}} -> {:ok, %{path: path, depth: depth}}
      {:ok, %{rows: []}} -> {:error, :no_path}
      error -> error
    end
  end

  # Circular dependencies
  def find_cycles(max_depth \\ 5) do
    query = """
    WITH RECURSIVE visited AS (
      SELECT source_id, target_id, ARRAY[source_id] as path, 1 as depth
      FROM call_graph_edges

      UNION ALL

      SELECT v.source_id, e.target_id, v.path || e.target_id, v.depth + 1
      FROM visited v
      JOIN call_graph_edges e ON v.target_id = e.source_id
      WHERE NOT e.target_id = ANY(v.path) AND v.depth < $1
    )
    SELECT DISTINCT source_id, path FROM visited
    WHERE target_id = ANY(path)
    ORDER BY array_length(path, 1);
    """

    Repo.query!(query, [max_depth])
  end

  # Impact analysis: what breaks if we change this?
  def impact_analysis(module_id, max_depth \\ 5) do
    query = """
    WITH RECURSIVE affected AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE target_id = $1

      UNION ALL

      SELECT e.source_id, c.target_id, c.depth + 1
      FROM affected c
      JOIN call_graph_edges e ON c.source_id = e.source_id
      WHERE c.depth < $2
    )
    SELECT DISTINCT target_id, depth, gn.pagerank_score, gn.name
    FROM affected
    JOIN graph_nodes gn ON gn.id = target_id
    ORDER BY depth, pagerank_score DESC;
    """

    Repo.query!(query, [module_id, max_depth])
  end
end
```

---

## Performance Expectations

| Query | Nodes | Time | Index |
|-------|-------|------|-------|
| Forward dependencies | 50 | <10ms | ✅ call_graph_edges(source_id) |
| Reverse callers | 50 | <10ms | ✅ call_graph_edges(target_id) |
| Shortest path | 1000 | <50ms | ✅ Both |
| Circular detection | 10000 | 100-500ms | ✅ Both |
| Impact analysis | 100 | <50ms | ✅ Both + graph_nodes(pagerank) |

---

## Database Setup

### Create Indexes

```sql
-- Existing indexes from migrations
CREATE INDEX idx_call_graph_edges_source ON call_graph_edges(source_id);
CREATE INDEX idx_call_graph_edges_target ON call_graph_edges(target_id);
CREATE INDEX idx_call_graph_edges_bidirectional ON call_graph_edges(source_id, target_id);

-- Speed up graph queries
CREATE INDEX idx_graph_nodes_pagerank ON graph_nodes(pagerank_score DESC);
```

### Verify Call Graph Data

```sql
-- Check call graph exists and has data
SELECT COUNT(*) as edge_count FROM call_graph_edges;

-- Distribution of edges
SELECT source_id, COUNT(*) as outgoing_edges
FROM call_graph_edges
GROUP BY source_id
ORDER BY outgoing_edges DESC
LIMIT 10;
```

---

## Elixir Integration

### 1. **Mix Task for Graph Analysis**

```bash
mix graph.analyze --module MyModule  # Show all callers/dependencies
mix graph.impact --module MyModule   # Show impact of changes
mix graph.cycles                     # Find all circular dependencies
```

### 2. **Agent Integration**

Architecture Agent can use:
```elixir
with {:ok, impact} <- CodeGraph.Queries.impact_analysis(module_id),
     {:ok, cycles} <- CodeGraph.Queries.find_cycles() do
  # Recommend refactoring targets
  high_impact = Enum.filter(impact, &(&1.depth <= 2 && &1.pagerank_score > 5.0))

  # Prevent circular dependencies
  circular = Enum.filter(cycles, &(Enum.length(&1.path) <= 5))

  {:ok, %{refactoring_targets: high_impact, circular_deps: circular}}
end
```

### 3. **Dashboard Widgets**

```elixir
# Show what's affected by recent change
recent_change = Enum.last(git_log)
{:ok, affected} = CodeGraph.Queries.impact_analysis(recent_change.module_id)

# Show circular dependencies to fix
{:ok, cycles} = CodeGraph.Queries.find_cycles()
```

---

## Implementation Timeline

| Phase | Task | Days | Effort |
|-------|------|------|--------|
| **1** | Create CodeGraph.Queries module | 1 | Easy |
| **2** | Implement 5 core queries | 1 | Easy |
| **3** | Add Mix tasks | 1 | Easy |
| **4** | Integrate with agents | 2 | Medium |
| **5** | Create dashboard widgets | 1 | Easy |
| **6** | Performance optimization | 1-2 | Medium |
| **Total** | | **7-8 days** | |

---

## Why Not AGE?

**AGE Limitations**:
- Not available on ARM64 macOS (this system)
- Requires separate graph database operations
- Additional complexity for Elixir integration
- Performance may not be better than optimized recursive CTEs

**PostgreSQL Native Benefits**:
- ✅ Works immediately on this system
- ✅ Joins with graph_nodes for metrics
- ✅ Can leverage existing indexes
- ✅ Simple Elixir integration
- ✅ 100% transaction ACID guarantees
- ✅ Can combine with full-text + vector search

---

## Key Insight

**Recursive CTEs are graph databases at scale < 10K nodes.**

For our codebase (typically 100-1000 nodes), PostgreSQL recursive CTEs outperform dedicated graph databases because:
1. No network overhead (local queries)
2. Perfect index utilization
3. Combine with relational data seamlessly
4. Query optimization is built-in
5. No separate database to operate

---

## Next Actions

1. **Implement CodeGraph.Queries** (1 day)
   - 5 core recursive CTE queries
   - Parameterized for depth/limits
   - Error handling

2. **Create Mix task** (0.5 days)
   - `mix graph.analyze`
   - `mix graph.impact`
   - `mix graph.cycles`

3. **Integration testing** (1 day)
   - Verify on real codebase
   - Performance profile
   - Index validation

4. **Agent integration** (1-2 days)
   - Architecture Agent uses for analysis
   - Refactoring recommendations
   - Change impact warnings

---

**Status**: Ready to implement
**Priority**: HIGH (enables safe refactoring + architectural analysis)
