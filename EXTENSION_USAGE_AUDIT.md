# PostgreSQL Extension Usage Audit

**Status:** ⚠️ **FIELDS DEFINED BUT NOT USED** (2025-10-24)

## Summary

✅ **Database Setup:** All extensions installed and optimized columns/indexes created
⚠️ **Code Integration:** New intarray fields defined in Ecto schemas but **NOT populated or queried**
✅ **Existing Usage:** Code DOES use intarray operators (&&, @>, <@) on OTHER fields (tags, patterns, frameworks)

---

## Current intarray Usage (Existing - NOT Related to New Fields)

The codebase already uses intarray operators on existing fields:

| File | Field | Operators | Purpose |
|------|-------|-----------|---------|
| `lib/singularity/storage/store.ex` | `tags` (text[]) | `&&` | Filter by tag overlap |
| `lib/singularity/storage/knowledge/artifact_store.ex` | `tags` (text[]) | `&&` | Find artifacts by tags |
| `lib/singularity/storage/code/code_location_index_service.ex` | `patterns` (text[]) | `@>` | Find pattern matches |
| `lib/singularity/storage/code/code_location_index_service.ex` | `frameworks` (text[]) | `@>` | Find framework usage |
| `lib/singularity/storage/code/code_location_index_service.ex` | `nats_subjects` (text[]) | `@>` | Find NATS subjects |
| `lib/singularity/execution/todos/todo_store.ex` | `tags` (text[]) | `&&` | Filter todos by tags |
| `lib/singularity/schemas/knowledge_artifact.ex` | `content` (jsonb) | `@>` | Filter by JSON content |

**Total intarray operator usage:** 9 locations across code

---

## NEW intarray Fields (Defined but NOT Used)

### GraphNode Array Fields

**File:** `lib/singularity/schemas/graph_node.ex`
- ✅ `field :dependency_node_ids, {:array, :integer}, default: []`
- ✅ `field :dependent_node_ids, {:array, :integer}, default: []`
- ✅ GIN indexes created in database
- ❌ **NOT populated or queried anywhere**

### CodeFile Array Fields

**File:** `lib/singularity/schemas/code_file.ex`
- ✅ `field :imported_module_ids, {:array, :integer}, default: []`
- ✅ `field :importing_module_ids, {:array, :integer}, default: []`
- ✅ GIN indexes created in database
- ❌ **NOT populated or queried anywhere**

---

## Where These Fields Should Be Used

### 1. **Graph Populator** (`lib/singularity/graph/graph_populator.ex`)

**Current State:** Creates graph_nodes WITHOUT populating dependency arrays

```elixir
# Line 193: process_call_graph - Current code
%GraphNode{}
|> GraphNode.changeset(%{
  codebase_id: codebase_id,
  node_id: node_id,
  node_type: "function",
  name: func_name,
  file_path: file.file_path,
  line_number: func_data["line"],
  metadata: %{...}
  # ❌ Missing: dependency_node_ids
  # ❌ Missing: dependent_node_ids
})

# Line 259: process_dependencies - Current code
%GraphNode{}
|> GraphNode.changeset(%{
  codebase_id: codebase_id,
  node_id: node_id,
  node_type: "module",
  name: module_name,
  file_path: file.file_path,
  metadata: %{...}
  # ❌ Missing: dependency_node_ids for internal_deps
})
```

**Should populate:**
- When processing call_graph: extract called function IDs → `dependency_node_ids`
- When processing dependencies: convert module names to node IDs → `dependency_node_ids`

### 2. **Unified Ingestion Service** (`lib/singularity/code/unified_ingestion_service.ex`)

**Current State:** Creates code_files WITHOUT populating module import arrays

```elixir
# Line 216: CodeFile.changeset - Current code
attrs = %{
  file_path: file_path,
  module_name: extract_module_name(parse_result, file_path),
  language: Atom.to_string(language),
  content: content,
  ast: validated_ast,
  codebase_id: codebase_id,
  last_modified: File.stat!(file_path).mtime |> NaiveDateTime.from_erl!()
  # ❌ Missing: imported_module_ids
  # ❌ Missing: importing_module_ids
}
```

**Should populate:**
- From `ast` or `parse_result`: extract imported module names → convert to IDs → `imported_module_ids`
- Would require second pass to populate `importing_module_ids` (which files import this one)

### 3. **Startup Code Ingestion** (`lib/singularity/code/startup_code_ingestion.ex`)

**Current State:** Creates code_files WITHOUT populating module import arrays

```elixir
# Line 692: Same issue - CodeFile.changeset called without import arrays
```

---

## Files Using GraphNode/CodeFile Schemas

**21 files use these schemas:**

