# Singularity Ecto Schema Organization Analysis

## Executive Summary

Found **63 total Ecto schemas** across Singularity codebase:
- **31 schemas** in centralized `/schemas` directory (49%)
- **32 schemas** scattered across domain modules (51%)
- **2 DUPLICATE KnowledgeArtifact** definitions (critical issue)
- **1 DUPLICATE CodeLocationIndex** reference issue

**Key Finding:** Schemas are split between centralized storage and domain-driven organization, creating maintenance overhead and potential confusion.

---

## Part 1: Complete Schema Inventory

### A. Centralized Schemas Directory (31 files)
Location: `/singularity/lib/singularity/schemas/`

**Knowledge & Learning (4):**
- `knowledge_artifact.ex` → `knowledge_artifacts` table
  - Purpose: Bidirectional template storage (Git ↔ PostgreSQL)
  - Fields: artifact_type, content_raw, content (JSONB), embedding (pgvector), usage tracking
  - Status: Production (AI metadata included)
  
- `template.ex` → `templates` table
  - Purpose: Code templates and patterns
  
- `template_cache.ex` → `template_cache` table
  - Purpose: Template caching layer
  
- `local_learning.ex` → `local_learning` table
  - Purpose: Track local learning experiments

**Code Analysis & Storage (7):**
- `code_chunk.ex` → `code_chunks` table
  - Purpose: Code chunks with 2560-dim pgvector embeddings
  - Status: Production (excellent AI metadata)
  - Validated: Enforces 2560-dimensional vectors
  
- `code_embedding_cache.ex` → `code_embedding_cache` table
  - Purpose: Cache for code embeddings
  
- `code_analysis_result.ex` → `code_analysis_results` table
  - Purpose: Results from code analysis operations
  
- `code_file.ex` → `code_files` table
  - Purpose: File-level code storage
  
- `dead_code_history.ex` → `dead_code_history` table
  - Purpose: Track dead code across versions
  
- `technology_detection.ex` → `technology_detection` table
  - Purpose: Detected technologies in codebase
  
- `technology_pattern.ex` → `technology_patterns` table
  - Purpose: Technology-specific patterns

**Templates & Technology (2):**
- `technology_template.ex` → `technology_templates` table
  
- `dependency_catalog.ex` → `dependency_catalog` table
  - Purpose: Package/dependency information

**Package Registry (4):**
- `package_dependency.ex` → `package_dependencies` table
- `package_code_example.ex` → `package_code_examples` table
- `package_prompt_usage.ex` → `package_prompt_usage` table
- `package_usage_pattern.ex` → `package_usage_patterns` table

**Codebase Analysis (5):**
- `codebase_snapshot.ex` → `codebase_snapshots` table
- `file_naming_violation.ex` → `file_naming_violations` table
- `file_architecture_pattern.ex` → `file_architecture_patterns` table
- `code_analysis_result.ex` → `code_analysis_results` table (listed twice?)
- `usage_event.ex` → `usage_events` table

**Graphs & Network (2):**
- `graph_node.ex` → `graph_nodes` table
- `graph_edge.ex` → `graph_edges` table

**Metrics & Monitoring (1):**
- `agent_metric.ex` → `agent_metrics` table
  - Purpose: Time-series agent performance metrics
  - Indexes: agent_id + time_window

**Access Control (1):**
- `user_codebase_permission.ex` → `user_codebase_permissions` table
- `user_preferences.ex` → `user_preferences` table

**T5 Model Training (4):**
- `t5_training_session.ex` → `t5_training_sessions` table
- `t5_training_example.ex` → `t5_training_examples` table
- `t5_model_version.ex` → `t5_model_versions` table
- `t5_evaluation_result.ex` → `t5_evaluation_results` table

**Approval & Workflow (1):**
- `approval_queue.ex` → `approval_queues` table

---

### B. Domain-Scattered Schemas (32 files)

#### 1. Execution Planning (7 schemas)
Location: `/singularity/lib/singularity/execution/planning/`

**In `schemas/` subdirectory (5):**
- `Singularity.Execution.Planning.Schemas.Capability` → `agent_capability_registry` table
  - Relationships: belongs_to :epic, has_many :features, has_many :capability_dependencies
  - Status: Excellent AI metadata with disambiguation from RuleEngine
  
- `Singularity.Execution.Planning.Schemas.CapabilityDependency` → `agent_capability_dependencies` table
  
- `Singularity.Execution.Planning.Schemas.Epic` → `agent_epic_registry` table
  
