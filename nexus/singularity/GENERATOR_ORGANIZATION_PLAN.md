# Generator System Organization - Phase 2 Implementation Plan

**Status**: Ready for Implementation
**Complexity**: Low (mechanical refactoring)
**Estimated Effort**: 4-6 hours (mostly file moves + import updates)

---

## Current Organization (Before Phase 2)

```
singularity/lib/singularity/
│
├─ code_generation/
│  ├─ generator_type.ex
│  ├─ generation_orchestrator.ex
│  ├─ inference_engine.ex
│  ├─ llm_service.ex
│  ├─ model_loader.ex
│  └─ generators/
│     ├─ code_generator_impl.ex ────────┐
│     ├─ rag_generator_impl.ex ─────────┼─ All wrap legacy modules
│     ├─ quality_generator.ex ──────────┤  (located in storage/code/generators/)
│     └─ generator_engine_impl.ex ──────┘
│
├─ storage/code/generators/ ◄─────────── LEGACY LOCATION
│  ├─ quality_code_generator.ex
│  ├─ rag_code_generator.ex
│  ├─ pseudocode_generator.ex
│  └─ code_synthesis_pipeline.ex
│
├─ generator_engine/ ◄────────────────── CONFUSING LOCATION
│  ├─ code.ex
│  ├─ naming.ex
│  ├─ pseudocode.ex
│  ├─ structure.ex
│  └─ util.ex
│
├─ engines/
│  └─ generator_engine.ex ◄────────────── CONFUSING (wraps generator_engine/ above)
│
├─ code_generator.ex ◄─────────────────── TOP-LEVEL (hard to find)
│
├─ llm/
│  └─ embedding_generator.ex
│
├─ infrastructure/
│  └─ documentation_generator.ex
│
└─ tools/
   ├─ code_generation.ex ◄──────────────── ENTRY POINT
   └─ validated_code_generation.ex
```

## Proposed Organization (After Phase 2)

```
singularity/lib/singularity/
│
├─ code_generation/ ◄──────────────────── UNIFIED GENERATOR HOME
│  │
│  ├─ orchestrator/
│  │  ├─ generation_orchestrator.ex (moved from code_generation/)
│  │  ├─ generator_type.ex (moved from code_generation/)
│  │  └─ result.ex (new: unified result format)
│  │
│  ├─ inference/
│  │  ├─ inference_engine.ex (moved from code_generation/)
│  │  ├─ llm_service.ex (moved from code_generation/)
│  │  ├─ model_loader.ex (moved from code_generation/)
│  │  └─ sampling.ex (optional: consolidate sampling logic)
│  │
│  ├─ generators/
│  │  ├─ code_generator_impl.ex (moved from code_generation/generators/)
│  │  ├─ rag_generator_impl.ex (moved from code_generation/generators/)
│  │  ├─ quality_generator_impl.ex (renamed from quality_generator.ex)
│  │  └─ generator_engine_impl.ex (moved from code_generation/generators/)
│  │
│  ├─ implementations/
│  │  ├─ code_generator.ex (moved from ../code_generator.ex)
│  │  ├─ rag_code_generator.ex (moved from ../storage/code/generators/)
│  │  ├─ quality_code_generator.ex (moved from ../storage/code/generators/)
│  │  ├─ generator_engine.ex (moved from ../generator_engine/)
│  │  │  ├─ code.ex
│  │  │  ├─ naming.ex
│  │  │  ├─ pseudocode.ex
│  │  │  ├─ structure.ex
│  │  │  └─ util.ex
│  │  └─ embedding_generator.ex (moved from ../llm/)
│  │
│  └─ validation/
│     └─ template_validator.ex (moved from ../code/quality/)
│
├─ tools/ ◄────────────────────────────── ENTRY POINTS (unchanged)
│  ├─ code_generation.ex (imports updated)
│  └─ validated_code_generation.ex (imports updated)
│
├─ infrastructure/
│  └─ documentation_generator.ex (keep as-is: different domain)
│
└─ (empty directories deleted):
   ├─ storage/code/generators/ ✗ DELETE (empty after moves)
   ├─ generator_engine/ ✗ DELETE (moved to code_generation/implementations/)
   └─ engines/generator_engine.ex ✗ DELETE (consolidated)

# DELETED (Orphaned, never used):
├─ storage/code/generators/pseudocode_generator.ex ✗
└─ storage/code/generators/code_synthesis_pipeline.ex ✗
```

---

## Phase 2 Migration Steps

### Step 1: Create New Directory Structure

```bash
mkdir -p singularity/lib/singularity/code_generation/orchestrator
mkdir -p singularity/lib/singularity/code_generation/inference
mkdir -p singularity/lib/singularity/code_generation/implementations/generator_engine
mkdir -p singularity/lib/singularity/code_generation/validation
```

### Step 2: Move Orchestrator Files