| File | Purpose | Status |
|------|---------|--------|
| `lib/mix/tasks/analyze.results.ex` | Analysis task | Read-only |
| `lib/mix/tasks/analyze.codebase.ex` | Analysis task | Read-only |
| `lib/singularity/code_analysis/analyzer.ex` | Analysis | Read-only |
| `lib/singularity/bootstrap/pagerank_bootstrap.ex` | PageRank | Reads, not populating arrays |
| `lib/singularity/analysis/metadata_validator.ex` | Validation | Read-only |
| `lib/singularity/analysis/ast_extractor.ex` | Extraction | Could populate arrays |
| `lib/singularity/graph/pagerank_queries.ex` | Query | Read-only (should use array filters!) |
| `lib/singularity/graph/graph_queries.ex` | Query | Read-only (should use array filters!) |
| `lib/singularity/graph/graph_populator.ex` | **Population** | ❌ **Should populate but doesn't** |
| `lib/singularity/code/unified_ingestion_service.ex` | **Ingestion** | ❌ **Should populate but doesn't** |
| `lib/singularity/code/startup_code_ingestion.ex` | **Ingestion** | ❌ **Should populate but doesn't** |
| `lib/singularity/code/codebase_detector.ex` | Detection | Read-only |
| `lib/singularity/schemas/code_file.ex` | Schema definition | ✅ Schema updated |
| `lib/singularity/schemas/graph_node.ex` | Schema definition | ✅ Schema updated |
| `lib/singularity/schemas/code_analysis_result.ex` | Related schema | Read-only |
| `lib/singularity/search/code_search_ecto.ex` | Search | **Should use array filters!** |
| `lib/singularity/engines/parser_engine.ex` | Parsing | Could populate arrays |
| `lib/singularity/execution/planning/code_file_watcher.ex` | File watching | Read-only |
| `lib/singularity/application_supervisor.ex` | Supervision | Read-only |
| `lib/singularity/code_graph/queries.ex` | Graph queries | **Should use array filters!** |
| `lib/singularity/jobs/pagerank_calculation_job.ex` | Background job | **Should use array filters!** |

---

## Implementation Gap

### ❌ Fields Populated: NONE
- `dependency_node_ids` - Never set when creating GraphNode
- `dependent_node_ids` - Never set when creating GraphNode
- `imported_module_ids` - Never set when creating CodeFile
- `importing_module_ids` - Never set when creating CodeFile

### ❌ Fields Queried: NONE
- No WHERE clauses using `fragment("? && ?", gn.dependency_node_ids, ^ids)`
- No WHERE clauses using `fragment("? @> ?", gn.dependency_node_ids, ^ids)`
- No filtering by module dependencies

### ⚠️ Opportunity Cost
- GIN indexes created on these fields but not being used
- 10-100x performance gains on dependency queries **not being realized**
- Array fields in schema but empty/unused in practice

---

## citext Usage Status

**Fields Converted to citext:** ✅
- `store_knowledge_artifacts.artifact_type`
- `store_knowledge_artifacts.artifact_id`
- `graph_nodes.name`
- `code_files.project_name`

**Code Usage:** ❌ **Unknown - Need to verify**
- Schema fields exist but unclear if queries rely on case-insensitive matching
- The conversion happens in database but application may not benefit if queries use LOWER()

---

## Recommendations

### Short Term (If Not Using These Optimizations)
1. **Remove unused fields** from database migrations (free up storage)
2. **Remove GIN indexes** (reduces index overhead)
3. **Remove array field definitions** from Ecto schemas
4. Keep extensions installed for future use

### Medium Term (To Actually Use These Optimizations)
1. **Update Graph Populator** to extract and populate dependency_node_ids from call graph and dependencies
2. **Update Ingestion Services** to extract and populate imported_module_ids from AST imports
3. **Add queries** in `graph_queries.ex` and `code_search_ecto.ex` to leverage intarray operators
4. **Add second-pass job** to populate importing_module_ids (reverse dependencies)

### Long Term (Advanced Graph Operations)
1. Leverage `find_nodes_with_common_dependencies()` function (already in migration)
2. Implement similarity-based clustering using dependency overlap
3. Use intarray operators for batch dependency resolution

---

## Summary

**Database:** ✅ Fully optimized (extensions, columns, indexes)
**Schemas:** ✅ Field definitions added
**Population:** ❌ Code doesn't populate the fields
**Queries:** ❌ Code doesn't query using the fields
**Status:** **Ready to implement but currently dormant**

**Decision Needed:**
- **Option A** - Remove unused optimizations to reduce complexity
- **Option B** - Implement code to populate and query these fields for 10-100x faster dependency operations

---

*Last Updated: 2025-10-24*
