# Technology Stack Clarity - October 2025

**Purpose:** Definitive reference for Rust NIF vs Pure Elixir implementations to prevent documentation drift.

---

## Quick Reference

| Component | Stack | Status | Details |
|-----------|-------|--------|---------|
| **Embeddings** | Pure Elixir (Nx) | ✅ Production | Qodo 1536 + Jina 1024 = 2560-dim concatenated |
| **Language Detection** | Rust NIF | ✅ Production | 25+ languages supported |
| **Code Analysis** | Rust NIF | ✅ Production | 20 languages via tree-sitter |
| **Architecture Analysis** | Rust NIF | ✅ Production | Framework/pattern detection |
| **Code Parser** | Rust NIF | ✅ Production | AST parsing, universal |
| **Quality Engine** | Rust NIF | ✅ Production | Code quality metrics |
| **Graph PageRank** | Rust NIF | ✅ Implemented | Algorithm ready, needs Elixir bridge |
| **AGE (Apache AGE)** | PostgreSQL Ext | ✅ Ready | Cypher queries via SQL, PageRank storage pending |

---

## Detailed Breakdown

### EMBEDDINGS - Pure Elixir (Nx) ✅

**Primary Implementation:**
- `lib/singularity/embedding/nx_service.ex` - Main Nx service
- `lib/singularity/embedding_generator.ex` - High-level API
- `lib/singularity/embedding_model_loader.ex` - Model management

**Technology Stack:**
- **Framework:** Nx (Numerical Elixir)
- **GPU Backend:** EXLA (Elixir XLA)
- **Inference Engine:** Ortex (ONNX in Elixir)
- **Models:** Safetensors format (Qodo), ONNX format (Jina)

**Models Used:**
```
Qodo-Embed-1 (1536-dim)
├─ Framework: Safetensors
├─ Purpose: Code semantics (code-specialized embeddings)
├─ Fine-tunable: Yes (via Axon)
└─ VRAM: ~3GB on RTX 4080

Jina v3 (1024-dim)
├─ Framework: ONNX
├─ Purpose: General text understanding
├─ Fine-tunable: No (reference model)
└─ VRAM: ~2GB on RTX 4080

Combined Output: 2560-dim (1536 + 1024 concatenated)
```

**Inference:**
```elixir
# Always returns 2560-dim, no choice
{:ok, embedding} = EmbeddingGenerator.embed("code text")
# => Pgvector with 2560 dimensions
```

**Key Files:**
- `lib/singularity/embedding/nx_service.ex` - Lines 60-77 show @models config
- `lib/singularity/embedding/trainer.ex` - Fine-tuning support
- `lib/singularity/embedding/tokenizer.ex` - Text tokenization

**NOT Rust NIF** - This is pure BEAM ML stack.

---

### LANGUAGE DETECTION - Rust NIF ✅

**Implementation:**
- `singularity/lib/singularity/language_detection.ex` - Elixir bridge
- `rust/parser_engine/src/language_detection.rs` - Rust NIF implementation

**Supported Languages:**
- 25+ languages (Python, Rust, Go, Ruby, Java, Elixir, etc.)

**Usage:**
```elixir
{:ok, language} = LanguageDetection.detect_language(file_path)
# => :elixir | :rust | :python | ...
```

---

### CODE ANALYSIS - Rust NIF ✅

**Implementation:**
- `singularity/lib/singularity/engines/code_engine.ex` - Elixir bridge
- `rust/code_engine/src/analysis/` - Analysis implementations

**Features:**
- AST parsing (20+ languages via tree-sitter)
- Complexity metrics
- Pattern detection
- Dependency analysis

**Uses Rust NIF** - This is native compiled code.

---

### ARCHITECTURE & PATTERN DETECTION - Rust NIF ✅

**Implementation:**
- `singularity/lib/singularity/engines/architecture_engine.ex` - Elixir bridge
- `rust/code_engine/src/analysis/` - Detection logic

**Detects:**
- Frameworks (React, Rails, Django, Spring, etc.)
- Design patterns (MVC, Microservices, etc.)
- Technology stacks

**Uses Rust NIF** - Native compiled detection.

---

### QUALITY ENGINE - Rust NIF ✅

**Implementation:**
- `singularity/lib/singularity/engines/quality_engine.ex` - Elixir bridge
- `rust/quality_engine/src/` - Quality analysis

