# CodeSearch Postgrex Refactor - Detailed Checklist

## Phase 1: Foundation - Create Ecto Schemas
**Target Duration:** 1 day | **Priority:** CRITICAL

- [ ] Create `lib/singularity/schemas/` directory structure
- [ ] Create `codebase_metadata.ex` schema with 55 fields
  - [ ] All numeric/string fields
  - [ ] JSONB array fields (domains, patterns, features, etc.)
  - [ ] pgvector field (vector_embedding)
  - [ ] Timestamps (inserted_at, updated_at)
  - [ ] Changeset function with validation
  - [ ] Document all field groupings in comments

- [ ] Create `codebase_registry.ex` schema
  - [ ] 9 core fields
  - [ ] JSONB metadata
  - [ ] Changeset with required field validation
  - [ ] Unique constraint on codebase_id

- [ ] Create `graph_node.ex` schema
  - [ ] 9 fields including vectors, metadata
  - [ ] Unique constraint on (codebase_id, node_id)
  - [ ] Changeset with JSON encoding for metadata

- [ ] Create `graph_edge.ex` schema
  - [ ] 7 fields including weight, metadata
  - [ ] Unique constraint on (codebase_id, edge_id)
  - [ ] Changeset with JSON encoding

- [ ] Create `graph_type.ex` schema
  - [ ] 3 fields (graph_type, description, created_at)
  - [ ] Unique constraint on graph_type
  - [ ] Seed data via migration or fixture

- [ ] Create `vector_search.ex` schema
  - [ ] 7 fields
  - [ ] Unique constraint on (codebase_id, file_path, content_type)
  - [ ] pgvector field

- [ ] Create `vector_similarity_cache.ex` schema
  - [ ] 5 fields (codebase_id, query_vector_hash, target_file_path, similarity_score, created_at)
  - [ ] Unique constraint on (codebase_id, query_vector_hash, target_file_path)

- [ ] Cleanup `code_search.ex` module
  - [ ] Delete `create_unified_schema()` function (DELETE, not migrate)
  - [ ] Delete `create_codebase_metadata_table()`
  - [ ] Delete `create_graph_tables()`
  - [ ] Delete `create_performance_indexes()`
  - [ ] Delete `create_apache_age_extension()` (move to separate task if needed)

- [ ] Verify migration still works
  - [ ] Run `mix ecto.reset` with fresh database
  - [ ] Confirm all tables created correctly
  - [ ] Confirm all indexes in place

- [ ] Add tests for schemas (basic validation)
  - [ ] `test/singularity/schemas/codebase_metadata_test.exs`
  - [ ] `test/singularity/schemas/codebase_registry_test.exs`
  - [ ] `test/singularity/schemas/graph_node_test.exs`
  - [ ] `test/singularity/schemas/graph_edge_test.exs`

### Phase 1 Success Criteria
- [ ] All 8 schemas compile without errors
- [ ] `mix test test/singularity/schemas/` passes
- [ ] `code_search.ex` compiles without the deleted functions
- [ ] Fresh database can be set up via migration only

---

## Phase 2: Simple Queries - SELECT & UPDATE
**Target Duration:** 1.5 days | **Priority:** HIGH

### 2.1 `get_codebase_registry/2` (15 min)
**Current:** Lines 591-638, Postgrex.query!() SELECT  
**Location:** Refactor location TBD

- [ ] Replace with `Repo.get_by(CodebaseRegistry, codebase_id: codebase_id)`
- [ ] Update docstring to indicate Repo parameter
- [ ] Test: returns matching registry record
- [ ] Test: returns nil when not found

### 2.2 `list_codebases/1` (15 min)
**Current:** Lines 643-682, Postgrex.query!() SELECT all  
**Location:** Refactor location TBD

- [ ] Replace with `from(c in CodebaseRegistry, order_by: [desc: c.inserted_at]) |> Repo.all()`
- [ ] Verify ORDER BY created_at DESC preserved
- [ ] Test: returns all registries sorted newest first
- [ ] Test: returns empty list when no registries

### 2.3 `update_codebase_status/3` (20 min)
**Current:** Lines 687-702, Postgrex.query!() UPDATE  
**Location:** Refactor location TBD

