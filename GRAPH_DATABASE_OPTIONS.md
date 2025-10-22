# Graph Database Options - Your Current Setup vs Apache AGE

**TL;DR:** You're currently using **Rust petgraph** for in-memory graphs, with **PostgreSQL tables** for persistence. You have Apache AGE-compatible tables but **AGE extension is NOT enabled**. You can either:
1. Enable AGE for native graph queries (Cypher)
2. Keep current setup (petgraph + PostgreSQL tables)
3. Hybrid: Use both

---

## What You're Currently Using ✅

### 1. NIF for AST Parsing ✅
**YES, you are using the Rust NIF for AST extraction!**

**Flow:**
```
Elixir calls: CodeEngine.parse_file("lib/foo.ex")
  ↓
Delegates to: Singularity.RustAnalyzer.parse_file_nif()
  ↓
Rust NIF (code_engine): Uses tree-sitter to parse
  ↓
Returns: %{ast_json: "...", symbols: [...], imports: [...], exports: [...]}
  ↓
Stored in: code_files.metadata JSONB field
```

**Rust NIF Location:** `/home/mhugo/code/singularity/rust/code_engine/src/`

**What it provides:**
- Full tree-sitter AST (JSON format)
- Symbols (functions, classes, modules)
- Imports (dependencies)
- Exports (public API)
- Language detection
- Complexity metrics

### 2. Rust petgraph for Graph Operations ✅
**File:** `rust/code_engine/src/graph/mod.rs`

**Uses petgraph crate** (in-memory graph library):
- Directed graphs (DAGs)
- PageRank algorithm
- Graph insights
- Vector-enhanced relationships

**Current Architecture:**
```
Rust petgraph (in-memory)
  ↓ Serialize
PostgreSQL tables (persistence)
  ├── graph_nodes
  ├── graph_edges
  ├── graph_types
  └── codebase_metadata
```

### 3. PostgreSQL Graph Tables ✅
**Migration:** `20250101000007_create_code_search_tables.exs`

**Tables designed for Apache AGE compatibility:**

#### graph_nodes
```sql
CREATE TABLE graph_nodes (
  codebase_id VARCHAR(255),
  node_id VARCHAR(255),
  node_type VARCHAR(100),    -- "function", "module", "class"
  name VARCHAR(255),
  file_path VARCHAR(500),
  line_number INTEGER,
  vector_embedding VECTOR(1536),  -- For semantic similarity
  metadata JSONB
);
```

#### graph_edges
```sql
CREATE TABLE graph_edges (
  codebase_id VARCHAR(255),
  edge_id VARCHAR(255),
  from_node_id VARCHAR(255),
  to_node_id VARCHAR(255),
  edge_type VARCHAR(100),    -- "calls", "imports", "depends_on"
  weight FLOAT,
  metadata JSONB
);
```

#### graph_types (Predefined)
```sql
INSERT INTO graph_types VALUES
  ('CallGraph', 'Function call dependencies (DAG)'),
  ('ImportGraph', 'Module import dependencies (DAG)'),
  ('SemanticGraph', 'Conceptual relationships (General Graph)'),
  ('DataFlowGraph', 'Variable and data dependencies (DAG)');
```

**Key Feature:** These tables are **AGE-compatible** (designed to work with Apache AGE) but **currently using PostgreSQL queries**, not Cypher!

---

## What is Apache AGE? 🤔

**Apache AGE** = Apache Graph Extension for PostgreSQL

**What it does:**
- Adds **Cypher query language** to PostgreSQL (like Neo4j uses)
- Stores graphs natively in PostgreSQL
- Enables graph queries without complex JOINs
- Open source (Apache 2.0 license)

**Example Cypher vs SQL:**

### Cypher (with AGE):
```cypher
-- Find all functions that call "process_data"
MATCH (caller:Function)-[:CALLS]->(callee:Function {name: 'process_data'})
RETURN caller.name, caller.file_path
```

