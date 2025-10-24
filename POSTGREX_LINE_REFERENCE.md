# Postgrex.query!() Line-by-Line Reference

## Quick Line Number Index

| Line | Function | Operation | Type |
|------|----------|-----------|------|
| 58 | create_codebase_metadata_table | CREATE TABLE codebase_metadata | DDL |
| 160 | create_codebase_metadata_table | CREATE TABLE codebase_registry | DDL |
| 184 | create_graph_tables | CREATE TABLE graph_nodes | DDL |
| 207 | create_graph_tables | CREATE TABLE graph_edges | DDL |
| 230 | create_graph_tables | CREATE TABLE graph_types | DDL |
| 244 | create_graph_tables | INSERT INTO graph_types (defaults) | DML |
| 260 | create_vector_search_tables | CREATE TABLE vector_search | DDL |
| 280 | create_vector_search_tables | CREATE TABLE vector_similarity_cache | DDL |
| 300 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_codebase_id | DDL |
| 309 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_codebase_path | DDL |
| 319 | create_performance_indexes | CREATE INDEX idx_codebase_registry_codebase_id | DDL |
| 328 | create_performance_indexes | CREATE INDEX idx_codebase_registry_codebase_path | DDL |
| 337 | create_performance_indexes | CREATE INDEX idx_codebase_registry_analysis_status | DDL |
| 346 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_path | DDL |
| 355 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_language | DDL |
| 364 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_file_type | DDL |
| 373 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_quality_score | DDL |
| 382 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_complexity | DDL |
| 391 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_pagerank | DDL |
| 401 | create_performance_indexes | CREATE INDEX idx_codebase_metadata_vector (ivfflat) | DDL |
| 411 | create_performance_indexes | CREATE INDEX idx_graph_nodes_codebase_id | DDL |
| 420 | create_performance_indexes | CREATE INDEX idx_graph_nodes_node_id | DDL |
| 429 | create_performance_indexes | CREATE INDEX idx_graph_nodes_node_type | DDL |
| 438 | create_performance_indexes | CREATE INDEX idx_graph_nodes_file_path | DDL |
| 447 | create_performance_indexes | CREATE INDEX idx_graph_edges_codebase_id | DDL |
| 456 | create_performance_indexes | CREATE INDEX idx_graph_edges_from_node | DDL |
| 465 | create_performance_indexes | CREATE INDEX idx_graph_edges_to_node | DDL |
| 474 | create_performance_indexes | CREATE INDEX idx_graph_edges_edge_type | DDL |
| 484 | create_performance_indexes | CREATE INDEX idx_graph_nodes_vector (ivfflat) | DDL |
| 494 | create_performance_indexes | CREATE INDEX idx_vector_search_codebase_id | DDL |
| 503 | create_performance_indexes | CREATE INDEX idx_vector_search_file_path | DDL |
| 512 | create_performance_indexes | CREATE INDEX idx_vector_search_content_type | DDL |
| 521 | create_performance_indexes | CREATE INDEX idx_vector_search_vector (ivfflat) | DDL |
| 534 | create_apache_age_extension | CREATE EXTENSION age | DDL |
| 560 | register_codebase | INSERT INTO codebase_registry + ON CONFLICT | DML |
| 592 | get_codebase_registry | SELECT codebase_registry | Query |
| 644 | list_codebases | SELECT * FROM codebase_registry | Query |
| 690 | update_codebase_status | UPDATE codebase_registry | DML |
| 708 | insert_codebase_metadata | INSERT INTO codebase_metadata + ON CONFLICT | DML |
| 859 | insert_graph_node | INSERT INTO graph_nodes + ON CONFLICT | DML |
| 893 | insert_graph_edge | INSERT INTO graph_edges + ON CONFLICT | DML |
| 955 | semantic_search | Ecto.Adapters.SQL.query! (NOT Postgrex) | Query |
| 961 | semantic_search | SELECT with vector <-> operator | Query |
| 990 | find_similar_nodes | SELECT with CTE + CROSS JOIN | Query |
| 1047 | multi_codebase_search | SELECT with dynamic IN clause | Query |
| 1093 | get_dependencies | SELECT with JOIN | Query |
| 1127 | get_dependents | SELECT with JOIN | Query |
| 1161 | detect_circular_dependencies | SELECT with RECURSIVE CTE | Query |
| 1223 | calculate_pagerank | SELECT with RECURSIVE CTE | Query |

---

## Grouped by Operation Type

### DDL Operations (Schema/Index Creation) - 33 Calls

**Table Creation (8 calls):**
- Line 58: codebase_metadata (99 columns)
- Line 160: codebase_registry (10 columns)
- Line 184: graph_nodes (9 columns)
- Line 207: graph_edges (7 columns + 2 FKs)
- Line 230: graph_types (3 columns)
- Line 260: vector_search (6 columns)
- Line 280: vector_similarity_cache (5 columns)
- Line 534: Apache AGE extension

