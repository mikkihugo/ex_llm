# Rust NIF Separation Architecture - Parser vs Code Engine

**Purpose:** Define clear separation of concerns between Parser Engine and Code Engine.

**Status:** Current implementation has good separation, but some consolidation opportunities exist.

---

## Executive Summary

| Engine | Purpose | Scope | Responsibility |
|--------|---------|-------|-----------------|
| **Parser Engine** | "Thin wrapper around parser_core" | Syntax analysis | Extract structure from source code |
| **Code Engine** | "Codebase analysis library" | Semantic analysis | Understand code relationships & intelligence |

---

## Parser Engine (parser_engine/)

### Purpose
Provide multi-language code parsing via tree-sitter, with NIF interface for Elixir.

### Responsibility
1. **AST Extraction** - Parse code to abstract syntax tree
2. **Language Detection** - Identify programming language
3. **Basic Metrics** - Count LOC, functions, classes
4. **Structure Analysis** - Extract functions, classes, imports, exports
5. **Syntax Metrics** - Cyclomatic complexity, Halstead metrics

### Should NOT Do
- ❌ Graph analysis (PageRank, cycles, SCC)
- ❌ Semantic interpretation (architecture, patterns)
- ❌ Metadata aggregation (100+ fields)
- ❌ Dependency relationship analysis (that's graph analysis)
- ❌ Architecture detection (frameworks, design patterns)

### Current Modules

| Module | Purpose | Status |
|--------|---------|--------|
| `languages.rs` | Language detection | ✅ Good |
| `languages/` | Language-specific parsing | ✅ Good |
| `dependencies.rs` | Extract dependency statements | ⚠️ See note below |
| `central_heuristics.rs` | Heuristic-based insights | 🔶 Should move to code_engine |
| `refactoring_suggestions.rs` | Refactoring advice | 🔶 Should move to code_engine |
| `beam/` | BEAM-specific parsing | ✅ Good |

### Issue: `dependencies.rs`

**Current behavior:** Extracts import/require statements from source

**Question:** Should this stay in parser?

**Analysis:**
- ✅ **PARSING** aspect: Extracting statements from AST → Parser's job
- ❌ **ANALYSIS** aspect: Analyzing relationships → Code engine's job
- ⚠️ **Current**: Parser extracts dependencies, code_engine builds graph from them

**Decision:** KEEP in parser, but:
1. Parser: Extract raw dependency statements (simple function calls, imports)
2. Code engine: Build graph, analyze relationships, detect cycles

---

## Code Engine (code_engine/)

### Purpose
Provide intelligent codebase analysis: graphs, semantics, architecture, patterns.

### Responsibility
1. **Graph Analysis** - PageRank, cycle detection, topological sort, SCC
2. **Semantic Analysis** - Embeddings, similarity, search
3. **Architecture Detection** - Framework detection, pattern identification
4. **Metadata Aggregation** - Collect 100+ metrics into CodebaseMetadata
5. **Intelligence** - Naming suggestions, evolution tracking, insights

### Should NOT Do
- ❌ Low-level AST extraction (that's parser's job)
- ❌ Basic parsing (use parser output)

### Current Modules

| Module | Purpose | Status |
|--------|---------|--------|
| `analysis/` | Code quality, patterns, dependencies | ✅ Good |
| `graph/` | PageRank, cycles, SCC, insights | ✅ Good |
| `codebase/` | Metadata storage, statistics | ✅ Good |
| `domain/` | Type definitions | ✅ Good |
| `repository/` | Project structure analysis | ✅ Good |
| `search/` | Semantic search engine | ✅ Good |
| `vectors/` | Vector embeddings | ✅ Good |
| `testing/` | Test analysis | ✅ Good |

---

## Data Flow Architecture

### Current Flow
```
Source Code
    ↓
Parser Engine (parser_engine)
    ├─ Language detection
    ├─ AST extraction
    ├─ Basic metrics (LOC, complexity)
    ├─ Dependency extraction
    └─ Returns: AnalysisResult
        ↓
Code Engine (code_engine)
    ├─ Parse AnalysisResult
    ├─ Build dependency graph
    ├─ Calculate PageRank
    ├─ Generate embeddings
    ├─ Detect architecture
    ├─ Aggregate to CodebaseMetadata
    └─ Returns: Rich metadata (100+ fields)
```

### Recommended Organization
```
SOURCE CODE
    ↓
PARSING LAYER (Parser Engine)
├─ Language detection
├─ AST extraction
├─ Structure analysis (functions, classes, imports)
├─ Basic metrics (LOC, complexity, halstead)
└─ Output: AnalysisResult (simple, focused)
    ↓
ANALYSIS LAYER (Code Engine)
├─ Build graphs from dependencies
├─ Graph algorithms (PageRank, cycles)
├─ Semantic analysis (embeddings, similarity)
├─ Architecture detection
├─ Pattern detection
├─ Aggregate all metrics
└─ Output: CodebaseMetadata (rich, 100+ fields)
    ↓
APPLICATION LAYER (Elixir)
├─ Store metadata in PostgreSQL
├─ Index in pgvector
├─ Query via AGE
└─ Expose via Elixir services
```

---

## Issue Analysis & Recommendations

### Issue 1: RCA Metrics Format

**Problem:** Parser outputs RCA metrics as strings
```rust
pub struct RcaMetrics {
    pub cyclomatic_complexity: String,  // ❌ String!
    pub halstead_metrics: String,       // ❌ String!
    pub maintainability_index: String,  // ❌ String!
}
```

**Better:** Code engine expects numbers
```rust
pub struct CodebaseMetadata {
    pub cyclomatic_complexity: f64,     // ✅ Number
    pub maintainability_index: f64,     // ✅ Number
    pub halstead_volume: f64,           // ✅ Number
}
```

**Recommendation:**
- Parser: Calculate metrics as numbers, not strings
- Code engine: Aggregate numbers into CodebaseMetadata
- Time to fix: 1-2 hours

### Issue 2: Redundant Modules

**Parser has:** `dependencies.rs` (extract from AST)
**Code engine has:** `analysis/dependency/` (build graphs)
**Code engine has:** `analysis/graph/` (PageRank, cycles)

**Current status:** Actually OK - clean separation
- Parser: What statements exist?
- Code engine: What are the relationships?

**No action needed** - separation is correct.

### Issue 3: "Intelligence" in Parser

**Current:** Parser includes:
- `central_heuristics.rs` - Heuristic analysis
- `refactoring_suggestions.rs` - Code improvement suggestions

**Problem:** These are analysis/interpretation, not parsing

**Recommendation:** Move to Code Engine
- Parser should output facts (AST, metrics)
- Code engine should output insights (suggestions, patterns)
- Time to refactor: 2-3 hours

---

## Graph Algorithms: Where Do They Belong?

### PageRank & Centrality
**Current:** Code engine (`code_engine/src/analysis/graph/pagerank.rs`)
**Correct?** ✅ YES
- Input: Dependency graph (from parser output)
- Output: Centrality scores (part of metadata)
- This is analysis, not parsing

### Cycle Detection
**Current:** Code engine (`code_engine/src/analysis/graph/`)
**Correct?** ✅ YES
- Input: Dependency graph
- Output: List of cycles
- This is analysis, not parsing

### Dependency Extraction
**Current:** Parser (`parser_engine/src/dependencies.rs`)
**Correct?** ✅ YES
- Input: AST
- Output: List of imports/requires
- This is parsing

### Graph Building
**Current:** Code engine (`code_engine/src/codebase/graphs.rs` and `analysis/graph/`)
**Correct?** ✅ YES
- Input: Parsed dependencies
- Output: PageRank scores, cycles, relationships
- This is analysis

---

## Summary: Proper Separation

### Parser Engine Should Have ✅
```
Language detection
AST extraction
Basic metrics (LOC, complexity, halstead) [as numbers!]
Structure analysis (functions, classes, imports)
Dependency extraction (what imports exist)
Tree-sitter analysis
```

### Code Engine Should Have ✅
```
Graph building from dependencies
PageRank calculation
Cycle detection
SCC analysis
Semantic embeddings
Architecture detection
Pattern detection
Metadata aggregation (100+ fields)
Intelligent naming
Evolution tracking
Semantic search
```

### Parser Engine Should NOT Have ❌
```
❌ Graph analysis (PageRank, cycles)
❌ Semantic interpretation
❌ Architecture detection
❌ Pattern analysis
❌ Heuristic insights
❌ Refactoring suggestions
❌ RCA metrics as strings [should be numbers]
```

---

## Migration Checklist (If Needed)

If you want to clean up the separation:

- [ ] Convert RCA metrics to numbers in Parser
- [ ] Remove `central_heuristics.rs` from Parser (move to Code Engine)
- [ ] Remove `refactoring_suggestions.rs` from Parser (move to Code Engine)
- [ ] Add "analysis" output struct in Parser (separate from parsing output)
- [ ] Document Parser output (AnalysisResult) as "structure only"
- [ ] Document Code Engine input as "AnalysisResult + graph building"

**Estimated effort:** 3-4 hours (low priority, current separation is mostly good)

---

## Conclusion

**Current separation is GOOD:**
- Parser focuses on syntax/structure
- Code engine focuses on semantics/intelligence
- Clear data flow (Parser → Code Engine → Elixir)
- Proper specialization

**Minor improvements possible:**
1. RCA metrics as numbers, not strings
2. Move "intelligent" modules from Parser to Code Engine
3. Add output struct documentation

**PageRank & Centrality are in CORRECT location:**
- Code engine (analysis layer) ✅
- Not in parser (would be parsing concern) ✅
- Ready for Elixir integration (next step)