- `Singularity.Execution.Planning.Schemas.Feature` → `agent_feature_registry` table
  
- `Singularity.Execution.Planning.Schemas.StrategicTheme` → `agent_strategic_theme_registry` table

**In parent directory (2):**
- `Singularity.Execution.Planning.Task` → **No Ecto schema** (pure struct, NOT persisted)
  - Status: Pure immutable task definition
  
- `Singularity.Execution.Planning.TaskExecutionStrategy` → (schema TBD)

#### 2. Execution Autonomy (3 schemas)
Location: `/singularity/lib/singularity/execution/autonomy/`

- `Singularity.Execution.Autonomy.Rule` → `agent_behavior_confidence_rules` table
  - Purpose: Evolvable rules with Lua script support
  - Status: Excellent AI metadata with comprehensive anti-patterns
  - Fields: condition, action, metadata (JSONB), embedding (pgvector), execution_type (lua_script | elixir_patterns)
  - Relationships: has_many :executions, has_many :evolution_proposals
  
- `Singularity.Execution.Autonomy.RuleExecution` → (execution log)
  
- `Singularity.Execution.Autonomy.RuleEvolutionProposal` → (evolution tracking)

#### 3. Execution Todos (1 schema)
Location: `/singularity/lib/singularity/execution/todos/`

- `Singularity.Execution.Todos.Todo` → `todos` table
  - Purpose: Task management with swarm-based execution
  - Status: Excellent AI metadata with status flow diagram
  - Fields: title, description, status, priority (1-5), complexity (simple|medium|complex), embedding (pgvector)
  - Relationships: parent_todo_id, depends_on_ids

#### 4. LLM Subsystem (1 schema)
Location: `/singularity/lib/singularity/llm/`

- `Singularity.LLM.Call` → `llm_calls` table
  - Purpose: LLM call history and cost tracking
  - Fields: provider, model, prompt, system_prompt, response, tokens_used, cost_usd, duration_ms
  - Embeddings: prompt_embedding, response_embedding (both pgvector)

#### 5. Knowledge System (1 schema)
Location: `/singularity/lib/singularity/knowledge/`

- `Singularity.Knowledge.TemplateGeneration` → (TBD)

#### 6. Storage Subsystems (2 schemas)
Location: `/singularity/lib/singularity/storage/`

**Code Storage:**
- `Singularity.CodeLocationIndex` → `code_location_index` table
  - Location: `/singularity/lib/singularity/storage/code/storage/code_location_index.ex`
  - Purpose: Index codebase files for pattern-based navigation
  - Status: Excellent implementation with helper methods
  - Fields: filepath, patterns (array), language, file_hash, lines_of_code, metadata, frameworks, microservice

**Knowledge Storage:**
- `Singularity.Knowledge.KnowledgeArtifact` → `curated_knowledge_artifacts` table
  - Location: `/singularity/lib/singularity/storage/knowledge/knowledge_artifact.ex`
  - **DUPLICATE:** Same concept as `/schemas/knowledge_artifact.ex` but different table
  - Table difference: Uses `curated_knowledge_artifacts` vs `knowledge_artifacts`

#### 7. Tools & Schemas (5 schemas)
Location: `/singularity/lib/singularity/tools/`

- `Singularity.Tools.Tool` → **Embedded Schema** (not persisted)
  - Purpose: Tool definition with metadata, parameter schema, execution function
  - Status: Excellent AI metadata with anti-patterns
  
- `Singularity.Tools.ToolParam` → **Embedded Schema**
  
- `Singularity.Tools.ToolCall` → (schema TBD)
  
- `Singularity.Tools.ToolResult` → (schema TBD)
  
- `Singularity.Tools.InstructorSchemas` → (Instructor integration schemas)

#### 8. Architecture Engine (3 schemas)
Location: `/singularity/lib/singularity/architecture_engine/meta_registry/`

- `Singularity.Architecture.FrameworkLearning` → (learning schema)
- `Singularity.Architecture.SingularityLearning` → (learning schema)
- `Singularity.Architecture.Frameworks.Ecto` → (framework metadata)

#### 9. Detection Subsystem (1 schema)
Location: `/singularity/lib/singularity/detection/`

- `Singularity.Detection.CodebaseSnapshots` → (snapshot schema)

#### 10. Git System (1 schema)
Location: `/singularity/lib/singularity/git/`

- `Singularity.Git.GitStateStore` → `git_state_store` table

