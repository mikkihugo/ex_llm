# 🏗️ Code Organization Action Plan

**Current State:** 450 files | 86 directories | Duplicates and scattered concerns
**Target State:** 430 files | 65 directories | Clear organization, single responsibility
**Effort:** 20-30 hours across 7 phases

---

## The Core Problem

Singularity has 8 **excellent orchestration systems** (pattern detection, code analysis, code generation, search, jobs, extraction, execution) but is undermined by:

1. **~50 duplicate files** scattered across multiple namespaces
2. **Kitchen sink directory** (`storage/code/`) mixing 8 different concerns
3. **24 root-level modules** (5,961 LOC) with no clear home
4. **Quality operations scattered** across 3 different namespaces
5. **Multiple engine directories** causing confusion
6. **Inconsistent patterns** in newer code

---

## The Golden Pattern (Copy This!)

All well-organized subsystems follow this structure:

```
domain_feature/
├── behavior_type.ex          # Contract: @callback definitions
├── orchestrator.ex           # Public API: Loads + coordinates implementations
├── implementations/          # All concrete implementations
│   ├── impl_a.ex
│   ├── impl_b.ex
│   └── impl_c.ex
└── utilities.ex              # Shared helpers (optional)
```

**Examples of correct implementation:**
- `architecture_engine/` - Pattern detection (perfect!)
- `code_analysis/` - Code scanning (minimal but clean)
- `code_generation/` - Code generation (excellent)
- `search/` - Search system (complete)
- `jobs/` - Background jobs (well-organized)

**Examples of broken implementation:**
- `storage/code/` - Kitchen sink (8 concerns mixed)
- root-level modules - 24 files floating
- `code_quality/` - Duplicates code_analysis/

---

## Phase-by-Phase Action Plan

### ⚡ PHASE 1: Analyzer Deduplication (2-3 days, HIGH VALUE)

**Current State:**
```
architecture_engine/analyzers/
├── analyzer_type.ex
├── analysis_orchestrator.ex
├── analyzers/
│   ├── feedback_analyzer.ex
│   ├── quality_analyzer.ex
│   ├── refactoring_analyzer.ex
│   └── microservice_analyzer.ex ← PRIMARY

storage/code/analyzers/
├── microservice_analyzer.ex ← DUPLICATE!
├── quality_analyzer.ex ← DUPLICATE!
└── ... (other duplicates)

code_quality/
├── ast_quality_analyzer.ex ← DUPLICATE!
└── ast_security_analyzer.ex

refactoring/
├── analyzer.ex ← DUPLICATE!

execution/feedback/
├── analyzer.ex ← DUPLICATE!
```

**Action:**
1. ✅ Keep: `architecture_engine/analyzers/` (used by orchestrator)
2. 🗑️ Delete: `storage/code/analyzers/` (all 4 files)
3. 🗑️ Delete: `code_quality/ast_quality_analyzer.ex`
4. 🗑️ Delete: `code_quality/ast_security_analyzer.ex`
5. 🗑️ Delete: `refactoring/analyzer.ex`
6. 🔄 Merge: `execution/feedback/analyzer.ex` → `architecture_engine/analyzers/feedback_analyzer.ex`
7. ✏️ Update: All imports pointing to old locations

**Files Affected:**
- Delete: ~8 files
- Update imports: ~15 files

**Verification:**
```bash
grep -r "storage.code.analyzers" --include="*.ex"  # Should be 0 results
grep -r "code_quality.*analyzer" --include="*.ex"  # Should be 0 results
grep -r "refactoring.*analyzer" --include="*.ex"   # Should be 0 results
```

**Expected Result:** Single source of truth for all analyzers

---

### ⚡ PHASE 2: Generator Deduplication (2-3 days, HIGH VALUE)

