# Table Renaming Recommendations - Longer, Self-Explanatory Names

**Philosophy**: Internal tooling = ZERO ambiguity. Favor clarity over brevity!

## High Priority Renames

### Package/Tool Tables (MAJOR CONFUSION)

| Current | Better | Reason |
|---------|--------|--------|
| `tools` | `external_package_registry` | "tools" is vague - these are npm/cargo/hex/pypi packages |
| `tool_knowledge` | `package_registry_knowledge` | Make it clear: external package knowledge, not internal tools |
| `tool_patterns` | `package_usage_patterns` | How packages are used in practice |
| `tool_examples` | `package_code_examples` | Code examples from package documentation |
| `tool_dependencies` | `package_dependency_graph` | Dependencies between packages |
| `dependency_catalog` | `external_package_catalog` | Already good, but make "external" explicit |

**Result**: Clear distinction between YOUR code and EXTERNAL packages!

### Store Prefix Tables (BACKWARDS)

| Current | Better | Reason |
|---------|--------|--------|
| `store_code_artifacts` | `code_artifacts` | Just drop "store" - redundant |
| `store_codebase_services` | `codebase_service_registry` | Registry is clearer than store |
| `store_git_state` | `git_state_snapshots` | Snapshots explains WHAT is stored |
| `store_knowledge_artifacts` | **DUPLICATE?** Merge with `knowledge_artifacts` | Same purpose? |
| `store_packages` | **DUPLICATE?** Merge with `external_package_registry` | Same purpose? |
| `store_templates` | **DUPLICATE?** Merge with `code_generation_templates` | Same purpose? |

### Template Tables (CONSOLIDATE)

| Current | Better | Reason |
|---------|--------|--------|
| `templates` | `code_generation_templates` | What kind of templates? Code generation! |
| `technology_templates` | `technology_stack_templates` | Templates for tech stacks (Elixir/Phoenix, Rust/Axum, etc.) |
| `store_templates` | **REMOVE** - merge into above | Duplicate? |

### Knowledge Tables (CLARIFY PURPOSE)

| Current | Better | Reason |
|---------|--------|--------|
| `knowledge_artifacts` | `curated_knowledge_artifacts` | Git ↔ DB learning (curated templates/patterns/prompts) |
| `technology_knowledge` | `detected_technology_knowledge` | Auto-detected from codebase scanning |
| `tool_knowledge` | `package_registry_knowledge` | External package metadata (see above) |
| `store_knowledge_artifacts` | **REMOVE** - duplicate of curated_knowledge_artifacts | Same? |

### Graph Tables (MISSING CONTEXT)

| Current | Better | Reason |
|---------|--------|--------|
| `graph_nodes` | `task_decomposition_graph_nodes` | HTDAG task graph nodes |
| `graph_edges` | `task_decomposition_graph_edges` | HTDAG task dependencies |
| `graph_types` | `task_decomposition_graph_types` | Types of task nodes |

**OR** if for package dependencies:
- `package_dependency_graph_nodes`
- `package_dependency_graph_edges`
- `package_dependency_graph_types`

### Generic Names (ADD CONTEXT)

| Current | Better | Reason |
|---------|--------|--------|
| `rules` | `agent_behavior_confidence_rules` | Rule engine for agent decision-making |
| `capabilities` | `agent_capability_registry` | What agents can do (tools/skills) |
| `features` | `safe_methodology_features` | SAFe Agile features |
| `epics` | `safe_methodology_epics` | SAFe Agile epics |
| `strategic_themes` | `safe_methodology_strategic_themes` | Already good, but add SAFe prefix for consistency |

### Cache Tables (CONSOLIDATE DUPLICATES?)

| Current | Better | Reason |
|---------|--------|--------|
| `cache_code_embeddings` | `code_embedding_cache` | Flip to noun-first |
| `cache_llm_responses` | `llm_response_cache` | Flip to noun-first |
| `cache_memory` | `agent_memory_cache` | What memory? Agent memory! |
| `cache_semantic_similarity` | `semantic_similarity_cache` | Flip to noun-first |
| `semantic_cache` | **REMOVE** - duplicate of above? | Same as cache_semantic_similarity? |
| `vector_similarity_cache` | **REMOVE** - duplicate of semantic_similarity_cache? | Same thing? |

## Medium Priority Renames

### Code Analysis Tables

| Current | Better | Reason |
|---------|--------|--------|
| `code_embeddings` | `codebase_chunk_embeddings` | Embeddings OF codebase chunks |
| `code_fingerprints` | `codebase_file_fingerprints` | Fingerprints OF files (hashes, AST) |
| `code_locations` | `codebase_symbol_locations` | WHERE symbols are defined |

### Runner Tables (OK if adding context)

| Current | Better | Reason |
|---------|--------|--------|
| `runner_analysis_executions` | `rust_analysis_tool_executions` | Runner = Rust analysis tools |
| `runner_rust_operations` | `rust_operation_executions` | Rust-specific operations |
| `runner_tool_executions` | `rust_tool_execution_history` | History of Rust tool runs |