#### 11. Learning System (1 schema)
Location: `/singularity/lib/singularity/learning/`

- `Singularity.Learning.ExperimentResult` → `experiment_results` table

#### 12. Metrics System (1 schema)
Location: `/singularity/lib/singularity/metrics/`

- `Singularity.Metrics.Event` → `metrics_events` table
  - Purpose: Raw metrics events from all sources
  - Status: Good AI metadata with example events

#### 13. Quality System (2 schemas)
Location: `/singularity/lib/singularity/quality/`

- `Singularity.Quality.Finding` → `quality_findings` table
- `Singularity.Quality.Run` → `quality_runs` table

#### 14. Runner System (1 schema)
Location: `/singularity/lib/singularity/runner/`

- `Singularity.Runner.ExecutionRecord` → `execution_records` table

#### 15. Search System (1 schema)
Location: `/singularity/lib/singularity/search/`

- `Singularity.Search.SearchMetric` → `search_metrics` table

---

## Part 2: Critical Issues

### ISSUE 1: Duplicate KnowledgeArtifact Definitions

**Location 1:** `/singularity/lib/singularity/schemas/knowledge_artifact.ex`
```elixir
defmodule Singularity.Schemas.KnowledgeArtifact
schema "knowledge_artifacts"
```

**Location 2:** `/singularity/lib/singularity/storage/knowledge/knowledge_artifact.ex`
```elixir
defmodule Singularity.Knowledge.KnowledgeArtifact
schema "curated_knowledge_artifacts"
```

**Differences:**
- Different module namespaces
- Different table names (`knowledge_artifacts` vs `curated_knowledge_artifacts`)
- Same fields: artifact_type, artifact_id, content_raw, content, embedding, version
- Location 1 has more complete implementation (learning tracking, usage fields)
- Location 2 is simpler, focused on curated artifacts

**Impact:** Confusing which to use; possible duplicate data; unclear purpose distinction

**Recommendation:** 
- Consolidate into single schema
- OR clearly separate by purpose (raw vs curated)
- Update documentation to explain difference

---

### ISSUE 2: Knowledge Artifact in Multiple Tables

The same concept is stored in:
1. `knowledge_artifacts` (Schemas.KnowledgeArtifact)
2. `curated_knowledge_artifacts` (Knowledge.KnowledgeArtifact)

**Questions to Resolve:**
- Are these two different types of artifacts?
- Should one be a view over the other?
- Should they share a single schema with a type discriminator?

---

### ISSUE 3: Scattered Planning Schemas

Location: `/execution/planning/`

Current organization:
```
execution/planning/
├── task.ex (pure struct, not Ecto schema)
├── task_execution_strategy.ex (schema TBD)
└── schemas/
    ├── capability.ex
    ├── capability_dependency.ex
    ├── epic.ex
    ├── feature.ex
    └── strategic_theme.ex
```

**Issue:** Mixing pure structs (`Task`) with Ecto schemas in same domain. The `schemas/` subdirectory suggests a split that isn't fully organized.

---

### ISSUE 4: Tools Schemas Are Embedded

Location: `/tools/`

- `Tool`, `ToolParam` are embedded schemas (not persisted)
- `ToolCall`, `ToolResult` purpose unclear
- `InstructorSchemas` may contain additional embedded schemas

**Issue:** Unclear purpose of each; need documentation on persistence model

---

### ISSUE 5: CodeLocationIndex Schema Misplacement

Location: `/storage/code/storage/code_location_index.ex`

**Issues:**
- Module name: `Singularity.CodeLocationIndex` (top-level)
- File path: deeply nested in `/storage/code/storage/`
- Should be at `/storage/code/code_location_index.ex` OR in `/schemas/`
- High implementation complexity (many helper methods) suggests it should be a service, not just a schema

---

## Part 3: Organization Analysis

### Current Pattern: Hybrid Organization

The codebase uses BOTH patterns:

**Pattern A: Centralized** (31 schemas in `/schemas/`)
```
schemas/
├── code_chunk.ex
├── knowledge_artifact.ex
├── agent_metric.ex
└── ... (28 more)
```

**Pattern B: Domain-Driven** (32 schemas scattered)
```
execution/planning/schemas/capability.ex
execution/autonomy/rule.ex
tools/tool.ex
storage/knowledge/knowledge_artifact.ex
```

