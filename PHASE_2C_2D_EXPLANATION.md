# Phase 2c & 2d: Detailed Explanation

## Phase 2c: Code Generation Systems Consolidation

### The Problem

The codebase has **4 competing code generation systems** that do similar things in different ways:

```
┌─────────────────────────────────────────────────────────┐
│                  User Code (Agents, Tools)              │
└──────────┬──────────────────────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
CodeGenerator  GeneratorEngine
     │           │
     └─────┬─────┘
           │ (direct call)
           ▼
    RAGCodeGenerator
           │
    GenerationOrchestrator (orphaned, barely used)
```

### System 1: CodeGenerator (15 refs) - PRIMARY

**Location:** `singularity/lib/singularity/code_generator.ex` (599 lines)

**What it does:**
- High-level orchestration with RAG + Quality enforcement
- Acts as main entry point for code generation
- Chains: RAG lookup → Quality templates → Strategy selection → Model choice

**How it works:**
```elixir
CodeGenerator.generate(task, opts)
  └─> Finds similar code with RAGCodeGenerator
  └─> Loads quality templates
  └─> Decides: Use local T5 or API?
  └─> Generates code
  └─> Validates & retries
```

**Key Features:**
- RAG-powered pattern discovery
- Quality template enforcement
- Adaptive method selection (T5-local vs LLM API)
- Complexity-based model selection
- Validation with retry logic

**Status:** ✅ **ACTIVELY USED** - Primary orchestration

**Callers:** 15 files including tools, analyzers, methodology executor

---

### System 2: RAGCodeGenerator (13 refs) - CORE

**Location:** `singularity/lib/singularity/storage/code/generators/rag_code_generator.ex` (31KB)

**What it does:**
- Retrieval-Augmented Generation using pgvector semantic search
- Finds best code examples from all codebases
- Ranks by quality (tests, recency, usage)

**How it works:**
```elixir
RAGCodeGenerator.generate(task, language, repos, top_k)
  └─> Search pgvector for similar code (768D embeddings)
  └─> Find best examples
  └─> Rank by quality metrics
  └─> Return ranked results
```

**Key Features:**
- pgvector semantic search (all codebases)
- Quality-aware ranking
- Cross-language pattern learning
- Multi-repo support
- Zero-shot quality generation

**Status:** ✅ **HEAVILY USED** - Core functionality

**Problem:** CodeGenerator calls it directly (tightly coupled, not pluggable)

---

### System 3: GeneratorEngine (7 refs) - NIF-BASED

**Location:** `singularity/lib/singularity/engines/generator_engine.ex` + submodules

**What it does:**
- Rust NIF-backed code generation
- Clean local generation (no API calls)
- Intelligent naming validation

**How it works:**
```elixir
GeneratorEngine.generate_clean_code(description, language)
GeneratorEngine.validate_naming_compliance(name, element_type)
GeneratorEngine.suggest_microservice_structure(domain)
```

**Key Features:**
- Implements `@behaviour Singularity.Engine`
- Language-specific descriptions
- Naming validation
- Structure suggestions
- Pseudocode generation

**Status:** 🟡 **PARTIALLY USED** - Limited integration

**Problem:** Barely integrated (only 7 internal references)

---

### System 4: GenerationOrchestrator (2 refs) - ORPHANED

**Location:** `singularity/lib/singularity/code_generation/generation_orchestrator.ex` (116 lines)

**What it does:**
- Config-driven orchestration framework
- Pluggable architecture for generators
- Parallel execution support

**How it works:**
```elixir
GenerationOrchestrator.generate(spec, generators: [:code_generator, :quality])
  └─> Load enabled generators from config
  └─> Execute in parallel
  └─> Combine results
  └─> Track learning metrics
```

**Key Features:**
- Follows CLAUDE.md unified pattern
- Config-driven extensibility
- Parallel execution
- Learning loop integration

