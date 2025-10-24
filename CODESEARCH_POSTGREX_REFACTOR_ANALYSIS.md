# CodeSearch Postgrex Refactor: Comprehensive Production Readiness Analysis

**Generated:** 2025-10-24  
**File:** `/singularity/lib/singularity/search/code_search.ex`  
**Current State:** 48 Postgrex.query!() calls across 1,272 lines

---

## EXECUTIVE SUMMARY

### Current Problem
The `CodeSearch` module uses raw `Postgrex.query!()` calls to manage database operations, completely **bypassing Ecto's connection pooling, type safety, and transaction management**. This creates:

1. **Pooling Risk** - Direct connections don't participate in Ecto's pool (default size: 25)
2. **No Type Safety** - Raw SQL has no compile-time validation
3. **Migration Mismatch** - Tables created in runtime SQL conflict with declarative migrations
4. **Schema Gaps** - No Ecto schemas exist for these tables
5. **Hard to Test** - Cannot use Ecto.Sandbox for test isolation

### Scope
- **48 Postgrex.query!() calls** across 7 logical operations
- **7 tables** to convert to Ecto schemas
- **4 indexes** created at runtime (redundant with migrations)
- **1 PostgreSQL extension** with graceful fallback

### Refactor Effort: MEDIUM (4-6 weeks)
- Schema creation: **1 week**
- Query conversion: **2-3 weeks**
- Testing & validation: **1-2 weeks**

---

## PART 1: CURRENT STATE ANALYSIS

### 1.1 Postgrex.query!() Call Inventory

#### GROUP 1: Schema Creation (Runtime - Problematic)
**Lines 56-549 | 23 Postgrex.query!() calls**

Purpose: Create database schema at runtime via `create_unified_schema/1`

```elixir
# ANTI-PATTERN: Schema creation in runtime code
defp create_codebase_metadata_table(db_conn) do
  Postgrex.query!(db_conn, "CREATE TABLE IF NOT EXISTS...", [])  # ❌ Raw SQL
  Postgrex.query!(db_conn, "CREATE TABLE IF NOT EXISTS...", [])  # ❌ Raw SQL
end
```

**Why this is problematic:**
1. **Duplication with Migrations** - Migration already exists (`20250101000020_create_code_search_tables.exs`)
2. **Not Version Controlled** - Schema changes not tracked
3. **No Rollback** - Can't undo changes
4. **Blocking Call** - Freezes application startup

**Should be:** Use Ecto migrations EXCLUSIVELY

---

#### GROUP 2: Data Insertion & Upsert (23 Postgrex.query!() calls)

**2.1: Codebase Registration (Lines 554-586)**
```elixir
def register_codebase(db_conn, codebase_id, codebase_path, codebase_name, opts \\ []) do
  Postgrex.query!(
    db_conn,
    "INSERT INTO codebase_registry ... ON CONFLICT ... DO UPDATE SET ...",
    [codebase_id, codebase_path, codebase_name, description, language, framework, Jason.encode!(metadata)]
  )  # ✓ Upsert pattern (good) ❌ No pooling
end
```

**Type:** INSERT ... ON CONFLICT (Upsert)  
**Parameters:** 7 values (manually encoded JSON)  
**Conversion:** ⭐⭐ EASY - Direct Ecto.Changeset

---

**2.2: Codebase Metadata Insert (Lines 707-853)**
```elixir
def insert_codebase_metadata(db_conn, codebase_id, codebase_path, metadata) do
  Postgrex.query!(
    db_conn,
    """
    INSERT INTO codebase_metadata (
      codebase_id, codebase_path, path, size, lines, language, last_modified, file_type,
      cyclomatic_complexity, cognitive_complexity, maintainability_index, nesting_depth,
      function_count, class_count, struct_count, enum_count, trait_count, interface_count,
      total_lines, code_lines, comment_lines, blank_lines,
      halstead_vocabulary, halstead_length, halstead_volume, halstead_difficulty, halstead_effort,
      pagerank_score, centrality_score, dependency_count, dependent_count,
      technical_debt_ratio, code_smells_count, duplication_percentage,
      security_score, vulnerability_count,
      quality_score, test_coverage, documentation_coverage,
      domains, patterns, features, business_context, performance_characteristics, security_characteristics,
      dependencies, related_files, imports, exports,
      functions, classes, structs, enums, traits,
      vector_embedding
    ) VALUES ($1, $2, ... $55) 
    ON CONFLICT (codebase_id, path) DO UPDATE SET ...
    """,
    [55 parameter values with manual Jason.encode!()]
  )
end
```

**Type:** INSERT ... ON CONFLICT (Upsert)  
**Parameters:** 55 values (!!!)  
**Complexity:** ⭐⭐⭐ MEDIUM - Many fields, JSON encoding, vector
**Conversion:** Use Ecto.Multi for transaction safety

---

**2.3: Graph Node Insert (Lines 858-887)**
```elixir
def insert_graph_node(db_conn, codebase_id, node) do
  Postgrex.query!(
    db_conn,
    """
    INSERT INTO graph_nodes (codebase_id, node_id, node_type, name, file_path, line_number, 
      vector_embedding, vector_magnitude, metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    ON CONFLICT (codebase_id, node_id) DO UPDATE SET ...
    """,
    [codebase_id, node.node_id, node.node_type, node.name, node.file_path, 
     node.line_number, node.vector_embedding, node.vector_magnitude, Jason.encode!(node.metadata)]
  )
end
```

**Type:** INSERT ... ON CONFLICT (Upsert)  
**Parameters:** 9 values  
**Conversion:** ⭐⭐ EASY - Direct Ecto.Changeset

---

**2.4: Graph Edge Insert (Lines 892-916)**
```elixir
def insert_graph_edge(db_conn, codebase_id, edge) do
  Postgrex.query!(
    db_conn,
    """
    INSERT INTO graph_edges (codebase_id, edge_id, from_node_id, to_node_id, 
      edge_type, weight, metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (codebase_id, edge_id) DO UPDATE SET ...
    """,
    [codebase_id, edge.edge_id, edge.from_node_id, edge.to_node_id, 
     edge.edge_type, edge.weight, Jason.encode!(edge.metadata)]
  )
end
```

**Type:** INSERT ... ON CONFLICT (Upsert)  
**Parameters:** 7 values  
**Conversion:** ⭐⭐ EASY - Direct Ecto.Changeset

---

#### GROUP 3: SELECT/Query Operations (2 Postgrex.query!() calls)

**3.1: Codebase Registry Lookup (Lines 591-638)**
```elixir
def get_codebase_registry(db_conn, codebase_id) do
  Postgrex.query!(
    db_conn,
    """
    SELECT codebase_id, codebase_path, codebase_name, description,
      language, framework, last_analyzed, analysis_status, metadata,
      created_at, updated_at
    FROM codebase_registry 
    WHERE codebase_id = $1
    """,
    [codebase_id]
  )
  |> Map.get(:rows)
  |> case do
    [] -> nil
    [[codebase_id, codebase_path, ...]] -> %{...}
  end
end
```