- [ ] Fetch existing registry with `Repo.get_by()`
- [ ] Build changeset with updated fields
- [ ] Use `Repo.update()` instead of raw SQL
- [ ] Handle case where registry doesn't exist
- [ ] Test: updates status and last_analyzed
- [ ] Test: updates updated_at timestamp
- [ ] Test: handles missing registry gracefully

### 2.4 `get_dependencies/2` (20 min)
**Current:** Lines 1092-1121, Postgrex.query!() SELECT with JOIN  
**Location:** Refactor location TBD

- [ ] Use Ecto.Query with `from()` and `join()`
- [ ] Join GraphEdge to GraphNode on (to_node_id = node_id)
- [ ] Preserve ORDER BY weight DESC
- [ ] Test: returns dependencies with correct join
- [ ] Test: returns empty list when node has no dependencies
- [ ] Test: weighted edges ordered correctly

### 2.5 `get_dependents/2` (20 min)
**Current:** Lines 1126-1155, Postgrex.query!() SELECT with JOIN  
**Location:** Refactor location TBD

- [ ] Use Ecto.Query with `from()` and `join()`
- [ ] Join GraphEdge to GraphNode on (from_node_id = node_id) - OPPOSITE direction
- [ ] Preserve ORDER BY weight DESC
- [ ] Test: returns dependents with correct join
- [ ] Test: returns empty list when node has no dependents
- [ ] Test: weighted edges ordered correctly

### Phase 2 Success Criteria
- [ ] All 5 functions refactored to Ecto
- [ ] No raw SQL in simple SELECT/UPDATE functions
- [ ] `mix test test/singularity/search/code_search_test.exs` passes
- [ ] Benchmark: performance similar to original

---

## Phase 3: INSERT & UPSERT Operations
**Target Duration:** 1 day | **Priority:** HIGH

### 3.1 `register_codebase/4` (25 min)
**Current:** Lines 554-586, INSERT ON CONFLICT UPSERT  
**Location:** Refactor location TBD

- [ ] Build changeset from params
- [ ] Use `Repo.insert(..., on_conflict: :replace_all)`
- [ ] Remove manual Jason.encode! for metadata
- [ ] Handle conflict resolution
- [ ] Test: inserts new registry
- [ ] Test: upserts existing registry
- [ ] Test: metadata JSON handled correctly

### 3.2 `insert_graph_node/3` (25 min)
**Current:** Lines 858-887, INSERT ON CONFLICT  
**Location:** Refactor location TBD

- [ ] Build struct from node data
- [ ] Use `Repo.insert(..., on_conflict: :replace_all)`
- [ ] Remove manual Jason.encode! for metadata
- [ ] Test: inserts new node
- [ ] Test: upserts existing node
- [ ] Test: vector_embedding handled correctly
- [ ] Test: metadata JSON handled correctly

### 3.3 `insert_graph_edge/3` (25 min)
**Current:** Lines 892-916, INSERT ON CONFLICT  
**Location:** Refactor location TBD

- [ ] Build struct from edge data
- [ ] Use `Repo.insert(..., on_conflict: :replace_all)`
- [ ] Remove manual Jason.encode! for metadata
- [ ] Test: inserts new edge
- [ ] Test: upserts existing edge
- [ ] Test: weight float handled correctly
- [ ] Test: metadata JSON handled correctly

### 3.4 `insert_codebase_metadata/3` (1.5 hours)
**Current:** Lines 707-853, INSERT ON CONFLICT with 55 fields!!!  
**Location:** Refactor location TBD

- [ ] Build changeset from metadata struct (55 fields)
- [ ] Use `Repo.insert(..., on_conflict: :replace_all)`
- [ ] Remove all manual Jason.encode! calls
- [ ] Handle all JSONB fields automatically
- [ ] Handle pgvector field correctly
- [ ] IMPORTANT: Test upsert with large metadata object
- [ ] Test: inserts new metadata
- [ ] Test: upserts existing metadata
- [ ] Test: all 55 fields updated correctly
- [ ] Test: complex JSONB structures preserved
- [ ] Performance: benchmark against original (should be faster)

### Phase 3 Success Criteria
- [ ] All 4 insert/upsert functions refactored
- [ ] No manual Jason.encode! calls
- [ ] All ON CONFLICT upserts work correctly
- [ ] `mix test test/singularity/search/code_search_test.exs` passes
- [ ] Large metadata insert performance acceptable