**Status:** ❌ **ORPHANED** - Only 2 references, barely used

**Problem:** Framework exists but not integrated!

---

### The Solution: Unify Under GenerationOrchestrator

**Goal:** Make GenerationOrchestrator the single entry point, with all systems as pluggable implementations.

**Architecture After Consolidation:**

```elixir
# New unified API:
GenerationOrchestrator.generate(spec, generators: [:code_generator, :rag])
  │
  ├─→ CodeGeneratorImpl
  ├─→ RAGGeneratorImpl
  ├─→ GeneratorEngineImpl
  └─→ QualityGeneratorImpl
```

### Implementation Strategy: 5 Phases

#### Phase 1: Create GeneratorType Implementations
**2 days - Create adapter modules**

```elixir
# New files to create:
Singularity.CodeGeneration.Generators.CodeGeneratorImpl
Singularity.CodeGeneration.Generators.RAGGeneratorImpl
Singularity.CodeGeneration.Generators.GeneratorEngineImpl
Singularity.CodeGeneration.Generators.QualityGeneratorImpl (already exists)

# Each implements @behaviour Singularity.CodeGeneration.GeneratorType
# GeneratorType behavior defines:
@callback generate(spec :: map(), opts :: Keyword.t()) ::
  {:ok, result} | {:error, reason}
@callback supports?(feature :: atom()) :: boolean()
@callback estimate_cost(spec :: map()) :: float()
```

**Example:**
```elixir
defmodule Singularity.CodeGeneration.Generators.CodeGeneratorImpl do
  @behaviour Singularity.CodeGeneration.GeneratorType

  def generate(spec, opts) do
    # Wrap CodeGenerator.generate internally
    CodeGenerator.generate(spec[:task], opts)
  end

  def supports?(:rag), do: true
  def supports?(:quality_templates), do: true
  def supports?(:t5_local), do: true

  def estimate_cost(spec) do
    # Estimate cost based on complexity
    case spec[:complexity] do
      :simple -> 0.01
      :medium -> 0.05
      :complex -> 0.15
    end
  end
end
```

#### Phase 2: Register in Config
**2 days - Configure and initialize**

```elixir
# config/config.exs
config :singularity, :generator_types,
  code_generator: %{
    module: Singularity.CodeGeneration.Generators.CodeGeneratorImpl,
    enabled: true,
    priority: 1,
    features: [:rag, :quality_templates, :t5_local]
  },
  rag: %{
    module: Singularity.CodeGeneration.Generators.RAGGeneratorImpl,
    enabled: true,
    priority: 2,
    features: [:semantic_search, :quality_ranking]
  },
  generator_engine: %{
    module: Singularity.CodeGeneration.Generators.GeneratorEngineImpl,
    enabled: true,
    priority: 3,
    features: [:naming_validation, :structure_suggestions]
  },
  quality: %{
    module: Singularity.CodeGeneration.Generators.QualityGeneratorImpl,
    enabled: true,
    priority: 4,
    features: [:quality_enforcement, :testing]
  }
```

#### Phase 3: Update GenerationOrchestrator
**2 days - Implement orchestration logic**

```elixir
# Updated GenerationOrchestrator
defmodule Singularity.CodeGeneration.GenerationOrchestrator do
  def generate(spec, opts \\ []) do
    generators = Keyword.get(opts, :generators, :all)

    # Load enabled generators from config
    enabled = load_generators(generators)

    # Execute in parallel if enabled
    results =
      if Keyword.get(opts, :parallel, true) do
        execute_parallel(enabled, spec, opts)
      else
        execute_sequential(enabled, spec, opts)
    end

    # Combine results
    combine_results(results, opts)
  end

  defp load_generators(:all) do
    Application.get_env(:singularity, :generator_types, %{})
    |> Enum.filter(fn {_, config} -> config[:enabled] end)
    |> Enum.sort_by(fn {_, config} -> config[:priority] end)
  end

  defp load_generators(list) when is_list(list) do
    all = load_generators(:all)
    Enum.filter(all, fn {key, _} -> key in list end)
  end
end
```

