# Phase 5: Quick Reference Guide

## TL;DR

**Goal:** Standardize directory structure across execution/, tools/, and storage/ domains

**Time:** 2.5 - 5 hours total (can be split into sessions)

**Risk:** Very Low (delegation modules provide 100% backward compatibility)

**Start with Phase 5A:** 1.5 hours, clear winner

---

## One-Page Summary

### Current Problems

1. **execution/** - 11 root files scattered + 4 subsystems
2. **tools/** - 40+ files unorganized, no categories
3. **storage/code/** - 26 files over-nested in 7 categories
4. **architecture_engine/** - Good but needs minor cleanup

### Solution

Apply **3 standard patterns:**

| Domain Size | Pattern | Example |
|-------------|---------|---------|
| < 10 files | **Flat** | embedding/ ✅ |
| 10-25 files | **Layered** (orchestrator/ + implementations/ + support/) | code_generation/ ✅ |
| 25+ files | **Structured** (orchestrator/ + strategies/ + subsystems/ + support/) | execution/ (target) |

### Outcome

- Clear 2-3 level directory hierarchy
- Consistent patterns across all domains
- 100% backward compatible (delegation modules)
- Zero breaking changes to user code

---

## Phase Decision Matrix

```
DO YOU HAVE 1.5 HOURS?
  ├─ YES → Do Phase 5A (quick wins)
  └─ NO → Skip for now, revisit later

DO YOU HAVE 2.5 HOURS?
  ├─ YES → Do Phase 5A + 5B1 (execution + tools)
  └─ NO → Do Phase 5A only

DO YOU HAVE 4-5 HOURS?
  ├─ YES → Do Phase 5A + 5B (complete restructuring)
  └─ NO → Do Phase 5A + 5B1 and save B2/B3 for next session
```

---

## Phase 5A: What to Do (1.5 hours)

### Step 1: Create execution/orchestrator/
```bash
mkdir -p lib/singularity/execution/orchestrator
git mv lib/singularity/execution/execution_orchestrator.ex \
       lib/singularity/execution/orchestrator/execution_orchestrator.ex
git mv lib/singularity/execution/execution_strategy_orchestrator.ex \
       lib/singularity/execution/orchestrator/execution_strategy_orchestrator.ex
git mv lib/singularity/execution/execution_strategy.ex \
       lib/singularity/execution/orchestrator/execution_strategy.ex
```

### Step 2: Update defmodule paths
In `execution/orchestrator/execution_orchestrator.ex`, change:
```elixir
# FROM
defmodule Singularity.Execution.ExecutionOrchestrator do

# TO
defmodule Singularity.Execution.Orchestrator.ExecutionOrchestrator do
```

Same for other files moved to orchestrator/

### Step 3: Create delegation modules
Create new file at old path:
```elixir
# lib/singularity/execution/execution_orchestrator.ex
defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc false
  
  defdelegate execute(goal, opts \\ []), 
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
  
  defdelegate execute_with_strategy(goal, strategy, opts \\ []),
    to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
end
```

### Step 4: Create execution/runners/
```bash
mkdir -p lib/singularity/execution/runners
git mv lib/singularity/execution/runner.ex \
       lib/singularity/execution/runners/runner.ex
git mv lib/singularity/execution/lua_runner.ex \
       lib/singularity/execution/runners/lua_runner.ex
git mv lib/singularity/execution/control.ex \
       lib/singularity/execution/runners/control.ex
```

Update defmodule paths and create delegation modules (same as Step 3)

### Step 5: Verify
```bash
cd singularity
mix compile
mix test
```

---

## Phase 5B1: Tools Organization (1 hour)

### Step 1: Create category subdirectories
```bash
mkdir -p lib/singularity/tools/{analysis,generation,operations,integration,knowledge,planning,security,testing,web,validation}
```

### Step 2: Move files by category
```bash
# Analysis
git mv lib/singularity/tools/code_analysis.ex \
       lib/singularity/tools/analysis/code_analysis.ex
git mv lib/singularity/tools/quality.ex \
       lib/singularity/tools/analysis/quality.ex
git mv lib/singularity/tools/quality_assurance.ex \
       lib/singularity/tools/analysis/quality_assurance.ex
# ... repeat for other categories
```

### Step 3: Consolidate duplicates (optional)
Merge quality_assurance.ex into quality.ex:
- Copy functions from quality_assurance.ex into quality.ex
- Delete quality_assurance.ex
- Create delegation module at old path (optional)

### Step 4: Create category modules (optional)
Create new `tools/analysis/analysis.ex`:
```elixir
defmodule Singularity.Tools.Analysis do
  @moduledoc """
  Analysis Tools - Unified analysis interface.
  
  Includes: Code analysis, quality checks, codebase understanding.
  """
  
  defdelegate analyze(code), to: Singularity.Tools.Analysis.CodeAnalysis
end
```

### Step 5: Verify
```bash
mix compile
mix test
```

---

## Phase 5B2: Execution Consolidation (1 hour)

### Step 1: Create execution/strategies/
```bash
mkdir -p lib/singularity/execution/strategies
git mv lib/singularity/execution/evolution.ex \
       lib/singularity/execution/strategies/evolution.ex
```

Update defmodule and create delegation module

### Step 2: Create execution/adapters/
```bash
mkdir -p lib/singularity/execution/adapters
git mv lib/singularity/execution/task_adapter.ex \
       lib/singularity/execution/adapters/task_adapter.ex
git mv lib/singularity/execution/task_adapter_orchestrator.ex \
       lib/singularity/execution/adapters/task_adapter_orchestrator.ex
```

Update defmodule and create delegation modules

### Step 3: Verify
```bash
mix compile
mix test
```

---

## Phase 5B3: Storage Consolidation (1.5 hours)

### Step 1: Create storage/code/core/
```bash
mkdir -p lib/singularity/storage/code/core
git mv lib/singularity/storage/code/code_location_index.ex \
       lib/singularity/storage/code/core/code_location_index.ex
git mv lib/singularity/storage/code/code_location_index_service.ex \
       lib/singularity/storage/code/core/code_location_index_service.ex
git mv lib/singularity/storage/code/session/code_session.ex \
       lib/singularity/storage/code/core/code_session.ex
```

### Step 2: Create storage/code/synthesis/
```bash
mkdir -p lib/singularity/storage/code/synthesis
git mv lib/singularity/storage/code/generators/pseudocode_generator.ex \
       lib/singularity/storage/code/synthesis/pseudocode_generator.ex
git mv lib/singularity/storage/code/generators/code_synthesis_pipeline.ex \
       lib/singularity/storage/code/synthesis/code_synthesis_pipeline.ex
```

### Step 3: Create storage/code/indexes/
```bash
mkdir -p lib/singularity/storage/code/indexes
git mv lib/singularity/storage/code/storage/code_store.ex \
       lib/singularity/storage/code/indexes/code_store.ex
git mv lib/singularity/storage/code/storage/codebase_registry.ex \
       lib/singularity/storage/code/indexes/codebase_registry.ex
git mv lib/singularity/storage/code/patterns/pattern_indexer.ex \
       lib/singularity/storage/code/indexes/pattern_indexer.ex
git mv lib/singularity/storage/code/patterns/pattern_consolidator.ex \
       lib/singularity/storage/code/indexes/pattern_consolidator.ex
```

### Step 4: Create extractors/
```bash
mkdir -p lib/singularity/storage/code/extractors
git mv lib/singularity/storage/code/ai_metadata_extractor.ex \
       lib/singularity/storage/code/extractors/ai_metadata_extractor.ex
git mv lib/singularity/storage/code/patterns/code_pattern_extractor.ex \
       lib/singularity/storage/code/extractors/code_pattern_extractor.ex
git mv lib/singularity/storage/code/patterns/pattern_miner.ex \
       lib/singularity/storage/code/extractors/pattern_miner.ex
```

### Step 5: Move analyzers
```bash
mkdir -p lib/singularity/storage/code/analyzers
git mv lib/singularity/storage/code/analyzers/* \
       lib/singularity/storage/code/analyzers/  # Already in place, just verify
```

### Step 6: Create behavior contracts
Create `lib/singularity/storage/code/analyzers/analyzer_type.ex`:
```elixir
defmodule Singularity.Storage.Code.Analyzers.AnalyzerType do
  @moduledoc """
  Analyzer behavior contract for config-driven discovery.
  """
  
  @callback analyze(code :: String.t(), opts :: Keyword.t()) ::
    {:ok, map()} | {:error, term()}
end
```

Same for `extractors/extractor_type.ex`

### Step 7: Verify
```bash
mix compile
mix test
```

---

## Quick Checklist

### Before Starting
- [ ] Read PHASE_5_STANDARDIZATION_PLAN.md for full context
- [ ] Commit current changes (`git status` should be clean)
- [ ] Choose which phase(s) to implement

### During Phase 5A
- [ ] Create execution/orchestrator/ directory
- [ ] Create execution/runners/ directory
- [ ] Create storage/code/core/ directory
- [ ] Add behavior contracts to storage/code/
- [ ] Create delegation modules for all moved files
- [ ] `mix compile` (should succeed)
- [ ] `mix test` (should pass)

### During Phase 5B1 (if doing)
- [ ] Create tools/ category directories
- [ ] Move files to categories (optional delegation modules)
- [ ] `mix compile`
- [ ] `mix test`

### During Phase 5B2+B3 (if doing)
- [ ] Create remaining execution/ subdirectories
- [ ] Reorganize storage/code/
- [ ] Create delegation modules
- [ ] `mix compile`
- [ ] `mix test`

### Final Verification
- [ ] All tests pass
- [ ] No compilation warnings
- [ ] No dialyzer errors (mix dialyzer)
- [ ] Old imports still work (search for old module names)
- [ ] Documentation updated (comment any changes)

---

## Troubleshooting

### Compilation Error: "module does not exist"
**Fix:** You moved a file but forgot to update the defmodule path
```
lib/singularity/execution/orchestrator/execution_orchestrator.ex:3

defmodule Singularity.Execution.ExecutionOrchestrator do
                    ^^^ This should match file path: Orchestrator.ExecutionOrchestrator
```

### Compilation Error: "function not found"
**Fix:** You moved a file but didn't create a delegation module at the old path
```elixir
# Create lib/singularity/execution/execution_orchestrator.ex
defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc false
  defdelegate execute(goal, opts \\ []), to: Singularity.Execution.Orchestrator.ExecutionOrchestrator
end
```

### Dialyzer Error: "Module does not exist"
**Fix:** Same as compilation error - update defmodule path and create delegation module

### Tests Fail: "function not found in module"
**Fix:** Check that delegation module's `defdelegate` is exporting all public functions
```bash
# List all public functions in original module
grep "def " lib/singularity/execution/orchestrator/execution_orchestrator.ex

# Make sure all are in delegation module
grep "defdelegate" lib/singularity/execution/execution_orchestrator.ex
```

---

## Tips & Tricks

### Using git mv Preserves History
```bash
git mv old/path/file.ex new/path/file.ex
git log --oneline new/path/file.ex  # Shows full history
```

### Create Multiple Files at Once
```bash
mkdir -p lib/singularity/execution/{orchestrator,runners,adapters,strategies}
```

### Find All References to Moved Module
```bash
grep -r "Execution.ExecutionOrchestrator" lib/
grep -r "import Execution.ExecutionOrchestrator" lib/
grep -r "alias Execution.ExecutionOrchestrator" lib/
```

### Test Specific Domain After Changes
```bash
mix test test/singularity/execution/
mix test test/singularity/tools/
mix test test/singularity/storage/code/
```

---

## What NOT to Do

❌ Don't change module behavior while moving
❌ Don't skip delegation modules (breaks backward compatibility)
❌ Don't move files without updating defmodule paths
❌ Don't forget to run `mix compile` after moves
❌ Don't commit before running `mix test`

---

## Questions?

See full documentation:
- **PHASE_5_STANDARDIZATION_PLAN.md** - Complete analysis and plan
- **PHASE_5_VISUAL_SUMMARY.md** - Visual before/after diagrams
- **CLAUDE.md** - Architecture principles and patterns

