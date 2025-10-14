# Graph Setup Guide - PostgreSQL Code Graphs

**Status:** ✅ Complete - Ready to use!

---

## What Was Built

A complete **PostgreSQL-based code graph system** that extracts and stores:
- **Call graphs** (who calls whom at function level)
- **Import graphs** (module dependencies)
- **Rich metadata** (line numbers, file paths, weights)

**No Apache AGE needed!** Uses standard PostgreSQL with optimized SQL queries.

---

## Quick Start

### 1. Ingest Code (Extract Metadata)
```bash
cd singularity_app

# This already runs on server startup via HTDAGAutoBootstrap
# But you can manually re-run if needed:
iex -S mix
iex> Singularity.Execution.Planning.HTDAGAutoBootstrap.run()
```

**What it does:**
- Scans all `.ex` files in `lib/`
- Parses with Rust NIF (tree-sitter)
- Extracts enhanced metadata (dependencies, call graph, types, docs)
- Stores in `code_files.metadata` JSONB field

### 2. Populate Graph Tables
```bash
# Populate both call graph and import graph
mix graph.populate

# Or rebuild from scratch
mix graph.populate --rebuild

# Or populate only one graph
mix graph.populate --only call
mix graph.populate --only import
```

**What it does:**
- Reads `code_files.metadata`
- Creates `graph_nodes` (functions, modules)
- Creates `graph_edges` (calls, imports)
- Uses UPSERT for idempotency

**Expected output:**
```
Populating all graphs for singularity...
✓ Call graph: 450 function nodes, 1200 call edges
✓ Import graph: 288 module nodes, 850 import edges
✓ Graph population complete!

Statistics:
  Nodes created: 738
  Edges created: 2050
```

### 3. Query the Graph
```elixir
iex -S mix
iex> alias Singularity.Graph.GraphQueries

# Find who calls a function
iex> GraphQueries.find_callers("persist_module_to_db/2")
[
  %{name: "persist_learned_codebase/1", file_path: "lib/singularity/execution/planning/htdag_auto_bootstrap.ex", line: 486}
]

# Find what a function calls
iex> GraphQueries.find_callees("persist_module_to_db/2")
[
  %{name: "CodeEngine.parse_file/1", file_path: "...", line: 527},
  %{name: "AstExtractor.extract_metadata/2", file_path: "...", line: 530}
]

# Find module dependencies
iex> GraphQueries.find_dependencies("Singularity.Manager")
[
  %{name: "Singularity.Repo", dependency_type: "internal", weight: 1.0},
  %{name: "Ecto.Query", dependency_type: "external", weight: 0.5}
]

# Find circular dependencies
iex> GraphQueries.find_circular_dependencies()
{:ok, [
  ["Singularity.Foo", "Singularity.Bar", "Singularity.Foo"]
]}

# Get statistics
iex> GraphQueries.stats()
%{
  nodes: %{total: 738, by_type: %{"function" => 450, "module" => 288}},
  edges: %{total: 2050, by_type: %{"calls" => 1200, "imports" => 850}}
}

# Find most called functions
iex> GraphQueries.most_called_functions(5)
[
  %{name: "Repo.insert/2", file_path: "...", caller_count: 45},
  %{name: "Logger.info/1", file_path: "...", caller_count: 38}
]

# Find most complex functions (call many others)
iex> GraphQueries.most_complex_functions(5)
[
  %{name: "persist_module_to_db/2", file_path: "...", callee_count: 15},
  %{name: "populate_all/1", file_path: "...", callee_count: 12}
]
```

---

## Architecture

### Data Flow
```
1. Code Ingestion (HTDAGAutoBootstrap)
   ↓
   CodeEngine NIF (Rust + tree-sitter)
   ↓
   Enhanced metadata extraction (AstExtractor)
   ↓
   Store in code_files.metadata (JSONB)

2. Graph Population (mix graph.populate)
   ↓
   Read code_files.metadata
   ↓
   Extract dependencies + call_graph
   ↓
   Create graph_nodes + graph_edges
   ↓
   Store in PostgreSQL tables

3. Query Graphs (GraphQueries)
   ↓
   SQL queries (JOINs + recursive CTEs)
   ↓
   Return results
```

### Database Schema

