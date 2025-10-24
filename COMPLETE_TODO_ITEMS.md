# Complete TODO Items - All Priority Levels (43 Items)

**Generated:** October 24, 2025
**Updated:** October 25, 2025 (Added 7 critical/missing items)
**Scope:** All tasks from documentation review, code review, architecture analysis, debt audit, observability, testing

---

## Summary by Priority

| Priority | Count | Effort | Impact |
|----------|-------|--------|--------|
| **CRITICAL** | 3 | 5-9 hours | Blocks production use |
| **HIGH** | 11 | 25-40 hours | Important for coherence, production-ready |
| **MEDIUM** | 14 | 35-50 hours | Nice to have, improves quality |
| **LOW** | 11 | 18-30 hours | Polish and optimization |
| **BACKLOG** | 4 | 50+ hours | Future enhancements |
| **TOTAL** | **43 items** | **~150-180 hours** | **4-6 weeks full-time** |

**Key Additions:**
- NEW #37: Resolve 86 embedded TODOs (debt triage)
- NEW #38: Observability for 72 GenServers/Agents (production-ready)
- NEW #39: TypeScript test coverage for AI server (reliability)
- NEW #40: Comment 4,751 private functions (maintainability)
- NEW #41: Complete Rust NIF stubs (architecture analysis)
- NEW #42: Test coverage dashboard (visibility)
- NEW #43: LLM-assisted comment generation (acceleration)

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

### 37. Resolve 86 Embedded TODOs/FIXMEs in Elixir Code
- **Status:** 86 TODO/FIXME comments scattered across singularity/lib
- **Files:** All `*.ex` files in `singularity/lib`
- **What:** Audit, classify, and prioritize all embedded work comments
- **Current state:** No visibility into scattered work items
- **Process:**
  1. Extract all TODO/FIXME/XXX/HACK comments:
     ```bash
     grep -r "TODO\|FIXME\|XXX\|HACK" singularity/lib --include="*.ex" | tee TODO_AUDIT.txt
     ```
  2. Classify by severity:
     - CRITICAL (5-10 items): Production blockers
     - HIGH (20-30 items): Important features
     - MEDIUM (30-40 items): Improvements
     - LOW (10-15 items): Informational/future
  3. Move CRITICAL items → COMPLETE_TODO_ITEMS.md
  4. Archive MEDIUM/LOW → separate `TECHNICAL_DEBT.md` reference doc
- **Effort:** 2-3 hours (audit + triage)
- **Priority:** HIGH (blocks visibility)
- **Benefit:** Single source of truth for all work items
- **Blocker:** None

### 38. Add Observability/Telemetry to 72 GenServers/Agents
- **Status:** 72 processes exist (GenServers, Agents, DynamicSupervisors), telemetry incomplete
- **Files:**
  - `lib/singularity/**/*supervisor.ex` (6+ supervisors)
  - `lib/singularity/jobs/*.ex` (GenServer jobs)
  - `lib/singularity/*orchestrator.ex` (5+ orchestrators)
- **What:** Instrument all processes with observability metrics
- **Metrics per process:**
  - Process startup/shutdown events
  - Message queue depth
  - Error rates and types
  - Execution time per operation
  - Memory usage trends
- **Template:** Extend existing telemetry patterns from `lib/singularity/telemetry.ex`
- **Implementation:**
  ```elixir
  # In each GenServer:
  :telemetry.execute([:process, :started], %{pid: self(), module: __MODULE__})
  # On handle_call:
  :telemetry.execute([:process, :operation], %{time: time_ms, status: status})
  # On error:
  :telemetry.execute([:process, :error], %{error: error, severity: severity})
  ```
- **Effort:** 5-8 hours (systematic instrumentation)
- **Priority:** HIGH → CRITICAL (production readiness)
- **Benefit:** Observability for distributed debugging, performance bottleneck identification
- **Blocker:** None (framework exists in `lib/singularity/telemetry.ex`)

### 39. Add TypeScript/Bun Test Coverage for AI Server
- **Status:** 35 TypeScript source files, 0 tests
- **Files:** `llm-server/src/*.ts` all untested
- **What:** Create comprehensive test suite for AI provider integration
- **Current gaps:**
  - No unit tests for provider abstraction
  - No integration tests for NATS communication
  - No mock tests for LLM provider responses
