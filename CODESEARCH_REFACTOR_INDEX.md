# CodeSearch Postgrex Refactor - Documentation Index

**Status:** Analysis Complete, Ready for Implementation  
**Generated:** 2025-10-24  
**Total Documentation:** 2,536 lines across 3 documents  
**File Analyzed:** `singularity/lib/singularity/search/code_search.ex` (1,272 lines)

---

## Document Overview

### 1. CODESEARCH_REFACTOR_SUMMARY.md (408 lines)
**Purpose:** Quick reference guide - read this first  
**Time to read:** 15 minutes

**Best for:**
- Getting the 60-second problem summary
- Understanding the big picture
- Finding quick code examples (before/after)
- Risk assessment overview
- Timeline estimates
- Success metrics checklist

**Key sections:**
- At a Glance (metrics table)
- The Problem (in 60 seconds)
- Real-World Impact
- 48 Calls Categorized (by group)
- Conversion Priority (6 phases)
- Code Examples
- Risk Analysis
- Testing Checklist

**Start here if:** You're new to the refactor and want the executive summary

---

### 2. CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md (1,608 lines)
**Purpose:** Comprehensive technical analysis with detailed explanations  
**Time to read:** 45 minutes

**Best for:**
- Understanding why Postgrex.query!() is problematic
- Deep dive into pooling architecture
- Detailed categorization of all 48 calls
- Complete refactor strategy
- Implementation patterns with code examples
- Risk mitigation approaches
- Testing methodology

**Key sections:**
- Part 1: Current State Analysis
  - Complete inventory of all 48 calls
  - Summary table with effort estimates
- Part 2: Pooling Impact Analysis
  - Why it bypasses pooling
  - Load test scenarios
  - Specific pooling issues with examples
- Part 3: Refactor Analysis
  - Which calls convert to Ecto
  - Which need fragments
  - Which have dynamic SQL
  - Priority order with effort
- Part 4: Implementation Plan
  - Full schema code examples
  - Query conversion before/after
- Part 5: Testing Approach
  - Unit test examples
  - Integration test patterns
  - Performance test strategy
  - Load test scenarios
- Part 6: Risk Mitigation
  - Breaking changes strategy
  - Vector embedding compatibility
  - Gradual rollout
  - Rollback plan
- Part 7: Success Criteria

**Start here if:** You want technical details before implementing

---

### 3. CODESEARCH_REFACTOR_CHECKLIST.md (520 lines)
**Purpose:** Detailed implementation checklist with task breakdown  
**Time to read:** 30 minutes (as reference while implementing)

**Best for:**
- Day-to-day implementation work
- Tracking progress phase by phase
- Detailed task breakdown within each phase
- Estimating per-function effort
- Pre-deployment verification
- Post-deployment checklist

**Key sections:**
- Phase 1: Foundation - Create Ecto Schemas
  - 8 schema creation tasks
  - Specific fields per schema
  - Migration verification
  - Initial test requirements
  
- Phase 2-5: Refactoring by Operation Type
  - Simple SELECT/UPDATE
  - INSERT/UPSERT
  - Vector Search
  - Advanced Algorithms
  - Specific function checklists per phase

- Phase 6: Testing & Validation
  - Unit test checklist
  - Integration test checklist
  - Performance test checklist
  - Load testing checklist
  - Regression testing checklist

- Pre-Deployment Checklist
- Post-Deployment Checklist
- Files Summary
- Timeline (best case)

**Start here if:** You're ready to implement and want task-by-task guidance

---

## How to Use These Documents

### For Project Managers / Decision Makers
1. Read **CODESEARCH_REFACTOR_SUMMARY.md** (15 min)
2. Check **Risk Analysis** section
3. Review **Timeline** section
4. Make go/no-go decision

### For Developers Starting the Refactor
1. Read **CODESEARCH_REFACTOR_SUMMARY.md** (15 min)
2. Skim **CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md** parts 1-3 (20 min)
3. Use **CODESEARCH_REFACTOR_CHECKLIST.md** as daily guide

### For Code Reviewers
1. Reference **CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md** part 4 (implementation patterns)
2. Cross-check against **CODESEARCH_REFACTOR_CHECKLIST.md** success criteria per phase
3. Verify pooling benefits with load testing (part 5)

### For Quality/Testing
1. Read **CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md** part 5 (testing)
2. Reference **CODESEARCH_REFACTOR_CHECKLIST.md** phase 6 (testing checklist)
3. Implement performance benchmarks from testing section

---

## Key Findings Summary

### The Problem
- **48 Postgrex.query!() calls** bypass Ecto's connection pool
- **No type safety** - raw SQL strings prone to errors
- **Pool exhaustion risk** - "too many open connections" errors at 25+ concurrent requests
- **Hard to test** - Postgrex bypasses Ecto.Sandbox