---

## Phase 4: Vector Search Queries
**Target Duration:** 2 days | **Priority:** HIGH

### 4.1 `semantic_search/4` (45 min)
**Current:** Lines 933-984, Raw SQL with pgvector <-> operator  
**Location:** Refactor location TBD

**Strategy:** Use Ecto.Query with fragment for vector operations

- [ ] Replace raw SQL with `from()` query
- [ ] Use `fragment("vector_embedding <-> ?", ^query_vector)` for distance
- [ ] Use `fragment("1 - (vector_embedding <-> ?)", ^query_vector)` for similarity
- [ ] Preserve WHERE clause filtering (codebase_id, NOT NULL)
- [ ] Preserve ORDER BY vector_embedding <->
- [ ] Preserve LIMIT
- [ ] Support both `Repo` and raw connection (deprecate Postgrex path with warning)
- [ ] Test: returns correct number of results
- [ ] Test: results ordered by similarity DESC
- [ ] Test: filters by codebase_id correctly
- [ ] Test: similarity_score in [0, 1] range

### 4.2 `find_similar_nodes/4` (1.5 hours)
**Current:** Lines 989-1038, CTE + pgvector query  
**Location:** Refactor location TBD

**Strategy:** Use Ecto.Query with CTE and vector fragments

- [ ] Build WITH CTE for query_node using Ecto
- [ ] Use `with_cte()` or raw SQL fragment for CTE
- [ ] Use `fragment()` for vector similarity calculation
- [ ] Join to codebase_metadata or graph_nodes table
- [ ] Filter out query_node_id itself
- [ ] Order by cosine_similarity DESC
- [ ] Limit to top_k
- [ ] Test: returns similar nodes
- [ ] Test: excludes query node itself
- [ ] Test: ordered by similarity
- [ ] Test: handles missing vectors gracefully

### 4.3 `multi_codebase_search/4` (1 hour)
**Current:** Lines 1043-1087, Dynamic IN clause + pgvector  
**Location:** Refactor location TBD

**Strategy:** Use Ecto.Query with dynamic WHERE clause for IN

- [ ] Replace dynamic string interpolation with Ecto.Query.dynamic()
- [ ] Use `in()` operator in WHERE clause
- [ ] Use `fragment()` for pgvector operators
- [ ] Build query to handle variable-length codebase_ids list
- [ ] Test: works with 1 codebase_id
- [ ] Test: works with 5+ codebase_ids
- [ ] Test: filters correctly by codebase_ids
- [ ] Test: vector search works across multiple codebases

### 4.4 Testing Vector Operations
- [ ] Create test fixtures with proper Pgvector values
- [ ] Test vector similarity calculations match expected results
- [ ] Benchmark vector search: should be < 100ms for 1000 vectors
- [ ] Verify ivfflat index is used (EXPLAIN ANALYZE)

### Phase 4 Success Criteria
- [ ] All 3 vector search functions refactored to Ecto
- [ ] No string interpolation in queries
- [ ] pgvector operators work via fragments
- [ ] `mix test test/singularity/search/code_search_test.exs` passes
- [ ] Performance benchmark shows no regression

---

## Phase 5: Advanced Graph Algorithms
**Target Duration:** 0.5 day | **Priority:** MEDIUM

### 5.1 `detect_circular_dependencies/1` (10 min)
**Current:** Lines 1160-1214, Complex recursive CTE  
**Location:** Refactor location TBD

**Strategy:** Keep complex SQL, just add pooling via Ecto.Adapters.SQL.query!

- [ ] Replace `Postgrex.query!()` with `Ecto.Adapters.SQL.query!(Repo, ...)`
- [ ] Keep SQL query unchanged (no need to convert complex CTE to Elixir)
- [ ] Verify pooling benefit (connection from pool)
- [ ] Test: detects circular dependencies correctly
- [ ] Test: recursion depth limit (< 10) works
- [ ] Test: array path construction works

### 5.2 `calculate_pagerank/3` (10 min)
**Current:** Lines 1219-1271, Complex iterative CTE  
**Location:** Refactor location TBD