### SQL (current approach):
```sql
-- Same query in SQL
SELECT gn1.name, gn1.file_path
FROM graph_nodes gn1
JOIN graph_edges ge ON ge.from_node_id = gn1.node_id
JOIN graph_nodes gn2 ON ge.to_node_id = gn2.node_id
WHERE gn2.name = 'process_data'
  AND ge.edge_type = 'calls'
  AND gn1.node_type = 'function'
  AND gn2.node_type = 'function';
```

**Cypher is simpler for graph queries!**

---

## Current Status: AGE Extension NOT Enabled ❌

**Checked:** `priv/repo/migrations/20240101000001_enable_extensions.exs`

**What's enabled:**
- ✅ pgvector (for semantic search)
- ✅ pg_trgm (text search)
- ✅ btree_gin (JSONB indexing)
- ✅ hstore, ltree, etc.

**What's NOT enabled:**
- ❌ Apache AGE

**Why?** AGE is not in the standard PostgreSQL distribution - must be installed separately.

---

## Option 1: Enable Apache AGE (Recommended for Complex Graphs)

### Benefits
- **Cypher queries** - Much simpler than SQL JOINs for graph traversal
- **Native graph algorithms** - PageRank, shortest path, community detection
- **Better performance** - Optimized for graph queries
- **Industry standard** - Same query language as Neo4j

### Installation Steps

#### 1. Install AGE Extension
```bash
# On Ubuntu/Debian
sudo apt-get install postgresql-17-age

# Or build from source
git clone https://github.com/apache/age.git
cd age
make PG_CONFIG=/usr/bin/pg_config
sudo make PG_CONFIG=/usr/bin/pg_config install
```

#### 2. Enable in Migration
```elixir
# Create new migration
mix ecto.gen.migration enable_apache_age

# In the migration file:
defmodule Singularity.Repo.Migrations.EnableApacheAge do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS age"
    execute "LOAD 'age'"
    execute "SET search_path = ag_catalog, \"$user\", public"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS age CASCADE"
  end
end
```

#### 3. Create AGE Graph
```elixir
# Create a graph for your codebase
execute "SELECT create_graph('singularity_code')"
```

#### 4. Migrate Existing Data
```elixir
# Convert graph_nodes and graph_edges to AGE format
defmodule Singularity.GraphMigrator do
  def migrate_to_age() do
    # Create vertices from graph_nodes
    Repo.all(GraphNode)
    |> Enum.each(fn node ->
      Repo.query!("""
        SELECT * FROM cypher('singularity_code', $$
          CREATE (n:#{node.node_type} {
            node_id: '#{node.node_id}',
            name: '#{node.name}',
            file_path: '#{node.file_path}',
            line_number: #{node.line_number}
          })
        $$) as (v agtype);
      """)
    end)

    # Create edges from graph_edges
    Repo.all(GraphEdge)
    |> Enum.each(fn edge ->
      Repo.query!("""
        SELECT * FROM cypher('singularity_code', $$
          MATCH (a {node_id: '#{edge.from_node_id}'}), (b {node_id: '#{edge.to_node_id}'})
          CREATE (a)-[:#{String.upcase(edge.edge_type)} {weight: #{edge.weight}}]->(b)
        $$) as (e agtype);
      """)
    end)
  end
end
```

#### 5. Query with Cypher
```elixir
defmodule Singularity.GraphQueries do
  def find_callers(function_name) do
    Repo.query!("""
      SELECT * FROM cypher('singularity_code', $$
        MATCH (caller:Function)-[:CALLS]->(callee:Function {name: '#{function_name}'})
        RETURN caller.name, caller.file_path
      $$) as (name agtype, file_path agtype);
    """)
  end

  def find_dependencies(module_name) do
    Repo.query!("""
      SELECT * FROM cypher('singularity_code', $$
        MATCH (module:Module {name: '#{module_name}'})-[:IMPORTS*1..3]->(dependency)
        RETURN dependency.name, dependency.file_path
      $$) as (name agtype, file_path agtype);
    """)
  end

  def find_circular_dependencies() do
    Repo.query!("""
      SELECT * FROM cypher('singularity_code', $$
        MATCH path = (a:Module)-[:IMPORTS*]->(a)
        RETURN [node IN nodes(path) | node.name]
      $$) as (cycle agtype);
    """)
  end
end
```