### The Solution
- Create **8 Ecto schemas** (codebase_metadata, codebase_registry, graph_node, graph_edge, graph_type, vector_search, vector_similarity_cache)
- Convert **35 calls to Ecto** (SELECT, INSERT, UPDATE, vector search with fragments)
- Wrap **2 advanced queries** in Ecto.Adapters.SQL (keep SQL, gain pooling)
- **Delete 23 runtime schema calls** (use migrations instead)

### Effort Estimate
- **Best case:** 10 days (2 weeks)
- **Realistic:** 5-10 weeks (at 1-2 days/week)
- **Phases:** 6 phases, each with clear success criteria
- **Risk:** HIGH if not completed (production stability)

### Key Metrics After Refactor
- Connection pool fully utilized
- No "too many open connections" errors
- Vector search maintained at < 100ms
- Type-safe schema validation
- Better test isolation (Ecto.Sandbox)
- Production-ready architecture

---

## Quick Navigation

### Find information about...

**Specific Postgrex.query!() call:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md, Part 1, Section 1.1

**Pooling behavior/risks:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md, Part 2

**Conversion strategy for a function:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md, Part 3, or Part 4

**Code examples (before/after):**
→ CODESEARCH_REFACTOR_SUMMARY.md "Code Examples" section  
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 4

**Schema field specifications:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 4.1

**Test implementation patterns:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 5

**Implementation task list:**
→ CODESEARCH_REFACTOR_CHECKLIST.md (Phase 1-6)

**Performance benchmarking:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 5 "Performance Testing"

**Load testing approach:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 5 "Load Testing"

**Risk mitigation:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 6

**Success criteria:**
→ CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md Part 7

---

## File Statistics

| Document | Size | Lines | Focus | Audience |
|----------|------|-------|-------|----------|
| Summary | 12 KB | 408 | Quick reference, overview | Everyone |
| Analysis | 50 KB | 1,608 | Technical deep dive | Developers, architects |
| Checklist | 19 KB | 520 | Implementation guide | Implementers, QA |
| **TOTAL** | **81 KB** | **2,536** | - | - |

---

## Related Files in Repository

### Source File (subject of refactor)
```
singularity/lib/singularity/search/code_search.ex
- 1,272 lines
- 48 Postgrex.query!() calls
- 7 database operations groups
```

### Existing Migration (already handles schema)
```
singularity/priv/repo/migrations/20250101000020_create_code_search_tables.exs
- Table creation (CREATE TABLE)
- Index creation (CREATE INDEX)
- Default data (INSERT)
- Uses Ecto.Migration DSL
```

### Where to Create New Files
```
singularity/lib/singularity/schemas/
  (8 new schema files needed)

singularity/lib/singularity/search/
  (modify code_search.ex)

test/singularity/schemas/
  (7+ new test files)

test/singularity/search/
  (expand code_search_test.exs, add perf tests)

test/support/
  (add perf_helpers.exs)
```

---

## Implementation Timeline

### Week 1: Foundation
- [ ] Read all 3 documents (Friday - 1.5 hours)
- [ ] Create GitHub issue with checklist
- [ ] **Phase 1:** Create 8 Ecto schemas (1 day)

### Week 2-3: Simple Queries
- [ ] **Phase 2:** Refactor SELECT/UPDATE (1.5 days)
- [ ] **Phase 3:** Refactor INSERT/UPSERT (1 day)
- [ ] Testing & validation (2 days)

### Week 4-5: Complex Queries
- [ ] **Phase 4:** Vector search (2 days)
- [ ] **Phase 5:** Advanced algorithms (0.5 day)
- [ ] Testing & validation (2.5 days)

### Week 6: Finalization
- [ ] **Phase 6:** Comprehensive testing (3.5 days)
- [ ] Pre-deployment checks
- [ ] Code review & merge
- [ ] Staged deployment

---

## Getting Started

### Step 1: Read the Docs (2 hours)
```bash
# Summary (15 min)
less CODESEARCH_REFACTOR_SUMMARY.md

# Analysis (45 min)
less CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md

# Checklist (30 min)
less CODESEARCH_REFACTOR_CHECKLIST.md
```

### Step 2: Understand the Current Code (1 hour)
```bash
# View the file to refactor
less singularity/lib/singularity/search/code_search.ex

# See the existing migration
less singularity/priv/repo/migrations/20250101000020_create_code_search_tables.exs
```