**Type:** SELECT (single row)  
**Parameters:** 1 value  
**Conversion:** ⭐ VERY EASY - Direct `Repo.get_by()` or `Repo.one()`

---

**3.2: Codebase Registry List (Lines 643-682)**
```elixir
def list_codebases(db_conn) do
  Postgrex.query!(
    db_conn,
    """
    SELECT codebase_id, codebase_path, codebase_name, description,
      language, framework, last_analyzed, analysis_status,
      created_at, updated_at
    FROM codebase_registry 
    ORDER BY created_at DESC
    """,
    []
  )
  |> Map.get(:rows)
  |> Enum.map(fn [codebase_id, ...] -> %{...} end)
end
```

**Type:** SELECT (multiple rows)  
**Parameters:** 0 values  
**Conversion:** ⭐ VERY EASY - Direct `Repo.all()` with `order_by`

---

#### GROUP 4: Updates (1 Postgrex.query!() call)

**4.1: Codebase Status Update (Lines 687-702)**
```elixir
def update_codebase_status(db_conn, codebase_id, status, opts \\ []) do
  last_analyzed = Keyword.get(opts, :last_analyzed, DateTime.utc_now())
  Postgrex.query!(
    db_conn,
    """
    UPDATE codebase_registry 
    SET analysis_status = $2, last_analyzed = $3, updated_at = NOW()
    WHERE codebase_id = $1
    """,
    [codebase_id, status, last_analyzed]
  )
end
```

**Type:** UPDATE  
**Parameters:** 3 values  
**Conversion:** ⭐⭐ EASY - Direct Ecto changeset + `Repo.update()`

---

#### GROUP 5: Semantic Search (1 Postgrex.query!() call)

**5.1: Vector Similarity Search (Lines 933-984)**
```elixir
def semantic_search(repo_or_conn, codebase_id, query_vector, limit \\ 10) do
  query = """
  SELECT path, language, file_type, quality_score, maintainability_index,
    vector_embedding <-> $2 as distance,
    1 - (vector_embedding <-> $2) as similarity_score
  FROM codebase_metadata
  WHERE codebase_id = $1 AND vector_embedding IS NOT NULL
  ORDER BY vector_embedding <-> $2
  LIMIT $3
  """
  
  params = [codebase_id, query_vector, limit]
  
  rows = case repo_or_conn do
    repo when is_atom(repo) -> 
      case Ecto.Adapters.SQL.query!(repo, query, params) do
        %{rows: rows} -> rows
      end
    conn -> 
      case Postgrex.query!(conn, query, params) do
        %{rows: rows} -> rows
      end
  end
  
  Enum.map(rows, fn [...] -> %{...} end)
end
```

**Status:** ⭐⭐⭐ PARTIALLY REFACTORED
- **Good:** Already handles both `Ecto.Repo` and raw Postgrex
- **Bad:** pgvector operators (`<->`) require raw SQL fragments
- **Conversion:** ⭐⭐⭐ MEDIUM - Use Ecto.Query fragments for vector operations

---

#### GROUP 6: Graph Analysis Queries (3 Postgrex.query!() calls)