#### code_files (Source Data)
```sql
CREATE TABLE code_files (
  id UUID PRIMARY KEY,
  project_name VARCHAR,
  file_path VARCHAR,
  metadata JSONB DEFAULT '{}',  -- ✅ Enhanced metadata here
  ...
);

-- metadata structure:
{
  "ast_json": "...",
  "symbols": [...],
  "imports": [...],
  "exports": [...],
  "dependencies": {           -- ✅ From AstExtractor
    "internal": ["Singularity.Foo"],
    "external": ["Ecto.Schema"]
  },
  "call_graph": {             -- ✅ From AstExtractor
    "my_function/2": {
      "calls": ["other_func/1", "Repo.insert/2"],
      "line": 42
    }
  }
}
```

#### graph_nodes (Graph Vertices)
```sql
CREATE TABLE graph_nodes (
  id UUID PRIMARY KEY,
  codebase_id VARCHAR,
  node_id VARCHAR,              -- "file.ex::function/2" or "module::Module.Name"
  node_type VARCHAR,            -- "function" or "module"
  name VARCHAR,
  file_path VARCHAR,
  line_number INTEGER,
  vector_embedding VECTOR(1536),  -- For future semantic queries
  metadata JSONB,

  UNIQUE (codebase_id, node_id)
);
```

#### graph_edges (Graph Edges)
```sql
CREATE TABLE graph_edges (
  id UUID PRIMARY KEY,
  codebase_id VARCHAR,
  edge_id VARCHAR,
  from_node_id VARCHAR,         -- Source node
  to_node_id VARCHAR,           -- Target node
  edge_type VARCHAR,            -- "calls" or "imports"
  weight FLOAT,                 -- 1.0 for internal, 0.5 for external
  metadata JSONB,

  UNIQUE (codebase_id, edge_id)
);
```

---

## Files Created

### Schemas
1. `lib/singularity/schemas/graph_node.ex` - Ecto schema for graph_nodes
2. `lib/singularity/schemas/graph_edge.ex` - Ecto schema for graph_edges

### Core Logic
3. `lib/singularity/graph/graph_populator.ex` - Populate graphs from metadata
4. `lib/singularity/graph/graph_queries.ex` - Query helper with common graph queries

### CLI
5. `lib/mix/tasks/graph.populate.ex` - Mix task for graph population

### Analysis (Previous)
6. `lib/singularity/analysis/ast_extractor.ex` - Extract enhanced metadata from AST

---

## Usage Patterns

### After Code Changes
```bash
# Files are automatically re-ingested by CodeFileWatcher
# But graphs need manual refresh:
mix graph.populate --only call  # Just update call graph

# Or rebuild everything:
mix graph.populate --rebuild
```

### Finding Impact of Changes
```elixir
# Before changing a function, find who calls it:
iex> GraphQueries.find_callers("my_function/2")

# If result is empty or just tests, safe to change!
# If many callers, refactor carefully
```

### Finding Dead Code
```elixir
# Find functions with zero callers (candidates for removal)
iex> alias Singularity.{Repo, Schemas.GraphNode, Schemas.GraphEdge}
iex> import Ecto.Query

iex> from(gn in GraphNode,
      left_join: ge in GraphEdge, on: ge.to_node_id == gn.node_id and ge.edge_type == "calls",
      where: gn.node_type == "function",
      where: is_nil(ge.id),
      select: %{name: gn.name, file_path: gn.file_path}
    ) |> Repo.all()
```

### Finding Coupling
```elixir
# Find most-imported modules (high coupling)
iex> from(gn in GraphNode,
      join: ge in GraphEdge, on: ge.to_node_id == gn.node_id,
      where: gn.node_type == "module",
      where: ge.edge_type == "imports",
      group_by: [gn.node_id, gn.name],
      select: %{module: gn.name, import_count: count(ge.id)},
      order_by: [desc: count(ge.id)],
      limit: 10
    ) |> Repo.all()
```

### Finding Circular Dependencies
```elixir
iex> GraphQueries.find_circular_dependencies()
{:ok, [
  ["ModuleA", "ModuleB", "ModuleC", "ModuleA"]
]}

# Visualize in Mermaid:
# graph LR
#   ModuleA --> ModuleB
#   ModuleB --> ModuleC
#   ModuleC --> ModuleA
```

---

## Advanced Queries

### Call Chain (N-Hops)
```elixir
# Find all functions that eventually call "process_data/2" (up to 3 hops)
iex> GraphQueries.find_call_chain("process_data/2", depth: 3)
{:ok, [
  %{name: "process_data/2", depth: 0, path: ["process_data/2"]},
  %{name: "handle_request/1", depth: 1, path: ["process_data/2", "handle_request/1"]},
  %{name: "run/0", depth: 2, path: ["process_data/2", "handle_request/1", "run/0"]}
]}
```