### Downsides
- **Installation required** - Not in standard PostgreSQL
- **Learning curve** - Need to learn Cypher
- **Migration effort** - Convert existing data to AGE format
- **Potential conflicts** - AGE schemas separate from regular PostgreSQL

---

## Option 2: Keep Current Setup (petgraph + PostgreSQL)

### Benefits
- **Already working** - No installation needed
- **Familiar** - Standard SQL queries
- **Flexible** - JSONB for ad-hoc queries
- **Vector integration** - Easy to combine graph + semantic search

### Current Capabilities

#### Query Callers (SQL)
```elixir
def find_callers(function_name) do
  from(gn1 in GraphNode,
    join: ge in GraphEdge, on: ge.from_node_id == gn1.node_id,
    join: gn2 in GraphNode, on: ge.to_node_id == gn2.node_id,
    where: gn2.name == ^function_name and ge.edge_type == "calls",
    select: %{name: gn1.name, file_path: gn1.file_path}
  )
  |> Repo.all()
end
```

#### Query Dependencies (SQL + JSONB)
```elixir
def find_dependencies(module_name) do
  # Use JSONB in metadata for transitive dependencies
  from(gn in GraphNode,
    where: gn.name == ^module_name,
    select: fragment("? -> 'dependencies'", gn.metadata)
  )
  |> Repo.one()
end
```

#### Query with Rust petgraph
```rust
// In Rust NIF - compute PageRank
pub fn calculate_pagerank(graph: &Graph) -> HashMap<String, f64> {
  let pagerank = PageRank::new(&graph.graph);
  pagerank.run()
}
```

### Downsides
- **Complex SQL** - Graph queries require multiple JOINs
- **Performance** - Slower for deep traversals (3+ hops)
- **No Cypher** - Less elegant syntax

---

## Option 3: Hybrid Approach (Best of Both)

Use **both** petgraph (in-memory) and PostgreSQL (persistence):

### Architecture
```
Rust petgraph (fast in-memory queries)
  ↕ Serialize/Deserialize
PostgreSQL tables (persistence + historical queries)
  ↕ Optional
Apache AGE (complex graph queries if needed)
```

### When to Use Each

**Rust petgraph:**
- Real-time analysis (PageRank, shortest path)
- Temporary graphs (single analysis session)
- Fast in-memory operations

**PostgreSQL tables:**
- Persistent storage
- Historical queries ("show me dependencies last week")
- Combined queries (graph + vector search)

**Apache AGE (if enabled):**
- Complex multi-hop queries
- Pattern matching (find all circular deps)
- Graph algorithms (community detection)

---

## Recommendations

### For Your Use Case (AI Code Understanding):

**Start with Option 2 (Current Setup):**
1. ✅ **Already working** - petgraph + PostgreSQL tables
2. ✅ **Vector integration** - Combine graph + semantic search
3. ✅ **Fast iteration** - No installation needed

**Enhance Current Setup:**
1. **Populate graph_nodes and graph_edges** (currently empty?)
2. **Use enhanced metadata** (dependencies, call_graph from AstExtractor)
3. **Query with Ecto + JSONB** (good enough for most cases)