**Analysis:**
- Neither pattern is fully applied
- Centralized directory has broad categories but mixed domains
- Domain-driven schemas have custom naming (some `Schemas.*`, some not)
- Creates cognitive overhead: "Where is schema X? `/schemas/` or domain directory?"

---

### Schema Categories (By Domain)

**Core Infrastructure (8):**
- KnowledgeArtifact (x2), Template, TemplateCache, LocalLearning
- CodeChunk, CodeEmbeddingCache, CodeLocationIndex

**Analysis & Detection (10):**
- CodeAnalysisResult, Technology*, Pattern*, FileNaming*, FileArchitecture*
- CodebaseSnapshot, DependencyCatalog

**Execution & Planning (11):**
- Task, TaskExecutionStrategy, Capability*, Feature, Epic, StrategicTheme, Rule*, RuleExecution, RuleEvolutionProposal, Todo

**Monitoring & Learning (7):**
- AgentMetric, Metrics.Event, QualityFinding, QualityRun
- ExperimentResult, SearchMetric, ExecutionRecord

**Package Registry (4):**
- PackageDependency, PackageCodeExample, PackagePromptUsage, PackageUsagePattern

**LLM & Tools (5):**
- LLM.Call, Tool, ToolParam, ToolCall, ToolResult

**Access Control (2):**
- UserCodebasePermission, UserPreferences

**ML Models (4):**
- T5TrainingSession, T5TrainingExample, T5ModelVersion, T5EvaluationResult

**Integration (3):**
- Git.GitStateStore, FrameworkLearning, SingularityLearning

**Graph & Network (2):**
- GraphNode, GraphEdge

---

## Part 4: Relationship Analysis

### High-Value Schemas (Well-Designed with AI Metadata)

**1. CodeChunk** ✅
- Excellent AI navigation metadata
- 2560-dimensional embedding validation
- Clear purpose and usage examples

**2. KnowledgeArtifact** ✅
- Comprehensive AI metadata
- Dual storage (raw + JSONB)
- Versioning with linked list (previous_version_id)
- Learning loop support (usage_count, success_count)

**3. Rule** ✅
- Exceptional AI metadata (886-line module with documentation)
- Anti-patterns clearly defined
- Lua script support for hot-reload
- Evolution tracking with proposals

**4. Capability** ✅
- Clear SAFe 6.0 alignment
- Integration points documented
- State map conversion for GenServer coordination

**5. Todo** ✅
- Good AI metadata
- Status flow diagram
- Complexity levels explained
- Dependency tracking

**6. Metrics.Event** ✅
- Clear purpose as raw event storage
- Example events documented
- Tag-based context (JSONB)

---

### Schemas Needing Attention

**1. Tool** ⚠️
- Excellent AI metadata but...
- Embedded schema (not persisted) - purpose should be clearer
- Mixed concerns: metadata + parameter validation + execution function

**2. CodeLocationIndex** ⚠️
- High implementation complexity
- Should be: Service with schema, not schema with service methods
- Suggests it needs refactoring

**3. GraphNode/GraphEdge** ⚠️
- Purpose unclear
- No apparent usage in codebase
- May be orphaned

**4. T5 Training Schemas** ⚠️
- Purpose: Fine-tuning T5 model?
- Integration point: unclear
- Usage: not found in search

**5. InstructorSchemas** ⚠️
- Purpose: Instructor output validation?
- Location: in `/tools/` but unclear relationship
- Integration: needs documentation

---

## Part 5: Relationship Mapping

### Dependency Graph (Key Relationships)

```
Rule
  ├─ has_many :executions → RuleExecution
  ├─ has_many :evolution_proposals → RuleEvolutionProposal
  └─ belongs_to :parent_rule → Rule (self-referential)

Capability
  ├─ belongs_to :epic → Epic
  ├─ has_many :features → Feature
  └─ has_many :capability_dependencies → CapabilityDependency
       └─ has_many :depends_on → Capability (through)

Epic
  ├─ has_many :capabilities → Capability
  ├─ has_many :features → Feature
  └─ belongs_to :strategic_theme → StrategicTheme

Feature
  ├─ belongs_to :capability → Capability
  ├─ belongs_to :epic → Epic
  └─ depends_on_ids: [Feature.id, ...]

Todo
  ├─ parent_todo_id: Todo.id (self-referential)
  └─ depends_on_ids: [Todo.id, ...]

KnowledgeArtifact
  └─ belongs_to :previous_version → KnowledgeArtifact (self-referential)

LLM.Call
  └─ correlation_id: UUID (for multi-turn conversations)

CodeChunk
  ├─ codebase_id: String
  └─ file_path: String (could be FK if CodeFile.ex exists)

CodeLocationIndex
  └─ No Ecto relationships (pure index)
```

