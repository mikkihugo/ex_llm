# Graph Database Options for Code Flow Mapping

## Option 1: PostgreSQL with Recursive CTEs (RECOMMENDED for you!)

**Why**: You already have PostgreSQL + you're internal tooling (no scale constraints)

**Pros**:
- ✅ Already set up
- ✅ Can store flows as edges table
- ✅ Recursive CTEs for traversal
- ✅ Combine with pgvector for semantic matching
- ✅ Single database = simpler

**Cons**:
- ⚠️ Slower for very deep traversals (100+ levels)
- ⚠️ More complex queries for graph algorithms

### Schema (Already Designed Above)

```sql
CREATE TABLE code_execution_flow_edges (
  id UUID PRIMARY KEY,
  from_node_id UUID REFERENCES code_execution_flow_nodes(id),
  to_node_id UUID REFERENCES code_execution_flow_nodes(id),
  edge_type TEXT,
  -- ...
);

-- Query: Find all paths from entry point to database
WITH RECURSIVE flow_path AS (
  -- Base case: start at entry point
  SELECT
    id as node_id,
    symbol_name,
    ARRAY[id] as path,
    0 as depth
  FROM code_execution_flow_nodes
  WHERE is_entry_point = true
    AND symbol_name = 'POST /api/users'

  UNION ALL

  -- Recursive: follow edges
  SELECT
    n.id,
    n.symbol_name,
    path || n.id,
    depth + 1
  FROM flow_path fp
  JOIN code_execution_flow_edges e ON e.from_node_id = fp.node_id
  JOIN code_execution_flow_nodes n ON n.id = e.to_node_id
  WHERE depth < 20  -- Prevent infinite loops
    AND NOT n.id = ANY(path)  -- Prevent cycles
)
SELECT
  path,
  depth,
  array_agg(symbol_name ORDER BY depth) as flow
FROM flow_path
WHERE symbol_name LIKE '%INSERT INTO%'  -- Found DB operation
GROUP BY path, depth
ORDER BY depth ASC
LIMIT 10;
```

**Result**:
```
path: [uuid1, uuid2, uuid3, uuid4]
flow: ["POST /api/users", "create_user/1", "validate_user/1", "INSERT INTO users"]
```

---

## Option 2: Apache AGE (PostgreSQL Extension)

**Why**: Graph database AS a PostgreSQL extension

**What**: Adds Cypher query language to PostgreSQL

**Pros**:
- ✅ Still PostgreSQL (same DB!)
- ✅ Cypher queries (like Neo4j)
- ✅ Graph-specific optimizations
- ✅ Can query with SQL OR Cypher

**Cons**:
- ⚠️ Need to install extension
- ⚠️ Less mature than Neo4j
- ⚠️ Smaller community

### Installation

```bash
# In Nix environment
nix-shell -p postgresql_15 age

# Or add to flake.nix
```

### Example Cypher Query

```cypher
-- Find all paths from HTTP endpoint to database
MATCH path = (entry:CodeNode {node_type: 'http_endpoint', symbol_name: 'POST /api/users'})
             -[:CALLS*1..10]->
             (db:CodeNode {node_type: 'db_query'})
WHERE entry.is_entry_point = true
RETURN path, length(path) as depth
ORDER BY depth ASC
LIMIT 10;
```

---

## Option 3: Neo4j (Dedicated Graph DB)

**Why**: Industry-standard graph database

**Pros**:
- ✅ Best graph query performance
- ✅ Rich Cypher query language
- ✅ Built-in graph algorithms (shortest path, centrality, etc.)
- ✅ Great visualization tools
- ✅ Massive community

**Cons**:
- ❌ Another database to manage
- ❌ Duplicate data (code flows in PostgreSQL AND Neo4j?)
- ❌ More complexity

### When to Use

- ✅ Very deep call graphs (1000+ nodes)
- ✅ Need real-time graph traversal
- ✅ Want built-in graph algorithms

### Docker Setup

```yaml
# docker-compose.yml
services:
  neo4j:
    image: neo4j:5.15
    ports:
      - "7474:7474"  # Web UI
      - "7687:7687"  # Bolt protocol
    environment:
      NEO4J_AUTH: neo4j/your-password
    volumes:
      - neo4j_data:/data
```

