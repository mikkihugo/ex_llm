# Existing Flow Analysis Capabilities - You Already Have This!

## ✅ What You Already Have

### 1. Rust Code Graph Analysis (`rust/analysis_suite/src/graph/code_graph.rs`)

**Graph Types**:
- ✅ `CallGraph` - Function call dependencies
- ✅ `ImportGraph` - Module imports
- ✅ `SemanticGraph` - Concept relationships
- ✅ `DataFlowGraph` - Data dependencies

**Analysis Functions** (using petgraph):
```rust
pub fn has_cycles(&self) -> bool
pub fn topological_sort(&self) -> Result<Vec<String>>
pub fn strongly_connected_components(&self) -> Vec<Vec<String>>
pub fn find_similar_nodes(&self, query_node_id: &str, top_k: usize) -> Vec<(String, f32)>
pub fn find_codebase_patterns(&self) -> CodebaseCodePatterns
pub fn get_metrics(&self) -> GraphMetrics
pub fn get_dependencies(&self, node_id: &str) -> Vec<&GraphNode>
pub fn get_dependents(&self, node_id: &str) -> Vec<&GraphNode>
```

### 2. Elixir Semantic Code Search (`lib/singularity/search/semantic_code_search.ex`)

**Features**:
- ✅ Semantic search with pgvector
- ✅ Apache AGE graph extension support
- ✅ 50+ code metrics (complexity, maintainability, etc.)
- ✅ Multi-language (Rust, Elixir, Gleam, TypeScript)
- ✅ Graph tables (nodes, edges)
- ✅ Vector search tables

### 3. Code Analyzers (`lib/singularity/code/analyzers/`)

- ✅ `architecture_agent.ex` - Architecture analysis
- ✅ `dependency_mapper.ex` - **Dependency mapping** ⭐
- ✅ `coordination_analyzer.ex` - Coordination analysis
- ✅ `microservice_analyzer.ex` - Microservice analysis
- ✅ `rust_tooling_analyzer.ex` - Rust analysis

### 4. Agent Flow Tracker (Just Created!)

- ✅ `agent_flow_tracker.ex` - Runtime agent tracking
- ✅ Migration ready for 7 tables

---

## ❌ What You're Missing (For Complete Flow Analysis)

### 1. Control Flow Graph (CFG) - Dead End Detection

**What**: Analyze function bodies for dead ends, unreachable code

**Example**:
```elixir
def process_user(user) do
  validate_user(user)  # May raise! ← DEAD END if no rescue
  process_data(user)   # Unreachable if validate raises
end
```

**Status**: ❌ Not implemented yet

**Where to add**:
- Rust: `rust/analysis_suite/src/analysis/control_flow.rs` (new file)
- Elixir: `lib/singularity/code/analyzers/control_flow_analyzer.ex` (new file)

### 2. Flow Completeness Checking

**What**: Check if code flows are "complete" (all paths handled)

**Example**:
```elixir
case result do
  {:ok, data} -> process(data)
  # Missing: {:error, reason} ← INCOMPLETE!
end
```

**Status**: ❌ Not implemented yet

**Where to add**:
- Use existing `CodeDependencyGraph` + add completeness analysis
- Store in `code_function_control_flow_graphs` table (migration ready!)

### 3. Automatic Flow Visualization

**What**: Generate diagrams from graphs

**Status**: ⚠️ Partial (you have graph data, but no auto-viz)

**Where to add**:
- Elixir: `lib/singularity/code/visualizers/flow_visualizer.ex`
- Generate Mermaid diagrams from graph data

---

## 🎯 What You Should Build Next

### Priority 1: Control Flow Analysis (Dead End Detection)

Use **existing Rust graph infrastructure** + add CFG analysis:

```rust
// rust/analysis_suite/src/analysis/control_flow.rs

use crate::graph::CodeDependencyGraph;

pub struct ControlFlowAnalyzer {
    // Uses existing CodeDependencyGraph!
}

impl ControlFlowAnalyzer {
    pub fn analyze_function(&self, func: &FunctionNode) -> ControlFlowGraph {
        let mut cfg = CodeDependencyGraph::new(GraphType::DataFlowGraph);

        // Build CFG from AST (you already have tree-sitter parsing!)
        // ...

        // Detect issues using existing graph algorithms
        let dead_ends = self.find_dead_ends(&cfg);
        let unreachable = self.find_unreachable_code(&cfg);

        ControlFlowGraph { cfg, dead_ends, unreachable }
    }

    fn find_dead_ends(&self, cfg: &CodeDependencyGraph) -> Vec<DeadEnd> {
        // Use existing graph traversal!
        cfg.graph.node_indices()
            .filter(|&idx| {
                let node = &cfg.graph[idx];
                // No outgoing edges + not a return = dead end
                cfg.graph.edges_directed(idx, Direction::Outgoing).count() == 0
                    && node.node_type != "return"
            })
            .map(|idx| DeadEnd {
                node_id: cfg.graph[idx].id.clone(),
                line: cfg.graph[idx].line_number,
            })
            .collect()
    }
}
```

**Effort**: 1-2 days (leverage existing graph code!)

### Priority 2: Elixir Integration

```elixir
# lib/singularity/code/analyzers/control_flow_analyzer.ex

defmodule Singularity.ControlFlowAnalyzer do
  @moduledoc """
  Analyze control flow using Rust analysis_suite
  """

  def analyze_file(file_path) do
    # Call Rust via NIF (you already have rust NIFs!)
    case Singularity.RustAnalyzer.analyze_control_flow(file_path) do
      {:ok, cfg_data} ->
        # Store in code_function_control_flow_graphs (migration ready!)
        store_cfg(cfg_data)

        {:ok, %{
          dead_ends: cfg_data.dead_ends,
          unreachable_code: cfg_data.unreachable,
          completeness: calculate_completeness(cfg_data)
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Effort**: 1 day

### Priority 3: Visualization (Leverage Existing Graphs)

```elixir
# lib/singularity/code/visualizers/flow_visualizer.ex

defmodule Singularity.FlowVisualizer do
  def generate_mermaid_diagram(function_name) do
    # Load from existing graph tables!
    {:ok, nodes} = Repo.all(from n in "graph_nodes", where: n.function_name == ^function_name)
    {:ok, edges} = Repo.all(from e in "graph_edges", where: e.from_node_id in ^node_ids)

    """
    flowchart TD
      #{render_nodes(nodes)}
      #{render_edges(edges)}
    """
  end
end
```

**Effort**: 1 day

---

## 🚀 Quick Start: Use What You Have NOW

### 1. Analyze Dependencies (Already Works!)

```elixir
# Uses existing dependency_mapper.ex
Singularity.DependencyMapper.map_dependencies("lib/")

# Returns call graph, import graph, etc.
```

### 2. Semantic Search (Already Works!)

```elixir
# Uses existing semantic_code_search.ex
Singularity.SemanticCodeSearch.search("authentication code")

# Finds similar code using pgvector
```

### 3. Graph Analysis (Rust - Already Works!)

```bash
# Your Rust analysis suite already builds graphs!
cd rust/analysis_suite
cargo run -- analyze /path/to/codebase

# Outputs:
# - Call graph
# - Import graph
# - Cycles detected
# - Strongly connected components
```

---

## Summary

### ✅ You Have (90% done!):
- Graph data structures (Rust petgraph)
- Graph algorithms (cycles, toposort, SCC)
- Dependency mapping
- Semantic search
- Database tables (graph_nodes, graph_edges)
- Apache AGE support

### ❌ You Need (10% remaining):
1. **Control Flow Analysis** (dead ends, unreachable code)
2. **Flow Completeness** (pattern match exhaustiveness)
3. **Visualization** (Mermaid diagrams from graphs)

### 🎯 To Build Complete System:

**Week 1**: Add CFG analysis to Rust (leverage existing graph code)
**Week 2**: Elixir integration + database storage
**Week 3**: Visualization + Phoenix LiveView dashboard

**Total**: 2-3 weeks to complete flow analysis system!

---

## Recommendation

**Don't rebuild what you have!**

Instead:
1. ✅ Use existing `CodeDependencyGraph` (Rust)
2. ✅ Use existing graph tables (PostgreSQL)
3. ✅ Add CFG analysis on top (small addition!)
4. ✅ Visualize using existing graph data

You're **90% there** already! 🎉