**Observations:**
- Heavy use of self-referential relationships (versioning, hierarchy)
- Multiple domains store arrays of IDs instead of Ecto relationships
- Some schemas (GraphNode/Edge) lack relationships

---

## Part 6: Recommendations

### 6.1 Immediate Actions (High Priority)

#### 1. Resolve KnowledgeArtifact Duplication
**Action:** Choose single schema
- Option A: Keep in `/schemas/knowledge_artifact.ex` (more complete)
- Option B: Consolidate in `/knowledge/` (domain-driven)

**Recommendation:** Move to `/schemas/` as it's more mature
- Delete `/storage/knowledge/knowledge_artifact.ex`
- Update imports across codebase
- Document dual table structure if needed:
  - `knowledge_artifacts` for all artifacts
  - Add source field to distinguish (currently has `source: "git" | "learned"`)

**Migration:** Single migration to consolidate tables (if needed)

---

#### 2. Fix CodeLocationIndex Location
**Action:** Restructure module
- Current: `/storage/code/storage/code_location_index.ex`
- Move to: `/storage/code/code_location_index.ex`
- OR move to: `/schemas/code_location_index.ex`

**Refactoring:** Separate concerns
```
├── code_location_index.ex (pure Ecto schema)
└── code_location_index_service.ex (the helper methods)
```

**Rationale:** Current module mixes schema definition with complex business logic

---

#### 3. Document Embedded Schemas
**Action:** Create documentation for:
- `Tool` - why embedded? When persisted?
- `ToolParam` - relationship to Tool?
- `ToolCall` - execution trace?
- `ToolResult` - output storage?

**Create:** `/singularity/lib/singularity/tools/README.md`

---

### 6.2 Medium-Term Actions (Next Sprint)

#### 4. Standardize Schema Organization
**Adopt:** Single consistent pattern

**Option A (Recommended): Domain-Driven with Schema Subdirectories**
```
execution/
├── planning/
│   ├── schemas/
│   │   ├── capability.ex
│   │   ├── epic.ex
│   │   └── feature.ex
│   ├── task.ex (pure struct)
│   └── orchestrator.ex
├── autonomy/
│   ├── schemas/
│   │   ├── rule.ex
│   │   ├── rule_execution.ex
│   │   └── rule_evolution_proposal.ex
│   └── rule_engine.ex
└── todos/
    ├── todo.ex (could move here)
    └── todo_coordinator.ex

knowledge/
├── schemas/
│   ├── knowledge_artifact.ex
│   ├── template.ex
│   └── template_cache.ex
└── artifact_store.ex

storage/
├── code/
│   ├── schemas/
│   │   └── code_location_index.ex
│   └── code_store.ex
└── knowledge/
    └── artifact_store.ex
```

**Benefits:**
- Clear co-location: schema near orchestrators
- Scalable: each domain can have multiple schemas
- Self-documenting: schema directory signals "these are persistent"

---

#### 5. Review Orphaned Schemas
**Schemas to audit:**
- `GraphNode`, `GraphEdge` - Used anywhere?
- `T5*` schemas - Still relevant?
- `InstructorSchemas` - Integration status?

**Action:** Document usage or deprecate

---

#### 6. Establish Naming Conventions
**Current:** Inconsistent naming
- `Singularity.Schemas.CodeChunk` (centralized)
- `Singularity.Execution.Planning.Schemas.Capability` (domain-driven)
- `Singularity.CodeLocationIndex` (top-level)
- `Singularity.LLM.Call` (no Schemas prefix)

**Proposed Standard:**
```elixir
# For centralized schemas (legacy - migrate out gradually)
defmodule Singularity.Schemas.X
  # Only for true cross-domain schemas

# For domain-specific schemas (preferred)
defmodule Singularity.DomainName.Schemas.X
  # Co-located with domain logic

# For embedded schemas (temporary/computed)
defmodule Singularity.SomeDomain.EmbeddedSchema.X
  # Use embedded_schema/0
```

---

### 6.3 Long-Term Actions (Phase 2+)

#### 7. Migrate All Centralized Schemas to Domains
**Migration Path:**
```
Phase 1: Create domain-specific subdirectories
Phase 2: Move 1-2 schemas per sprint
Phase 3: Archive /schemas/ as "legacy" (keep for imports)
Phase 4: Complete consolidation (after all imports updated)
```