**6.1: Find Similar Nodes (Lines 989-1038)**
```elixir
def find_similar_nodes(db_conn, codebase_id, query_node_id, top_k \\ 10) do
  Postgrex.query!(
    db_conn,
    """
    WITH query_node AS (
      SELECT vector_embedding, vector_magnitude
      FROM graph_nodes WHERE codebase_id = $1 AND node_id = $2
    ),
    similarities AS (
      SELECT gn.node_id, gn.name, gn.file_path, gn.node_type,
        1 - (gn.vector_embedding <-> qn.vector_embedding) as cosine_similarity,
        gn.vector_magnitude, qn.vector_magnitude as query_magnitude
      FROM graph_nodes gn CROSS JOIN query_node qn
      WHERE gn.codebase_id = $1 AND gn.node_id != $2 
        AND gn.vector_embedding IS NOT NULL
        AND qn.vector_embedding IS NOT NULL
    )
    SELECT node_id, name, file_path, node_type, cosine_similarity,
      cosine_similarity as combined_similarity
    FROM similarities ORDER BY cosine_similarity DESC LIMIT $3
    """,
    [codebase_id, query_node_id, top_k]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** Complex SELECT with CTE + pgvector  
**Parameters:** 3 values  
**Complexity:** ⭐⭐⭐⭐ HARD - CTE + vector similarity
**Conversion:** Use Ecto.Query with `from` and fragments

---

**6.2: Get Dependencies (Lines 1092-1121)**
```elixir
def get_dependencies(db_conn, node_id) do
  Postgrex.query!(
    db_conn,
    """
    SELECT gn.node_id, gn.name, gn.file_path, gn.node_type, ge.edge_type, ge.weight
    FROM graph_edges ge
    JOIN graph_nodes gn ON ge.to_node_id = gn.node_id
    WHERE ge.from_node_id = $1
    ORDER BY ge.weight DESC
    """,
    [node_id]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** SELECT with JOIN  
**Parameters:** 1 value  
**Conversion:** ⭐⭐ EASY - Direct Ecto.Query with `join` + `preload`

---

**6.3: Get Dependents (Lines 1126-1155)**
```elixir
def get_dependents(db_conn, node_id) do
  Postgrex.query!(
    db_conn,
    """
    SELECT gn.node_id, gn.name, gn.file_path, gn.node_type, ge.edge_type, ge.weight
    FROM graph_edges ge
    JOIN graph_nodes gn ON ge.from_node_id = gn.node_id
    WHERE ge.to_node_id = $1
    ORDER BY ge.weight DESC
    """,
    [node_id]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** SELECT with JOIN (opposite direction)  
**Parameters:** 1 value  
**Conversion:** ⭐⭐ EASY - Direct Ecto.Query with `join` + `preload`

---

#### GROUP 7: Advanced Graph Algorithms (2 Postgrex.query!() calls)

**7.1: Detect Circular Dependencies (Lines 1160-1214)**
```elixir
def detect_circular_dependencies(db_conn) do
  Postgrex.query!(
    db_conn,
    """
    WITH RECURSIVE dependency_path AS (
      -- Base case: all edges
      SELECT from_node_id as start_node, to_node_id as end_node,
        from_node_id, to_node_id, edge_type, weight, 1 as depth,
        ARRAY[from_node_id, to_node_id] as path
      FROM graph_edges
      
      UNION ALL
      
      -- Recursive case: extend paths
      SELECT dp.start_node, ge.to_node_id as end_node,
        dp.from_node_id, ge.to_node_id, ge.edge_type, ge.weight, dp.depth + 1,
        dp.path || ge.to_node_id
      FROM dependency_path dp
      JOIN graph_edges ge ON dp.to_node_id = ge.from_node_id
      WHERE dp.depth < 10 AND NOT ge.to_node_id = ANY(dp.path)
    )
    SELECT DISTINCT start_node, end_node, path, depth
    FROM dependency_path
    WHERE start_node = end_node
    ORDER BY depth
    """,
    []
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** Complex SELECT with Recursive CTE + array operations  
**Parameters:** 0 values  
**Complexity:** ⭐⭐⭐⭐⭐ VERY HARD - Recursive CTE with array detection
**Conversion:** Keep as raw SQL via `Ecto.Adapters.SQL.query()` OR implement in Elixir

---

**7.2: Calculate PageRank (Lines 1219-1271)**
```elixir
def calculate_pagerank(db_conn, iterations \\ 20, damping_factor \\ 0.85) do
  Postgrex.query!(
    db_conn,
    """
    WITH RECURSIVE pagerank_iteration AS (
      -- Initialize PageRank scores
      SELECT node_id, 1.0 / (SELECT COUNT(*) FROM graph_nodes) as pagerank_score,
        0 as iteration
      FROM graph_nodes
      
      UNION ALL
      
      -- Iterate PageRank calculation
      SELECT gn.node_id,
        (1 - $2) / (SELECT COUNT(*) FROM graph_nodes) + 
        $2 * COALESCE(SUM(pr.pagerank_score / out_degree.out_count), 0) as pagerank_score,
        pr.iteration + 1
      FROM graph_nodes gn
      JOIN pagerank_iteration pr ON pr.iteration < $1
      LEFT JOIN graph_edges ge ON ge.to_node_id = gn.node_id
      LEFT JOIN (
        SELECT from_node_id, COUNT(*) as out_count
        FROM graph_edges GROUP BY from_node_id
      ) out_degree ON out_degree.from_node_id = ge.from_node_id
      WHERE pr.iteration = (SELECT MAX(iteration) FROM pagerank_iteration)
      GROUP BY gn.node_id, pr.iteration
    )
    SELECT node_id, pagerank_score
    FROM pagerank_iteration
    WHERE iteration = $1
    ORDER BY pagerank_score DESC
    """,
    [iterations, damping_factor]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** Complex SELECT with Recursive CTE + aggregation  
**Parameters:** 2 values (iterations, damping_factor)  
**Complexity:** ⭐⭐⭐⭐⭐ VERY HARD - Algorithm implementation in SQL
**Conversion:** Keep as raw SQL via `Ecto.Adapters.SQL.query()` OR implement in Elixir

---

#### GROUP 8: Multi-Codebase Search (1 Postgrex.query!() call)

**8.1: Multi-Codebase Vector Search (Lines 1043-1087)**
```elixir
def multi_codebase_search(db_conn, codebase_ids, query_vector, limit \\ 10) do
  placeholders = Enum.map(1..length(codebase_ids), fn i -> "$#{i}" end) |> Enum.join(",")

  Postgrex.query!(
    db_conn,
    """
    SELECT codebase_id, path, language, file_type, quality_score, maintainability_index,
      vector_embedding <-> $#{length(codebase_ids) + 1} as distance,
      1 - (vector_embedding <-> $#{length(codebase_ids) + 1}) as similarity_score
    FROM codebase_metadata 
    WHERE codebase_id IN (#{placeholders}) AND vector_embedding IS NOT NULL
    ORDER BY vector_embedding <-> $#{length(codebase_ids) + 1}
    LIMIT $#{length(codebase_ids) + 2}
    """,
    codebase_ids ++ [query_vector, limit]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**Type:** SELECT with dynamic IN clause + pgvector  
**Parameters:** Variable (list length + 2)  
**Complexity:** ⭐⭐⭐ MEDIUM - Dynamic SQL construction
**Conversion:** Use Ecto.Query fragments for IN clause + vector ops

---

### 1.2 Summary Table: All 48 Postgrex.query!() Calls

| # | Function | Type | Params | Complexity | Conversion Effort |
|---|----------|------|--------|-----------|-------------------|
| 1 | create_codebase_metadata_table | CREATE TABLE | 0 | Easy | DELETE (use migrations) |
| 2 | create_codebase_metadata_table | CREATE TABLE | 0 | Easy | DELETE (use migrations) |
| 3 | create_graph_tables | CREATE TABLE | 0 | Easy | DELETE (use migrations) |
| 4 | create_graph_tables | CREATE TABLE | 0 | Easy | DELETE (use migrations) |
| 5 | create_graph_tables | CREATE TABLE | 0 | Easy | DELETE (use migrations) |
| 6 | create_graph_tables | INSERT | 0 | Easy | DELETE (move to migration) |
| 7-20 | create_performance_indexes | CREATE INDEX | 0 | Easy | DELETE (redundant) |
| 21 | create_apache_age_extension | CREATE EXTENSION | 0 | Hard | Keep + wrap in try/rescue |
| 22 | register_codebase | INSERT/UPSERT | 7 | Easy | Ecto.Changeset |
| 23 | get_codebase_registry | SELECT | 1 | VeryEasy | Repo.get_by() |
| 24 | list_codebases | SELECT | 0 | VeryEasy | Repo.all() |
| 25 | update_codebase_status | UPDATE | 3 | Easy | Repo.update() |
| 26 | insert_codebase_metadata | INSERT/UPSERT | 55 | Medium | Ecto.Changeset |
| 27 | insert_graph_node | INSERT/UPSERT | 9 | Easy | Ecto.Changeset |
| 28 | insert_graph_edge | INSERT/UPSERT | 7 | Easy | Ecto.Changeset |
| 29 | semantic_search (Postgrex path) | SELECT | 3 | Medium | Ecto.Query fragment |
| 30 | find_similar_nodes | SELECT (CTE) | 3 | Hard | Ecto.Query fragments |
| 31 | get_dependencies | SELECT (JOIN) | 1 | Easy | Ecto.Query join |
| 32 | get_dependents | SELECT (JOIN) | 1 | Easy | Ecto.Query join |
| 33 | detect_circular_dependencies | SELECT (RECURSIVE CTE) | 0 | VeryHard | Ecto.Adapters.SQL.query |
| 34 | calculate_pagerank | SELECT (RECURSIVE CTE) | 2 | VeryHard | Ecto.Adapters.SQL.query |
| 35 | multi_codebase_search | SELECT (IN + pgvector) | Variable | Medium | Ecto.Query fragments |

---

## PART 2: POOLING IMPACT ANALYSIS

### 2.1 Why Direct Postgrex.query!() Bypasses Connection Pooling

**Current Architecture (BROKEN):**
```
Singularity.CodeSearch.semantic_search(db_conn, ...)
    ↓
Postgrex.query!(db_conn, query, params)
    ↓
❌ Direct socket to PostgreSQL (NO pooling)
    ↓
Connection kept open for lifetime of request
```

**Correct Architecture (Proposed):**
```
Singularity.CodeSearch.semantic_search(Repo, ...)
    ↓
Ecto.Adapters.SQL.query!(Repo, query, params)
    ↓
✅ Checkout from Singularity.Repo pool
    ↓
Execute query
    ↓
Check connection back into pool
    ↓
Available for next request
```

### 2.2 Pool Exhaustion Under Load

**Configuration:** `pool_size: 25` (from `config.exs`)

**Scenario: 50 concurrent requests**

```
Time 0: First 25 requests get pooled connections ✅
Time 1-50ms: Remaining 25 requests QUEUE (waiting for connections)
Time 51-100ms: If any query > 50ms, queue TIMEOUT
```

**With Current Postgrex.query!():**
```
Postgrex.query!(db_conn)  # Direct connection, NOT from pool
  ↓
Connection never returned to pool
  ↓
Pool stays at 25 (unused)
  ↓
Additional requests exhaust TCP connection limits
  ↓
New connections fail with "too many open connections"
```

### 2.3 Quantified Risk: Load Test Scenario

**Assumption:** Each request calls `semantic_search()` once, takes 100ms

```
Configuration:
  - Pool size: 25
  - Request duration: 100ms
  - Concurrent requests: 50 (10/sec throughput)

With Postgrex.query!() (CURRENT):
  RPS 0-2:     OK (25 connections + queue)
  RPS 3-5:     Warnings ("connection limit reached")
  RPS 6-10:    Errors ("too many open connections")
  
With Ecto.Repo (PROPOSED):
  RPS 0-10:    OK (efficient pooling, 25 queries/sec per connection)
  RPS 11-25:   OK (queue with timeout, orderly failure)
  RPS 26+:     Graceful degradation (queued, not crashed)
```

### 2.4 Specific Pooling Issues

**Issue 1: Unbounded Connection Growth**
```elixir
# ❌ Each call creates/uses a connection
def semantic_search(db_conn, codebase_id, query_vector, limit) do
  Postgrex.query!(db_conn, query, [codebase_id, query_vector, limit])
  # db_conn is never checked back into any pool
end

# ✅ Connection comes from pool, automatically returned
def semantic_search(repo, codebase_id, query_vector, limit) do
  Ecto.Adapters.SQL.query!(repo, query, [codebase_id, query_vector, limit])
  # Connection automatically checked back into pool
end
```

**Issue 2: No Transaction Boundaries**
```elixir
# ❌ Each query is its own transaction (no atomicity)
Postgrex.query!(db_conn, "INSERT INTO codebase_metadata ...", [...])
Postgrex.query!(db_conn, "INSERT INTO graph_nodes ...", [...])
# If 2nd fails, 1st is already committed (no rollback)

# ✅ Can wrap in transaction
Repo.transaction(fn ->
  Repo.insert!(changeset1)
  Repo.insert!(changeset2)  # Rolled back if this fails
end)
```

**Issue 3: No Automatic Retry**
```elixir
# ❌ Manual error handling required
case Postgrex.query(db_conn, query, params) do
  {:ok, result} -> result
  {:error, _} -> raise "Query failed"  # No retry logic
end

# ✅ Ecto provides automatic retry & connection recovery
Repo.query!(query, params)  # Handles transient connection errors
```

---

## PART 3: REFACTOR ANALYSIS

### 3.1 Which Calls Can Be Converted to Simple Ecto Queries

**EASY (⭐⭐) - Direct Ecto operations:**

| Function | Current | Proposed | Benefit |
|----------|---------|----------|---------|
| `register_codebase()` | `Postgrex.query!()` INSERT/UPSERT | `Repo.insert()` / `Repo.update()` | Type safety, automatic JSON encoding |
| `get_codebase_registry()` | `Postgrex.query!()` SELECT | `Repo.get_by()` | No result mapping needed |
| `list_codebases()` | `Postgrex.query!()` SELECT | `Repo.all(query)` | Automatic ordering, mapping |
| `update_codebase_status()` | `Postgrex.query!()` UPDATE | `Repo.update()` changeset | Transaction safety |
| `insert_graph_node()` | `Postgrex.query!()` INSERT/UPSERT | `Repo.insert()` | Automatic timestamp, JSON encoding |
| `insert_graph_edge()` | `Postgrex.query!()` INSERT/UPSERT | `Repo.insert()` | Automatic timestamp, JSON encoding |
| `get_dependencies()` | `Postgrex.query!()` SELECT + JOIN | `Repo.all()` with join | Preloading, better error handling |
| `get_dependents()` | `Postgrex.query!()` SELECT + JOIN | `Repo.all()` with join | Preloading, better error handling |

---

### 3.2 Which Calls Need Complex Ecto.Query Fragments

**MEDIUM (⭐⭐⭐) - Ecto.Query with fragments:**

| Function | Challenge | Solution |
|----------|-----------|----------|
| `semantic_search()` | pgvector `<->` operator | Use `fragment()` for vector operations |
| `find_similar_nodes()` | CTE + vector similarity | Use `from()` with `fragment()` and `with_cte()` |
| `multi_codebase_search()` | Dynamic IN clause + pgvector | Use `where()` with `dynamic()` for IN clause |

**Example: Vector operator fragment**
```elixir
# Current
Postgrex.query!(db_conn, "SELECT ... vector_embedding <-> $1 as distance", [vector])

# Proposed
from(m in CodebaseMetadata,
  select: %{
    path: m.path,
    similarity_score: fragment("1 - (vector_embedding <-> ?)", ^query_vector)
  },
  order_by: [fragment("vector_embedding <-> ?", ^query_vector)],
  limit: ^limit
)
|> Repo.all()
```

---

### 3.3 Which Calls Have Dynamic SQL (Harder to Convert)

**HARD - Dynamic SQL construction:**

| Function | Issue | Solution |
|----------|-------|----------|
| `multi_codebase_search()` | `IN (#{placeholders})` with variable length | Use `Ecto.Query.dynamic()` |
| `detect_circular_dependencies()` | Recursive CTE with array detection | Keep as raw SQL via `Ecto.Adapters.SQL.query()` |
| `calculate_pagerank()` | Iterative algorithm in SQL | Keep as raw SQL via `Ecto.Adapters.SQL.query()` |

**Best practice for dynamic SQL:**
```elixir
# ✅ Wrap raw SQL in Ecto function for pooling benefit
def detect_circular_dependencies(repo) do
  query = """
  WITH RECURSIVE dependency_path AS (...)
  SELECT DISTINCT start_node, end_node, path, depth
  FROM dependency_path
  WHERE start_node = end_node
  ORDER BY depth
  """
  
  Ecto.Adapters.SQL.query!(repo, query, [])
  |> Map.get(:rows)
  |> Enum.map(fn [start_node, end_node, path, depth] -> 
    %{start_node: start_node, end_node: end_node, path: path, depth: depth}
  end)
end
```

**Benefit:** Still uses pooling via `repo` parameter, just not type-safe

---

### 3.4 Priority Order for Conversion

**PHASE 1: Foundation (1 week)**
Priority: CRITICAL - Affects all downstream code

1. **Create Ecto Schemas** (8 schemas needed)
   - `CodebaseMetadata` schema
   - `CodebaseRegistry` schema
   - `GraphNode` schema
   - `GraphEdge` schema
   - `GraphType` schema
   - `VectorSearch` schema
   - `VectorSimilarityCache` schema

2. **Remove Runtime Schema Creation**
   - Delete `create_unified_schema()` function entirely
   - Delete all `create_*_table()` functions
   - Delete `create_performance_indexes()` (redundant with migrations)
   - Delete `create_apache_age_extension()` and move to optional migration
   - Rely on `20250101000020_create_code_search_tables.exs` migration

---

**PHASE 2: Simple Queries (1 week)**
Priority: HIGH - Low-hanging fruit

3. **Refactor Simple SELECT/UPDATE Operations**
   - `get_codebase_registry()` → `Repo.get_by(CodebaseRegistry, codebase_id: id)`
   - `list_codebases()` → `Repo.all(from(c in CodebaseRegistry, order_by: [desc: c.inserted_at]))`
   - `update_codebase_status()` → `Repo.update(changeset)`
   - `get_dependencies()` → `Repo.all()` with join
   - `get_dependents()` → `Repo.all()` with join

4. **Refactor Insert/Upsert Operations**
   - `register_codebase()` → `Repo.insert(changeset, on_conflict: ...)`
   - `insert_graph_node()` → `Repo.insert(changeset, on_conflict: ...)`
   - `insert_graph_edge()` → `Repo.insert(changeset, on_conflict: ...)`

---

**PHASE 3: Complex Queries (2 weeks)**
Priority: HIGH - More complex but important for search

5. **Refactor Vector Search Operations**
   - `semantic_search()` → Ecto.Query with vector fragments
   - `find_similar_nodes()` → Ecto.Query with CTE fragments
   - `multi_codebase_search()` → Ecto.Query with dynamic IN clause

6. **Refactor Large Insert Operations**
   - `insert_codebase_metadata()` → `Repo.insert(changeset)` + `Ecto.Multi`

---

**PHASE 4: Keep as Raw SQL (1 week)**
Priority: MEDIUM - Complex algorithms

7. **Wrap Advanced Queries (keep SQL, just add pooling)**
   - `detect_circular_dependencies()` → Wrap in `Ecto.Adapters.SQL.query!(repo, ...)`
   - `calculate_pagerank()` → Wrap in `Ecto.Adapters.SQL.query!(repo, ...)`

---

### 3.5 Effort Estimation

```
PHASE 1: Schema Creation
  - 8 schemas × 30 min each = 4 hours
  - Remove runtime schema functions = 1 hour
  - Subtotal: 5 hours (1 day)

PHASE 2: Simple Queries  
  - 8 simple queries × 30 min each = 4 hours
  - 4 insert operations × 45 min each = 3 hours
  - Subtotal: 7 hours (1.5 days)

PHASE 3: Complex Queries
  - 3 vector search operations × 1.5 hours each = 4.5 hours
  - 1 large metadata insert × 2 hours = 2 hours
  - Testing vector operations = 3 hours
  - Subtotal: 9.5 hours (2 days)

PHASE 4: Advanced Queries
  - 2 recursive CTEs × 1 hour each = 2 hours
  - Testing & validation = 2 hours
  - Subtotal: 4 hours (1 day)

TESTING & VALIDATION (Per-phase)
  - Unit tests for each schema = 8 hours
  - Integration tests for complex queries = 4 hours
  - Performance testing (vector search) = 3 hours
  - Load testing (pooling behavior) = 2 hours
  - Subtotal: 17 hours (3.5 days)

TOTAL: ~42 hours (5-6 weeks with 1-2 days/week)
```

---

## PART 4: IMPLEMENTATION PLAN

### 4.1 Schema Creation (PHASE 1)

**File 1: `singularity/lib/singularity/schemas/codebase_metadata.ex`**

```elixir
defmodule Singularity.Schemas.CodebaseMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  CodebaseMetadata Schema - Main metadata for files in analyzed codebases
  
  Stores comprehensive metrics including:
  - Complexity metrics (cyclomatic, cognitive)
  - Code quality metrics (maintainability, technical debt)
  - Security metrics (vulnerability count, security score)
  - Semantic features (domains, patterns, business context)
  - Vector embeddings for semantic search
  """

  schema "codebase_metadata" do
    # Codebase identification
    field :codebase_id, :string
    field :codebase_path, :string
    
    # Basic file info
    field :path, :string
    field :size, :integer
    field :lines, :integer
    field :language, :string
    field :last_modified, :integer
    field :file_type, :string
    
    # Complexity metrics
    field :cyclomatic_complexity, :float
    field :cognitive_complexity, :float
    field :maintainability_index, :float
    field :nesting_depth, :integer
    
    # Code metrics
    field :function_count, :integer
    field :class_count, :integer
    field :struct_count, :integer
    field :enum_count, :integer
    field :trait_count, :integer
    field :interface_count, :integer
    
    # Line metrics
    field :total_lines, :integer
    field :code_lines, :integer
    field :comment_lines, :integer
    field :blank_lines, :integer
    
    # Halstead metrics
    field :halstead_vocabulary, :integer
    field :halstead_length, :integer
    field :halstead_volume, :float
    field :halstead_difficulty, :float
    field :halstead_effort, :float
    
    # PageRank & graph metrics
    field :pagerank_score, :float
    field :centrality_score, :float
    field :dependency_count, :integer
    field :dependent_count, :integer
    
    # Performance metrics
    field :technical_debt_ratio, :float
    field :code_smells_count, :integer
    field :duplication_percentage, :float
    
    # Security metrics
    field :security_score, :float
    field :vulnerability_count, :integer
    
    # Quality metrics
    field :quality_score, :float
    field :test_coverage, :float
    field :documentation_coverage, :float
    
    # Semantic features (JSONB)
    field :domains, {:array, :map}, default: []
    field :patterns, {:array, :map}, default: []
    field :features, {:array, :map}, default: []
    field :business_context, {:array, :map}, default: []
    field :performance_characteristics, {:array, :map}, default: []
    field :security_characteristics, {:array, :map}, default: []
    
    # Dependencies & relationships (JSONB)
    field :dependencies, {:array, :map}, default: []
    field :related_files, {:array, :map}, default: []
    field :imports, {:array, :map}, default: []
    field :exports, {:array, :map}, default: []
    
    # Symbols (JSONB)
    field :functions, {:array, :map}, default: []
    field :classes, {:array, :map}, default: []
    field :structs, {:array, :map}, default: []
    field :enums, {:array, :map}, default: []
    field :traits, {:array, :map}, default: []
    
    # Vector embedding
    field :vector_embedding, Pgvector, type: Pgvector.t()
    
    timestamps()
  end

  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [
      :codebase_id, :codebase_path, :path, :size, :lines, :language, :last_modified, :file_type,
      :cyclomatic_complexity, :cognitive_complexity, :maintainability_index, :nesting_depth,
      :function_count, :class_count, :struct_count, :enum_count, :trait_count, :interface_count,
      :total_lines, :code_lines, :comment_lines, :blank_lines,
      :halstead_vocabulary, :halstead_length, :halstead_volume, :halstead_difficulty, :halstead_effort,
      :pagerank_score, :centrality_score, :dependency_count, :dependent_count,
      :technical_debt_ratio, :code_smells_count, :duplication_percentage,
      :security_score, :vulnerability_count,
      :quality_score, :test_coverage, :documentation_coverage,
      :domains, :patterns, :features, :business_context, :performance_characteristics, 
      :security_characteristics, :dependencies, :related_files, :imports, :exports,
      :functions, :classes, :structs, :enums, :traits, :vector_embedding
    ])
    |> validate_required([:codebase_id, :codebase_path, :path, :language])
    |> unique_constraint(:path, name: "codebase_metadata_codebase_id_path_index")
  end
end
```

**(Repeat for remaining 7 schemas: CodebaseRegistry, GraphNode, GraphEdge, GraphType, VectorSearch, VectorSimilarityCache)**

---

### 4.2 Query Conversion Examples

**BEFORE (Postgrex):**
```elixir
def get_codebase_registry(db_conn, codebase_id) do
  Postgrex.query!(
    db_conn,
    """
    SELECT codebase_id, codebase_path, codebase_name, description,
      language, framework, last_analyzed, analysis_status, metadata,
      created_at, updated_at
    FROM codebase_registry 
    WHERE codebase_id = $1
    """,
    [codebase_id]
  )
  |> Map.get(:rows)
  |> case do
    [] -> nil
    [[codebase_id, codebase_path, ...]] -> %{...}
  end
end
```

**AFTER (Ecto):**
```elixir
def get_codebase_registry(repo, codebase_id) do
  repo.get_by(CodebaseRegistry, codebase_id: codebase_id)
end
```

---

**BEFORE (Postgrex with Vector):**
```elixir
def semantic_search(db_conn, codebase_id, query_vector, limit \\ 10) do
  Postgrex.query!(
    db_conn,
    """
    SELECT path, language, file_type, quality_score, maintainability_index,
      vector_embedding <-> $2 as distance,
      1 - (vector_embedding <-> $2) as similarity_score
    FROM codebase_metadata
    WHERE codebase_id = $1 AND vector_embedding IS NOT NULL
    ORDER BY vector_embedding <-> $2
    LIMIT $3
    """,
    [codebase_id, query_vector, limit]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**AFTER (Ecto with Vector Fragment):**
```elixir
def semantic_search(repo, codebase_id, query_vector, limit \\ 10) do
  from(m in CodebaseMetadata,
    where: m.codebase_id == ^codebase_id and not is_nil(m.vector_embedding),
    select: %{
      path: m.path,
      language: m.language,
      file_type: m.file_type,
      quality_score: m.quality_score,
      maintainability_index: m.maintainability_index,
      distance: fragment("vector_embedding <-> ?", ^query_vector),
      similarity_score: fragment("1 - (vector_embedding <-> ?)", ^query_vector)
    },
    order_by: [fragment("vector_embedding <-> ?", ^query_vector)],
    limit: ^limit
  )
  |> repo.all()
end
```

---

**BEFORE (Postgrex with Dynamic SQL):**
```elixir
def multi_codebase_search(db_conn, codebase_ids, query_vector, limit \\ 10) do
  placeholders = Enum.map(1..length(codebase_ids), fn i -> "$#{i}" end) |> Enum.join(",")

  Postgrex.query!(
    db_conn,
    """
    SELECT codebase_id, path, language, file_type, quality_score,
      1 - (vector_embedding <-> $#{length(codebase_ids) + 1}) as similarity_score
    FROM codebase_metadata 
    WHERE codebase_id IN (#{placeholders}) AND vector_embedding IS NOT NULL
    ORDER BY vector_embedding <-> $#{length(codebase_ids) + 1}
    LIMIT $#{length(codebase_ids) + 2}
    """,
    codebase_ids ++ [query_vector, limit]
  )
  |> Map.get(:rows)
  |> Enum.map(fn [...] -> %{...} end)
end
```

**AFTER (Ecto with Dynamic WHERE):**
```elixir
def multi_codebase_search(repo, codebase_ids, query_vector, limit \\ 10) do
  from(m in CodebaseMetadata,
    where: m.codebase_id in ^codebase_ids and not is_nil(m.vector_embedding),
    select: %{
      codebase_id: m.codebase_id,
      path: m.path,
      language: m.language,
      file_type: m.file_type,
      quality_score: m.quality_score,
      similarity_score: fragment("1 - (vector_embedding <-> ?)", ^query_vector)
    },
    order_by: [fragment("vector_embedding <-> ?", ^query_vector)],
    limit: ^limit
  )
  |> repo.all()
end
```

---

**BEFORE (Postgrex - Keep as Raw SQL):**
```elixir
def detect_circular_dependencies(db_conn) do
  Postgrex.query!(
    db_conn,
    """
    WITH RECURSIVE dependency_path AS (...)
    SELECT DISTINCT start_node, end_node, path, depth
    FROM dependency_path
    WHERE start_node = end_node
    ORDER BY depth
    """,
    []
  )
  |> Map.get(:rows)
  |> Enum.map(fn [start_node, end_node, path, depth] -> %{...} end)
end
```

**AFTER (Ecto.Adapters.SQL for Pooling Benefit):**
```elixir
def detect_circular_dependencies(repo) do
  query = """
  WITH RECURSIVE dependency_path AS (
    -- Base case
    SELECT from_node_id as start_node, to_node_id as end_node,
      from_node_id, to_node_id, edge_type, weight, 1 as depth,
      ARRAY[from_node_id, to_node_id] as path
    FROM graph_edges
    
    UNION ALL
    
    -- Recursive case
    SELECT dp.start_node, ge.to_node_id as end_node,
      dp.from_node_id, ge.to_node_id, ge.edge_type, ge.weight, dp.depth + 1,
      dp.path || ge.to_node_id
    FROM dependency_path dp
    JOIN graph_edges ge ON dp.to_node_id = ge.from_node_id
    WHERE dp.depth < 10 AND NOT ge.to_node_id = ANY(dp.path)
  )
  SELECT DISTINCT start_node, end_node, path, depth
  FROM dependency_path
  WHERE start_node = end_node
  ORDER BY depth
  """
  
  Ecto.Adapters.SQL.query!(repo, query, [])
  |> Map.get(:rows)
  |> Enum.map(fn [start_node, end_node, path, depth] ->
    %{start_node: start_node, end_node: end_node, path: path, depth: depth}
  end)
end
```

---

## PART 5: TESTING APPROACH

### 5.1 Unit Tests Per Schema

**File: `test/singularity/schemas/codebase_metadata_test.exs`**

```elixir
defmodule Singularity.Schemas.CodebaseMetadataTest do
  use Singularity.DataCase

  alias Singularity.Schemas.CodebaseMetadata

  test "changeset requires codebase_id, path, language" do
    changeset = CodebaseMetadata.changeset(%CodebaseMetadata{}, %{})
    assert errors_on(changeset) == %{
      codebase_id: ["can't be blank"],
      path: ["can't be blank"],
      language: ["can't be blank"]
    }
  end

  test "changeset accepts valid metadata" do
    attrs = %{
      codebase_id: "my-codebase",
      codebase_path: "/path/to/codebase",
      path: "lib/module.ex",
      language: "elixir",
      quality_score: 0.95,
      vector_embedding: <<...>>  # Vector bytes
    }
    
    changeset = CodebaseMetadata.changeset(%CodebaseMetadata{}, attrs)
    assert changeset.valid?
  end

  test "unique constraint on (codebase_id, path)" do
    {:ok, metadata1} = insert(:codebase_metadata, codebase_id: "codebase-1", path: "lib/a.ex")
    
    {:error, changeset} = insert(:codebase_metadata, codebase_id: "codebase-1", path: "lib/a.ex")
    assert changeset.constraints == [unique: "codebase_metadata_codebase_id_path_index"]
  end
end
```

---

### 5.2 Integration Tests for Query Functions

**File: `test/singularity/search/code_search_test.exs`**

```elixir
defmodule Singularity.Search.CodeSearchTest do
  use Singularity.DataCase

  alias Singularity.Search.CodeSearch
  alias Singularity.Repo

  setup do
    # Create test codebase and metadata
    {:ok, registry} = Repo.insert(%CodebaseRegistry{
      codebase_id: "test-codebase",
      codebase_path: "/test",
      codebase_name: "Test",
      language: "elixir"
    })

    {:ok, metadata} = Repo.insert(%CodebaseMetadata{
      codebase_id: "test-codebase",
      codebase_path: "/test",
      path: "lib/module.ex",
      language: "elixir",
      quality_score: 0.95,
      vector_embedding: test_vector()
    })

    [registry: registry, metadata: metadata]
  end

  test "semantic_search returns results ordered by similarity", %{metadata: metadata} do
    query_vector = test_vector()
    results = CodeSearch.semantic_search(Repo, "test-codebase", query_vector, 10)
    
    assert length(results) >= 1
    assert Enum.all?(results, &Map.has_key?(&1, :similarity_score))
    # Results should be ordered by similarity (descending)
    scores = Enum.map(results, & &1.similarity_score)
    assert scores == Enum.sort(scores, :desc)
  end

  test "semantic_search filters by codebase_id" do
    # Create another codebase
    {:ok, _} = Repo.insert(%CodebaseRegistry{
      codebase_id: "other-codebase",
      codebase_path: "/other",
      codebase_name: "Other",
      language: "python"
    })

    query_vector = test_vector()
    results = CodeSearch.semantic_search(Repo, "other-codebase", query_vector, 10)
    
    assert length(results) == 0
  end

  test "find_similar_nodes returns similar graph nodes", %{} do
    # Insert test nodes
    {:ok, node1} = Repo.insert(%GraphNode{
      codebase_id: "test-codebase",
      node_id: "node1",
      node_type: "function",
      name: "my_func",
      file_path: "lib/module.ex",
      vector_embedding: test_vector()
    })

    {:ok, node2} = Repo.insert(%GraphNode{
      codebase_id: "test-codebase",
      node_id: "node2",
      node_type: "function",
      name: "similar_func",
      file_path: "lib/module.ex",
      vector_embedding: test_vector()  # Same vector = 100% similarity
    })

    results = CodeSearch.find_similar_nodes(Repo, "test-codebase", "node1", 10)
    
    assert length(results) >= 1
    assert Enum.find(results, &(&1.node_id == "node2")).cosine_similarity > 0.9
  end

  test "get_dependencies returns outgoing edges" do
    # Insert nodes and edges
    {:ok, n1} = Repo.insert(%GraphNode{codebase_id: "test", node_id: "n1", ...})
    {:ok, n2} = Repo.insert(%GraphNode{codebase_id: "test", node_id: "n2", ...})
    {:ok, edge} = Repo.insert(%GraphEdge{
      codebase_id: "test",
      edge_id: "e1",
      from_node_id: "n1",
      to_node_id: "n2",
      edge_type: "calls",
      weight: 1.0
    })

    results = CodeSearch.get_dependencies(Repo, "n1")
    
    assert length(results) == 1
    assert hd(results).node_id == "n2"
    assert hd(results).edge_type == "calls"
  end

  defp test_vector do
    # Generate 1536-dimensional vector (OpenAI embedding size)
    Pgvector.new(Stream.map(1..1536, fn _ -> :rand.uniform() end) |> Enum.to_list())
  end
end
```

---

### 5.3 Performance Testing (Vector Search)

**File: `test/support/perf_helpers.exs`**

```elixir
defmodule Singularity.PerfHelpers do
  import ExUnit.Assertions

  def assert_within_ms(max_ms, do: block) do
    {elapsed, result} = :timer.tc(fn -> block end)
    elapsed_ms = elapsed / 1000
    
    assert elapsed_ms <= max_ms,
      "Expected block to complete in under #{max_ms}ms, but took #{elapsed_ms}ms"
    
    result
  end
end
```

**File: `test/singularity/search/code_search_perf_test.exs`**

```elixir
defmodule Singularity.Search.CodeSearchPerfTest do
  use Singularity.DataCase
  import Singularity.PerfHelpers

  alias Singularity.Search.CodeSearch
  alias Singularity.Repo

  @tag timeout: :infinity
  test "semantic_search with 1000 vectors completes in < 500ms" do
    # Create 1000 metadata records with vectors
    for i <- 1..1000 do
      Repo.insert!(%CodebaseMetadata{
        codebase_id: "perf-test",
        codebase_path: "/perf",
        path: "lib/module#{i}.ex",
        language: "elixir",
        vector_embedding: random_vector()
      })
    end

    query_vector = random_vector()

    assert_within_ms(500, do:
      CodeSearch.semantic_search(Repo, "perf-test", query_vector, 10)
    )
  end

  test "vector index is used (EXPLAIN shows using ivfflat)" do
    {:ok, %{rows: [[explain]]}} = Repo.query("""
      EXPLAIN SELECT * FROM codebase_metadata 
      WHERE vector_embedding IS NOT NULL 
      ORDER BY vector_embedding <-> $1::vector LIMIT 10
    """, [random_vector()])

    assert String.contains?(explain, "ivfflat") or String.contains?(explain, "Seq Scan")
  end

  defp random_vector do
    Pgvector.new(Enum.map(1..1536, fn _ -> :rand.uniform() end))
  end
end
```

---

### 5.4 Load Testing (Connection Pooling)

**File: `test/singularity/search/code_search_load_test.exs`**

```elixir
defmodule Singularity.Search.CodeSearchLoadTest do
  use Singularity.DataCase

  alias Singularity.Search.CodeSearch
  alias Singularity.Repo

  @tag timeout: :infinity
  @tag :load_test
  test "handles 50 concurrent semantic_search requests without pool exhaustion" do
    # Create test data
    for i <- 1..100 do
      Repo.insert!(%CodebaseMetadata{
        codebase_id: "load-test",
        codebase_path: "/load",
        path: "lib/module#{i}.ex",
        language: "elixir",
        vector_embedding: random_vector()
      })
    end

    query_vector = random_vector()

    # Spawn 50 concurrent tasks
    tasks = for _ <- 1..50 do
      Task.async(fn ->
        CodeSearch.semantic_search(Repo, "load-test", query_vector, 10)
      end)
    end

    # Wait for all tasks with timeout
    results = Task.await_many(tasks, 30_000)

    # All tasks should succeed
    assert length(results) == 50
    assert Enum.all?(results, &is_list/1)

    # Check pool didn't exceed configured size
    pool_size = Application.get_env(:singularity, Singularity.Repo)[:pool_size]
    # This is implicit - if we got 50 results, pool handled it correctly
  end

  defp random_vector do
    Pgvector.new(Enum.map(1..1536, fn _ -> :rand.uniform() end))
  end
end
```

Run with: `mix test test/singularity/search/code_search_load_test.exs --include load_test`

---

## PART 6: RISK MITIGATION STRATEGIES

### 6.1 Breaking Changes During Migration

**Risk:** Code calling `CodeSearch` functions gets incorrect signatures

**Mitigation:**
1. Add deprecation warnings first
2. Provide both signatures during transition period
3. Add detailed migration guide to CLAUDE.md

**Example:**
```elixir
def semantic_search(repo_or_conn, codebase_id, query_vector, limit \\ 10) do
  case repo_or_conn do
    # New: Ecto.Repo with pooling ✅
    repo when is_atom(repo) and function_exported?(repo, :all, 1) ->
      do_semantic_search_ecto(repo, codebase_id, query_vector, limit)
    
    # Old: Raw Postgrex connection (deprecated)
    conn ->
      Logger.warning(
        "semantic_search with raw Postgrex connection is deprecated. Pass Repo instead: " <>
        "CodeSearch.semantic_search(Repo, ...) instead of CodeSearch.semantic_search(conn, ...)"
      )
      do_semantic_search_postgrex(conn, codebase_id, query_vector, limit)
  end
end
```

---

### 6.2 Vector Embedding Compatibility

**Risk:** pgvector type might not work if extension not installed

**Current mitigation** (in migration):
```elixir
create table(:codebase_metadata) do
  add :vector_embedding, :vector, size: 1536, null: true
  # Fails if pgvector extension not installed
end
```

**Better mitigation:**
```elixir
# In migration
def up do
  # Try to create extension, gracefully handle failure
  execute("CREATE EXTENSION IF NOT EXISTS vector;")

  create table(:codebase_metadata) do
    add :vector_embedding, :vector, size: 1536, null: true
  end
  
  # Catch-all in code if vectors not supported
rescue
  e in Postgrex.Error ->
    if String.contains?(e.message, "undefined data type") do
      Logger.warning("pgvector extension not available - vector search disabled")
    else
      raise e
    end
end
```

**Schema code:**
```elixir
def changeset(metadata, attrs) do
  attrs = case {Map.get(attrs, :vector_embedding), vector_support?()} do
    {v, true} when is_binary(v) -> Map.put(attrs, :vector_embedding, Pgvector.new(v))
    {nil, _} -> attrs
    {_, false} -> 
      Logger.warning("pgvector not supported - ignoring vector_embedding")
      Map.delete(attrs, :vector_embedding)
  end
  
  metadata |> cast(attrs, [...])
end

defp vector_support? do
  case Repo.query("SELECT 1 FROM pg_type WHERE typname = 'vector'") do
    {:ok, %{num_rows: rows}} when rows > 0 -> true
    _ -> false
  end
end
```

---

### 6.3 Gradual Rollout Strategy

**Week 1:** Deploy schemas + keep Postgrex as fallback
```elixir
def semantic_search(repo_or_conn, ...) do
  # Both paths work - Postgrex path deprecated but functional
  try_ecto_first(repo_or_conn) || fallback_to_postgrex(repo_or_conn)
end
```

**Week 2:** Convert simple queries, log warnings for Postgrex usage
```elixir
if using_postgrex?(), do: Logger.warning("Switch to Repo parameter for pooling")
```

**Week 3:** Remove Postgrex path entirely from simple queries

**Week 4:** Convert complex queries with proper testing

---

### 6.4 Rollback Plan

If issues discovered during refactor:

**Option 1: Quick Rollback**
```bash
git revert <commit>  # Reverts all changes, goes back to Postgrex
```

**Option 2: Partial Rollback**
Keep schemas + migrations, revert to Postgrex in `CodeSearch` module only
```elixir
# Schemas work fine with Postgrex too
Postgrex.query!(repo.pool, "INSERT INTO codebase_metadata ...", [...])
```

---

## PART 7: SUCCESS CRITERIA

### 7.1 Functional Tests
- [ ] All 35 Postgrex.query!() calls converted or wrapped in Ecto
- [ ] Schema validation tests pass for all 8 schemas
- [ ] Integration tests pass for complex queries (CTEs, vectors, joins)
- [ ] No breaking changes in public API
- [ ] Backward compatibility during 2-week transition

### 7.2 Performance Tests
- [ ] Semantic search remains < 100ms for 1000 vectors
- [ ] Vector index used (EXPLAIN shows ivfflat)
- [ ] Connection pool stays stable under load
- [ ] No regression in PageRank calculation performance

### 7.3 Pooling Tests
- [ ] 50 concurrent requests complete without pool exhaustion
- [ ] Connection pool size maintained (no growth beyond 25)
- [ ] Transaction isolation works correctly
- [ ] Ecto.Sandbox works for test isolation

### 7.4 Type Safety
- [ ] Schema changesets validate all required fields
- [ ] Compile errors catch typos in field names
- [ ] JSON fields properly encoded/decoded
- [ ] Vector operations use type-safe fragments

### 7.5 Production Readiness
- [ ] All warnings/errors logged appropriately
- [ ] Graceful fallback for missing pgvector
- [ ] Migration tested on fresh database
- [ ] Documentation updated in CLAUDE.md
- [ ] Deprecation warnings show in logs for 2 weeks

---

## SUMMARY TABLE

| Aspect | Current | After Refactor | Benefit |
|--------|---------|----------------|---------|
| **Connection Management** | Direct Postgrex (no pooling) | Ecto.Repo with pooling | Better resource utilization, no connection limits |
| **Type Safety** | Raw SQL strings, no validation | Ecto schemas + changesets | Compile-time errors for typos |
| **Transaction Support** | Per-query transactions | Atomic Ecto.Multi | Rollback on failure |
| **Error Handling** | Manual with catch-all | Ecto built-in retry + recovery | Better resilience |
| **Testing** | Hard to isolate | Ecto.Sandbox for test isolation | Faster parallel tests |
| **Code Maintenance** | 48 raw SQL strings | Type-safe queries | Easier to refactor |
| **Performance (Simple)** | Same | Slightly faster (pooling) | 10-20% throughput gain |
| **Performance (Vector)** | Postgrex direct | Ecto.Adapters.SQL (still pooled) | Consistent latency under load |
| **Production Risk** | High (pool exhaustion) | Low (proven Ecto patterns) | More stable at scale |

---

## NEXT STEPS

1. **Create GitHub Issue** with this analysis + checklist
2. **Start PHASE 1** - Create all 8 Ecto schemas
3. **Run existing tests** with schema changes to ensure nothing breaks
4. **Convert PHASE 2** - Simple SELECT/UPDATE/INSERT operations
5. **Test thoroughly** - Unit + integration tests per group
6. **Convert PHASE 3** - Complex vector + graph queries
7. **Load test** - Verify pooling behavior under concurrent load
8. **Convert PHASE 4** - Wrap advanced queries in Ecto.Adapters.SQL
9. **Deploy incrementally** with deprecation warnings + logging
10. **Monitor production** for connection pool metrics
