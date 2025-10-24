# Complete TODO Items - All Priority Levels

**Generated:** October 24, 2025
**Scope:** All tasks from documentation review, code review, and architecture analysis

---

## Summary by Priority

| Priority | Count | Effort | Impact |
|----------|-------|--------|--------|
| **CRITICAL** | 3 | 2-4 hours | Blocks production use |
| **HIGH** | 8 | 10-15 hours | Important for coherence |
| **MEDIUM** | 12 | 15-25 hours | Nice to have, improves quality |
| **LOW** | 9 | 10-20 hours | Polish and optimization |
| **BACKLOG** | 5 | 20+ hours | Future enhancements |
| **TOTAL** | **37 items** | **~80-90 hours** | |

---

## CRITICAL (Blocks Production) 🔴

### 1. Wire PageRank to Elixir (NIF Bridge)
- **Status:** PageRank algorithm 100% implemented in Rust, needs Elixir interface
- **Files:** Create `lib/singularity/graph/pagerank_calculator.ex`
- **What:** Build Elixir wrapper for Rust NIF PageRank
- **Steps:**
  1. Define NIF function in code_engine to call CentralPageRank
  2. Create Elixir module with `calculate/1` function
  3. Convert graph_edges table to HashMap input
  4. Store results back to graph_nodes or codebase_metadata
- **Effort:** 2-3 hours
- **Blockers:** None (implementation is ready)
- **Benefit:** PageRank scores immediately usable in Elixir

### 2. Store PageRank in AGE Graph
- **Status:** AGE setup complete, PageRank scores not yet stored
- **Files:** `singularity/priv/repo/migrations/*` (new migration)
- **What:** Add pagerank_score column to graph_nodes, populate from calculator
- **Steps:**
  1. Create migration: `add_pagerank_score_to_graph_nodes`
  2. Create job to calculate and store PageRank scores
  3. Add AGE query to fetch by PageRank score
- **Effort:** 1-2 hours
- **Blockers:** Item #1 (PageRank calculator must exist first)
- **Benefit:** Can query "top functions by importance" via Cypher

### 3. Complete Elixir Bridge for Code Engine NIF
- **Status:** Code engine exists, full Elixir interface incomplete
- **Files:** `lib/singularity/engines/code_engine.ex`
- **What:** Ensure ALL code_engine functions have Elixir wrappers
- **Current gaps:**
  - Metadata aggregation functions
  - Semantic search functions
  - Graph analysis functions
- **Effort:** 3-4 hours
- **Blockers:** None
- **Benefit:** Can call all code_engine features from Elixir

---

## HIGH (Important) 🟠

### 4. Convert Parser RCA Metrics to Numbers
- **Status:** Parser outputs RCA metrics as strings (wrong format)
- **Files:** `rust/parser_engine/src/lib.rs` (RcaMetrics struct)
- **What:** Change RCA metric output from String to f64/u64
- **Current:**
  ```rust
  cyclomatic_complexity: String,  // ❌
  halstead_metrics: String,       // ❌
  maintainability_index: String,  // ❌
  ```
- **Target:**
  ```rust
  cyclomatic_complexity: f64,     // ✅
  halstead_volume: f64,           // ✅
  maintainability_index: f64,     // ✅
  ```
- **Effort:** 1-2 hours
- **Blockers:** None
- **Benefit:** Metrics usable directly, no parsing needed

### 5. Move Intelligence Modules from Parser to Code Engine
- **Status:** Parser has modules that should be in code_engine
- **Files to move:**
  - `rust/parser_engine/src/central_heuristics.rs` → code_engine/analysis/
  - `rust/parser_engine/src/refactoring_suggestions.rs` → code_engine/analysis/
- **What:** Move analysis/insight logic from parser to code engine
- **Reason:** Parser should extract structure, not interpret
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Clean separation of concerns

