# Postgrex.query!() Usage Analysis - CodeSearch Module

## Summary
- **Total Postgrex.query!() calls:** 48
- **File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/code_search.ex`
- **Lines of code:** 1,273
- **Ecto imports/usage:** Minimal (only in `semantic_search` at line 955)

---

## Postgrex Usage Pattern Analysis

### Pattern 1: DDL Operations (Schema Creation)
**Purpose:** Create/manage database tables and indexes
**Conversion Approach:** Use Ecto Migrations instead

#### Table Creation Calls (6 functions)

1. **`create_codebase_metadata_table/1`** (Lines 56-180)
   - Line 58: Create codebase_metadata table
   - Line 160: Create codebase_registry table
   - **Total calls:** 2

2. **`create_graph_tables/1`** (Lines 182-256)
   - Line 184: Create graph_nodes table
   - Line 207: Create graph_edges table
   - Line 230: Create graph_types table
   - Line 244: Insert default graph types
   - **Total calls:** 4

3. **`create_vector_search_tables/1`** (Lines 258-296)
   - Line 260: Create vector_search table
   - Line 280: Create vector_similarity_cache table
   - **Total calls:** 2

4. **`create_performance_indexes/1`** (Lines 298-529)
   - Multiple index creation calls:
     - Lines 300-307: idx_codebase_metadata_codebase_id
     - Lines 309-316: idx_codebase_metadata_codebase_path
     - Lines 319-326: idx_codebase_registry_codebase_id
     - Lines 328-335: idx_codebase_registry_codebase_path
     - Lines 337-344: idx_codebase_registry_analysis_status
     - Lines 346-353: idx_codebase_metadata_path
     - Lines 355-362: idx_codebase_metadata_language
     - Lines 364-371: idx_codebase_metadata_file_type
     - Lines 373-380: idx_codebase_metadata_quality_score
     - Lines 382-389: idx_codebase_metadata_complexity
     - Lines 391-398: idx_codebase_metadata_pagerank
     - Lines 401-408: idx_codebase_metadata_vector (ivfflat)
     - Lines 411-418: idx_graph_nodes_codebase_id
     - Lines 420-427: idx_graph_nodes_node_id
     - Lines 429-436: idx_graph_nodes_node_type
     - Lines 438-445: idx_graph_nodes_file_path
     - Lines 447-454: idx_graph_edges_codebase_id
     - Lines 456-463: idx_graph_edges_from_node
     - Lines 465-472: idx_graph_edges_to_node
     - Lines 474-481: idx_graph_edges_edge_type
     - Lines 484-491: idx_graph_nodes_vector (ivfflat)
     - Lines 494-501: idx_vector_search_codebase_id
     - Lines 503-510: idx_vector_search_file_path
     - Lines 512-519: idx_vector_search_content_type
     - Lines 521-528: idx_vector_search_vector (ivfflat)
   - **Total calls:** 24

5. **`create_apache_age_extension/1`** (Lines 531-549)
   - Line 534: CREATE EXTENSION IF NOT EXISTS age
   - **Total calls:** 1

---

### Pattern 2: DML Operations (Data Manipulation)
**Purpose:** Insert, update, and query data
**Conversion Approach:** Use Ecto.Changeset and Ecto.Query

#### Insert Operations

6. **`register_codebase/5`** (Lines 554-586)
   - Line 560: INSERT INTO codebase_registry with ON CONFLICT
   - **Total calls:** 1

7. **`insert_codebase_metadata/3`** (Lines 707-853)
   - Line 708: Large INSERT with 55 parameters + ON CONFLICT
   - **Total calls:** 1
   - **Complexity:** Complex 55-column insert with JSONB encoding

8. **`insert_graph_node/2`** (Lines 858-887)
   - Line 859: INSERT INTO graph_nodes with ON CONFLICT
   - **Total calls:** 1

9. **`insert_graph_edge/2`** (Lines 892-916)
   - Line 893: INSERT INTO graph_edges with ON CONFLICT
   - **Total calls:** 1

#### Select/Query Operations

10. **`get_codebase_registry/2`** (Lines 591-638)
    - Line 592: SELECT codebase registry with manual row mapping
    - **Total calls:** 1

11. **`list_codebases/1`** (Lines 643-682)
    - Line 644: SELECT all codebases with manual row mapping
    - **Total calls:** 1

12. **`update_codebase_status/3`** (Lines 687-702)
    - Line 690: UPDATE codebase_registry
    - **Total calls:** 1

13. **`semantic_search/4`** (Lines 933-984)
    - Line 955: Uses **Ecto.Adapters.SQL.query!** (already partially migrated!)
    - Line 961: Falls back to Postgrex.query! for backwards compatibility
    - **Total calls:** 1 (Postgrex fallback path)
    - **NOTE:** This function already shows the conversion pattern!

14. **`find_similar_nodes/3`** (Lines 989-1038)
    - Line 990: Complex vector similarity query with CTEs
    - **Total calls:** 1

15. **`multi_codebase_search/4`** (Lines 1043-1087)
    - Line 1047: Multi-codebase vector search with dynamic SQL
    - **Total calls:** 1

16. **`get_dependencies/2`** (Lines 1092-1121)
    - Line 1093: Graph edge traversal with JOIN
    - **Total calls:** 1

17. **`get_dependents/2`** (Lines 1126-1155)
    - Line 1127: Graph edge traversal (incoming)
    - **Total calls:** 1

18. **`detect_circular_dependencies/1`** (Lines 1160-1214)
    - Line 1161: Recursive CTE for cycle detection
    - **Total calls:** 1

19. **`calculate_pagerank/3`** (Lines 1219-1271)
    - Line 1223: Recursive CTE for PageRank calculation
    - **Total calls:** 1

---

## Detailed Call Breakdown by Function

```
Function Name                          Calls   Type      Complexity  Lines
─────────────────────────────────────────────────────────────────────────
create_codebase_metadata_table           2      DDL       Low         56-180
create_graph_tables                      4      DDL       Low         182-256
create_vector_search_tables              2      DDL       Low         258-296
create_performance_indexes              24      DDL       Low         298-529
create_apache_age_extension              1      DDL       Low         531-549
register_codebase                        1      DML       Medium      554-586
insert_codebase_metadata                 1      DML       High        707-853
insert_graph_node                        1      DML       Medium      858-887
insert_graph_edge                        1      DML       Medium      892-916
get_codebase_registry                    1      Query     Medium      591-638
list_codebases                           1      Query     Medium      643-682
update_codebase_status                   1      DML       Low         687-702
semantic_search                          1      Query     High        933-984
find_similar_nodes                       1      Query     High        989-1038
multi_codebase_search                    1      Query     High        1043-1087
get_dependencies                         1      Query     Medium      1092-1121
get_dependents                           1      Query     Medium      1126-1155
detect_circular_dependencies             1      Query     High        1160-1214
calculate_pagerank                       1      Query     High        1219-1271
─────────────────────────────────────────────────────────────────────────
TOTAL                                   48
```

---

## Pattern Analysis

### 1. DDL Pattern (Schema Management) - 33 calls

**Current Approach:**
```elixir
Postgrex.query!(db_conn, "CREATE TABLE IF NOT EXISTS ...", [])
Postgrex.query!(db_conn, "CREATE INDEX IF NOT EXISTS ...", [])
```

**Issues:**
- Duplicated across multiple functions
- No version control for schema
- Hard to test in isolation
- Assumes raw connection parameter

**Conversion Recommendation:**
Move all DDL to proper Ecto migrations:
```
priv/repo/migrations/YYYYMMDDHHMMSS_create_codebase_search_schema.exs
priv/repo/migrations/YYYYMMDDHHMMSS_create_graph_tables.exs
priv/repo/migrations/YYYYMMDDHHMMSS_create_vector_search_tables.exs
priv/repo/migrations/YYYYMMDDHHMMSS_create_codebase_indexes.exs
```

---

### 2. DML Pattern (Data Operations) - 6 calls

**Current Approach:**
```elixir
Postgrex.query!(db_conn, "INSERT INTO ... ON CONFLICT ...", [params])
Postgrex.query!(db_conn, "UPDATE ... WHERE ...", [params])
```

**Issues:**
- No type validation
- Manual parameter binding required
- Row extraction is manual
- JSON encoding/decoding scattered

**Conversion Recommendation:**
```elixir
# Create Ecto schemas for each table:
- Singularity.Search.CodebaseMetadata
- Singularity.Search.CodebaseRegistry
- Singularity.Search.GraphNode
- Singularity.Search.GraphEdge