**Current State:**
```
code_generation/
├── generator_type.ex
├── generation_orchestrator.ex
└── generators/
    ├── code_generator_impl.ex
    ├── rag_generator_impl.ex
    ├── generator_engine_impl.ex
    └── quality_generator.ex ← PRIMARY

storage/code/generators/
├── code_generator.ex ← DUPLICATE!
├── quality_generator.ex ← DUPLICATE!
└── ... (other duplicates)

generator_engine/
├── lib.ex (directory) ← CONFUSING!

engines/generator_engine.ex (file!) ← CONFUSING!

Root-level code_generator.ex ← DUPLICATE! (598 LOC)
```

**Action:**
1. ✅ Keep: `code_generation/generators/` (used by orchestrator)
2. 🗑️ Delete: `storage/code/generators/` (all 4 files)
3. 🗑️ Delete: `generator_engine/` directory
4. 🗑️ Delete: `engines/generator_engine.ex`
5. 🗑️ Delete: root-level `code_generator.ex` (move logic to proper place)
6. 🔄 Consolidate: `embedding_engine.ex` (308 LOC) - decide: integrate or keep?
7. ✏️ Update: All imports and references

**Files Affected:**
- Delete: ~12 files
- Update imports: ~20 files

**Special Case: `embedding_engine.ex` (308 LOC)**
- Option A: Integrate into `embedding/` subsystem (better)
- Option B: Move to `infrastructure/` (acceptable)
- Decision needed based on usage patterns

**Expected Result:** Single source of truth for all generators, no root-level code_generator.ex

---

### 📦 PHASE 3: Root Module Migration (1-2 days, HIGH VALUE)

**Current State:**
```
lib/singularity/ (root level - CHAOS!)
├── runner.ex (1,190 LOC) - Execution/Job Runner
├── code_analyzer.ex (734 LOC) - Duplicate of orchestrator
├── code_generator.ex (598 LOC) - Duplicate (deleted in Phase 2)
├── quality.ex (487 LOC) - Quality operations
├── refactoring.ex (401 LOC) - Refactoring logic
├── code_pattern_extractor.ex (279 LOC) - Extraction logic
├── semantic_code_search.ex (247 LOC) - Search utility
├── language_detection.ex (210 LOC) - Language detection
├── nats_orchestrator.ex (198 LOC) - NATS coordination
├── schema_generator.ex (187 LOC) - Generation utility
└── ... (14 more files, 4,200 more LOC)
```

**Action:**
1. `runner.ex` (1,190 LOC) → `execution/runner.ex`
2. `code_analyzer.ex` (734 LOC) → Delete (duplicate of orchestrator)
3. `quality.ex` (487 LOC) → `code_analysis/quality.ex`
4. `refactoring.ex` (401 LOC) → `code_analysis/refactoring.ex`
5. `code_pattern_extractor.ex` (279 LOC) → `analysis/extractors/code_pattern_extractor.ex`
6. `semantic_code_search.ex` (247 LOC) → `search/semantic_code_search.ex`
7. `language_detection.ex` (210 LOC) → `analysis/language_detection.ex`
8. `nats_orchestrator.ex` (198 LOC) → `nats/orchestrator.ex`
9. `schema_generator.ex` (187 LOC) → `code_generation/schema_generator.ex`
10. ... (and 14 more)

**Files Affected:**
- Move: 24 files
- Delete: 3 files (duplicates)
- Update imports: ~40 files

**Expected Result:** Only ~6 essential root modules remain:
- `application.ex` - OTP supervisor
- `repo.ex` - Database connection
- `lib.ex` - Public API (if needed)
- `supervisor.ex` - Main supervisor
- `telemetry.ex` - Metrics
- `config.ex` - Configuration

---

### 🍲 PHASE 4: Decompose Kitchen Sink `storage/code/` (2-3 days, HIGH VALUE)