**Analyzes:**
- Code complexity
- Maintainability index
- Security issues
- Performance characteristics

**Uses Rust NIF** - Native compiled analysis.

---

### CENTRALITY MEASURES - Rust Code Analyzer Engine ✅

**Status:** PageRank fully implemented; other centrality measures not yet implemented.

**Part of:** Singularity Code Analyzer (code_engine Rust NIF)

#### PageRank Centrality (Implemented) ✅

**Implementation:**
- `rust/code_engine/src/analysis/graph/pagerank.rs` - Rust algorithm
- `rust/code_engine/src/graph/pagerank.rs` - Duplicate/alternate location (same code)
- `rust/code_engine/src/codebase/metadata.rs` - CodebaseMetadata struct (lines 70-78) stores scores
- `rust/code_engine/src/domain/files.rs` - FileNode struct stores scores

**What it measures:**
- **Node importance** based on incoming link count
- **Iterative voting** where high-score nodes vote more heavily
- **Suitable for:** Finding critical modules, most-depended-on functions

**Features:**
```rust
pub struct CentralPageRank {
  graph: HashMap<String, Vec<String>>,      // Adjacency matrix
  scores: HashMap<String, f64>,             // PageRank scores (0.0-1.0)
  config: PageRankConfig,                   // Damping factor, convergence
  cache: RefCell<HashMap<String, f64>>,    // Performance cache
}
```

**Algorithm Configuration:**
- **Damping factor:** 0.85 (configurable) - probability of following a link
- **Convergence threshold:** 1e-6 - stop when scores stabilize
- **Max iterations:** 100 - prevent infinite loops
- **Dangling nodes:** Handled (nodes with no outgoing links)

**Available Methods:**
```rust
pub fn calculate_pagerank(&mut self) -> Result<PageRankMetrics>
pub fn get_score(&self, node_id: &str) -> f64
pub fn get_top_nodes(&self, n: usize) -> Vec<PageRankResult>
pub fn get_all_results(&self) -> Vec<PageRankResult>
pub fn export_dot(&self) -> String  // Graphviz format

// Integration trait for Elixir
pub trait PageRankIntegration {
  async fn calculate_centrality_score(&self, file_path: &Path, pagerank: &CentralPageRank) -> Result<f64>
  async fn get_file_importance_rank(&self, file_path: &Path, pagerank: &CentralPageRank) -> Result<Option<usize>>
}
```

**Test Coverage:**
- `test_pagerank_basic()` - Simple graph with 3 nodes
- `test_pagerank_top_nodes()` - Star topology (central node)
- `test_pagerank_dependencies()` - File dependency graph

**Returns:**
```rust
pub struct PageRankResult {
  pub node_id: String,          // Module/function name
  pub score: f64,               // Raw PageRank score
  pub normalized_score: f64,    // 0.0-1.0 normalized
  pub rank: usize,              // 1 = highest, n = lowest
}

pub struct PageRankMetrics {
  pub total_nodes: usize,
  pub total_edges: usize,
  pub average_degree: f64,
  pub density: f64,
  pub iterations_to_converge: usize,
  pub converged: bool,
}
```

**Status:** ✅ Fully implemented, needs Elixir bridge for production use.

**Storage:** Centrality scores stored in:
- `CodebaseMetadata` struct: `pagerank_score` and `centrality_score` fields (line 72-74)
- `FileNode` struct: `pagerank_score` and `centrality_score` fields
- **Note:** Fields initialized to 0.0, need calculation/population in analysis pipeline

#### Betweenness Centrality (Not Implemented) ❌

**What it measures:** How often a node lies on shortest paths between other nodes
- **Use case:** Finding bottlenecks or critical intermediaries
- **Example:** A module that is a bridge between two subsystems
- **Status:** NOT implemented

#### Closeness Centrality (Not Implemented) ❌

**What it measures:** Average distance from a node to all other nodes
- **Use case:** Finding "hubs" that are close to everything
- **Example:** A utility module used by many others
- **Status:** NOT implemented

#### Degree Centrality (Partially Implemented) 🔶

**What it measures:** Simple in-degree + out-degree count
- **In-degree:** How many modules depend on this
- **Out-degree:** How many modules this depends on
- **Current status:** Used in code_graph.rs for filtering (see lines 193-211)
- **Missing:** Formal centrality calculation (not normalized, no ranking)