**Index Creation (25 calls):**
- codebase_metadata indexes: lines 300, 309, 346, 355, 364, 373, 382, 391, 401 (9 indexes)
- codebase_registry indexes: lines 319, 328, 337 (3 indexes)
- graph_nodes indexes: lines 411, 420, 429, 438, 484 (5 indexes)
- graph_edges indexes: lines 447, 456, 465, 474 (4 indexes)
- vector_search indexes: lines 494, 503, 512, 521 (4 indexes)

### DML Operations (Data Manipulation) - 6 Calls

| Line | Function | Operation | Parameters | Complexity |
|------|----------|-----------|------------|------------|
| 560 | register_codebase | INSERT ON CONFLICT | 7 params | Medium |
| 708 | insert_codebase_metadata | INSERT ON CONFLICT | 55 params | **HIGH** |
| 859 | insert_graph_node | INSERT ON CONFLICT | 9 params | Medium |
| 893 | insert_graph_edge | INSERT ON CONFLICT | 7 params | Medium |
| 690 | update_codebase_status | UPDATE WHERE | 3 params | Low |
| 244 | create_graph_tables | INSERT (defaults) | 0 params | Low |

### Query Operations (Data Retrieval) - 9 Calls

| Line | Function | SQL Type | Complexity | Parameters |
|------|----------|----------|------------|------------|
| 592 | get_codebase_registry | SELECT WHERE | Medium | 1 |
| 644 | list_codebases | SELECT ORDER BY | Low-Medium | 0 |
| 961 | semantic_search | SELECT with <-> | **HIGH** | 3 |
| 990 | find_similar_nodes | WITH + CROSS JOIN | **HIGH** | 3 |
| 1047 | multi_codebase_search | SELECT with IN | Medium | N+2 |
| 1093 | get_dependencies | SELECT with JOIN | Medium | 1 |
| 1127 | get_dependents | SELECT with JOIN | Medium | 1 |
| 1161 | detect_circular_dependencies | RECURSIVE CTE | **HIGH** | 0 |
| 1223 | calculate_pagerank | RECURSIVE CTE | **HIGH** | 2 |

---

## Migration Grouping Suggestion

### Migration 1: Core Schema (Lines 58-280)
- codebase_metadata table (line 58)
- codebase_registry table (line 160)
- graph_nodes table (line 184)
- graph_edges table (line 207)
- graph_types table + initial data (lines 230, 244)
- vector_search table (line 260)
- vector_similarity_cache table (line 280)

**Rationale:** Core tables that everything depends on

### Migration 2: Performance Indexes (Lines 300-528)
- All 25 index creation statements
- Separate because indexes can be added incrementally

**Rationale:** Can be added after tables are populated

### Migration 3: Apache AGE (Line 534)
- CREATE EXTENSION age

**Rationale:** Optional, can fail gracefully

---

## Ecto Schema Generation Plan

### Schema 1: CodebaseMetadata (Line 58 table)
```elixir
defmodule Singularity.Search.CodebaseMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  schema "codebase_metadata" do
    field :codebase_id, :string
    field :codebase_path, :string
    field :path, :string
    field :size, :integer
    field :lines, :integer
    # ... 95+ more fields
    field :vector_embedding, :map  # or custom type for pgvector
    
    timestamps()
  end

  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [...all fields...])
    |> validate_required([:codebase_id, :path])
    |> unique_constraint([:codebase_id, :path])
  end
end
```

### Schema 2: CodebaseRegistry (Line 160 table)
```elixir
defmodule Singularity.Search.CodebaseRegistry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "codebase_registry" do
    field :codebase_id, :string
    field :codebase_path, :string
    field :codebase_name, :string
    field :description, :string
    field :language, :string
    field :framework, :string
    field :last_analyzed, :utc_datetime
    field :analysis_status, :string
    field :metadata, :map
    
    timestamps()
  end

  def changeset(registry, attrs) do
    registry
    |> cast(attrs, [...all fields...])
    |> validate_required([:codebase_id, :codebase_path, :codebase_name])
    |> unique_constraint(:codebase_id)
  end
end
```

### Schema 3: GraphNode (Line 184 table)
```elixir
defmodule Singularity.Search.GraphNode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "graph_nodes" do
    field :codebase_id, :string
    field :node_id, :string
    field :node_type, :string
    field :name, :string
    field :file_path, :string
    field :line_number, :integer
    field :vector_embedding, :map
    field :vector_magnitude, :float
    field :metadata, :map
    
    timestamps(updated_at: false)
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [...all fields...])
    |> validate_required([:codebase_id, :node_id, :node_type, :name, :file_path])
    |> unique_constraint([:codebase_id, :node_id])
  end
end
```