#### Phase 4: Migrate 15+ Callers
**2 days - Update all call sites**

**Before:**
```elixir
CodeGenerator.generate("Create GenServer", language: "elixir")
```

**After:**
```elixir
GenerationOrchestrator.generate(%{
  task: "Create GenServer",
  language: "elixir"
}, generators: [:code_generator])
```

**Files to update (15+):**
- tools/code_generation.ex
- tools/code_naming.ex
- quality/methodology_executor.ex
- code_analyzer.ex
- agents/remediation_engine.ex
- execution/planning/task_graph_executor.ex
- And 9+ more

**Process:**
1. Create deprecation wrappers for backward compatibility
2. Migrate high-impact callers first
3. Update tests
4. Validate behavior unchanged

#### Phase 5: Remove Dead Code
**1 day - Clean up**

**Delete 3 unused modules:**
- `code_generation/inference_engine.ex` (0 refs)
- `code_generation/llm_service.ex` (0 refs)
- `code_generation/model_loader.ex` (0 refs)

**Deprecate old modules:**
- Mark CodeGenerator as deprecated (keep wrapper)
- Mark RAGCodeGenerator as deprecated (keep wrapper)
- Mark GeneratorEngine as deprecated (keep wrapper)

### Benefits

✅ **Follows CLAUDE.md Pattern** - Matches AnalysisOrchestrator, ScanOrchestrator
✅ **Config-Driven** - Add new generators without code changes
✅ **Parallel Execution** - Run multiple generators simultaneously
✅ **Learning Integration** - Tracks which generators work best
✅ **No Breaking Changes** - Deprecated wrappers maintain backward compatibility
✅ **Clear Deprecation Path** - Gradual migration possible
✅ **Extensible** - Easy to add new generators

### Timeline

- Phase 1: 2 days (implementations)
- Phase 2: 2 days (config + registration)
- Phase 3: 2 days (orchestrator logic)
- Phase 4: 2 days (migrate callers)
- Phase 5: 1 day (cleanup + testing)
- **Total: 1 week** with full backward compatibility

---

## Phase 2d: ArchitectureEngine Namespace Split

### The Problem

There's a **critical namespace split** causing broken code:

```
BROKEN (Singularity.Detection.*)          ACTIVE (Singularity.Architecture.*)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files reference:                           Actual modules exist:
├─ Detection.FrameworkDetector            ├─ Architecture.Detectors.FrameworkDetector
├─ Detection.TechnologyDetector           ├─ Architecture.Detectors.TechnologyDetector
└─ (5+ broken files)                      └─ Architecture.Detectors.*

Result: 13 broken references in 7 files!
```

### Critical Issue: Missing Module

**File:** `singularity/lib/singularity/detection/framework_detector.ex`

**Status:** **DOESN'T EXIST** but is referenced by 3 files:
- `detection/technology_agent.ex` (line 109, 139)
- `nats/nats_server.ex` (line 259)
- `test/singularity/framework_detector_test.exs` (line 4)

**Symptom:** Compilation would fail if these files were loaded

### Active vs Deprecated Modules

#### ✅ ACTIVE PRODUCTION CODE (Singularity.Architecture.*)

**37 references across 13 files** - These work correctly:

```elixir
# Pattern Detection System
Singularity.Architecture.PatternType (behavior contract)
Singularity.Architecture.PatternDetector (orchestrator)
Singularity.Architecture.Detectors.FrameworkDetector
Singularity.Architecture.Detectors.TechnologyDetector
Singularity.Architecture.Detectors.ServiceArchitectureDetector

# Code Analysis System
Singularity.Architecture.AnalyzerType (behavior contract)
Singularity.Architecture.AnalysisOrchestrator (orchestrator)
Singularity.Architecture.Analyzers.FeedbackAnalyzer
Singularity.Architecture.Analyzers.QualityAnalyzer
Singularity.Architecture.Analyzers.RefactoringAnalyzer
Singularity.Architecture.Analyzers.MicroserviceAnalyzer
```