---

### Next Steps: Wire PageRank to Elixir

**Goal:** Store PageRank scores in PostgreSQL, query via AGE.

**Steps:**
```
1. Create Elixir wrapper for Rust PageRank
   └─ singularity/lib/singularity/graph/pagerank_calculator.ex

2. Build call graph from graph_edges
   └─ Load edges, convert to HashMap

3. Calculate PageRank scores
   └─ Call Rust NIF, get Vec<PageRankResult>

4. Store in graph_nodes or codebase_metadata
   └─ Add pagerank_score column

5. Query via AGE
   └─ MATCH (n:Function) RETURN n.name, n.pagerank_score ORDER BY n.pagerank_score DESC
```

**Estimated effort:** 2-3 hours (NIF bridge + integration)

---

### APACHE AGE (Graph Database) - PostgreSQL Extension ✅

**Status:** Enabled and ready (not Rust NIF).

**Implementation:**
- `singularity/lib/singularity/graph/age_queries.ex` - Cypher queries
- `singularity/priv/repo/migrations/20251014110353_enable_apache_age.exs` - Setup

**Capabilities:**
```elixir
# Cypher-based graph queries
AgeQueries.find_callers_cypher("function_name/2")
AgeQueries.find_circular_dependencies_cypher()
AgeQueries.shortest_path_cypher("start/0", "end/1")
AgeQueries.most_called_functions_cypher(10)
```

**What's Missing:** PageRank scores not yet stored in AGE graph.

**Plan:**
1. Wire Rust PageRank to Elixir (2-3 hours)
2. Calculate PageRank for codebase
3. Store scores in `graph_nodes` table
4. Add AGE query to fetch top functions by PageRank

---

## Summary Table

| Technology | Where | Implementation | Status |
|-----------|-------|----------------|--------|
| **Nx** | Embeddings | Pure Elixir | ✅ Production |
| **Ortex** | ONNX Inference | Elixir wrapper | ✅ Production |
| **Axon** | Fine-tuning | Pure Elixir | ✅ Ready |
| **EXLA** | GPU Backend | Elixir binding | ✅ Configured |
| **Rustler** | NIF bridge | Rust + Elixir | ✅ Working |
| **tree-sitter** | Code parsing | Rust NIF | ✅ Working |
| **PostgreSQL** | Database | SQL + pgvector | ✅ Working |
| **Apache AGE** | Graph DB | PostgreSQL ext | ✅ Working |
| **Cypher** | Graph queries | SQL via AGE | ✅ Queries ready |

---

## Documentation References

**For Embeddings:** See `PURE_ELIXIR_ML_ARCHITECTURE.md`
**For Rust NIFs:** See `rust/*/src/` modules
**For Graph:** See `CLAUDE.md` section "Semantic Code Search"
**For PageRank:** See `rust/code_engine/src/analysis/graph/pagerank.rs` and this file
**For AGE:** See `singularity/lib/singularity/graph/age_queries.ex`

---

## Future Enhancement: PageRank in AGE

**Goal:** Store PageRank scores in PostgreSQL, query via AGE.

**Steps:**
```
1. Create Elixir wrapper for Rust PageRank
   └─ singularity/lib/singularity/graph/pagerank_calculator.ex

2. Build call graph from graph_edges
   └─ Load edges, convert to HashMap

3. Calculate PageRank scores
   └─ Call Rust NIF, get Vec<PageRankResult>

4. Store in graph_nodes or codebase_metadata
   └─ Add pagerank_score column

5. Query via AGE
   └─ MATCH (n:Function) RETURN n.name, n.pagerank_score ORDER BY n.pagerank_score DESC
```

**Estimated effort:** 2-3 hours (NIF bridge + integration)

---

## Key Takeaway

**DO NOT say:**
- "Embeddings are Rust NIF" ❌
- "8 Rust NIF Engines" ❌
- "Embeddings use ONNX runtime via Rust" ❌

**DO say:**
- "Embeddings are pure Elixir via Nx/Ortex" ✅
- "Rust NIF Engines: Architecture, Code Analysis, Parser, Quality, Language Detection, PageRank" ✅
- "Multi-vector embeddings (Qodo + Jina v3) = 2560-dim concatenated" ✅