### Step 3: Create Implementation Plan (30 min)
```bash
# Create GitHub issue from CODESEARCH_REFACTOR_CHECKLIST.md
gh issue create --title "CodeSearch: Refactor Postgrex → Ecto" \
  --body "See CODESEARCH_REFACTOR_ANALYSIS.md for full details"

# Or use this simpler version:
gh issue create \
  --title "CodeSearch: Refactor Postgrex → Ecto" \
  --body "## Summary
48 Postgrex.query!() calls bypass connection pooling.

## Risk
- Pool exhaustion at 25+ concurrent requests
- Production 'too many open connections' errors
- No type safety, hard to test

## Solution
- Create 8 Ecto schemas
- Convert to Ecto.Query/Changesets
- Still use Ecto.Adapters.SQL for complex queries

## Effort
- 10 days estimated (2 weeks)
- 5-10 weeks realistic (1-2 days/week)

## Next Steps
See CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md for full technical analysis.
See CODESEARCH_REFACTOR_CHECKLIST.md for phase-by-phase tasks."
```

### Step 4: Start Phase 1
```bash
# Create schema directory
mkdir -p singularity/lib/singularity/schemas

# Use templates from CODESEARCH_POSTGREX_REFACTOR_ANALYSIS.md part 4.1
# Create 8 schema files (CodebaseMetadata, CodebaseRegistry, etc.)
```

---

## Document Maintenance

These documents were generated from:
- Source file: `singularity/lib/singularity/search/code_search.ex`
- Migration: `singularity/priv/repo/migrations/20250101000020_create_code_search_tables.exs`
- Analysis date: 2025-10-24

**Updates needed if:**
- Code structure changes significantly
- New pgvector features added
- Ecto version upgrades
- PostgreSQL version changes

**To update:**
1. Review changes to code_search.ex
2. Recount Postgrex.query!() calls
3. Update PART 1 of analysis document
4. Recalculate effort estimates
5. Update timeline/checklist

---

## Questions / Clarifications

**Q: Why 8 schemas if there are only 7 tables?**  
A: 8 tables total (codebase_metadata, codebase_registry, graph_nodes, graph_edges, graph_types, vector_search, vector_similarity_cache + one more during analysis). Each gets an Ecto schema.

**Q: Can we keep using Postgrex?**  
A: Not recommended. It bypasses pooling entirely. Ecto.Adapters.SQL.query!() achieves best of both worlds: pooling + raw SQL for complex queries.

**Q: Will this break existing code?**  
A: Yes, function signatures change (db_conn → repo). Deprecation warnings planned for 2 weeks during transition.

**Q: What if pgvector extension isn't installed?**  
A: Schema gracefully degrades. Migration can handle failure. Code checks for vector support at runtime.

**Q: Can we do this incrementally?**  
A: Yes! Each phase is somewhat independent:
- Phase 1 (schemas) → foundation
- Phase 2-3 (simple ops) → can merge once Phase 1 done
- Phase 4 (complex) → can merge once Phase 1-3 done
- Phase 5 (algorithms) → independent
- Phase 6 (testing) → continuous throughout

**Q: Performance impact?**  
A: None or better. Vector search might be faster with Ecto's prepared statements. Pooling helps under concurrent load.

---

**Last Updated:** 2025-10-24  
**Status:** ANALYSIS COMPLETE, READY TO IMPLEMENT  
**Estimated Reading Time:** 2-3 hours for all documents  
**Estimated Implementation Time:** 2 weeks to 10 weeks (depending on resource allocation)

---

## Directory Structure After Implementation

```
singularity/
├── lib/singularity/
│   ├── schemas/                          (NEW)
│   │   ├── codebase_metadata.ex          (NEW)
│   │   ├── codebase_registry.ex          (NEW)
│   │   ├── graph_node.ex                 (NEW)
│   │   ├── graph_edge.ex                 (NEW)
│   │   ├── graph_type.ex                 (NEW)
│   │   ├── vector_search.ex              (NEW)
│   │   └── vector_similarity_cache.ex    (NEW)
│   └── search/
│       └── code_search.ex                (MODIFIED)
├── priv/repo/migrations/
│   └── 20250101000020_create_code_search_tables.exs (VERIFIED)
└── test/
    ├── support/
    │   └── perf_helpers.exs              (NEW)
    └── singularity/
        ├── schemas/                      (NEW)
        │   ├── codebase_metadata_test.exs
        │   ├── codebase_registry_test.exs
        │   ├── graph_node_test.exs
        │   ├── graph_edge_test.exs
        │   ├── graph_type_test.exs
        │   ├── vector_search_test.exs
        │   └── vector_similarity_cache_test.exs
        └── search/
            ├── code_search_test.exs      (EXPANDED)
            ├── code_search_perf_test.exs (NEW)
            └── code_search_load_test.exs (NEW)
```