```bash
# Already in code_generation/, just move to orchestrator/
mv singularity/lib/singularity/code_generation/generator_type.ex \
   singularity/lib/singularity/code_generation/orchestrator/

mv singularity/lib/singularity/code_generation/generation_orchestrator.ex \
   singularity/lib/singularity/code_generation/orchestrator/

# Create new unified result module
touch singularity/lib/singularity/code_generation/orchestrator/result.ex
```

### Step 3: Move Inference Files

```bash
mv singularity/lib/singularity/code_generation/inference_engine.ex \
   singularity/lib/singularity/code_generation/inference/

mv singularity/lib/singularity/code_generation/llm_service.ex \
   singularity/lib/singularity/code_generation/inference/

mv singularity/lib/singularity/code_generation/model_loader.ex \
   singularity/lib/singularity/code_generation/inference/
```

### Step 4: Move Generator Implementations

```bash
# Already in code_generation/generators/, rename quality_generator.ex
mv singularity/lib/singularity/code_generation/generators/quality_generator.ex \
   singularity/lib/singularity/code_generation/generators/quality_generator_impl.ex
```

### Step 5: Move Implementation Modules

```bash
# CodeGenerator (top-level)
mv singularity/lib/singularity/code_generator.ex \
   singularity/lib/singularity/code_generation/implementations/

# RAGCodeGenerator (from storage/)
mv singularity/lib/singularity/storage/code/generators/rag_code_generator.ex \
   singularity/lib/singularity/code_generation/implementations/

# QualityCodeGenerator (from storage/)
mv singularity/lib/singularity/storage/code/generators/quality_code_generator.ex \
   singularity/lib/singularity/code_generation/implementations/

# GeneratorEngine (from engines/)
mv singularity/lib/singularity/generator_engine/ \
   singularity/lib/singularity/code_generation/implementations/generator_engine

mv singularity/lib/singularity/engines/generator_engine.ex \
   singularity/lib/singularity/code_generation/implementations/
```

### Step 6: Move Embedding Generator (Optional)

```bash
# If treating embeddings as part of code generation
mv singularity/lib/singularity/llm/embedding_generator.ex \
   singularity/lib/singularity/code_generation/implementations/

# Otherwise, keep in llm/ (probably better semantically)
# Decision: KEEP IN LLM/ (embeddings are LLM concern, not code generation)
```

### Step 7: Delete Orphaned Files

```bash
# Delete legacy modules that are duplicated
rm singularity/lib/singularity/storage/code/generators/pseudocode_generator.ex
rm singularity/lib/singularity/storage/code/generators/code_synthesis_pipeline.ex

# Clean up empty directories
rmdir singularity/lib/singularity/storage/code/generators/
rmdir singularity/lib/singularity/generator_engine/
rm singularity/lib/singularity/engines/generator_engine.ex
```

---

## Import Update Checklist

### 1. Update Module Paths

Files that reference old modules need import updates:

**Old Path → New Path:**

```elixir
# OLD: Singularity.CodeGenerator
# NEW: Singularity.CodeGeneration.Implementations.CodeGenerator
alias Singularity.CodeGeneration.Implementations.CodeGenerator

# OLD: Singularity.RAGCodeGenerator
# NEW: Singularity.CodeGeneration.Implementations.RAGCodeGenerator
alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator

# OLD: Singularity.QualityCodeGenerator
# NEW: Singularity.CodeGeneration.Implementations.QualityCodeGenerator
alias Singularity.CodeGeneration.Implementations.QualityCodeGenerator

# OLD: Singularity.GeneratorEngine
# NEW: Singularity.CodeGeneration.Implementations.GeneratorEngine
alias Singularity.CodeGeneration.Implementations.GeneratorEngine

# OLD: Singularity.CodeGeneration.GeneratorType
# NEW: Singularity.CodeGeneration.Orchestrator.GeneratorType
alias Singularity.CodeGeneration.Orchestrator.GeneratorType

# OLD: Singularity.CodeGeneration.GenerationOrchestrator
# NEW: Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator
alias Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator

# OLD: Singularity.CodeGeneration.InferenceEngine
# NEW: Singularity.CodeGeneration.Inference.InferenceEngine
alias Singularity.CodeGeneration.Inference.InferenceEngine

# OLD: Singularity.CodeGeneration.LLMService
# NEW: Singularity.CodeGeneration.Inference.LLMService
alias Singularity.CodeGeneration.Inference.LLMService

# OLD: Singularity.CodeGeneration.ModelLoader
# NEW: Singularity.CodeGeneration.Inference.ModelLoader
alias Singularity.CodeGeneration.Inference.ModelLoader
```

### 2. Files That Need Import Updates

Use grep to find all files that import old modules:

```bash
# Find all imports of old modules
grep -r "Singularity.CodeGenerator\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.RAGCodeGenerator\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.QualityCodeGenerator\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.GeneratorEngine\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.CodeGeneration.InferenceEngine\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.CodeGeneration.LLMService\b" --include="*.ex" \
  singularity/lib/ singularity/test/

grep -r "Singularity.CodeGeneration.ModelLoader\b" --include="*.ex" \
  singularity/lib/ singularity/test/
```

