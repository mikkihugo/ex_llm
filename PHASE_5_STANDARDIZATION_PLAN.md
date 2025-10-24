# Phase 5: Directory Standardization Plan

**Scope:** Standardize directory organization across 40+ modules and 8 major domains
**Duration:** 2-4 hours  
**Risk Level:** Low (clear patterns exist, minimal import changes needed)
**Status:** Analysis phase

---

## Executive Summary

Singularity's directory structure is 60% standardized but has inconsistencies that make navigation and scaling difficult:

- **Pattern 1 (Correct):** `code_generation/orchestrator/generation_orchestrator.ex` + `code_generation/generators/` ✅
- **Pattern 2 (Inconsistent):** `execution/` has flat structure mixing orchestrators, strategies, and subsystems ❌
- **Pattern 3 (Good):** `architecture_engine/` has clear layering (detectors/, analyzers/, meta_registry/) ✅
- **Pattern 4 (Messy):** `storage/code/` has too many sub-layers ❌
- **Pattern 5 (Unclear):** `tools/` is flat with 40+ files, mixing categories without structure ❌

**Goal:** Apply standardized patterns to all domains while maintaining backward compatibility.

---

## Current State Analysis

### Domain Structure Audit Summary

#### Excellent Pattern (Already Correct)

**`code_generation/` - Model to follow:**
- Clear separation: **orchestrator** → **generators** → **inference** 
- Implementations nested under `implementations/` keep root clean
- Sub-engines (generator_engine/) isolated in their own scope
- 18 files organized into 4-5 logical layers
- **Status:** Production-ready ✅

#### Good Pattern (Mostly Correct)

**`architecture_engine/` - Good structure, needs minor cleanup:**
- Well-organized `detectors/`, `analyzers/`, `meta_registry/`
- Issues: Root-level orchestrators, duplicate naming, storage concerns mixed in
- **Status:** Good, needs minor cleanup 🟡

#### Problematic Pattern (Needs Restructuring)

**`execution/` - Currently flat with 52 files:**
- 11 root-level files mixed with 4 subsystems
- Duplicate task_graph concept between planning/task_graph and execution/task_graph/
- Root orchestrators should be consolidated
- Runner files scattered
- Task adapters need organization
- **Status:** Needs restructuring 🔴

#### Massive Pattern (Over-Nested)

**`storage/code/` - Too many nesting levels (26 files across 7 categories):**
- 7 sub-categories for 26 files is excessive
- Generator category overlaps with `code_generation/` domain
- storage/storage/ is redundant naming
- Root-level files need categorization
- No behavior contracts for config-driven discovery
- **Status:** Needs significant restructuring 🔴

#### Flat Domain (Needs Categorization)

**`tools/` - 40+ files, no structure:**
- No categorization - Hard to find related tools
- Mix of concerns - UX, operations, analysis all mixed
- No grouping pattern - Unlike code_generation which has clear structure
- Duplicate concepts - Both quality.ex and quality_assurance.ex
- **Status:** Needs restructuring with consolidation 🔴

#### Simple Domains (Good Pattern)

**`embedding/` - Correct structure (8 files):**
- Well-organized with clear orchestrator and support layers
- **Status:** Good, no changes needed ✅

---

## Standardization Templates

### Template 1: Simple Domain (Flat OK)
For domains with <10 files - Keep flat at root level
**Examples:** embedding/, quality/, code_analysis/

### Template 2: Medium Domain (Layered)
For domains with 10-25 files
```
medium_domain/
├── orchestrator/
│   ├── medium_domain_orchestrator.ex
│   └── orchestrator_type.ex
├── implementations/
├── support/
└── schemas/
```

### Template 3: Complex Domain (Highly Structured)
For domains with 25+ files
```
complex_domain/
├── orchestrator/
├── strategies/
├── subsystems/
├── support/
├── adapters/
└── schemas/
```

---

## Concrete Standardization Changes

### Phase 5A: High-Value, Low-Risk (1.5 hours)

Quick wins with minimal refactoring.

#### A1: Create `execution/orchestrator/` Directory
**Files to move:**
- `execution/execution_orchestrator.ex` → `execution/orchestrator/execution_orchestrator.ex`
- `execution/execution_strategy_orchestrator.ex` → `execution/orchestrator/execution_strategy_orchestrator.ex`
- `execution/execution_strategy.ex` → `execution/orchestrator/execution_strategy.ex`

**Impact:** Low - Update 5-10 imports (search `Execution.ExecutionOrchestrator`)
**Backward compatibility:** Add delegation module at old path
**Time:** 15 min

#### A2: Create `execution/runners/` Directory
**Files to move:**
- `execution/runner.ex` → `execution/runners/runner.ex`
- `execution/lua_runner.ex` → `execution/runners/lua_runner.ex`
- `execution/control.ex` → `execution/runners/control.ex`

**Impact:** Very Low - Update 2-3 imports
**Backward compatibility:** Add delegation modules for each
**Time:** 10 min

#### A3: Organize `tools/` with Category Guidance
**Create structure without moving files yet:**
```
tools/
├── CATEGORIES.md (NEW - documents: analysis, generation, operations, integration, testing)
├── [existing 40 files remain at root]
└── tools.ex
```
**Impact:** Zero - Just adding documentation
**Backward compatibility:** 100%
**Time:** 20 min