- **Test areas:**
  1. Provider selection logic (model routing)
  2. NATS message handling (subscribe/publish)
  3. LLM provider integration (Claude, Gemini, OpenAI, Copilot)
  4. Error handling and retries
  5. Cost optimization logic
- **Framework:** Vitest or Bun's native test runner
- **Effort:** 4-6 hours (test setup + core coverage)
- **Priority:** HIGH (AI server is critical path)
- **Benefit:** Catch AI integration bugs before production, ensure provider reliability
- **Blocker:** None

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

### 41. Complete Rust NIF Stubs in Architecture Engine
- **Status:** Architecture engine has 20+ TODO stubs, partially implemented
- **Files:**
  - `rust/architecture_engine/src/patterns/*.rs` (4 stubs)
  - `rust/architecture_engine/src/architecture/*.rs` (3 stubs)
  - `rust/architecture_engine/src/code_evolution/*.rs` (3 stubs)
- **What:** Implement stubbed functions currently marked TODO
- **Stubs to complete:**
  1. `naming_patterns.rs::detect_naming_patterns()` - Identify naming convention violations
  2. `anti_pattern_detector.rs::detect_anti_patterns()` - Find architectural anti-patterns
  3. `pattern_detector.rs::detect_patterns()` - General pattern detection
  4. `component_analysis.rs::analyze_components()` - Component boundary analysis
  5. `architectural_patterns.rs::detect_architectural_patterns()` - Microservice/layered/etc patterns
  6. `layer_analysis.rs::analyze_layers()` - Vertical architecture layer detection
  7. `naming_evolution.rs::track_naming_evolution()` - Module naming changes over time
  8. `deprecated_detector.rs::detect_deprecated_code()` - Find deprecated modules/functions
  9. `change_analyzer.rs::analyze_changes()` - Code change impact analysis
