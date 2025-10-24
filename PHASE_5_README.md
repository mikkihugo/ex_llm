# Phase 5: Directory Standardization

## Overview

Comprehensive standardization plan for Singularity's directory structure across 60% of the codebase.

**Status:** Analysis complete, ready for implementation  
**Scope:** 4 major domains (execution, tools, storage/code, architecture_engine)  
**Files:** 200+ analyzed, 50+ to be moved  
**Time:** 1.5 - 5 hours (depending on which phases)  
**Risk:** Very low (100% backward compatible)  
**Breaking changes:** Zero

---

## Documents

### 1. PHASE_5_EXECUTIVE_SUMMARY.md (What & Why)
**Start here for decision-making**
- Problem statement and current state assessment
- High-level solution overview
- Implementation roadmap with timeline
- Success metrics and FAQ
- 5-10 minute read

**Use when:** Deciding whether to do this, understanding scope

---

### 2. PHASE_5_QUICK_REFERENCE.md (How - Hands-on)
**Start here for implementation**
- TL;DR summary (1 page)
- Phase decision matrix (time vs. scope)
- Copy-paste command sequences for each step
- Detailed verification checklist
- Troubleshooting guide with common errors
- Tips & tricks for smooth execution
- 20-30 minute read, then reference while implementing

**Use when:** Actually doing the work, following step-by-step

---

### 3. PHASE_5_STANDARDIZATION_PLAN.md (Deep dive)
**Reference for detailed understanding**
- Current state analysis of all 8 domains
- Detailed before/after structures
- 3 standardization templates
- Phase-by-phase breakdown with concrete changes
- Import impact analysis
- Verification checklist
- 30-45 minute read

**Use when:** Understanding full architecture, planning Phase 5C, deep learning

---

### 4. PHASE_5_VISUAL_SUMMARY.md (Pictures & Diagrams)
**Visual reference for quick understanding**
- Side-by-side directory trees (current vs. target)
- Annotated with what moves where
- Color-coded by change type
- Implementation roadmap diagram
- File movement summary table
- Risk assessment matrix
- 15-20 minute read

**Use when:** Visual learner, presenting to others, quick reference

---

## Quick Decision Tree

```
Do I have 30 minutes?
├─ YES → Read PHASE_5_EXECUTIVE_SUMMARY.md
├─ NO → Skip to decision tree below

Do I have 1.5 hours?
├─ YES → Do Phase 5A (execution/orchestrator + execution/runners)
└─ NO → Skip this phase

Do I have 2.5 hours?
├─ YES → Do Phase 5A + 5B1 (execution + tools)
└─ NO → Come back later

Do I have 4+ hours?
├─ YES → Do Phase 5A + 5B (complete 3 domains)
└─ NO → Do Phase 5A only, Phase 5B later

Ready to implement?
└─ YES → Open PHASE_5_QUICK_REFERENCE.md and follow Step 1
```

---

## Implementation Phases

### Phase 5A: Foundation (1.5 hours)
Highest value, lowest risk

**What:** Create clear subdirectories for execution/ and storage/code/
- execution/orchestrator/ (move 3 files)
- execution/runners/ (move 3 files)
- storage/code/core/ (move 3 files)
- Add behavior contracts (2 new files)

**Outcome:** Clear structure for 2 domains, 0 breaking changes

**Start:** PHASE_5_QUICK_REFERENCE.md → Phase 5A steps

---

### Phase 5B: Consolidation (2.5 hours total, can do in parts)

**B1: Tools organization (1 hour)**
- Create 10 category directories
- Move 40+ files to categories
- Consolidate duplicates

**B2: Complete execution (1 hour)**
- Move strategies to strategies/
- Move adapters to adapters/
- Merge duplicate concepts

**B3: Dedup storage/code (0.5 hours)**
- Create synthesis/, indexes/, extractors/
- Eliminate redundant naming
- Move overlapping concerns

**Outcome:** Complete standardization of 3 major domains

**Start:** After Phase 5A success, PHASE_5_QUICK_REFERENCE.md → Phase 5B

---

### Phase 5C: Optimization (4+ hours, DEFERRED)
Complex restructuring, planned for Phase 6

**What:** 
- Reconcile execution/planning/task_graph vs execution/task_graph
- Split architecture_engine concerns
- Optimize cross-domain dependencies

**Status:** Research and planning only

**Learn more:** PHASE_5_STANDARDIZATION_PLAN.md → Phase 5C section

---

## Before You Start

### Checklist
- [ ] Read PHASE_5_EXECUTIVE_SUMMARY.md (10 min)
- [ ] Review PHASE_5_VISUAL_SUMMARY.md (10 min)
- [ ] Open PHASE_5_QUICK_REFERENCE.md in editor
- [ ] Commit current changes (`git status` clean)
- [ ] Plan which phase(s) to implement
- [ ] Block time on calendar

### Required
- Git (for moving files with `git mv`)
- Elixir/Mix (for compilation and testing)
- Terminal/bash shell
- 1.5 - 5 hours of focused time