**Strategy:** Keep complex SQL, just add pooling via Ecto.Adapters.SQL.query!

- [ ] Replace `Postgrex.query!()` with `Ecto.Adapters.SQL.query!(Repo, ...)`
- [ ] Keep SQL query unchanged
- [ ] Verify pooling benefit (connection from pool)
- [ ] Test: calculates pagerank scores correctly
- [ ] Test: respects iteration count parameter
- [ ] Test: respects damping_factor parameter
- [ ] Test: results in expected range [0.0, 1.0]

### Phase 5 Success Criteria
- [ ] Both advanced functions wrapped in `Ecto.Adapters.SQL.query!()`
- [ ] Still getting pooling benefit via Repo
- [ ] `mix test test/singularity/search/code_search_test.exs` passes

---

## Phase 6: Comprehensive Testing & Validation
**Target Duration:** 3.5 days | **Priority:** CRITICAL

### 6.1 Unit Tests for Schemas
- [ ] `test/singularity/schemas/codebase_metadata_test.exs`
  - [ ] Validates required fields
  - [ ] Accepts valid attributes
  - [ ] Enforces unique constraint on (codebase_id, path)
  - [ ] JSON fields default to empty array
  - [ ] Vector field optional

- [ ] `test/singularity/schemas/codebase_registry_test.exs`
  - [ ] Validates required fields
  - [ ] Enforces unique codebase_id
  - [ ] Metadata JSONB handling

- [ ] `test/singularity/schemas/graph_node_test.exs`
  - [ ] Unique constraint on (codebase_id, node_id)
  - [ ] Vector field optional
  - [ ] Metadata JSON handling

- [ ] `test/singularity/schemas/graph_edge_test.exs`
  - [ ] Unique constraint on (codebase_id, edge_id)
  - [ ] Weight float field

- [ ] `test/singularity/schemas/graph_type_test.exs`
  - [ ] Unique constraint on graph_type
  - [ ] Description optional

- [ ] `test/singularity/schemas/vector_search_test.exs`
  - [ ] Unique constraint on (codebase_id, file_path, content_type)
  - [ ] Vector field required

- [ ] `test/singularity/schemas/vector_similarity_cache_test.exs`
  - [ ] Unique constraint on (codebase_id, query_vector_hash, target_file_path)

### 6.2 Integration Tests for Refactored Functions
- [ ] `test/singularity/search/code_search_test.exs` (expanded)
  - [ ] Test all refactored functions
  - [ ] Test parameter passing (Repo instead of db_conn)
  - [ ] Test return values unchanged
  - [ ] Test error handling

- [ ] Specific integration tests per phase:
  - [ ] Phase 2: SELECT/UPDATE functions return correct data
  - [ ] Phase 3: INSERT/UPSERT functions create/update correctly
  - [ ] Phase 4: Vector search functions return similarity-ranked results
  - [ ] Phase 5: Advanced algorithms complete without errors

### 6.3 Performance Tests
**File:** `test/singularity/search/code_search_perf_test.exs`

- [ ] Create helper `test/support/perf_helpers.exs` with `assert_within_ms/2`
- [ ] Semantic search < 100ms for 1000 vectors
- [ ] Vector index used (EXPLAIN shows ivfflat or Seq Scan)
- [ ] PageRank calculation < 1s for 1000 nodes
- [ ] No performance regression vs. original Postgrex implementation

### 6.4 Load Testing (Connection Pooling)
**File:** `test/singularity/search/code_search_load_test.exs`

- [ ] Tag as `@tag :load_test` to run separately
- [ ] Test 50 concurrent semantic_search requests
  - [ ] All complete without "too many open connections"
  - [ ] Pool size stays at or below 25
  - [ ] Response times consistent (no timeout exceeded errors)
  - [ ] Connection pool metrics healthy

- [ ] Test transaction isolation with Ecto.Sandbox
  - [ ] Multiple test processes don't interfere
  - [ ] Rollback on test completion works

### 6.5 Migration Testing
- [ ] Fresh database setup via `mix ecto.reset`
- [ ] All tables created with correct schema
- [ ] All indexes created correctly
- [ ] pgvector extension installed (or handled gracefully)
- [ ] Seed data for graph_types inserted