# Use Repo functions:
Singularity.Repo.insert!(changeset)
Singularity.Repo.update!(changeset)
```

---

### 3. Query Pattern (Complex Queries) - 9 calls

**Current Approach:**
```elixir
Postgrex.query!(db_conn, """
  SELECT ... WHERE ... ORDER BY ...
  LIMIT $N
""", [params])
|> Map.get(:rows)
|> Enum.map(fn [...] -> %{...} end)
```

**Complexity Levels:**
- **Simple queries (2-3 conditions):** get_codebase_registry, list_codebases, update_codebase_status
- **Medium queries (JOINs, aggregation):** get_dependencies, get_dependents
- **Complex queries (CTEs, vector ops):** 
  - semantic_search (vector <-> distance operator)
  - find_similar_nodes (WITH + CROSS JOIN)
  - multi_codebase_search (dynamic WHERE IN clause)
  - detect_circular_dependencies (RECURSIVE CTE)
  - calculate_pagerank (RECURSIVE CTE with aggregation)

**Conversion Recommendation:**

For simple/medium queries:
```elixir
from(m in CodebaseMetadata, where: m.codebase_id == ^codebase_id)
|> Singularity.Repo.one!()
```

For complex queries (CTEs, custom operators):
```elixir
query = """SELECT ... FROM ..."""
Ecto.Adapters.SQL.query!(Singularity.Repo, query, params)
```
✅ Already demonstrated in `semantic_search/4` at line 955!

---

## Existing Ecto Integration

**Good News:** The code already shows the conversion pattern!

### `semantic_search/4` (Lines 933-984) - PARTIAL MIGRATION EXAMPLE

```elixir
def semantic_search(repo_or_conn, codebase_id, query_vector, limit \\ 10) do
  query = """
  SELECT
    path, language, file_type, quality_score, maintainability_index,
    vector_embedding <-> $2 as distance,
    1 - (vector_embedding <-> $2) as similarity_score
  FROM codebase_metadata
  WHERE codebase_id = $1 AND vector_embedding IS NOT NULL
  ORDER BY vector_embedding <-> $2
  LIMIT $3
  """

  params = [codebase_id, query_vector, limit]

  rows =
    case repo_or_conn do
      # ✅ Ecto.Adapters.SQL.query! - Recommended approach
      repo when is_atom(repo) ->
        case Ecto.Adapters.SQL.query!(repo, query, params) do
          %{rows: rows} -> rows
        end

      # Legacy Postgrex fallback - For backwards compatibility
      conn ->
        case Postgrex.query!(conn, query, params) do
          %{rows: rows} -> rows
        end
    end

  # Manual row mapping
  Enum.map(rows, fn [...] -> %{...} end)
