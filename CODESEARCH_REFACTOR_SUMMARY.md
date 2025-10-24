# CodeSearch Postgrex Refactor - Quick Reference

## At a Glance

| Metric | Value |
|--------|-------|
| **Total Postgrex.query!() calls** | 48 |
| **Tables to migrate** | 7 |
| **Ecto schemas needed** | 8 |
| **Estimated effort** | 4-6 weeks |
| **Production risk** | HIGH (connection pool exhaustion) |
| **Refactor complexity** | MEDIUM |

---

## The Problem (In 60 Seconds)

```
Current: CodeSearch uses raw Postgrex.query!() 
         → Bypasses Ecto's connection pool
         → No type safety, hard to test
         → Pool exhaustion under load

Fixed:   CodeSearch uses Ecto.Repo
         → Leverages connection pooling
         → Type-safe schemas & changesets
         → Proper transaction support
```

### Real-World Impact

**Before (10+ concurrent requests):**
```
✅ Requests 1-25: Work fine
⚠️  Request 26: "too many open connections" error
❌ Application crashes
```

**After (10+ concurrent requests):**
```
✅ Requests 1-25: Fast from pool
✅ Requests 26-50: Queue (wait for connections)
✅ All requests complete eventually
```

---

## 48 Postgrex.query!() Calls Categorized

### Group 1: Runtime Schema Creation (23 calls)
**Status:** DELETE THESE - Migrations handle this

- `create_codebase_metadata_table()` - 2 CREATE TABLE statements
- `create_graph_tables()` - 3 CREATE TABLE + 1 INSERT
- `create_performance_indexes()` - 14 CREATE INDEX statements
- `create_apache_age_extension()` - 1 CREATE EXTENSION

**Action:** Remove entire `create_unified_schema()` function. Rely on migration `20250101000020_create_code_search_tables.exs`.

---

### Group 2: Simple SELECT/UPDATE (8 calls)
**Status:** CONVERT TO ECTO - Easy, high impact

| Function | Current | Convert To | Effort |
|----------|---------|-----------|--------|
| `get_codebase_registry()` | Raw SELECT | `Repo.get_by()` | 15 min |
| `list_codebases()` | Raw SELECT | `Repo.all()` | 15 min |
| `update_codebase_status()` | Raw UPDATE | Changeset + `Repo.update()` | 20 min |
| `get_dependencies()` | SELECT + JOIN | `Repo.all()` + `join()` | 20 min |
| `get_dependents()` | SELECT + JOIN | `Repo.all()` + `join()` | 20 min |

---

### Group 3: INSERT/UPSERT (4 calls)
**Status:** CONVERT TO ECTO - Medium complexity

| Function | Current | Convert To | Effort |
|----------|---------|-----------|--------|
| `register_codebase()` | INSERT ON CONFLICT | `Repo.insert(..., on_conflict: ...)` | 25 min |
| `insert_graph_node()` | INSERT ON CONFLICT | `Repo.insert(..., on_conflict: ...)` | 25 min |
| `insert_graph_edge()` | INSERT ON CONFLICT | `Repo.insert(..., on_conflict: ...)` | 25 min |
| `insert_codebase_metadata()` | INSERT 55 fields ON CONFLICT | `Repo.insert()` + `Ecto.Multi` | 1.5 hours |

---

### Group 4: Vector Search (4 calls)
**Status:** CONVERT TO ECTO WITH FRAGMENTS - Medium complexity

| Function | Current | Convert To | Effort |
|----------|---------|-----------|--------|
| `semantic_search()` | Raw SQL pgvector | `Ecto.Query` + `fragment()` | 45 min |
| `find_similar_nodes()` | CTE + pgvector | `Ecto.Query` + `with_cte()` + `fragment()` | 1.5 hours |
| `multi_codebase_search()` | Dynamic IN + pgvector | Dynamic `where()` + `fragment()` | 1 hour |

---

### Group 5: Advanced Algorithms (2 calls)
**Status:** KEEP AS RAW SQL - Just add pooling

| Function | Current | Convert To | Effort |
|----------|---------|-----------|--------|
| `detect_circular_dependencies()` | Recursive CTE | `Ecto.Adapters.SQL.query!()` | 10 min |
| `calculate_pagerank()` | Recursive CTE + aggregation | `Ecto.Adapters.SQL.query!()` | 10 min |

**Benefit:** Still uses Ecto's connection pooling, just not fully type-safe (acceptable for complex algorithms).

---

## Conversion Priority