### 6. Complete AI Metadata for 31 Modules
- **Status:** 11% complete (4/35 critical modules have full metadata)
- **Files:** All Elixir production modules need @moduledoc enhancement
- **What:** Add JSON, Mermaid diagrams, YAML call graphs, anti-patterns, keywords
- **Priority modules:**
  - All orchestrators (5 modules)
  - All supervisors (6 modules)
  - All services (10 modules)
- **Template:** `templates_data/code_generation/examples/AI_METADATA_QUICK_REFERENCE.md`
- **Effort:** 15-20 hours (30 min per module × 31 modules)
- **Blockers:** None
- **Benefit:** AI can navigate codebase without getting lost

### 7. Wire Instructor Validation to Code Generation Tools
- **Status:** Instructor framework exists, not fully integrated into generators
- **Files:** `lib/singularity/code_generation/generators/*.ex`
- **What:** Add output validation to all code generators
- **Current:** Quality generator has it, RAG and Pseudocode need it
- **Effort:** 2-3 hours
- **Blockers:** None (Instructor already integrated)
- **Benefit:** Guaranteed code quality from generators

### 8. Implement LLM Auto-Fix for Missing AI Metadata
- **Status:** Validator can detect missing metadata, auto-generation not complete
- **Files:** `lib/singularity/analysis/metadata_validator.ex`
- **What:** Use LLM to generate missing metadata fields
- **How:** Call InstructorAdapter.generate_validated_code for metadata generation
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Batch-generate metadata for all modules

### 9. Add Graph Edge Metadata (Criticality Level)
- **Status:** Edges exist, but no metadata (criticality, failure impact)
- **Files:** `singularity/lib/singularity/schemas/graph_edge.ex`
- **What:** Add columns to track edge importance
- **New fields:**
  - criticality_level: ENUM(optional, recommended, required)
  - failure_impact: ENUM(none, partial, critical)
- **Effort:** 1-2 hours
- **Blockers:** None
- **Benefit:** Can query "critical dependencies" or "high-risk changes"

### 10. Create Dashboard for Module Dependencies
- **Status:** Queries exist, no visualization
- **Files:** `singularity/lib/singularity/dashboard/dependency_graph.ex` (new)
- **What:** Web/dashboard view of AGE dependency graph
- **Features:**
  - Node size = PageRank score
  - Color = criticality level
  - Interactive filtering
- **Effort:** 4-5 hours
- **Blockers:** None
- **Benefit:** Visual understanding of architecture

### 11. Complete NATS Integration for All Engines
- **Status:** LLM NATS working, code_engine NATS incomplete
- **Files:** `lib/singularity/nats/execution_router.ex`
- **What:** Wire all code_engine functions to NATS topics
- **Current gaps:**
  - Code analysis requests
  - Semantic search requests
  - Graph analysis requests
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Can call code_engine from distributed services

---

## MEDIUM (Nice to Have) 🟡

### 12. Implement Betweenness Centrality
- **Status:** Not implemented, PageRank complete
- **Files:** Create `rust/code_engine/src/analysis/graph/betweenness.rs`
- **What:** Find bottlenecks and critical intermediary nodes
- **Algorithm:** Floyd-Warshall shortest paths, count intermediaries
- **Effort:** 3-4 hours
- **Blockers:** None
- **Benefit:** Identify critical bridge modules

### 13. Implement Closeness Centrality
- **Status:** Not implemented
- **Files:** Create `rust/code_engine/src/analysis/graph/closeness.rs`
- **What:** Find hubs that are close to everything
- **Algorithm:** Average distance to all other nodes
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Identify "hub" utilities

### 14. Formalize Degree Centrality
- **Status:** Used in filtering, not as formal metric
- **Files:** `rust/code_engine/src/analysis/graph/degree.rs` (new)
- **What:** Proper in-degree and out-degree calculations
- **Effort:** 1-2 hours
- **Blockers:** None
- **Benefit:** Complete centrality measure set