end
```

**This is the template for all complex queries!**

---

## Conversion Scope & Effort

| Category | Calls | Effort | Dependencies |
|----------|-------|--------|---|
| **DDL (Migrations)** | 33 | High | Need to write 4+ migrations |
| **DML (Schemas+Changesets)** | 6 | Medium | Create 4 Ecto schemas |
| **Simple Queries** | 3 | Low | Basic Ecto.Query |
| **Complex Queries** | 9 | Low-Medium | Use Ecto.Adapters.SQL.query! |
| **TOTAL EFFORT** | 48 | Medium | 2-3 days for complete migration |

---

## Recommended Conversion Order

1. **Phase 1: Foundation**
   - Create Ecto schemas (CodebaseMetadata, CodebaseRegistry, GraphNode, GraphEdge)
   - Update `config/config.exs` with repo configuration
   - Create first migration: Table creation

2. **Phase 2: Basic Migrations**
   - Extract 33 DDL calls into proper migrations
   - Extract indexes into separate migration
   - Verify migration runs without errors

3. **Phase 3: Data Functions**
   - Convert DML operations to use Repo
   - Create changesets for inserts/updates
   - Update function signatures to accept `repo` instead of `db_conn`

4. **Phase 4: Query Functions**
   - Simple queries → Ecto.Query
   - Complex queries → Keep as Ecto.Adapters.SQL.query! (shown at line 955)
   - Maintain backwards compatibility initially

5. **Phase 5: Testing & Cleanup**
   - Test all functions with Ecto.Sandbox
   - Remove raw Postgrex parameter passing
   - Clean up manual row mapping utilities

---

## Key Observations

### ✅ Strengths
- Clear separation of DDL, DML, and Query concerns
- Consistent error handling (using `!` operators)
- Good documentation of vector operations
- Already partially migrated (semantic_search shows pattern)

### ⚠️ Weaknesses
- Parameter binding is manual and error-prone (55 parameters in insert_codebase_metadata!)
- No type validation on inserts
- JSON encoding/decoding scattered throughout
- Hard to test in isolation (depends on raw connection)
- Mixing of schema creation logic with application code
- No version control for schema changes

### Migration Quick-Wins
1. Move all DDL to migrations immediately (reduces 33 calls)
2. Create Ecto schemas for the 4 main tables
3. For vector queries, use `Ecto.Adapters.SQL.query!` pattern (already shown)