- **Effort:** 6-8 hours (implement 9 functions)
- **Priority:** MEDIUM (improves architecture analysis)
- **Benefit:** Complete architecture engine capabilities, full feature parity with code_engine
- **Blocker:** None (but depends on #3 for production use)

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

### 40. Add Comments to 4,751 Private Functions
- **Status:** Private functions (defp/defmacrop) largely undocumented
- **Files:** All `singularity/lib/**/*.ex` files with `defp` definitions
- **What:** Add concise comments explaining purpose and invariants
- **Approach:**
  1. Identify all `defp` and `defmacrop` definitions (4,751 found)
  2. Add 1-3 line comment per function explaining:
     - Purpose (what does this do?)
     - Key invariants (pre-conditions)
     - Error conditions (when does this fail?)
  3. Template:
     ```elixir
     # Validates input format and returns normalized tuple.
     # Raises ArgumentError if input is malformed.
     defp validate_and_normalize(input) do
       ...
     end
     ```
- **Note:** Use comments (not @doc) for private functions to avoid compilation warnings
- **Effort:** 8-12 hours (comment-only, systematic pass through codebase)
- **Priority:** LOW (documentation, not blocking functionality)
- **Benefit:** Better code maintainability, AI comprehension, faster debugging
- **Blocker:** None

### 42. Create Test Coverage Report Dashboard
- **Status:** 96 test files exist (Elixir), coverage not visualized
- **Files:** `lib/singularity/dashboard/test_coverage.ex` (new)
- **What:** Create dashboard showing test coverage metrics
- **Features:**
  - Overall coverage % (current: unknown)
  - Module-by-module coverage breakdown
  - Low-coverage modules (< 70%) highlighted
  - Coverage trends over time
  - Test execution time per module
- **Implementation:**
  1. Configure ExCoveralls in mix.exs
  2. Generate HTML coverage report
  3. Create dashboard parsing ExCoveralls JSON output
  4. Display in web interface or text format
- **Effort:** 2-3 hours
- **Priority:** LOW (nice-to-have visibility)
- **Benefit:** Visibility into test health, identify gaps in coverage
- **Blocker:** None

### 43. Add LLM-Assisted Code Comment Generation
- **Status:** 4,751 private functions need comments (item #40 above)
- **Files:** Create `lib/singularity/tools/comment_generator.ex` (new)
- **What:** Tool to batch-generate comments for private functions using LLM
- **How it works:**
  1. Parse module AST to extract all `defp` functions
  2. For each function: call `LLM.Service(:simple, prompt)`
  3. Prompt asks LLM to generate 1-3 line comment explaining function
  4. Return suggestions for human review
  5. Optionally auto-insert into source
- **Implementation:**
  ```elixir
  defmodule Singularity.Tools.CommentGenerator do
    def generate_comments_for_module(module_path) do
      # 1. Parse module AST
      # 2. Extract all defp functions with current comments
      # 3. For each missing comment:
      #    - call LLM.Service(:simple, "Add comment to: #{code}")
      #    - return {function_name, suggested_comment}
      # 4. Display suggestions for review
    end

    def generate_comments_for_codebase(codebase_path) do
      # Batch process all modules in parallel
      # Generate 4,751 comments in ~2-3 hours instead of 40-60 hours
    end
  end
  ```
- **Effort:** 3-4 hours (tool implementation)
- **Priority:** MEDIUM → LOW (accelerates item #40 by 10x)
- **Benefit:** 10x faster comment generation (30 min per module → 3 min per module)
- **Blocker:** None (LLM.Service ready)
- **Note:** Accelerator tool for item #40, not required but highly recommended

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

### Week 1 (Critical Path - 5-9 hours)
1. ⭐ Wire PageRank to Elixir (#1)
2. ⭐ Store PageRank in AGE (#2)
3. ⭐ Complete code_engine NIF bridge (#3)

### Week 2 (Debt & Production-Ready - 12-16 hours)
4. ⭐ Resolve 86 embedded TODOs (#37) - Highest ROI, unblocks hidden work
5. ⭐ Add observability to 72 GenServers (#38) - Production-ready instrumentation
6. ⭐ TypeScript test coverage for AI server (#39) - Critical path reliability
7. Convert Parser RCA metrics (#4)
8. Move Parser intelligence modules (#5)

### Week 3 (High Priority - 15-20 hours)
9. Auto-fix missing AI metadata (#8)
10. Wire Instructor to generators (#7)
11. Add graph edge metadata (#9)
12. Complete AI metadata for modules (#6) - Can parallelize with #43 (LLM-assisted)
13. Create dashboard (#10)

### Week 4 (High + Early Medium - 12-15 hours)
14. NATS integration (#11)
15. Add comments to 4,751 private functions (#40) - Use #43 (LLM tool) to accelerate
16. LLM-assisted comment generation tool (#43) - Implement FIRST to accelerate #40
17. Complete Rust NIF stubs (#41) - Architecture engine completion

### Week 5+ (Medium & Low - As time permits)
18. Implement centrality measures (#12-14)
19. Add performance tracking (#24-28)
20. Implement security search (#23)
21. Evolution timeline (#18)
22. Additional items as needed

**Note:** New items #37-43 prioritized for debt reduction and production-readiness
- Item #37 (TODO audit) should be FIRST to uncover any hidden blockers
- Items #38-39 improve production reliability significantly
- Item #43 (LLM tool) should be done BEFORE #40 (comments) to achieve 10x speedup

---

## Effort Estimation (Updated with 7 New Items)

| Phase | Items | Effort | Timeline |
|-------|-------|--------|----------|
| **Critical** | 3 | 5-9 hours | 1 day |
| **High** | 11 | 40-55 hours | 2 weeks (includes new debt items) |
| **Medium** | 14 | 42-62 hours | 2-3 weeks |
| **Low** | 11 | 21-33 hours | 1-2 weeks |
| **Backlog** | 4 | 50+ hours | Q4 2025+ |
| **TOTAL** | **43** | **~150-180 hours** | **4-6 weeks full-time** |

**Breakdown of New Items:**
- #37 (TODO audit): 2-3 hours
- #38 (Observability): 5-8 hours
- #39 (TypeScript tests): 4-6 hours
- #40 (Private function comments): 8-12 hours (or 1-2 hours with #43)
- #41 (Rust stubs): 6-8 hours
- #42 (Coverage dashboard): 2-3 hours
- #43 (LLM comment tool): 3-4 hours

**Strategic Approach:**
- If doing #40 manually: +40-48 hours (8-12 hours × multiple modules)
- If doing #43 first: -35 hours (tool generates most comments, only review needed)
- Net gain from #43: ~35 hours saved (70% efficiency improvement)

*Note: Neo4j (#33) removed - PostgreSQL + AGE + Rust algorithms provide all needed functionality*

---

## Quick Reference by Category

### Critical Path (Week 1 - Do First!)
- #1: Wire PageRank to Elixir ⭐ CRITICAL
- #2: Store PageRank in AGE ⭐ CRITICAL
- #3: Code engine NIF bridge ⭐ CRITICAL

### Debt & Production-Ready (Week 2 - New Priority!)
- #37: Resolve 86 embedded TODOs ⭐ HIGH (highest ROI)
- #38: Observability for 72 GenServers ⭐ HIGH (production-ready)
- #39: TypeScript test coverage for AI ⭐ HIGH (reliability)

### Graph & Centrality
- #1: Wire PageRank to Elixir ⭐ CRITICAL
- #2: Store PageRank in AGE ⭐ CRITICAL
- #9: Add graph edge metadata 🟠
- #12-14: Implement centrality measures 🟡
- #17: Community detection 🟡
- #29: Visualization export 🟢

### Code Quality & Analysis
- #6: Complete AI metadata 🟠
- #8: Auto-fix missing metadata 🟠
- #15-16: Embedding standardization 🟡
- #18: Evolution timeline 🟡
- #20: Health score dashboard 🟡
- #21: Performance regression 🟡
- #30: Code smell trends 🟢
- #40: Comments for private functions 🟢 (accelerated by #43)
- #42: Test coverage dashboard 🟢
- #43: LLM-assisted comment generation 🟢 (do BEFORE #40)

### Architecture & Design
- #4: Parser RCA metrics 🟠
- #5: Move Parser modules 🟠
- #9: Graph edge metadata 🟠
- #22: Dependency constraints 🟡
- #23: Security-aware search 🟡
- #41: Complete Rust NIF stubs 🟡

### Tooling & Infrastructure
- #3: Code engine NIF bridge 🔴
- #7: Instructor validation 🟠
- #10: Dependency dashboard 🟠
- #11: NATS integration 🟠
- #24: NIF performance metrics 🟢
- #25: NIF caching 🟢
- #26: Rust documentation 🟢
- #27: Integration tests 🟢
- #28: Batch calculation 🟢
- #31: Error recovery 🟢
- #32: Developer onboarding 🟢

---

## Dependencies

```
🔴 CRITICAL PATH (Blocking):
#1 (PageRank Elixir)
  ↓ (required by)
  ├─ #2 (Store in AGE)
  ├─ #9 (Edge metadata)
  ├─ #12-14 (Centrality measures)
  └─ #28 (Batch calculation)

⭐ HIGHEST ROI (Do Early):
#37 (TODO Audit) → Uncovers hidden blockers
#38 (Observability) → Enables production use
#39 (TypeScript Tests) → Improves AI server reliability

🎯 ACCELERATION CHAIN (Do in Order):
#43 (LLM Comment Tool)
  ↓ (accelerates by 10x)
  #40 (Private Function Comments)

📊 QUALITY CHAIN:
#6 (AI Metadata)
  ↓ (enhanced by)
  #8 (Auto-fix)

⏱️ TIME-SERIES CHAIN:
#18 (Evolution Timeline)
  ↓ (required by)
  ├─ #21 (Performance regression)
  └─ #30 (Smell trends)

🏗️ ARCHITECTURE CHAIN:
#4 (Parser Metrics)
  ↓ (prerequisite for better)
  #6 (AI Metadata)

#3 (Code Engine Bridge)
  ↓ (enables)
  #41 (Rust NIF Stubs - optional)

📝 NOTE: No blocking dependencies between most items - highly parallelizable!
Maximum concurrency: weeks 2-4 can run 3-4 items simultaneously
```

---

## Success Metrics

**After completing all 43 items:**

### Architecture & Code Understanding
- ✅ 100% of critical modules have AI metadata (v2.5.0 complete)
- ✅ PageRank scores queryable and visible via AGE/Cypher
- ✅ All centrality measures calculated (PageRank, Betweenness, Closeness, Degree)
- ✅ Codebase communities detected (microservice boundary identification)
- ✅ 4,751 private functions documented with comments
- ✅ All 86+ embedded TODOs triaged and prioritized

### Production Readiness
- ✅ 72 GenServers/Agents fully observable (telemetry instrumentation)
- ✅ AI server (35 TS files) fully tested and reliable
- ✅ Comprehensive error recovery across codebase
- ✅ NIF engines (parser, code_engine, architecture) fully bridged to Elixir
- ✅ All Rust stubs completed (architecture engine feature parity)
- ✅ Integration tests covering parser → code_engine pipeline

### Quality & Monitoring
- ✅ Dashboard showing dependencies + health + coverage
- ✅ Automatic code quality monitoring (health scores)
- ✅ Performance regression detection enabled
- ✅ Code smell trend analysis operational
- ✅ Security-aware code search functional
- ✅ Evolution timeline tracking codebase maturity

### Performance
- ✅ 5-10x faster metadata calculation via caching
- ✅ NIF performance metrics instrumented and visible
- ✅ Batch metadata calculation optimized
- ✅ Embedding quality metrics tracked

### Debt & Technical Health
- ✅ Zero scattered TODOs (all consolidated)
- ✅ Full observability into process health
- ✅ Comprehensive test coverage reported
- ✅ Developer onboarding guide complete

---

## Implementation Strategy

### Phase 1: Unblock Production (Week 1-2, 17-25 hours)
**Goal:** Get PageRank working + fix critical issues + reduce technical debt

1. Week 1 (5-9 hours):
   - #1 Wire PageRank to Elixir
   - #2 Store PageRank in AGE
   - #3 Code engine NIF bridge

2. Week 2 (12-16 hours):
   - #37 Resolve TODOs (highest ROI)
   - #38 Observability (production-ready)
   - #39 TypeScript tests (reliability)
   - #4-5 Architecture cleanup

**Parallelization:** Items #37, #38, #39 can run in parallel - assign to different developers/streams

### Phase 2: Quality Foundation (Week 3-4, 27-35 hours)
**Goal:** Complete AI metadata + improve code quality + create dashboards

1. #43 LLM Comment Tool (FIRST - accelerates #40 by 10x)
2. #6 AI Metadata completion (can parallelize with #8)
3. #8 Auto-fix metadata
4. #40 Private function comments (accelerated by #43)
5. #9 Graph edge metadata
6. #10 Dependency dashboard

**Parallelization:** #6/#8, #43/#40, and #9/#10 can run in parallel

### Phase 3: Full Capabilities (Week 5+, 80+ hours)
**Goal:** Complete graph analysis, monitoring, and nice-to-haves

- Centrality measures (#12-14, #17)
- Evolution timeline (#18)
- Performance monitoring (#21, #24-28)
- Security analysis (#23)
- Rust stubs (#41)

**Recommended:** Do #43 first if doing #40 (saves 35+ hours)

---

## New Item Summary (Items #37-43)

| # | Item | Why Added | Impact |
|---|------|-----------|--------|
| 37 | Resolve 86 TODOs | Scattered work items, no visibility | HIGH - Uncovers hidden work |
| 38 | 72 GenServer observability | Not instrumented, can't debug production | HIGH - Production-ready |
| 39 | TS test coverage | 35 files, 0 tests, critical path | HIGH - Reliability |
| 40 | Comment 4,751 functions | Undocumented private code | LOW - Maintainability |
| 41 | Complete Rust stubs | 20+ unfinished functions | MEDIUM - Feature completeness |
| 42 | Coverage dashboard | Can't see test health | LOW - Visibility |
| 43 | LLM comment tool | Accelerates #40 by 10x | MEDIUM - Force multiplier |

**Total New Effort:** 30-44 hours, but enables 150-180 total hours of work to be done efficiently