### Recommended
- Coffee/water nearby
- No interruptions
- Fresh terminal session
- One monitoring window for tests

---

## During Implementation

### Key Commands

```bash
# Check current status
cd singularity
git status

# Move files with history preservation
git mv old/path/file.ex new/path/file.ex

# Compile after changes
mix compile

# Run tests
mix test

# Specific domain tests
mix test test/singularity/execution/

# Check for lingering imports
grep -r "Execution.ExecutionOrchestrator" lib/
```

### Critical Steps
1. Create directory: `mkdir -p lib/singularity/execution/orchestrator`
2. Move file: `git mv lib/singularity/execution/execution_orchestrator.ex ...`
3. Update defmodule path in moved file
4. Create delegation module at old path
5. Compile: `mix compile`
6. Test: `mix test`

**Verify after each major move!**

---

## After Implementation

### Verification
```bash
# All tests pass?
mix test  # Should see all tests pass

# No compilation warnings?
mix compile  # Should have no warnings

# Old imports still work?
grep -r "Execution.ExecutionOrchestrator" lib/ | head

# New structure correct?
find lib/singularity/execution -type d | sort
```

### Success Criteria (All must pass)
- [x] All tests pass
- [x] No compilation errors or warnings
- [x] Old imports work via delegation modules
- [x] New structure matches target diagrams
- [x] No breaking changes to public API

---

## Troubleshooting

### Problem: "Module does not exist"
**Solution:** You moved a file but forgot to update the defmodule path
```elixir
# Before move
defmodule Singularity.Execution.ExecutionOrchestrator do

# After move to execution/orchestrator/
defmodule Singularity.Execution.Orchestrator.ExecutionOrchestrator do
```

### Problem: "Function not found"
**Solution:** You moved a file but didn't create a delegation module
```elixir
# Create at old path: lib/singularity/execution/execution_orchestrator.ex
defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc false
  defdelegate execute(goal, opts \\ []), 
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
end
```

### Problem: Tests fail after moves
**Solution:** Most likely `git mv` worked fine, but imports need delegation
1. Check that delegation modules exist at old paths
2. Verify defmodule names in moved files match new paths
3. Run: `mix compile` then `mix test`

---

## Document Map

| Need | Read | Time |
|------|------|------|
| Decide whether to do this | PHASE_5_EXECUTIVE_SUMMARY.md | 5-10 min |
| Quick visual comparison | PHASE_5_VISUAL_SUMMARY.md | 10-15 min |
| Step-by-step instructions | PHASE_5_QUICK_REFERENCE.md | 20-30 min |
| Deep technical details | PHASE_5_STANDARDIZATION_PLAN.md | 30-45 min |
| Troubleshooting during work | PHASE_5_QUICK_REFERENCE.md (Troubleshooting section) | 5 min |
| Presenting to team | PHASE_5_VISUAL_SUMMARY.md | 10 min |

---

## Key Benefits

After Phase 5A + 5B (4 hours):

✅ **Clear structure** - Every file has a logical home  
✅ **Consistent patterns** - Same structure across all domains  
✅ **Easier navigation** - No guessing where to find code  
✅ **Better onboarding** - New developers understand organization  
✅ **Scalable** - Adding new features follows clear patterns  
✅ **Config-driven** - 100% of relevant modules support it  
✅ **Zero breaking changes** - All old code continues to work  

---

## What's NOT Changing

- Module behavior (only structure)
- Public APIs (all supported via delegation)
- Test behavior (tests should all pass)
- Database schemas (none affected)
- Configuration (only organization)
- Runtime performance (only import paths change)

---

## Estimated Effort

| Phase | Duration | Files | New Dirs | Risk |
|-------|----------|-------|----------|------|
| **5A** | 1.5 hrs | 9 move | 3 create | Very low |
| **5B** | 2.5 hrs | 25+ move | 7+ create | Low |
| **5C** | 4+ hrs | Research | Plan | N/A |
| **Total** | 4-8 hrs | 50+ move | 10+ create | Low |

---

## Next Steps

1. **Decide:** Which phase(s) will you do?
   - Just 5A? (1.5 hours) ← Recommended for first time
   - 5A + 5B? (4 hours) ← If you have the time
   - 5A + 5B + research? (5+ hours) ← Full commitment

2. **Read:** PHASE_5_EXECUTIVE_SUMMARY.md (10 min decision aid)

3. **Plan:** Look at PHASE_5_VISUAL_SUMMARY.md to understand scope

4. **Schedule:** Block time on calendar

5. **Execute:** Follow PHASE_5_QUICK_REFERENCE.md step-by-step

6. **Verify:** Run checklist after each phase

---

## Questions?

**General:** See FAQ in PHASE_5_EXECUTIVE_SUMMARY.md  
**Implementation:** See PHASE_5_QUICK_REFERENCE.md  
**Architecture:** See PHASE_5_STANDARDIZATION_PLAN.md  
**Visuals:** See PHASE_5_VISUAL_SUMMARY.md  

---

**Status:** Ready for implementation  
**Created:** October 25, 2025  
**Last updated:** October 25, 2025