**OR** if "Runner" is a known concept:
- `agent_runner_analysis_executions`
- `agent_runner_rust_operations`
- `agent_runner_tool_executions`

## Summary by Category

### YOUR Codebase (Internal)
- `codebase_chunks` - Your code, chunked for search ✅
- `codebase_chunk_embeddings` - Vectors of your code
- `codebase_file_fingerprints` - Hashes/AST of your files
- `codebase_symbol_locations` - Symbol definitions (functions, classes)
- `codebase_metadata` - Metadata about your repos ✅
- `codebase_registry` - Registry of your codebases ✅
- `codebase_snapshots` - Historical snapshots ✅
- `codebase_service_registry` - Services in your codebase

### External Packages (Dependencies)
- `external_package_registry` - Main package table (npm/cargo/hex/pypi)
- `external_package_catalog` - Searchable package catalog
- `package_registry_knowledge` - Package metadata for search
- `package_usage_patterns` - How packages are used
- `package_code_examples` - Example code from package docs
- `package_dependency_graph` - Package dependencies
- `package_dependency_graph_nodes` - If using graph structure
- `package_dependency_graph_edges` - If using graph structure

### Knowledge & Templates
- `curated_knowledge_artifacts` - Git ↔ DB learning (templates/patterns/prompts)
- `detected_technology_knowledge` - Auto-detected tech from scanning
- `code_generation_templates` - Templates for code generation
- `technology_stack_templates` - Tech stack templates (Elixir/Phoenix, etc.)

### Framework & Technology Detection
- `framework_patterns` - Framework detection patterns ✅
- `technology_patterns` - Technology detection patterns ✅
- `semantic_patterns` - Semantic code patterns ✅

### Agent & Execution
- `agent_behavior_confidence_rules` - Rule engine for agents
- `agent_capability_registry` - Agent capabilities
- `agent_memory_cache` - Agent working memory
- `git_agent_sessions` - Agent Git sessions ✅
- `rust_analysis_tool_executions` - Rust analysis tool runs
- `rust_operation_executions` - Rust operations
- `rust_tool_execution_history` - Rust tool history

### Quality & Analysis
- `quality_findings` - Quality issues found ✅
- `quality_metrics` - Quality measurements ✅
- `quality_runs` - Quality check executions ✅
- `analysis_summaries` - Analysis results ✅

### Git Integration
- `git_commits` - Git commits ✅
- `git_merge_history` - Merge history ✅
- `git_pending_merges` - Pending merges ✅
- `git_sessions` - Git sessions ✅
- `git_state_snapshots` - Git state snapshots

### RAG & Search
- `rag_documents` - RAG document store ✅
- `rag_feedback` - RAG user feedback ✅
- `rag_queries` - RAG search queries ✅
- `vector_search` - Generic vector search ✅

### LLM Integration
- `llm_calls` - LLM API calls ✅
- `llm_response_cache` - Cached LLM responses

### Caching
- `code_embedding_cache` - Code embedding cache
- `llm_response_cache` - LLM response cache
- `agent_memory_cache` - Agent memory cache
- `semantic_similarity_cache` - Semantic similarity cache

### SAFe Methodology
- `safe_methodology_epics` - SAFe epics
- `safe_methodology_features` - SAFe features
- `safe_methodology_strategic_themes` - Strategic themes

### Detection & Events
- `detection_events` - Technology/framework detection events ✅

### Task Planning (HTDAG)
- `task_decomposition_graph_nodes` - HTDAG task nodes
- `task_decomposition_graph_edges` - Task dependencies
- `task_decomposition_graph_types` - Task types

## Migration Strategy

1. **Phase 1: Rename high-confusion tables** (packages, stores, duplicates)
2. **Phase 2: Consolidate duplicates** (cache tables, knowledge tables, template tables)
3. **Phase 3: Add context to generic names** (rules, capabilities, features, graphs)
4. **Phase 4: Code updates** (update all references in Elixir/Rust/SQL)

## Benefits of Longer Names

✅ **Zero ambiguity** - No guessing what a table contains
✅ **Self-documenting** - Code reads like English
✅ **AI-friendly** - LLMs understand context immediately
✅ **Maintainable** - New developers know exactly what to use
✅ **Internal tooling** - No need for brevity (not a public API!)

**Example**:
```elixir
# BEFORE (confusing)
Repo.all(from t in "tools", where: t.ecosystem == "npm")
Repo.all(from t in "templates", where: t.language == "elixir")
Repo.all(from r in "rules", where: r.active == true)

# AFTER (self-explanatory)
Repo.all(from p in "external_package_registry", where: p.ecosystem == "npm")
Repo.all(from t in "code_generation_templates", where: t.language == "elixir")
Repo.all(from r in "agent_behavior_confidence_rules", where: r.active == true)
```

Much better! 🎯