### Elixir Client

```elixir
# mix.exs
{:bolt_sips, "~> 2.0"}

# Usage
{:ok, conn} = Bolt.Sips.start_link(url: "bolt://localhost:7687")

# Query
Bolt.Sips.query!(conn, """
  MATCH (entry:CodeNode {is_entry_point: true})
        -[:CALLS*1..10]->(node)
  RETURN entry, collect(node) as reachable
""")
```

---

## Option 4: DGraph (Distributed Graph DB)

**Why**: GraphQL-native graph database

**Pros**:
- ✅ GraphQL queries (familiar if you use GraphQL)
- ✅ Distributed (scales horizontally)
- ✅ Good performance

**Cons**:
- ❌ Another database
- ❌ Overkill for internal tooling
- ❌ Smaller community than Neo4j

---

## Option 5: Memgraph (In-Memory Graph DB)

**Why**: Faster than Neo4j for real-time queries

**Pros**:
- ✅ Very fast (in-memory)
- ✅ Cypher compatible
- ✅ Good for streaming data

**Cons**:
- ❌ Another database
- ❌ Data loss if crash (in-memory)

---

## Recommendation for Singularity

### Use PostgreSQL with Recursive CTEs ✅

**Why**:
1. ✅ **Already set up** - Zero new infrastructure
2. ✅ **Single database** - Simpler (internal tooling philosophy)
3. ✅ **Rich features** - Combine flows + embeddings + full-text search
4. ✅ **Good enough performance** - Internal use, not real-time queries

### Upgrade Path (If Needed Later):

```
Phase 1: PostgreSQL recursive CTEs (NOW)
  ↓
Phase 2: Add Apache AGE extension (if queries get slow)
  ↓
Phase 3: Add Neo4j (only if you need real-time graph viz)
```

---

## PostgreSQL Graph Query Examples

### 1. Find All Paths from Entry to Database

```sql
WITH RECURSIVE execution_paths AS (
  -- Start: HTTP endpoints
  SELECT
    n.id,
    n.symbol_name,
    n.file_path,
    ARRAY[n.id] as path,
    ARRAY[n.symbol_name] as flow,
    0 as depth
  FROM code_execution_flow_nodes n
  WHERE n.is_entry_point = true

  UNION ALL

  -- Follow edges
  SELECT
    target.id,
    target.symbol_name,
    target.file_path,
    path || target.id,
    flow || target.symbol_name,
    depth + 1
  FROM execution_paths ep
  JOIN code_execution_flow_edges e ON e.from_node_id = ep.id
  JOIN code_execution_flow_nodes target ON target.id = e.to_node_id
  WHERE depth < 50
    AND NOT target.id = ANY(path)  -- Prevent cycles
)
SELECT
  flow[1] as entry_point,
  flow[array_length(flow, 1)] as terminal,
  depth,
  flow
FROM execution_paths
WHERE symbol_name LIKE '%INSERT%' OR symbol_name LIKE '%UPDATE%' OR symbol_name LIKE '%DELETE%'
ORDER BY depth ASC;
```

**Result**:
```
entry_point          | terminal                    | depth | flow
---------------------|----------------------------|-------|--------------------------------------
POST /api/users      | INSERT INTO users          | 4     | {POST /api/users, create_user, validate, INSERT INTO users}
PUT /api/users/:id   | UPDATE users SET           | 5     | {PUT /api/users/:id, update_user, authorize, validate, UPDATE users SET}
```

### 2. Find Missing Error Handling

```sql
-- Find flows that don't have error handling paths
WITH error_handled_flows AS (
  SELECT DISTINCT e.from_node_id
  FROM code_execution_flow_edges e
  WHERE e.is_error_path = true
)
SELECT
  n.symbol_name,
  n.file_path,
  n.line_start,
  'Missing error handling' as issue
FROM code_execution_flow_nodes n
WHERE n.is_entry_point = true
  AND n.id NOT IN (SELECT from_node_id FROM error_handled_flows);
```

### 3. Find Circular Dependencies