### 6.6 Regression Testing
- [ ] All existing tests still pass
- [ ] No warnings from compiler
- [ ] No deprecation warnings in logs
- [ ] Docstrings updated for all changed functions

### Phase 6 Success Criteria
- [ ] All unit tests pass (8 schema tests)
- [ ] All integration tests pass (refactored functions)
- [ ] Performance tests show no regression
- [ ] Load test shows healthy pooling behavior
- [ ] Migration tests pass on fresh database
- [ ] `mix test` completes successfully
- [ ] `mix quality` passes (format, credo, dialyzer)

---

## Pre-Deployment Checklist

### Code Quality
- [ ] No `Postgrex.query!()` calls remain (except wrapped in Ecto.Adapters.SQL)
- [ ] No raw SQL string concatenation
- [ ] All schemas have @moduledoc
- [ ] All functions have @doc with examples
- [ ] No compiler warnings: `mix compile --warnings-as-errors`
- [ ] Credo passes: `mix credo --strict`
- [ ] Dialyzer passes: `mix dialyzer`

### Documentation
- [ ] Update CLAUDE.md with refactor completion
- [ ] Add migration guide for other modules using CodeSearch
- [ ] Document function signature changes (db_conn → repo)
- [ ] Add troubleshooting guide for pgvector issues

### Backward Compatibility
- [ ] Deprecation warnings added for old `db_conn` parameter (1 week)
- [ ] Both signatures supported temporarily (2 weeks)
- [ ] Old signature removed after deprecation period

### Performance Verification
- [ ] Benchmark vector search: before/after
- [ ] Benchmark pool utilization: before/after
- [ ] Verify no query plan changes (EXPLAIN)
- [ ] Load test with realistic data volume

### Production Safety
- [ ] Staged rollout plan documented
- [ ] Monitoring alerts for connection pool
- [ ] Rollback procedure tested
- [ ] Team trained on new schema structure

---

## Post-Deployment Checklist

- [ ] Monitor connection pool metrics in production
- [ ] Verify no "too many open connections" errors
- [ ] Check vector search performance
- [ ] Monitor query performance (EXPLAIN ANALYZE logs)
- [ ] Verify test coverage metrics improved
- [ ] Update team wiki/docs with new approach
- [ ] Close refactor GitHub issue
- [ ] Document lessons learned

---

## Files Summary

### Created
```
lib/singularity/schemas/
├── codebase_metadata.ex
├── codebase_registry.ex
├── graph_node.ex
├── graph_edge.ex
├── graph_type.ex
├── vector_search.ex
└── vector_similarity_cache.ex

test/singularity/schemas/
├── codebase_metadata_test.exs
├── codebase_registry_test.exs
├── graph_node_test.exs
├── graph_edge_test.exs
├── graph_type_test.exs
├── vector_search_test.exs
└── vector_similarity_cache_test.exs

test/singularity/search/
├── code_search_perf_test.exs
└── code_search_load_test.exs

test/support/
└── perf_helpers.exs
```

### Modified
```
lib/singularity/search/code_search.ex
  - Remove: create_unified_schema() and all create_* functions
  - Replace: 48 Postgrex.query!() calls with Ecto equivalents
  - Update: All function signatures (db_conn → repo)

test/singularity/search/code_search_test.exs
  - Expand: Add tests for all refactored functions
  - Update: Parameter passing (Repo vs. db_conn)
```

### Optional
```
priv/repo/migrations/
  - New migration for Apache AGE setup (if needed)
  - Verify 20250101000020_create_code_search_tables.exs is current
```

---

## Estimated Timeline (Best Case)

| Phase | Duration | Cumulative |
|-------|----------|-----------|
| **1** | 1 day | 1 day |
| **2** | 1.5 days | 2.5 days |
| **3** | 1 day | 3.5 days |
| **4** | 2 days | 5.5 days |
| **5** | 0.5 days | 6 days |
| **6** | 3.5 days | 9.5 days |
| **Review** | 0.5 days | 10 days |
| **TOTAL** | **~10 days** | **2 weeks** |

*With 1-2 days/week focused effort: 5-10 weeks*

---

**Last Updated:** 2025-10-24  
**Status:** READY FOR IMPLEMENTATION  
**Difficulty:** MEDIUM  
**Risk:** HIGH (if not completed - production stability issue)