### 15. Standardize Embedding Dimension (1536 vs 2560)
- **Status:** Currently using 2560-dim (Qodo + Jina concatenated)
- **Decision needed:** Keep 2560 or simplify to 1536?
- **Pro 2560:** Better quality (dual-model strength)
- **Con 2560:** 2x storage, 2x inference time
- **Pro 1536:** Faster, smaller, still good quality
- **Effort:** 2-4 hours to refactor if changing
- **Blockers:** None (current 2560 is fine)
- **Benefit:** Clarity + performance decision

### 16. Add Embedding Quality Metrics
- **Status:** Embeddings work, quality not measured
- **Files:** `lib/singularity/embedding/quality_tracker.ex`
- **What:** Track embedding consistency, drift, quality over time
- **Metrics:**
  - Semantic stability (same input → same embedding)
  - Model drift (embeddings changing over time)
  - Retrieval quality (search result relevance)
- **Effort:** 3-4 hours
- **Blockers:** None
- **Benefit:** Monitor embedding health

### 17. Implement Community Detection (Graph Clustering)
- **Status:** Not implemented
- **Files:** Create `rust/code_engine/src/analysis/graph/community.rs`
- **What:** Find clusters of tightly-coupled modules
- **Algorithm:** Louvain or similar modularity optimization
- **Effort:** 4-5 hours
- **Blockers:** None
- **Benefit:** Identify potential microservices

### 18. Create Codebase Evolution Timeline
- **Status:** Evolution tracking exists but not exposed
- **Files:** `lib/singularity/timeline/codebase_evolution.ex`
- **What:** Track how codebase changes over time (metrics, structure, complexity)
- **Features:**
  - Complexity growth chart
  - Module dependency growth
  - Code smell trends
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** See codebase maturity/degradation trends

### 19. Implement Intelligent Module Naming
- **Status:** Code engine has skeleton, not integrated
- **Files:** `lib/singularity/analysis/intelligent_naming.ex`
- **What:** Suggest better names for modules/functions based on context
- **Data:** Use semantic embeddings + call graph + functionality
- **Effort:** 3-4 hours
- **Blockers:** None (framework exists)
- **Benefit:** Improve code readability

### 20. Add Code Health Score Dashboard
- **Status:** Metrics exist, no dashboard
- **Files:** `lib/singularity/dashboard/health_score.ex`
- **What:** Overall codebase health metric combining:
  - Complexity score
  - Test coverage
  - Technical debt
  - Security issues
  - Documentation coverage
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Executive-level codebase visibility