**Current State:**
```
storage/code/ (31 files - 8 different concerns!)
├── ai_metadata_extractor.ex → extraction/
├── code_pattern_extractor.ex → analysis/ (moved in Phase 3)
├── patterns/
│   ├── code_pattern_extractor.ex
│   └── code_pattern_store.ex
├── quality/
│   ├── refactoring_agent.ex
│   └── ... (quality stuff)
├── session/
│   └── ... (session stuff)
├── analyzers/ → DELETE (Phase 1)
├── generators/ → DELETE (Phase 2)
├── training/ → training/
├── visualizers/ → analysis/visualizers/
└── storage files
```

**Action:**
1. 🔄 Create proper homes for each concern:
   - `analysis/extractors/` - AI metadata + code pattern extraction
   - `analysis/training/` - Training data collection
   - `code_analysis/quality/` - Quality operations
   - `storage/code/` - Keep ONLY core storage (models, embeddings)
   - `analysis/visualizers/` - Code visualization

2. 🗑️ Delete analyzers (Phase 1) and generators (Phase 2)

3. ✏️ Update imports throughout codebase

**Result Structure:**
```
storage/code/
├── code_file.ex (schema)
├── code_chunk.ex (schema)
└── embeddings/ (storage only)

analysis/extractors/
├── ai_metadata_extractor.ex
├── code_pattern_extractor.ex
└── ...

code_analysis/quality/
├── refactoring_agent.ex
└── ...

training/
├── data_collection.ex
└── ...
```

**Files Affected:**
- Move: 20 files
- Delete: 8 files (duplicates)
- Update imports: ~30 files

---

### 🎯 PHASE 5: Consolidate Quality Operations (1-2 days, MEDIUM VALUE)

**Current State:**
```
quality.ex (root) ← MOVE
code_quality/
├── ast_quality_analyzer.ex ← DELETE (duplicate)
└── ast_security_analyzer.ex ← DELETE (duplicate)
code_analysis/scanners/quality_scanner.ex
architecture_engine/analyzers/quality_analyzer.ex
```

**Action:**
1. ✏️ Rename `code_analysis/quality.ex` → `code_analysis/quality_operations.ex`
2. ✏️ Consolidate quality logic from all sources
3. 🗑️ Delete `code_quality/` directory entirely
4. ✏️ Update QualityScanner to reference consolidated module
5. ✏️ Update QualityAnalyzer to reference consolidated module

**Expected Result:** Single quality subsystem in `code_analysis/`, no scattered quality operations

---

### 🔧 PHASE 6: Organize Engines (1-2 days, LOW VALUE)

**Current State:**
```
engines/ (9 engines)
├── architecture_engine.ex
├── generator_engine.ex ← DELETE (Phase 2)
├── parser_engine.ex
├── prompt_engine.ex
└── ... (6 more)

generator_engine/ (directory) ← DELETE (Phase 2)
architecture_engine/ (directory, well-organized!)
```

**Action:**
1. 🗑️ Delete `generator_engine/` directory (Phase 2)
2. 🗑️ Delete `engines/generator_engine.ex` (Phase 2)
3. ✏️ Clarify remaining engines
4. 📋 Document what each engine does
5. ✏️ Ensure consistent naming

**Expected Result:** Clear engine namespace with no duplicates

---

### 🎲 PHASE 7: Consolidate Execution Subsystem (1-2 days, LOW VALUE)

**Current State:**
```
execution/ (4 subdirectories, some organization exists)
├── autonomy/
├── planning/
├── sparc/
└── feedback/ ← Duplicate analysis code here
```

**Action:**
1. 🔄 Move feedback logic to architecture_engine (Phase 1)
2. ✏️ Consolidate planning modules
3. ✏️ Unify autonomy patterns
4. ✏️ Update SPARC integration

---

## Summary of Impact

### File Reduction
```
Before:  450 files | 86 directories | 24 root modules | 5,961 root LOC
After:   430 files | 65 directories | 6 root modules  | 500 root LOC

Change:  -20 files | -21 dirs | -75% root files | -92% root LOC
```