### 3. Config Updates

Update `config/config.exs`:

```elixir
# OLD:
config :singularity, :generator_types,
  code_generator: %{
    module: Singularity.CodeGeneration.Generators.CodeGeneratorImpl,
    enabled: true
  }

# NEW:
config :singularity, :generator_types,
  code_generator: %{
    module: Singularity.CodeGeneration.Generators.CodeGeneratorImpl,
    enabled: true
  }
# (No change - generators stay in code_generation/generators/)
```

---

## Module Renaming Strategy

### Rationale for Renaming

Current: `Singularity.CodeGeneration.Generators.QualityGenerator`
Issue: Confusing - is this the behavior or the implementation?

After: `Singularity.CodeGeneration.Generators.QualityGeneratorImpl`
Benefit: Clear it's the GeneratorType implementation wrapper

### Files to Rename

1. **quality_generator.ex** → **quality_generator_impl.ex**
   - `Singularity.CodeGeneration.Generators.QualityGenerator` → `Singularity.CodeGeneration.Generators.QualityGeneratorImpl`

2. Keep others as-is (they already end in `Impl`):
   - CodeGeneratorImpl
   - RAGGeneratorImpl
   - GeneratorEngineImpl

---

## Testing Strategy

### 1. Pre-Migration Tests

```bash
# Run all generator tests
cd singularity
mix test test/singularity/code_generation/ -v
mix test test/singularity/tools/code_generation_test.exs -v
```

### 2. Post-Migration Tests

```bash
# After moving files, run same tests
mix test test/singularity/code_generation/ -v

# Verify imports work with new paths
mix test test/singularity/tools/code_generation_test.exs -v

# Run full test suite
mix test.ci
```

### 3. Manual Verification

```bash
# Check that GenerationOrchestrator still loads config
iex(1)> alias Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator
iex(2)> GenerationOrchestrator.generate(%{spec: "test"})

# Check that tools still work
iex(3)> alias Singularity.Tools.CodeGeneration
iex(4)> CodeGeneration.code_generate("test function")

# Check config is still correct
iex(5)> Application.get_env(:singularity, :generator_types)
```

---

## Migration Timeline

| Step | Time | What |
|------|------|------|
| 1 | 15 min | Create directory structure |
| 2 | 20 min | Move files (code_generation/) |
| 3 | 15 min | Move files (storage/ → implementations/) |
| 4 | 15 min | Move files (engines/ → implementations/) |
| 5 | 30 min | Update imports (grep + sed) |
| 6 | 15 min | Delete orphaned files and directories |
| 7 | 30 min | Run tests and verify |
| 8 | 10 min | Final cleanup and verification |
| **Total** | **3 hours** | **Complete migration** |

---

## Rollback Plan

If anything goes wrong:

```bash
# All changes are file moves, so rollback is simple:

# 1. Restore from git
git reset --hard origin/main

# 2. Or manually move files back to original locations
# (should only take 5-10 minutes)
```

---

## Success Criteria

### Migration is successful when:

1. ✅ All files moved to new locations
2. ✅ All imports updated (no compilation errors)
3. ✅ All tests pass (mix test)
4. ✅ Configuration still loads generators correctly
5. ✅ GenerationOrchestrator loads all 4 generators
6. ✅ Tools layer still works (agents can call code_generate)
7. ✅ No broken references in codebase

### Post-Migration Verification:

```bash
# No "undefined module" errors
grep -r "undefined module" test_results

# All generators register
iex(1)> alias Singularity.CodeGeneration.Orchestrator.{GenerationOrchestrator, GeneratorType}
iex(2)> GeneratorType.load_enabled_generators()
[code_generator: ..., rag: ..., generator_engine: ..., quality: ...]

# Tools work
iex(3)> alias Singularity.Tools.CodeGeneration
iex(4)> CodeGeneration.code_generate("test", [])
{:ok, ...}
```

---

## Documentation Updates After Migration

1. Update module docstrings to reflect new paths
2. Update README with new directory structure
3. Update CLAUDE.md with new import paths
4. Update architecture docs with consolidated structure
5. Create migration guide for developers

---

## Summary

Phase 2 consolidates generator system from:
- **4 scattered directories** → **1 unified code_generation/ directory**
- **Confusing import paths** → **Clear, predictable paths**
- **Legacy orphaned code** → **Clean, maintained codebase**
- **Multiple entry points** → **Single orchestrator entry point**

The refactoring is **purely mechanical** (file moves + imports) with **low risk** and **high benefit** for code clarity and maintainability.

---

## See Also

- `GENERATOR_AUDIT_REPORT.md` - Detailed audit of all generator files
- `GENERATOR_AUDIT_SUMMARY.md` - Executive summary
- `config/config.exs` - Current generator configuration