### 21. Implement Performance Regression Detection
- **Status:** Not implemented
- **Files:** Create `lib/singularity/analysis/performance_regression.ex`
- **What:** Alert when code changes introduce performance risks
- **Detection:** Complexity jumps, dependency additions, LOC growth
- **Effort:** 2-3 hours
- **Blockers:** Evolution timeline (item #18)
- **Benefit:** Proactive performance monitoring

### 22. Create Dependency Constraint System
- **Status:** Dependencies tracked, no constraints/policies
- **Files:** Create `lib/singularity/architecture/dependency_constraints.ex`
- **What:** Define and enforce architectural rules
- **Examples:**
  - "Controllers can't import Services"
  - "Util modules can't import Domain"
  - "No circular dependencies allowed"
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Enforce architecture boundaries

### 23. Implement Security-Aware Code Search
- **Status:** Semantic search exists, security context missing
- **Files:** Extend `lib/singularity/search/semantic_code_search.ex`
- **What:** Add security classification to code chunks
- **Features:**
  - Find all authentication code
  - Find all encryption usage
  - Find potential vulnerability patterns
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Security analysis faster

---

## LOW (Polish & Optimization) 🟢

### 24. Add Rust NIF Performance Metrics
- **Status:** Engines work, no performance tracking
- **Files:** `lib/singularity/infrastructure/nif_performance.ex`
- **What:** Track NIF call latency, memory usage
- **Metrics:**
  - Parse time per file
  - Graph calculation time
  - Embedding inference time
- **Effort:** 1-2 hours
- **Blockers:** None
- **Benefit:** Identify bottlenecks

### 25. Implement NIF Result Caching
- **Status:** Some caching exists, not comprehensive
- **Files:** Enhance existing cache modules
- **What:** Cache expensive NIF operations
- **Examples:**
  - Parser output for unchanged files
  - PageRank scores (expensive to recalculate)
  - Embeddings (expensive to generate)
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** 10-50x speedup for repeated queries

### 26. Add Rust Code Documentation Generation
- **Status:** Elixir has doc templates, Rust is minimal
- **Files:** Add @doc comments to all Rust NIF functions
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Better Rust code maintainability

### 27. Create Integration Tests for Parser → Code Engine Pipeline
- **Status:** Unit tests exist, integration tests limited
- **Files:** `test/integration/parser_to_engine_test.exs`
- **What:** Test full pipeline: parse → analyze → store → query
- **Effort:** 3-4 hours
- **Blockers:** None
- **Benefit:** Catch integration bugs early

### 28. Implement Async Batch Metadata Calculation
- **Status:** Metadata calculated per-file, not batched
- **Files:** `lib/singularity/jobs/metadata_batch_job.ex`
- **What:** Calculate PageRank, embeddings, analysis in parallel batches
- **Effort:** 2-3 hours
- **Blockers:** Item #1 (PageRank calculator)
- **Benefit:** 5-10x faster for large codebases

### 29. Add Visualization Export (GraphViz)
- **Status:** PageRank has export_dot(), not exposed
- **Files:** `lib/singularity/export/graph_visualization.ex`
- **What:** Export graphs to GraphViz, SVG, PNG
- **Effort:** 1-2 hours
- **Blockers:** None
- **Benefit:** Printable architecture diagrams

### 30. Implement Code Smell Trend Analysis
- **Status:** Smells detected, trends not tracked
- **Files:** Create `lib/singularity/analysis/smell_trends.ex`
- **What:** Alert when code smell count increases
- **Effort:** 1-2 hours
- **Blockers:** Evolution timeline (item #18)
- **Benefit:** Proactive code quality monitoring

### 31. Add Comprehensive Error Recovery
- **Status:** Some error handling, not comprehensive
- **Files:** Various `.ex` files
- **What:** Add retry logic, graceful degradation, better error messages
- **Effort:** 3-4 hours
- **Blockers:** None
- **Benefit:** Better reliability in production

### 32. Create Developer On-Boarding Guide
- **Status:** Architecture docs exist, developer guide missing
- **Files:** `docs/DEVELOPER_ONBOARDING.md` (new)
- **What:** Step-by-step guide to understanding the codebase
- **Effort:** 2-3 hours
- **Blockers:** None
- **Benefit:** Faster onboarding for new devs

---

## BACKLOG (Future Enhancements) 📋

### 33. ~~Implement Neo4j as Secondary Graph DB~~ ❌ NOT NEEDED
- **Status:** REMOVED - PostgreSQL + AGE is sufficient for all use cases
- **Why:**
  - PageRank, Centrality, Community Detection all implementable in PostgreSQL
  - No unique Neo4j capability we need
  - Additional database = operational overhead
  - Same effort (~20-30 hours) to implement all Neo4j algorithms in Rust
- **Alternative:** See items #12-14, #17, #9 (implement algorithms in Rust instead)
- **Decision:** SKIP - focus on PostgreSQL/Rust implementations instead

### 34. Add Machine Learning for Code Generation
- **Status:** LLM-based generation working
- **Effort:** 20+ hours
- **Decision:** Future phase

### 35. Implement Distributed Codebase Analysis
- **Status:** Single-instance only
- **Effort:** 15+ hours
- **Decision:** When scaling needed

### 36. Add Interactive Web IDE Integration
- **Status:** CLI + MCP only
- **Effort:** 30+ hours
- **Decision:** Future phase

### 37. Implement Cross-Repository Analysis
- **Status:** Single repo only
- **Effort:** 10+ hours
- **Decision:** When analyzing multiple repos needed

---

## Implementation Order (Recommended)

### Week 1 (Critical - 5-9 hours)
1. ✅ Wire PageRank to Elixir (#1)
2. ✅ Store PageRank in AGE (#2)
3. ✅ Complete code_engine NIF bridge (#3)

### Week 2 (High - 10-15 hours)
4. ✅ Convert Parser RCA metrics (#4)
5. ✅ Move Parser intelligence modules (#5)
6. ✅ Auto-fix missing AI metadata (#8)
7. ✅ Wire Instructor to generators (#7)

### Week 3-4 (High continuation - 8-12 hours)
8. ✅ Add graph edge metadata (#9)
9. ✅ Complete AI metadata for modules (#6)
10. ✅ Create dashboard (#10)
11. ✅ NATS integration (#11)

### Week 5+ (Medium & Low - As time permits)
12. ✅ Implement centrality measures (#12-14)
13. ✅ Add performance tracking (#24-28)
14. ✅ Implement security search (#23)
15. ✅ Evolution timeline (#18)

---

## Effort Estimation

| Phase | Items | Effort | Timeline |
|-------|-------|--------|----------|
| **Critical** | 3 | 5-9 hours | 1-2 days |
| **High** | 8 | 18-25 hours | 1 week |
| **Medium** | 12 | 30-40 hours | 1-2 weeks |
| **Low** | 9 | 15-25 hours | 1-2 weeks |
| **Backlog** | 4 | 50+ hours | Q4 2025+ |
| **TOTAL** | **36** | **~120-140 hours** | **4-6 weeks** |

*Note: Neo4j (#33) removed - PostgreSQL + AGE + Rust algorithms provide all needed functionality*

---

## Quick Reference by Category

### Graph & Centrality
- #1: Wire PageRank to Elixir ⭐ CRITICAL
- #2: Store PageRank in AGE ⭐ CRITICAL
- #9: Add graph edge metadata 🟠
- #12-14: Implement centrality measures 🟡
- #17: Community detection 🟡
- #29: Visualization export 🟢

### Code Quality & Analysis
- #6: Complete AI metadata 🟠
- #15-16: Embedding standardization 🟡
- #18: Evolution timeline 🟡
- #20: Health score dashboard 🟡
- #21: Performance regression 🟡
- #30: Code smell trends 🟢

### Architecture & Design
- #4: Parser RCA metrics 🟠
- #5: Move Parser modules 🟠
- #9: Graph edge metadata 🟠
- #22: Dependency constraints 🟡
- #23: Security-aware search 🟡

### Tooling & Infrastructure
- #3: Code engine NIF bridge 🔴
- #7: Instructor validation 🟠
- #8: Auto-fix metadata 🟠
- #10: Dependency dashboard 🟠
- #11: NATS integration 🟠
- #24: NIF performance metrics 🟢
- #25: NIF caching 🟢
- #27: Integration tests 🟢
- #28: Batch calculation 🟢
- #31: Error recovery 🟢

---

## Dependencies

```
#1 (PageRank Elixir)
  ↓ (required by)
#2 (Store in AGE)
#9 (Edge metadata)
#12-14 (Centrality measures)
#28 (Batch calculation)

#6 (AI Metadata)
  ↓ (enhanced by)
#8 (Auto-fix)

#18 (Evolution Timeline)
  ↓ (required by)
#21 (Performance regression)
#30 (Smell trends)

#4 (Parser Metrics)
  ↓ (prerequisite for)
#6 (AI Metadata)
```

---

## Success Metrics

After completing all items:
- ✅ 100% of modules have AI metadata
- ✅ PageRank scores queryable via AGE
- ✅ All centrality measures calculated
- ✅ Dashboard showing dependencies + health
- ✅ Automatic code quality monitoring
- ✅ Performance regression detection
- ✅ Security-aware code search
- ✅ 5-10x faster metadata calculation (caching)