### Schema 4: GraphEdge (Line 207 table)
```elixir
defmodule Singularity.Search.GraphEdge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "graph_edges" do
    field :codebase_id, :string
    field :edge_id, :string
    field :from_node_id, :string
    field :to_node_id, :string
    field :edge_type, :string
    field :weight, :float
    field :metadata, :map
    
    timestamps(updated_at: false)
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [...all fields...])
    |> validate_required([:codebase_id, :edge_id, :from_node_id, :to_node_id, :edge_type])
    |> unique_constraint([:codebase_id, :edge_id])
  end
end
```

---

## Conversion Examples

### Example 1: Simple Insert (Line 560)

**Before (Postgrex):**
```elixir
def register_codebase(db_conn, codebase_id, codebase_path, codebase_name, opts \\ []) do
  description = Keyword.get(opts, :description, "")
  language = Keyword.get(opts, :language, "unknown")
  framework = Keyword.get(opts, :framework, "unknown")
  metadata = Keyword.get(opts, :metadata, %{})

  Postgrex.query!(
    db_conn,
    """
    INSERT INTO codebase_registry (
      codebase_id, codebase_path, codebase_name, description, 
      language, framework, metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (codebase_id) DO UPDATE SET
      codebase_path = EXCLUDED.codebase_path,
      codebase_name = EXCLUDED.codebase_name,
      description = EXCLUDED.description,
      language = EXCLUDED.language,
      framework = EXCLUDED.framework,
      metadata = EXCLUDED.metadata,
      updated_at = NOW()
    """,
    [
      codebase_id,
      codebase_path,
      codebase_name,
      description,
      language,
      framework,
      Jason.encode!(metadata)
    ]
  )
end
```

**After (Ecto):**
```elixir
def register_codebase(repo, codebase_id, codebase_path, codebase_name, opts \\ []) do
  attrs = %{
    codebase_id: codebase_id,
    codebase_path: codebase_path,
    codebase_name: codebase_name,
    description: Keyword.get(opts, :description, ""),
    language: Keyword.get(opts, :language, "unknown"),
    framework: Keyword.get(opts, :framework, "unknown"),
    metadata: Keyword.get(opts, :metadata, %{})
  }

  Singularity.Search.CodebaseRegistry
  |> repo.get_by(codebase_id: codebase_id)
  |> case do
    nil -> Singularity.Search.CodebaseRegistry.new()
    existing -> existing
  end
  |> Singularity.Search.CodebaseRegistry.changeset(attrs)
  |> repo.insert_or_update!()
end
```

### Example 2: Complex Insert (Line 708)

**Before (Postgrex):**
55 parameters! (too large to show in full, see lines 708-852)

**After (Ecto):**
```elixir
def insert_codebase_metadata(repo, codebase_id, codebase_path, metadata) do
  attrs = metadata
  |> Map.put(:codebase_id, codebase_id)
  |> Map.put(:codebase_path, codebase_path)

  Singularity.Search.CodebaseMetadata
  |> repo.get_by(codebase_id: codebase_id, path: metadata.path)
  |> case do
    nil -> Singularity.Search.CodebaseMetadata.new()
    existing -> existing
  end
  |> Singularity.Search.CodebaseMetadata.changeset(attrs)
  |> repo.insert_or_update!()
end
```

### Example 3: Complex Query (Line 961)

**Before (Postgrex):**
```elixir
Postgrex.query!(conn, query, params)
|> Map.get(:rows)
|> Enum.map(fn [...] -> %{...} end)
```

**After (Ecto - Already Shown at Line 955!):**
```elixir
case Ecto.Adapters.SQL.query!(repo, query, params) do
  %{rows: rows} -> rows
end
|> Enum.map(fn [...] -> %{...} end)
```

---

## Key Conversion Decisions

1. **Function Signatures:** Change from `def func(db_conn, ...)` to `def func(repo, ...)`
   - Advantage: Uses connection pooling automatically
   - Advantage: Works with Ecto.Sandbox for testing

2. **Complex Queries:** Keep as `Ecto.Adapters.SQL.query!` for:
   - Vector operations (<-> operator)
   - CTEs (RECURSIVE)
   - Custom PostgreSQL features
   - See: semantic_search/4 at line 955 for example

3. **Error Handling:** Use `!` versions (insert!, update!, one!) for:
   - Consistency with current approach
   - Clear failure semantics
   - Can be wrapped in try/catch if needed

4. **JSON Handling:** Let Ecto handle JSON encoding/decoding automatically:
   - `:map` field type with `json` database type
   - Or custom `Jason` module if needed

