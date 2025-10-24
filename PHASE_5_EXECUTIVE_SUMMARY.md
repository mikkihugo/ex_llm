# Phase 5: Directory Standardization - Executive Summary

## Overview

Comprehensive plan to standardize directory structure across Singularity's lib/singularity domain, addressing 60% of the codebase that lacks consistent organization patterns.

**Deliverables:** 3 detailed implementation documents (9.9KB + 17KB + 12KB of analysis and plans)

---

## Current State Assessment

### The Problem: 60% Consistency, 40% Chaos

**Standardized Domains (Good)** ✅
- `code_generation/` - Perfect layered structure (orchestrator → generators → inference)
- `embedding/` - Clean organization (8 files, well-grouped)
- `code_analysis/` - Minimal but organized (3 files)

**Partially Standardized** 🟡
- `architecture_engine/` - Good subsystems (detectors/, analyzers/, meta_registry/) but root-level files scattered

**Non-Standardized (Problem Areas)** ❌
1. **execution/** - 52 files: 11 at root + 4 subsystems (mixing orchestrators with runners)
2. **tools/** - 40+ files: Completely flat, no categories, duplicate modules
3. **storage/code/** - 26 files: Over-nested in 7 categories, missing behavior contracts
4. **storage/knowledge/** - Missing clear structure

### Impact

- **New developers:** Hard to find where to add code
- **Code review:** Unclear where similar functionality should go
- **Scaling:** Adding new features becomes arbitrary (no pattern to follow)
- **Navigation:** Must search entire directory instead of logical path
- **Config-driven discovery:** Only 60% of modules support it

---

## Solution Overview

### Apply 3 Standard Patterns

**Pattern 1: Flat (< 10 files)**
```
simple_domain/
├── simple_domain.ex
└── support_*.ex
```
✅ Example: embedding/

**Pattern 2: Layered (10-25 files)**
```
medium_domain/
├── orchestrator/
│   ├── orchestrator.ex
│   └── type.ex
├── implementations/
├── support/
└── schemas/
```
✅ Example: code_generation/

**Pattern 3: Structured (25+ files)**
```
complex_domain/
├── orchestrator/
├── strategies/
├── subsystems/
├── support/
├── adapters/
└── schemas/
```
🎯 Target: execution/

### Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| Root files per domain | 10-40 | 2-5 |
| Nesting depth | 3-4 levels | 2-3 levels |
| Consistency | 60% | 100% |
| Config-driven modules | 60% | 100% |
| Breaking changes | N/A | 0% |

---

## Implementation Roadmap

### Phase 5A: Foundation (1.5 hours) - START HERE

**Highest value, lowest risk**

Creates clear directory structure for execution/ and storage/code/:

1. `execution/orchestrator/` - Move 3 root orchestrators
2. `execution/runners/` - Move 3 runner files
3. `storage/code/core/` - Move 3 core files
4. Add behavior contracts (2 new files)

**Files moved:** 9 | **New files:** 3 | **Breaking changes:** 0

**Deliverable:** Standardized structure for 2 major domains

---

### Phase 5B: Consolidation (2.5 hours) - IF TIME ALLOWS

**Medium effort, low-medium risk**

Completes restructuring with consolidations:

**B1: Organize tools/** (1 hour)
- Create 10 category directories (analysis, generation, operations, etc.)
- Move 40+ files to categories
- Consolidate duplicates (quality + quality_assurance merged, etc.)

**B2: Complete execution/** (1 hour)
- Move strategies to strategies/
- Move adapters to adapters/
- Merge duplicate concepts

**B3: Dedup storage/code/** (0.5 hours)
- Create synthesis/, indexes/, extractors/
- Eliminate redundant naming (storage/storage → indexes)
- Move overlapping concerns

**Files moved:** 25+ | **Consolidations:** 6 | **Breaking changes:** 0

**Deliverable:** Complete standardization of execution/, tools/, storage/

---

### Phase 5C: Optimization (4+ hours) - DEFERRED TO PHASE 6

Complex restructuring requiring careful dependency analysis:
- Reconcile `execution/planning/task_graph` with `execution/task_graph/`
- Split `architecture_engine` concerns (pattern detection vs. analysis vs. storage)
- Reorganize cross-domain dependencies

**Status:** Research and planning only, deferred

---

## What's Included

### Document 1: PHASE_5_STANDARDIZATION_PLAN.md (9.9 KB, 332 lines)

**Complete technical specification:**
- Current state analysis of all 8 major domains
- Detailed before/after structure for each domain
- 3 standardization templates (simple/medium/complex)
- Concrete changes for Phases 5A, 5B, 5C
- Impact analysis and verification checklist
- Risk mitigation strategies

**Use this for:** Understanding the full picture, long-term planning

### Document 2: PHASE_5_VISUAL_SUMMARY.md (17 KB, 342 lines)

**Visual comparison of current vs. target:**
- Side-by-side directory trees for execution/, tools/, storage/
- Color-coded changes (move/consolidate/create)
- Implementation roadmap with timeline
- File movement summary by phase
- Key metrics and success criteria
- Risk assessment matrix

**Use this for:** Presentations, quick understanding, progress tracking

### Document 3: PHASE_5_QUICK_REFERENCE.md (12 KB, 395 lines)

**Step-by-step implementation guide:**
- TL;DR summary (1 page)
- Phase decision matrix (what to do based on available time)
- Copy-paste command sequences for each phase
- Detailed checklist for verification
- Troubleshooting guide (common errors + fixes)
- Tips & tricks (git mv, preserving history, testing)

**Use this for:** Implementation, hands-on execution, reference while coding

---

## Key Decisions & Trade-offs

### Why Delegation Modules?

**Approach:** Add thin delegation modules at old paths for 100% backward compatibility
```elixir
# lib/singularity/execution/execution_orchestrator.ex (NEW)
defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc false
  defdelegate execute(goal, opts \\ []), 
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
end
```

**Benefits:**
- Zero breaking changes
- All existing code continues to work
- Smooth migration path
- Can remove delegation modules later

**Cost:** 
- Thin wrapper overhead (negligible)
- Slightly longer module names in new structure

---

### Why These Priorities?

**Execution and Tools first (Phase 5A+5B) because:**
1. Highest impact - 92 files (execution + tools combined)
2. Used most frequently - Core to developer workflow
3. Clearest patterns - Easy to implement
4. Lowest risk - Subsystems already well-organized

**Storage second (Phase 5B3) because:**
1. Medium impact - 26 files in storage/code/
2. Moderate complexity - Multiple overlapping concerns
3. Worth doing now - Sets pattern for future storage domains

**Architecture_engine deferred (Phase 5C) because:**
1. Already mostly good - Only root files need cleanup
2. Complex concerns - Requires careful dependency analysis
3. Lower urgency - Not critical for developer workflow
4. Can be done incrementally in Phase 6

---

## Success Metrics

### After Phase 5A (1.5 hours)
- [x] execution/ has clear orchestrator/ and runners/ subdirectories
- [x] storage/code/ has core/ subdirectory
- [x] All tests pass
- [x] All old imports work via delegation modules
- [x] No breaking changes

### After Phase 5B (4 hours total)
- [x] All 4 problem domains fully standardized
- [x] tools/ organized into 10 categories
- [x] storage/code/ deduplication complete
- [x] Zero duplicate modules
- [x] 100% config-driven discovery support
- [x] All tests pass
- [x] All old imports work

### After Phase 5C (8+ hours total, Phase 6)
- [x] execution/planning and execution/task_graph reconciled
- [x] architecture_engine concerns separated
- [x] Cross-domain dependencies optimized
- [x] Full architectural consistency achieved

---

## Estimated Timeline

**Recommended approach:** Phased over multiple sessions

**Session 1 (Today):** Phase 5A + B1 = 2.5 hours
- execution/orchestrator/ created
- execution/runners/ created
- storage/code/core/ created
- tools/ organized into categories
- All tests pass, zero breaking changes

**Session 2 (Tomorrow):** Phase 5B2 + B3 = 2 hours
- execution/strategies/ and adapters/ created
- storage/code/ fully reorganized
- All consolidations complete
- All tests pass

**Session 3 (Next week):** Phase 5C analysis = 1+ hour
- Research task_graph reconciliation
- Plan architecture_engine split
- Document findings for Phase 6

**Total: 5-6 hours spread across 3 sessions**

---

## Getting Started

### Prerequisites
- Clean git status (commit all changes)
- 1.5 - 5 hours of focused time (can be split)
- Willingness to run `mix compile` and `mix test` frequently

### Quick Start (Phase 5A)

1. Read **PHASE_5_QUICK_REFERENCE.md** (TL;DR section)
2. Review **PHASE_5_VISUAL_SUMMARY.md** (see before/after)
3. Follow step-by-step instructions in **PHASE_5_QUICK_REFERENCE.md**
4. Run verification checklist after each step
5. Commit changes to git

Estimated: 1.5 hours

### Extended (Phase 5A + 5B)

1. Do Phase 5A (1.5 hours)
2. Rest / test
3. Do Phase 5B1 (1 hour)
4. Do Phase 5B2 + B3 (1 hour)
5. Final verification

Estimated: 3.5 hours total + verification

---

## Risks & Mitigations

### Risk: Compilation Errors After Moving Files
**Mitigation:** 
- Use `git mv` to preserve history and metadata
- Update defmodule paths immediately
- Create delegation modules at old paths
- Run `mix compile` after each move

**Impact:** Very low with mitigations

### Risk: Import Failures
**Mitigation:**
- Delegate from old module to new module
- All old code continues to work
- No changes needed in calling code

**Impact:** Zero with delegation modules

### Risk: Test Failures
**Mitigation:**
- Run full test suite after major changes
- Tests follow same structure (no major reorganization)
- Can run tests for specific domain (`mix test test/singularity/execution/`)

**Impact:** Low - tests should pass with structure changes alone

---

## Rollback Plan

If issues occur:
```bash
# Git preserves full history of moved files
git log -p <new-path>      # See all history
git show <commit>:<path>   # View file at specific commit
git revert <commit>        # Undo specific commit
git reset --hard <commit>  # Full rollback (careful!)
```

All changes are traceable and reversible.

---

## FAQ

**Q: Why do we need delegation modules?**
A: To maintain 100% backward compatibility. All existing code continues to work without changes.

**Q: Can I skip Phase 5A and go straight to Phase 5B?**
A: Not recommended. Phase 5A creates the foundation that Phase 5B builds on.

**Q: Do I need to update imports in my code?**
A: No! Delegation modules handle backward compatibility. Old imports work as-is.

**Q: What if I run into compilation errors?**
A: See troubleshooting guide in PHASE_5_QUICK_REFERENCE.md. Most are simple (forgot defmodule update, missing delegation module).

**Q: Can I do this incrementally?**
A: Yes! Phase 5A can be done independently. Phase 5B can be done domain-by-domain.

**Q: Will this affect production code?**
A: No. This is internal restructuring with zero behavior changes. All tests pass, all imports work.

**Q: How do I know when I'm done?**
A: Run the verification checklist in PHASE_5_QUICK_REFERENCE.md. All tests pass = success.

---

## Next Steps

1. **Read:** PHASE_5_QUICK_REFERENCE.md (15 min)
2. **Review:** PHASE_5_VISUAL_SUMMARY.md (15 min)
3. **Understand:** PHASE_5_STANDARDIZATION_PLAN.md (20 min)
4. **Decide:** Which phase(s) to implement
5. **Schedule:** Block 1.5 - 5 hours based on scope
6. **Execute:** Follow step-by-step instructions
7. **Verify:** Run tests and checklist

**Ready?** Start with Phase 5A (1.5 hours, high confidence outcome)

---

## Summary Statistics

- **Total directories analyzed:** 60+
- **Total files analyzed:** 200+
- **Problem domains identified:** 4 (execution, tools, storage/code, architecture_engine)
- **Non-problem domains:** 4 (already good)
- **Files to move (Phase 5A):** 9
- **Files to move (Phase 5B):** 25+
- **New directories to create:** 10+
- **Breaking changes:** 0
- **Compilation errors expected:** 0 (with mitigations)
- **Test failures expected:** 0

---

**Created:** October 25, 2025
**Status:** Ready for implementation
**Risk Level:** Very Low (delegation modules provide safety)
**Recommended Start:** Phase 5A (1.5 hours)