### Phase 1: Schemas (1 day)
**Create 8 Ecto schemas:**
1. CodebaseMetadata
2. CodebaseRegistry
3. GraphNode
4. GraphEdge
5. GraphType
6. VectorSearch
7. VectorSimilarityCache

**Remove:** All `create_*` functions from CodeSearch module

### Phase 2: Simple Queries (1.5 days)
**Convert 5 select/update queries** - Straightforward Ecto.Query replacements

### Phase 3: Insert/Upsert (1 day)
**Convert 4 insert operations** - Use Ecto changesets + `on_conflict` options

### Phase 4: Vector Search (2 days)
**Convert 3 vector operations** - Use `Ecto.Query` fragments for pgvector operators

### Phase 5: Advanced Algorithms (0.5 days)
**Wrap 2 recursive CTEs** - Move to `Ecto.Adapters.SQL.query!()`

### Phase 6: Testing & Validation (3.5 days)
**Per phase:**
- Unit tests for schemas
- Integration tests
- Performance testing
- Load testing (pooling behavior)

---

## Code Examples: Before → After

### Example 1: Simple SELECT
```elixir
# BEFORE (48 chars, no type safety)
def get_codebase_registry(db_conn, codebase_id) do
  Postgrex.query!(db_conn, "SELECT ... FROM codebase_registry WHERE codebase_id = $1", [codebase_id])
  |> Map.get(:rows)
  |> case do [...] -> %{...} end
end

# AFTER (25 chars, type-safe)
def get_codebase_registry(repo, codebase_id) do
  repo.get_by(CodebaseRegistry, codebase_id: codebase_id)
end
```

### Example 2: Vector Search
```elixir
# BEFORE (complex raw SQL)
def semantic_search(db_conn, codebase_id, query_vector, limit) do
  Postgrex.query!(db_conn, """
    SELECT ... vector_embedding <-> $2 as distance ...
    ORDER BY vector_embedding <-> $2
  """, [codebase_id, query_vector, limit])
end

# AFTER (composable Ecto query)
def semantic_search(repo, codebase_id, query_vector, limit) do
  from(m in CodebaseMetadata,
    where: m.codebase_id == ^codebase_id and not is_nil(m.vector_embedding),
    select: %{
      path: m.path,
      similarity: fragment("1 - (vector_embedding <-> ?)", ^query_vector)
    },
    order_by: [fragment("vector_embedding <-> ?", ^query_vector)],
    limit: ^limit
  )
  |> repo.all()
end
```

### Example 3: Complex Algorithm
```elixir
# BEFORE (Postgrex direct)
def detect_circular_dependencies(db_conn) do
  Postgrex.query!(db_conn, "WITH RECURSIVE dependency_path AS (...)", [])
  |> Map.get(:rows)
end

# AFTER (Pooled via Ecto)
def detect_circular_dependencies(repo) do
  Ecto.Adapters.SQL.query!(repo, "WITH RECURSIVE dependency_path AS (...)", [])
  |> Map.get(:rows)
end
# Still gets connection from pool! Just not type-safe (acceptable for complex SQL)
```

---

## Risk Analysis

### Risk 1: Connection Pool Exhaustion
**Severity:** HIGH  
**Current:** Postgrex.query!() bypasses pool (default: 25 connections)  
**Impact:** "too many open connections" errors at 25+ concurrent requests  
**Solution:** Migrate to Ecto.Repo (uses pooling)  
**Timeline:** Immediate (blocking production issues)

### Risk 2: No Type Safety
**Severity:** MEDIUM  
**Current:** Raw SQL strings, typos not caught until runtime  
**Impact:** Production crashes from bad SQL  
**Solution:** Ecto schemas + changesets  
**Timeline:** Medium (prevents regressions)

### Risk 3: Test Isolation
**Severity:** MEDIUM  
**Current:** Postgrex bypasses Ecto.Sandbox  
**Impact:** Tests interfere with each other, non-deterministic failures  
**Solution:** Use Ecto.Repo with Sandbox  
**Timeline:** Long-term (improves test reliability)

### Risk 4: Migration Duplication
**Severity:** LOW  
**Current:** Schema created both in migration AND runtime  
**Impact:** Maintenance burden, version skew  
**Solution:** Delete runtime schema creation  
**Timeline:** Cleanup during refactor

---

## Testing Checklist

### Unit Tests
- [ ] All 8 schemas validate correctly
- [ ] Changesets enforce required fields
- [ ] JSON fields encode/decode properly
- [ ] Vector field handles Pgvector types