**Config Location:** `config/config.exs`
```elixir
config :singularity, :pattern_types,
  framework: %{module: Singularity.Architecture.Detectors.FrameworkDetector, enabled: true},
  technology: %{module: Singularity.Architecture.Detectors.TechnologyDetector, enabled: true},
  service_architecture: %{...}

config :singularity, :analyzer_types,
  feedback: %{module: Singularity.Architecture.Analyzers.FeedbackAnalyzer, enabled: true},
  quality: %{module: Singularity.Architecture.Analyzers.QualityAnalyzer, enabled: true},
  ...
```

#### ❌ BROKEN/DEPRECATED CODE (Singularity.Detection.*)

**13 references across 7 files** - These are broken:

```
Files with broken imports:
├─ detection/technology_agent.ex (2 refs to Detection.FrameworkDetector)
├─ nats/nats_server.ex (1 ref)
├─ test/framework_detector_test.exs (1 ref)
├─ storage/store.ex (references non-existent module)
├─ dashboard/system_health_page.ex (wrong API call)
└─ Others in detection/ directory
```

### Specific Broken References

#### Issue 1: Missing Module Import
**File:** `singularity/lib/singularity/detection/technology_agent.ex`

```elixir
# Line 109 (BROKEN)
alias Singularity.Detection.FrameworkDetector  # ← DOESN'T EXIST!

# Should be:
alias Singularity.Architecture.Detectors.FrameworkDetector
```

#### Issue 2: Wrong API Call
**File:** `singularity/lib/singularity/nats/nats_server.ex` (line 259)

```elixir
# BROKEN CODE:
Singularity.Detection.FrameworkDetector.detect_frameworks(patterns, context: path)

# Correct API:
Singularity.Architecture.Detectors.FrameworkDetector.detect_frameworks(patterns, context: path)

# Or via orchestrator (preferred):
Singularity.Architecture.PatternDetector.detect(path, types: [:framework])
```

#### Issue 3: Config Mismatch
**File:** `config/config.exs`

```elixir
# CONFIG SAYS:
config :singularity, :pattern_types,
  framework: %{module: Singularity.Architecture.Detectors.FrameworkDetector, ...}

# BUT CODE IMPORTS:
alias Singularity.Detection.FrameworkDetector

# Result: Module not found error!
```

### Files with Broken References

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `detection/technology_agent.ex` | 109, 139 | Wrong import | Change to `Architecture.Detectors.*` |
| `nats/nats_server.ex` | 259 | Wrong API | Use `PatternDetector.detect/2` |
| `test/framework_detector_test.exs` | 4 | Test import | Update test fixture |
| `storage/store.ex` | - | Non-existent ref | Remove or fix |
| `dashboard/system_health_page.ex` | - | Broken call | Update API |

### The Root Cause

Someone started migrating from `Singularity.Detection.*` to `Singularity.Architecture.*` but:
1. Didn't complete the migration
2. Left old imports in place
3. Didn't delete obsolete code
4. Created empty modules that don't work

### Solution: Complete the Migration

**Approach:** Finish what was started - move everything to Singularity.Architecture.*

**3-Phase Implementation:**

#### Phase 1: Fix Broken Imports (1 day)

**Step 1:** Update all imports
```elixir
# Before:
alias Singularity.Detection.FrameworkDetector

# After:
alias Singularity.Architecture.Detectors.FrameworkDetector
```

**Step 2:** Update API calls
```elixir
# Before:
Singularity.Detection.FrameworkDetector.detect_frameworks(patterns, context: path)

# After (direct):
Singularity.Architecture.Detectors.FrameworkDetector.detect_frameworks(patterns, context: path)

# After (via orchestrator - preferred):
Singularity.Architecture.PatternDetector.detect(path, types: [:framework])
```