### Quality Improvements
- ✅ Single source of truth for analyzers, generators
- ✅ Clear ownership boundaries
- ✅ 92% reduction in root-level code
- ✅ Easier to navigate and understand
- ✅ Consistent patterns throughout

### Breaking Changes
- ⚠️ Import paths will change for:
  - All analyzer references
  - All generator references
  - All root-level module references
- ✅ Can be done with automated search/replace
- ✅ Add deprecation warnings during transition

---

## Implementation Strategy

### Phase Order
1. **URGENT (High Value):**
   - Phase 1: Analyzer dedup (2-3 days)
   - Phase 2: Generator dedup (2-3 days)
   - Phase 3: Root migration (1-2 days)
   - Phase 4: Kitchen sink decomposition (2-3 days)

2. **MEDIUM (Medium Value):**
   - Phase 5: Quality consolidation (1-2 days)

3. **NICE-TO-HAVE (Low Value):**
   - Phase 6: Engine organization (1-2 days)
   - Phase 7: Execution consolidation (1-2 days)

### Recommended Execution
- **Do Phases 1-4** (9-11 days) for maximum benefit
- **Skip Phases 6-7** unless reorganization is a stated goal
- **Phase 5** is optional but recommended

### Git Strategy
- Create feature branch: `refactor/code-organization`
- One commit per phase
- Each commit should compile + all tests pass
- Detailed commit messages explaining what moved and why

### Testing
- [ ] Each phase: `mix compile` passes
- [ ] No new compilation warnings
- [ ] No breaking changes to public APIs (only internal moves)
- [ ] Search for old import paths to catch missed refactors

---

## Quick Start Checklist

Ready to begin? Here's the order:

**Day 1-2: Phase 1 (Analyzer Dedup)**
- [ ] Identify all duplicate analyzers
- [ ] Create imports redirect in architecture_engine
- [ ] Delete duplicate files
- [ ] Run tests and compile check
- [ ] Commit

**Day 2-3: Phase 2 (Generator Dedup)**
- [ ] Identify all duplicate generators
- [ ] Consolidate into code_generation/
- [ ] Decide on embedding_engine.ex
- [ ] Delete duplicate files
- [ ] Run tests and compile check
- [ ] Commit

**Day 4-5: Phase 3 (Root Migration)**
- [ ] Move 24 root modules to proper locations
- [ ] Update all imports (can be automated)
- [ ] Verify only 6 root modules remain
- [ ] Run tests and compile check
- [ ] Commit

**Day 5-7: Phase 4 (Kitchen Sink Decomposition)**
- [ ] Create proper subdirectories
- [ ] Move files to new locations
- [ ] Update storage/code/ to contain only core storage
- [ ] Update all imports
- [ ] Run tests and compile check
- [ ] Commit

**Optional Day 7-8: Phase 5 (Quality Consolidation)**
- [ ] Consolidate quality operations
- [ ] Delete code_quality/ directory
- [ ] Update references
- [ ] Commit

---

## Rollback Strategy

If something goes wrong:
```bash
git reset --hard origin/main
# or
git revert <commit-hash>
```

Each phase is independent, so if Phase 1 goes wrong, you can:
1. Revert Phase 1 commit
2. Try again
3. Move to Phase 2

---

## Success Criteria

**Code organization is successful when:**

✅ All modules follow the golden pattern:
- Behavior contract → Orchestrator → Implementations

✅ No duplicate files exist:
- Single source of truth for each functionality
- No scattered implementations

✅ Clear ownership:
- Each subsystem has clear boundaries
- Related code lives together

✅ Root level is clean:
- Max 6-8 essential modules
- Everything else organized into subsystems

✅ Navigation is obvious:
- New developer can find any feature by subsystem name
- AI assistants can understand structure

---

**Ready to start? Begin with Phase 1: Analyzer Deduplication.**

The payoff is huge: 9-11 days of work → 450 → 430 files, 92% root-level reduction, crystal-clear organization.