```sql
WITH RECURSIVE cycle_detection AS (
  SELECT
    id,
    symbol_name,
    ARRAY[id] as path,
    false as is_cycle
  FROM code_execution_flow_nodes
  WHERE is_entry_point = true

  UNION ALL

  SELECT
    target.id,
    target.symbol_name,
    path || target.id,
    target.id = ANY(path) as is_cycle
  FROM cycle_detection cd
  JOIN code_execution_flow_edges e ON e.from_node_id = cd.id
  JOIN code_execution_flow_nodes target ON target.id = e.to_node_id
  WHERE NOT cd.is_cycle
    AND array_length(path, 1) < 100
)
SELECT DISTINCT
  path,
  array_length(path, 1) as cycle_length
FROM cycle_detection
WHERE is_cycle = true;
```

### 4. Find Most Connected Nodes (Centrality)

```sql
-- Find functions called by many others (potential bottlenecks)
SELECT
  n.symbol_name,
  n.file_path,
  COUNT(DISTINCT e.from_node_id) as called_by_count,
  COUNT(DISTINCT e2.to_node_id) as calls_count,
  COUNT(DISTINCT e.from_node_id) + COUNT(DISTINCT e2.to_node_id) as total_connections
FROM code_execution_flow_nodes n
LEFT JOIN code_execution_flow_edges e ON e.to_node_id = n.id
LEFT JOIN code_execution_flow_edges e2 ON e2.from_node_id = n.id
GROUP BY n.id, n.symbol_name, n.file_path
ORDER BY total_connections DESC
LIMIT 20;
```

---

## Hybrid Approach: PostgreSQL + Graph Visualization

**Best of both worlds**:

1. **Store in PostgreSQL** (source of truth)
2. **Export to graph viz tools** for exploration

### Tools for Visualization:

#### Graphviz (Generate Static Diagrams)

```elixir
defmodule Singularity.FlowVisualizer.GraphvizExporter do
  def export_flow_to_dot(flow_id) do
    flow = load_flow_with_edges(flow_id)

    dot = """
    digraph CodeFlow {
      rankdir=LR;
      node [shape=box, style=rounded];

      #{render_nodes(flow.nodes)}
      #{render_edges(flow.edges)}
    }
    """

    # Save to file
    File.write!("/tmp/flow_#{flow_id}.dot", dot)

    # Generate PNG
    System.cmd("dot", ["-Tpng", "/tmp/flow_#{flow_id}.dot", "-o", "/tmp/flow_#{flow_id}.png"])
  end

  defp render_nodes(nodes) do
    Enum.map_join(nodes, "\n", fn node ->
      color = if node.is_entry_point, do: "lightblue", else: "white"
      ~s|  "#{node.id}" [label="#{node.symbol_name}", fillcolor=#{color}, style=filled];|
    end)
  end

  defp render_edges(edges) do
    Enum.map_join(edges, "\n", fn edge ->
      style = if edge.is_error_path, do: "dashed", else: "solid"
      ~s|  "#{edge.from_node_id}" -> "#{edge.to_node_id}" [style=#{style}];|
    end)
  end
end
```

#### D3.js (Interactive Web Visualization)

Export to JSON, render in browser:

```elixir
def export_flow_to_json(flow_id) do
  flow = load_flow_with_edges(flow_id)

  %{
    nodes: Enum.map(flow.nodes, fn n ->
      %{id: n.id, label: n.symbol_name, type: n.node_type}
    end),
    edges: Enum.map(flow.edges, fn e ->
      %{source: e.from_node_id, target: e.to_node_id, type: e.edge_type}
    end)
  }
  |> Jason.encode!()
end
```

Then use D3.js force-directed graph in Phoenix LiveView!

---

## Summary

| Option | Complexity | Performance | Setup Time | Recommended? |
|--------|------------|-------------|------------|--------------|
| **PostgreSQL + Recursive CTEs** | Low | Good | 0 (done!) | ✅ YES - Start here |
| **Apache AGE** | Medium | Better | 1 hour | ⚠️ If PG CTEs too slow |
| **Neo4j** | High | Best | 4 hours | ❌ Overkill for now |
| **DGraph** | High | Good | 4 hours | ❌ Overkill |
| **Memgraph** | High | Excellent | 4 hours | ❌ Overkill |

**Go with PostgreSQL!** You get:
- Zero new infra
- Graph queries via recursive CTEs
- Combine with pgvector (semantic search)
- Export to viz tools when needed

Want me to create the migrations and build the flow extractor?