**Priority Order:**
1. Knowledge schemas → `/knowledge/schemas/`
2. Code schemas → `/storage/code/schemas/`
3. Execution schemas → `/execution/*/schemas/`
4. Metrics → `/metrics/schemas/`
5. Others → appropriate domains

---

#### 8. Establish Schema API Patterns
**Create templates for:**
- Changeset functions (create, update, status changes)
- Query helpers (by type, by status, search)
- Relationship preloads
- Versioning/evolution patterns

**Document in:** `templates_data/base/elixir-schema-*.json`

---

#### 9. Add Comprehensive AI Navigation Metadata
**Current Status:**
- ✅ CodeChunk - excellent
- ✅ KnowledgeArtifact - excellent
- ✅ Rule - exceptional
- ✅ Capability - good
- ✅ Todo - good
- ✅ Metrics.Event - good
- ⚠️ Most others - missing or minimal

**Action:** Apply OPTIMAL_AI_DOCUMENTATION_PATTERN.md to all schemas

**Priority:** Core schemas first
1. CodeChunk ✅
2. KnowledgeArtifact ✅
3. Rule ✅
4. Capability ✅
5. Todo ✅
6. Others per quarterly reviews

---

## Part 7: Impact Assessment

### Breaking Changes (If Reorganizing)

**High Impact:**
- Moving KnowledgeArtifact from `/storage/` to `/schemas/`
  - Requires: Update 10+ import statements
  - Migration: Single rename/remap in Repo config
  - Scope: 30 minutes

**Medium Impact:**
- Reorganizing into domain-driven structure
  - Requires: Update all schema imports
  - Can be: Gradual (old paths point to new via aliases)
  - Scope: 2-3 hours per schema

**Low Impact:**
- Adding documentation/AI metadata
  - Requires: Just docstrings
  - Scope: 15-30 min per schema

---

### File Paths (For Reference)

**All 63 schemas found at:**

Centralized (31):
```
/singularity/lib/singularity/schemas/
```

Domain-Scattered (32):
```
/execution/planning/schemas/* (5)
/execution/autonomy/* (3)
/execution/todos/* (1)
/execution/planning/* (2)
/llm/* (1)
/knowledge/* (1)
/storage/code/* (1)
/storage/knowledge/* (1)
/tools/* (5)
/architecture_engine/* (3)
/detection/* (1)
/git/* (1)
/learning/* (1)
/metrics/* (1)
/quality/* (2)
/runner/* (1)
/search/* (1)
```

---

## Part 8: Summary & Next Steps

### Key Takeaways

1. **Organization is Hybrid:** Mix of centralized and domain-driven, needs consistency
2. **Duplication Exists:** KnowledgeArtifact defined twice with different tables
3. **Misplaced Modules:** CodeLocationIndex deeply nested, mixes schema + logic
4. **AI Metadata Incomplete:** Only ~25% of schemas have production-grade documentation
5. **Orphaned Schemas:** Several schemas (GraphNode/Edge, T5*) lack clear usage
6. **Relationships Incomplete:** Some domains store IDs as arrays instead of Ecto relationships

### Recommended Execution Order

**This Week:**
1. Resolve KnowledgeArtifact duplication
2. Create plan for CodeLocationIndex restructuring
3. Document Tool/ToolParam/ToolCall/ToolResult purpose

**Next Week:**
1. Audit GraphNode/Edge, T5 schemas, Instructor schemas
2. Create domain-driven schema organization template
3. Start migrating 1-2 centralized schemas to domain-driven

**Next Month:**
1. Complete migration of high-value schemas
2. Add AI navigation metadata to top 20 schemas
3. Establish naming/organization conventions

**Next Quarter:**
1. Complete full schema migration
2. Full AI metadata coverage
3. Relationship refactoring (arrays → Ecto relationships)

---

## Appendix A: Test Coverage for Schemas

Should verify:
- [ ] All 63 schemas have changesets tested
- [ ] Relationship integrity (foreign keys)
- [ ] Embedding field validation (for pgvector schemas)
- [ ] JSONB field validation (for content fields)
- [ ] Unique constraint handling
- [ ] Timestamp handling (auto-update on changes)

---

## Appendix B: Files Generated by This Analysis

This analysis examined:
- 63 Ecto schema files
- 38 migration files
- CLAUDE.md project guidelines
- Sample implementation patterns

Total code reviewed: ~15,000+ lines