#### A4: Add Behavior Contracts to `storage/code/`
**Create new files:**
```
storage/code/
├── analyzer_type.ex (NEW - Behavior for config-driven discovery)
├── extractor_type.ex (NEW - Behavior for config-driven discovery)
```
**Impact:** Zero - Just adding new files
**Time:** 15 min

#### A5: Move Root-Level Storage Files to `storage/code/core/`
**Create:**
```
storage/code/core/
├── code_location_index.ex
├── code_location_index_service.ex
└── code_session.ex
```
**Backward compatibility:** Add delegation modules
**Time:** 15 min

**Phase 5A Total:** ~1.5 hours, 0% compilation risk

---

### Phase 5B: Medium-Effort Standardizations (1-2 hours)

Major structural improvements with careful refactoring.

#### B1: Consolidate `tools/` Categories
**Step 1: Merge duplicate modules**
- `tools/quality.ex` + `tools/quality_assurance.ex` → unified
- `tools/development.ex` + `tools/planning.ex` → unified
- `tools/security.ex` + `tools/security_policy.ex` → unified

**Step 2: Create subdirectories with delegation**
```
tools/
├── analysis/
│   ├── analysis.ex (NEW)
│   ├── code_analysis.ex
│   ├── quality.ex (MOVE)
│   └── codebase_understanding.ex
├── generation/
│   ├── generation.ex (NEW)
│   ├── code_generation.ex
│   ├── code_naming.ex
│   └── validated_code_generation.ex
├── [other categories]
└── [root delegation modules]
```
**Impact:** Medium - Update 20-30 imports (can use delegation modules)
**Time:** 1 hour

#### B2: Consolidate `execution/` Root Files
**Create `execution/orchestrator/` with all root orchestrators:**
```
execution/orchestrator/
├── execution_orchestrator.ex
├── execution_strategy_orchestrator.ex
├── execution_strategy.ex
└── execution_type.ex (NEW)
```

**Create `execution/strategies/` for strategy implementations:**
```
execution/strategies/
├── task_dag_strategy.ex
├── sparc_strategy.ex
├── methodology_strategy.ex
└── evolution.ex (MOVE)
```
**Impact:** Medium - Update 15-20 imports (plus delegation modules)
**Time:** 1 hour

#### B3: Deduplication in `storage/code/`
**New structure:**
```
storage/code/
├── core/ (Core location/session tracking)
├── analyzers/ (Analysis tools - KEEP)
├── extractors/ (Pattern extraction - CONSOLIDATE)
├── indexes/ (Storage/indexing - FROM storage/storage/)
├── synthesis/ (Code generation for storage)
├── quality/ (Quality operations)
├── training/ (ML models)
└── visualizers/ (Visualization)
```
**Impact:** Medium-High - Update 15-25 imports
**Time:** 1.5 hours

**Phase 5B Total:** ~3.5 hours, low compilation risk

---

### Phase 5C: Complex Restructuring (Deferred)

Long-term improvements requiring more careful planning.

#### C1: Reconcile `execution/planning/task_graph` with `execution/task_graph`
**Issue:** Two competing task graph implementations
**Resolution:** Merge compatible pieces, eliminate duplicates
**Time:** 2+ hours (requires careful analysis)
**Status:** DEFERRED to Phase 6

#### C2: Split `architecture_engine` Concerns
**Issue:** Mixes pattern detection, analysis, knowledge storage, meta-registry
**Resolution:** Separate into distinct domains
**Time:** 2-3 hours
**Status:** DEFERRED to Phase 6

**Phase 5C Total:** 4+ hours (DEFERRED)

---

## Implementation Strategy

### Recommended: Phased Approach

**Session 1 (Today):** Phase 5A + B1 (2.5 hours)
- execution/ and tools/ fully standardized
- Low risk, clear patterns

**Session 2 (Tomorrow):** B2 + B3 (2 hours)
- storage/code/ restructured
- Low-medium risk

**Session 3 (Next week):** C1 + C2 research (1+ hour)
- Plan for Phase 6

---

## Import Impact Analysis

### Modules That Need Update

**High impact (10+ imports):**
- `Singularity.Execution.ExecutionOrchestrator`

**Medium impact (3-10 imports):**
- `Singularity.Execution.Runner`
- `Singularity.Storage.Code.*` modules

**Mitigation:** Use delegation modules for 100% backward compatibility

---

## Verification Checklist

After each phase:
```bash
cd singularity
mix compile     # Check compilation
mix test        # Run tests
mix dialyzer    # Check types
```

---

## Summary of Benefits

After Phase 5A + 5B:

| Aspect | Before | After |
|--------|--------|-------|
| Max nesting depth | 3-4 levels | 2-3 levels |
| Root files per domain | 10-40 | 2-5 |
| Subdirectory organization | Inconsistent | Standardized |
| Config-driven discovery | Partial | Complete |
| Backward compatibility | N/A | 100% |
| New developer onboarding | Confusing | Clear patterns |

---

## Next Steps

1. Review this plan
2. Choose implementation option (Today for 5A+B1, or spread over 3 sessions)
3. Start with Phase 5A (execution/orchestrator/ directory)
4. Verify compilation and tests after each move
5. Document patterns for future domains