**Example: Populate Graph from Metadata**
```elixir
defmodule Singularity.GraphPopulator do
  alias Singularity.{Repo, Schemas.CodeFile, Schemas.GraphNode, Schemas.GraphEdge}
  import Ecto.Query

  def populate_call_graph() do
    # Get all files with call_graph metadata
    files = Repo.all(from c in CodeFile, where: not is_nil(c.metadata["call_graph"]))

    Enum.each(files, fn file ->
      call_graph = file.metadata["call_graph"]

      # Create nodes for each function
      Enum.each(call_graph, fn {func_name, func_data} ->
        %GraphNode{}
        |> GraphNode.changeset(%{
          codebase_id: "singularity",
          node_id: "#{file.file_path}::#{func_name}",
          node_type: "function",
          name: func_name,
          file_path: file.file_path,
          line_number: func_data["line"],
          metadata: %{func_data: func_data}
        })
        |> Repo.insert(on_conflict: :replace_all, conflict_target: [:codebase_id, :node_id])

        # Create edges for each call
        Enum.each(func_data["calls"] || [], fn called_func ->
          %GraphEdge{}
          |> GraphEdge.changeset(%{
            codebase_id: "singularity",
            edge_id: "#{file.file_path}::#{func_name}->#{called_func}",
            from_node_id: "#{file.file_path}::#{func_name}",
            to_node_id: called_func,  # TODO: resolve to full path
            edge_type: "calls",
            weight: 1.0
          })
          |> Repo.insert(on_conflict: :nothing, conflict_target: [:codebase_id, :edge_id])
        end)
      end)
    end)
  end
end
```

**Later (if needed): Add AGE for complex queries**
- Only if you find SQL too verbose for graph queries
- When you need advanced graph algorithms
- If you want to use standard Cypher syntax

---

## Summary: Answering Your Questions

### Q1: "Are we using the NIF for AST?"
**YES! ✅**
- Rust NIF: `CodeEngine.parse_file()` → `Singularity.RustAnalyzer.parse_file_nif()`
- Uses tree-sitter for parsing
- Returns AST JSON + symbols + imports + exports
- Stored in `code_files.metadata.ast_json`

### Q2: "And the graph data in the AST results, it says neo but can't we do postgres graph?"
**You have 3 options:**

1. **Current:** Rust petgraph (in-memory) + PostgreSQL tables ✅ **WORKING**
   - Fast in-memory graph operations
   - PostgreSQL for persistence
   - SQL for queries

2. **Apache AGE:** Native PostgreSQL graph extension ❌ **NOT ENABLED**
   - Cypher query language (like Neo4j)
   - Native graph algorithms
   - Requires installation

3. **Hybrid:** Use both ✅ **RECOMMENDED**
   - petgraph for fast in-memory analysis
   - PostgreSQL tables for persistence
   - Optionally add AGE if Cypher is needed

### Q3: "Age I think it's called?"
**YES! Apache AGE = Apache Graph Extension for PostgreSQL**
- Same Cypher syntax as Neo4j
- Runs inside PostgreSQL
- Open source
- **NOT currently enabled in your setup**

---

## Next Steps (If You Want AGE)

**Quick test (see if AGE is available):**
```bash
# Check if AGE is installed
psql singularity -c "SELECT * FROM pg_available_extensions WHERE name = 'age';"

# If available, enable it:
psql singularity -c "CREATE EXTENSION IF NOT EXISTS age;"
psql singularity -c "LOAD 'age';"
psql singularity -c "SELECT create_graph('singularity_code');"
```

**If not available, install:**
```bash
# For PostgreSQL 17
sudo apt-get install postgresql-17-age

# Or build from source
git clone https://github.com/apache/age.git
cd age && make install
```

**Create migration to enable AGE:**
```bash
cd singularity
mix ecto.gen.migration enable_apache_age
```

---

## My Recommendation

**Start with what you have (Option 2):**
1. Your current setup (petgraph + PostgreSQL tables) is solid
2. Populate `graph_nodes` and `graph_edges` from enhanced metadata
3. Use SQL + JSONB for queries (works great!)

**Add AGE later (Option 3 - Hybrid) if:**
- SQL becomes too verbose for complex graph queries
- You need advanced graph algorithms (community detection, etc.)
- You want standardized Cypher syntax

**Don't rush to Neo4j or AGE unless you hit limitations!**

Your current architecture is actually quite elegant:
- ✅ Rust NIF for fast parsing
- ✅ petgraph for in-memory graph analysis
- ✅ PostgreSQL for persistence + semantic search
- ✅ AGE-compatible tables (future-proof!)