**Files to fix:**
1. `detection/technology_agent.ex` (2 refs)
2. `nats/nats_server.ex` (1 ref)
3. `test/framework_detector_test.exs` (1 ref)
4. `storage/store.ex` (multiple refs)
5. `dashboard/system_health_page.ex` (multiple refs)

#### Phase 2: Delete Obsolete Code (1 day)

**Files to delete:**
```
singularity/lib/singularity/detection/
├─ framework_detector.ex (doesn't actually exist, but referenced)
├─ technology_agent.ex (broken, migrate to new pattern)
├─ technology_pattern_adapter.ex (obsolete)
├─ codebase_snapshots.ex (orphaned)
├─ technology_template_loader.ex (obsolete)
└─ template_matcher.ex (functionality moved)
```

**Verify before deleting:** Search for all references to ensure nothing else depends on them

#### Phase 3: Consolidate Architecture Modules (1 day)

**Verify proper location structure:**
```
singularity/lib/singularity/architecture/
├─ pattern_type.ex (behavior)
├─ pattern_detector.ex (orchestrator)
├─ detectors/
│  ├─ framework_detector.ex ✅
│  ├─ technology_detector.ex ✅
│  └─ service_architecture_detector.ex ✅
├─ analyzer_type.ex (behavior)
├─ analysis_orchestrator.ex (orchestrator)
└─ analyzers/
   ├─ feedback_analyzer.ex ✅
   ├─ quality_analyzer.ex ✅
   ├─ refactoring_analyzer.ex ✅
   └─ microservice_analyzer.ex ✅
```

**Update tests:**
- Fix all test fixtures to use `Singularity.Architecture.*`
- Verify test coverage

### Implementation Checklist

```
Phase 1: Fix Broken Imports
  ☐ Update detection/technology_agent.ex
  ☐ Update nats/nats_server.ex
  ☐ Update test/framework_detector_test.exs
  ☐ Update storage/store.ex
  ☐ Update dashboard/system_health_page.ex
  ☐ Search for any other broken refs
  ☐ Verify compilation passes

Phase 2: Delete Obsolete Code
  ☐ Verify no references to detection/* modules
  ☐ Delete detection/framework_detector.ex (if exists)
  ☐ Delete detection/technology_agent.ex (migrate first)
  ☐ Delete detection/technology_pattern_adapter.ex
  ☐ Delete detection/codebase_snapshots.ex
  ☐ Delete detection/technology_template_loader.ex
  ☐ Delete detection/template_matcher.ex

Phase 3: Consolidate
  ☐ Verify architecture/ modules all exist
  ☐ Verify config.exs points to Singularity.Architecture.*
  ☐ Run full test suite
  ☐ Verify no compilation errors
```

### Timeline

- **Phase 1:** 1 day (fix broken imports)
- **Phase 2:** 1 day (delete obsolete code)
- **Phase 3:** 1 day (consolidate + test)
- **Total: 3 days** (shorter than Phase 2c)

### Benefits

✅ **Fixes Broken Code** - Eliminates 13 broken references
✅ **Cleaner Architecture** - No duplicate module namespaces
✅ **Unified Pattern** - Uses PatternDetector + AnalysisOrchestrator (config-driven)
✅ **Easier Maintenance** - Single source of truth
✅ **Better Tests** - Fix test fixtures to match reality
✅ **Reduced Confusion** - No more Detection vs Architecture split

---

## Summary

| Phase | Issue | Solution | Timeline |
|-------|-------|----------|----------|
| **2c** | 4 competing generators | Unify under GenerationOrchestrator with GeneratorType behavior | 1 week |
| **2d** | Namespace split (13 broken refs) | Complete migration to Singularity.Architecture.* | 3 days |

Both phases follow CLAUDE.md unified orchestration pattern and improve code consistency!