### Custom Queries
```elixir
# Find all functions in a specific module
iex> from(gn in GraphNode,
      where: gn.node_type == "function",
      where: fragment("? LIKE ?", gn.file_path, "%manager.ex"),
      select: %{name: gn.name, line: gn.line_number}
    ) |> Repo.all()

# Find functions with specific metadata
iex> from(gn in GraphNode,
      where: gn.node_type == "function",
      where: fragment("? -> 'language' = ?", gn.metadata, "elixir"),
      select: gn.name
    ) |> Repo.all()
```

---

## Performance Tips

### Indexes Already Created ✅
- `graph_nodes(codebase_id, node_id)` - UNIQUE index
- `graph_nodes(codebase_id)` - Query by codebase
- `graph_nodes(codebase_id, node_type)` - Filter by type
- `graph_edges(codebase_id, edge_id)` - UNIQUE index
- `graph_edges(from_node_id)` - Find outgoing edges
- `graph_edges(to_node_id)` - Find incoming edges
- `graph_edges(edge_type)` - Filter by relationship type

### Query Optimization
- Use `codebase_id` in all queries (indexed)
- Filter by `node_type` or `edge_type` early (indexed)
- Use EXPLAIN ANALYZE for slow queries
- Consider materialized views for complex aggregations

---

## Future Enhancements

### Phase 1: Add Vector Search (Easy - 2 hours)
Currently `vector_embedding` column exists but is NULL.

**Add semantic search:**
```elixir
# Find functions similar to "handle authentication"
iex> embedding = EmbeddingGenerator.generate("handle authentication")
iex> from(gn in GraphNode,
      where: gn.node_type == "function",
      order_by: fragment("? <=> ?", gn.vector_embedding, ^embedding),
      limit: 10
    ) |> Repo.all()
```

**Implementation:**
1. Generate embeddings during graph population
2. Update `graph_nodes.vector_embedding` column
3. Add semantic search functions to GraphQueries

### Phase 2: Add Apache AGE (Optional - 4 hours)
If SQL becomes too verbose, enable AGE for Cypher queries.

**Benefits:**
- Simpler syntax: `MATCH (a)-[:CALLS]->(b) RETURN a, b`
- Native graph algorithms (PageRank, shortest path)
- Standard query language (same as Neo4j)

**See:** `GRAPH_DATABASE_OPTIONS.md` for full guide

### Phase 3: Integrate with Rust petgraph (Advanced - 8 hours)
Currently Rust `code_engine/src/graph/` has petgraph code but it's not connected.

**Integration:**
1. Export graph data to Rust via NIF
2. Run graph algorithms (PageRank, community detection)
3. Import results back to PostgreSQL
4. Add to `graph_nodes.metadata` (e.g., `pagerank_score`)

---

## Troubleshooting

### "No metadata found"
```elixir
# Check if code ingestion ran
iex> alias Singularity.{Repo, Schemas.CodeFile}
iex> import Ecto.Query

iex> from(c in CodeFile,
      where: not is_nil(fragment("? -> 'call_graph'", c.metadata)),
      select: count()
    ) |> Repo.one()

# If 0, run ingestion:
iex> Singularity.Execution.Planning.HTDAGAutoBootstrap.run()
```

### "Graph is empty"
```elixir
# Check if graph was populated
iex> Singularity.Graph.GraphQueries.stats()

# If all zeros, populate:
# mix graph.populate
```

### "Query is slow"
```sql
-- Check if indexes exist
SELECT indexname FROM pg_indexes WHERE tablename IN ('graph_nodes', 'graph_edges');

-- Analyze query
EXPLAIN ANALYZE
SELECT ...;

-- Reindex if needed
REINDEX TABLE graph_nodes;
REINDEX TABLE graph_edges;
```

---

## Summary

**You now have:**
- ✅ Rust NIF for fast AST parsing (tree-sitter)
- ✅ Enhanced metadata extraction (dependencies, call graph, types, docs)
- ✅ PostgreSQL tables for graph storage (graph_nodes, graph_edges)
- ✅ Graph population from metadata (mix graph.populate)
- ✅ Rich query API (GraphQueries module)
- ✅ CLI tools for easy management

**Next steps:**
1. Run `mix graph.populate` to build graphs
2. Try queries in IEx
3. Use for impact analysis, dead code detection, circular dependencies
4. Optionally add semantic search or Apache AGE later

**No external dependencies needed!** Everything runs in PostgreSQL with standard SQL.

Enjoy your PostgreSQL-based code graphs! 🎉