### Integration Tests  
- [ ] `get_codebase_registry()` returns correct record
- [ ] `list_codebases()` ordered by created_at DESC
- [ ] `semantic_search()` returns results ordered by similarity
- [ ] `find_similar_nodes()` handles missing vectors gracefully
- [ ] `insert_codebase_metadata()` upserts correctly
- [ ] `detect_circular_dependencies()` finds cycles

### Performance Tests
- [ ] Vector search < 100ms for 1000 vectors
- [ ] Vector index used (EXPLAIN shows ivfflat)
- [ ] 50 concurrent requests complete without errors

### Pooling Tests
- [ ] Connection pool stays ≤ 25 under load
- [ ] Connections returned to pool after query
- [ ] Ecto.Sandbox isolation works for tests
- [ ] Transaction rollback works

---

## Success Metrics

After refactor, you should see:

**Stability:**
- No more "too many open connections" errors
- Graceful degradation at high concurrency (queuing, not crashing)

**Performance:**
- Vector search maintains < 100ms latency
- No regression in PageRank calculation speed
- Connection pool fully utilized

**Quality:**
- Compile-time errors catch SQL typos
- All 48 Postgrex calls replaced or wrapped
- Test coverage improves (Ecto.Sandbox works)

**Maintainability:**
- Schema code self-documents via Ecto
- Migrations versioned and reversible
- Less raw SQL in codebase

---

## Files to Create/Modify

### New Files (8 schemas)
```
lib/singularity/schemas/
  ├── codebase_metadata.ex
  ├── codebase_registry.ex
  ├── graph_node.ex
  ├── graph_edge.ex
  ├── graph_type.ex
  ├── vector_search.ex
  └── vector_similarity_cache.ex
```

### Modified Files
```
lib/singularity/search/code_search.ex
  - Remove all create_* functions
  - Replace 48 Postgrex.query!() calls
  - Update function signatures to accept Repo

priv/repo/migrations/
  - Optional: Create migration for Apache AGE setup
  - Verify 20250101000020_create_code_search_tables.exs is current
```

### Test Files
```
test/singularity/schemas/
  ├── codebase_metadata_test.exs
  ├── codebase_registry_test.exs
  ├── graph_node_test.exs
  └── [etc. for other schemas]

test/singularity/search/
  ├── code_search_test.exs (expanded)
  ├── code_search_perf_test.exs (new)
  └── code_search_load_test.exs (new)
```

---

## Quick Decision Tree

**Question 1: Is the query simple (SELECT, INSERT, UPDATE)?**
- YES → Convert to Ecto.Query or Changeset (Phase 2-3)
- NO → Go to Question 2

**Question 2: Does it use pgvector operations?**
- YES → Use Ecto.Query with `fragment()` (Phase 4)
- NO → Go to Question 3

**Question 3: Is it a complex algorithm (recursive CTE)?**
- YES → Wrap in `Ecto.Adapters.SQL.query!()` (Phase 5)
- NO → Should have caught in earlier questions!

---

## Timeline

| Phase | Work | Days | Status |
|-------|------|------|--------|
| **1** | Create 8 schemas | 1 | Not started |
| **2** | Convert simple queries | 1.5 | Not started |
| **3** | Convert inserts | 1 | Not started |
| **4** | Vector search queries | 2 | Not started |
| **5** | Wrap advanced queries | 0.5 | Not started |
| **6** | Test & validate | 3.5 | Not started |
| **TOTAL** | All phases | **~10 days** | Not started |

**With 1-2 days/week effort: 5-10 weeks**

---

## Full Documentation

For detailed information, see: `CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md`

**That document includes:**
- Complete inventory of all 48 calls
- Detailed pooling analysis
- Full implementation examples
- Comprehensive testing approach
- Risk mitigation strategies
- Success criteria checklist

---

## Quick Start

```bash
# Step 1: Read this summary (you're here!)

# Step 2: Read detailed analysis
cat CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md

# Step 3: Create issue with checklist
gh issue create --title "CodeSearch: Refactor Postgrex → Ecto" \
  --body "See CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md for details"

# Step 4: Start Phase 1
# Create lib/singularity/schemas/ directory + 8 schema files

# Step 5: Run tests after each phase
mix test test/singularity/schemas/
mix test test/singularity/search/

# Step 6: Deploy incrementally with deprecation warnings
```

---

**Generated:** 2025-10-24  
**Repository:** /Users/mhugo/code/singularity-incubation  
**Related Files:**
- CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md (full technical guide)
- singularity/lib/singularity/search/code_search.ex (subject of refactor)
- singularity/priv/repo/migrations/20250101000020_create_code_search_tables.exs (existing migrations)
