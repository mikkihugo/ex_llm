# Postgrex.query!() Analysis Documentation

Complete analysis of 48 Postgrex.query!() calls in `singularity/lib/singularity/search/code_search.ex`, with detailed conversion plan to Ecto.Repo patterns.

## Documents Overview

### 1. POSTGREX_SUMMARY.txt (Quick Start)
**Best for:** Getting a high-level overview in 2-3 minutes
- Breakdown by operation type (DDL, DML, Query)
- Conversion impact assessment
- Recommended phases
- Conversion checklist
- 8.1 KB, ~200 lines

### 2. POSTGREX_ANALYSIS.md (Comprehensive Analysis)
**Best for:** Understanding the full conversion strategy
- Detailed pattern analysis (Pattern 1: DDL, Pattern 2: DML, Pattern 3: Query)
- All 48 calls grouped by function and type
- Existing Ecto integration (semantic_search example)
- Conversion scope & effort breakdown
- Recommended conversion order (5 phases)
- Key observations and quick-wins
- 13 KB, ~380 lines

### 3. POSTGREX_LINE_REFERENCE.md (Technical Reference)
**Best for:** Implementation and code generation
- Line-by-line index of all 48 calls
- Grouped by operation type
- Migration consolidation plan (3 migrations)
- Complete Ecto schema templates (copy-paste ready)
- Before/after conversion examples
- Key conversion decisions
- 13 KB, ~380 lines

---

## Quick Facts

| Metric | Value |
|--------|-------|
| Total Postgrex.query!() calls | 48 |
| File size | 1,273 lines |
| DDL operations (DDL) | 33 (69%) |
| DML operations (INSERT/UPDATE) | 6 (13%) |
| Query operations (SELECT) | 9 (18%) |
| Estimated conversion time | 5-10 days |

---

## Operation Breakdown

### DDL (Schema Creation) - 33 calls
- 8 table creation calls (lines 58, 160, 184, 207, 230, 260, 280, 534)
- 25 index creation calls (lines 300-528)
- **Conversion:** Move to Ecto migrations

### DML (Data Manipulation) - 6 calls
- 5 INSERT operations with ON CONFLICT (lines 560, 708, 859, 893, 244)
- 1 UPDATE operation (line 690)
- **Conversion:** Use Repo.insert_or_update!() with Changesets

### Query (Data Retrieval) - 9 calls
- 4 simple/medium queries (lines 592, 644, 1093, 1127)
- 5 complex queries with vectors/CTEs (lines 961, 990, 1047, 1161, 1223)
- **Conversion:** Use Ecto.Query for simple, Ecto.Adapters.SQL.query! for complex

---

## Key Finding: Existing Pattern

**Good news!** The module already demonstrates the conversion pattern:

**semantic_search/4 (lines 933-984):**
- Accepts both Ecto.Repo AND Postgrex connection
- Uses `Ecto.Adapters.SQL.query!()` for complex vector queries
- Template for converting all remaining queries

---

## Recommended Phases

```
Phase 1: Foundation (2-3 days)
├── Create 4 Ecto schemas
├── Write initial migration
└── Create changeset functions

Phase 2: Migrations (1-2 days)
├── Extract 33 DDL calls
└── Verify migration runs

Phase 3: Data Functions (1-2 days)
├── Convert 6 DML operations
└── Update function signatures

Phase 4: Query Functions (1 day)
├── Simple queries → Ecto.Query
└── Complex queries → Use existing pattern

Phase 5: Testing & Cleanup (1-2 days)
├── Test with Ecto.Sandbox
└── Performance verification
```

---

## Ecto Schemas Needed

1. **CodebaseMetadata** - 99 fields (largest!)
   - Stores file metadata with 50+ code metrics
   - Includes vector embeddings

2. **CodebaseRegistry** - 10 fields
   - Tracks registered codebases
   - Analysis status and metadata

3. **GraphNode** - 9 fields
   - Graph nodes for code relationships
   - Includes vector embeddings

4. **GraphEdge** - 7 fields
   - Graph edges between nodes
   - Dependency tracking

See POSTGREX_LINE_REFERENCE.md for complete schema templates.

---

## Complex Queries (Keep as SQL)

These queries require custom PostgreSQL features and should use `Ecto.Adapters.SQL.query!()`:

1. **semantic_search** - Vector distance operator (<->)
2. **find_similar_nodes** - CTE with CROSS JOIN
3. **multi_codebase_search** - Dynamic WHERE IN clause
4. **detect_circular_dependencies** - RECURSIVE CTE
5. **calculate_pagerank** - RECURSIVE CTE with aggregation

Pattern (line 955):
```elixir
query = """SELECT ... WHERE ... LIMIT $1"""
Ecto.Adapters.SQL.query!(repo, query, params)
|> Map.get(:rows)
|> Enum.map(fn [...] -> %{...} end)
```

---

## Reading Guide

**If you have 5 minutes:** Read POSTGREX_SUMMARY.txt (lines 1-100)

**If you have 15 minutes:** Read POSTGREX_SUMMARY.txt (entire file)

**If you have 30 minutes:** Read POSTGREX_ANALYSIS.md (entire file)

**If you're implementing the conversion:** Use POSTGREX_LINE_REFERENCE.md for templates

---

## Implementation Checklist

See POSTGREX_SUMMARY.txt "CONVERSION CHECKLIST" section for complete list.

Quick priority:
1. [ ] Create 4 Ecto schemas
2. [ ] Write migrations (DDL calls)
3. [ ] Convert DML functions
4. [ ] Update query functions
5. [ ] Test with Ecto.Sandbox

---

## No Blockers!

This conversion is straightforward:

- ✅ Ecto supports all operations (vectors, CTEs, jsonb)
- ✅ Pattern already demonstrated (semantic_search/4)
- ✅ No complex cross-cutting concerns
- ✅ Clear separation of concerns (DDL/DML/Query)
- ✅ Good existing error handling

---

## Questions?

- **Why Ecto instead of Postgrex?**
  - Connection pooling automatically managed
  - Type safety with schemas
  - Changesets for validation
  - Better testing with Ecto.Sandbox
  - Standard Elixir pattern

- **Do we need to convert complex queries?**
  - No! Use Ecto.Adapters.SQL.query!() which is already in use
  - Allows custom SQL when needed

- **Will this affect performance?**
  - No! Ecto uses Postgrex under the hood
  - Connection pooling may improve performance
  - Same query execution, better infrastructure

---

## File Locations

All analysis files in repository root:
- `/Users/mhugo/code/singularity-incubation/POSTGREX_README.md` (this file)
- `/Users/mhugo/code/singularity-incubation/POSTGREX_SUMMARY.txt`
- `/Users/mhugo/code/singularity-incubation/POSTGREX_ANALYSIS.md`
- `/Users/mhugo/code/singularity-incubation/POSTGREX_LINE_REFERENCE.md`

Source file:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/code_search.ex`

---

Generated: October 24, 2025
