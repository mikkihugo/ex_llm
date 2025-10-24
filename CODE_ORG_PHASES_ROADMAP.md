# Code Organization Roadmap: Phases 2-7 Complete Guide

## Overview

This document provides a comprehensive roadmap for completing Code Org Phases 2-7, building on the Phase 3 Ecto consolidation (all 67 schemas centralized to `/schemas/`).

---

## Phase 2: Generator Deduplication ✓ PARTIALLY COMPLETE

### Status
- **File Moves**: COMPLETE ✓ (14 files reorganized)
- **Module Renaming**: PENDING
- **Import Updates**: PENDING
- **Compilation Testing**: PENDING

### Completion Checklist

#### Step 1: Update Module Names (1-2 hours)
All 14 files in new locations need module name updates.

**Orchestrator Layer** (2 files)
```bash
# Update module definitions
sed -i '' 's/defmodule Singularity\.CodeGeneration\.GeneratorType/defmodule Singularity.CodeGeneration.Orchestrator.GeneratorType/' lib/singularity/code_generation/orchestrator/generator_type.ex
sed -i '' 's/defmodule Singularity\.CodeGeneration\.GenerationOrchestrator/defmodule Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator/' lib/singularity/code_generation/orchestrator/generation_orchestrator.ex
```

**Inference Layer** (3 files)
```bash
sed -i '' 's/defmodule Singularity\.CodeGeneration\.InferenceEngine/defmodule Singularity.CodeGeneration.Inference.InferenceEngine/' lib/singularity/code_generation/inference/inference_engine.ex
sed -i '' 's/defmodule Singularity\.CodeGeneration\.LLMService/defmodule Singularity.CodeGeneration.Inference.LLMService/' lib/singularity/code_generation/inference/llm_service.ex
sed -i '' 's/defmodule Singularity\.CodeGeneration\.ModelLoader/defmodule Singularity.CodeGeneration.Inference.ModelLoader/' lib/singularity/code_generation/inference/model_loader.ex
```

**Implementations Layer** (5 files)
```bash
sed -i '' 's/defmodule Singularity\.CodeGenerator/defmodule Singularity.CodeGeneration.Implementations.CodeGenerator/' lib/singularity/code_generation/implementations/code_generator.ex
sed -i '' 's/defmodule Singularity\.Storage\.Code\.Generators\.QualityCodeGenerator/defmodule Singularity.CodeGeneration.Implementations.QualityCodeGenerator/' lib/singularity/code_generation/implementations/quality_code_generator.ex
sed -i '' 's/defmodule Singularity\.Storage\.Code\.Generators\.RAGCodeGenerator/defmodule Singularity.CodeGeneration.Implementations.RAGCodeGenerator/' lib/singularity/code_generation/implementations/rag_code_generator.ex
sed -i '' 's/defmodule Singularity\.LLM\.EmbeddingGenerator/defmodule Singularity.CodeGeneration.Implementations.EmbeddingGenerator/' lib/singularity/code_generation/implementations/embedding_generator.ex
sed -i '' 's/defmodule Singularity\.GeneratorEngine\b/defmodule Singularity.CodeGeneration.Implementations.GeneratorEngine/' lib/singularity/code_generation/implementations/generator_engine.ex
```

**Generators Layer** (1 file)
```bash
sed -i '' 's/defmodule Singularity\.CodeGeneration\.Generators\.QualityGenerator\b/defmodule Singularity.CodeGeneration.Generators.QualityGeneratorImpl/' lib/singularity/code_generation/generators/quality_generator_impl.ex
```

#### Step 2: Update Internal References (1-2 hours)
Files that reference each other need module name updates.

**Key References to Update:**
- In `orchestrator/generation_orchestrator.ex`: Update references to orchestrator/generator_type.ex
- In `generators/*`: Update references to inference modules
- In `implementations/*`: Update references to orchestrator/generators

#### Step 3: Update All Imports (2-3 hours)
Find and replace in ~25-35 files:

**Priority Files:**
1. `lib/singularity/tools/code_generation.ex` - Entry point
2. `lib/singularity/tools/validated_code_generation.ex` - Entry point
3. `lib/singularity/interfaces/nats.ex` - NATS integration
4. `lib/singularity/storage/code/code_location_index_service.ex`
5. `lib/singularity/execution/planning/safe_work_planner.ex`

**Find all imports:**
```bash
grep -r "alias Singularity.CodeGeneration\|alias Singularity.CodeGenerator\|alias Singularity.Storage.Code.Generators\|alias Singularity.GeneratorEngine\|alias Singularity.LLM.EmbeddingGenerator" lib --include="*.ex" | grep -v "code_generation/"
```

#### Step 4: Test & Commit (30 min)
```bash
timeout 120 mix compile.elixir
# Fix any remaining errors
git add -A
git commit -m "refactor: Complete Phase 2 - Update generator module names and imports"
```

---

## Phase 3: Root Module Consolidation

### Analysis Needed

**Current Root Modules** (24 top-level modules):
1. `lib/singularity/code_generator.ex` - MOVED (Phase 2)
2. `lib/singularity/language_detection.ex` - Bridge to Rust NIF
3. `lib/singularity/nats_orchestrator.ex` - NATS messaging
4. `lib/singularity/semantic_code_search.ex` - Search operations
5. `lib/singularity/git.ex` - Git operations
6. `lib/singularity/application.ex` - OTP application
7... and 17 more

### Consolidation Strategy

**Group into 8-10 domain modules:**
1. **Application** (`application.ex` - unchanged)
2. **Language Services** (language_detection.ex, etc.)
3. **Messaging** (nats_orchestrator.ex + related)
4. **Search** (semantic_code_search.ex + embeddings)
5. **Git Operations** (git.ex + git utilities)
6. **Storage** (storage.ex + repo utilities)
7. **Tools** (tools.ex + tool utilities)
8. **Infrastructure** (remaining infrastructure modules)
9. **Analysis** (remaining analysis modules)
10. **Learning** (remaining learning modules)

### Time Estimate: 2-3 hours

---

## Phase 4: Kitchen Sink Decomposition

### Identify Large Modules

Find files > 500 lines that should be split:

```bash
wc -l lib/singularity/**/*.ex | sort -n | tail -20
```

### Strategy

Decompose based on responsibilities:
- Separate read-only queries from write operations
- Extract test helpers into separate modules
- Extract documentation generators
- Break up large case statements into function delegates

### Time Estimate: 3-4 hours

---

## Phase 5: Sub-Directory Organization

### Organize by Domain

Create consistent sub-directory structure:
```
lib/singularity/
├── analysis/          (Complete - analyzers, extractors)
├── agents/            (Complete - 6 agent types)
├── code_generation/   (Complete - Phase 2)
├── execution/         (Mostly complete)
├── infrastructure/    (Needs cleanup)
├── knowledge/         (Needs cleanup)
├── storage/           (Needs cleanup)
├── tools/             (Entry points for tools)
├── interfaces/        (MCP, NATS interfaces)
├── llm/              (LLM provider integration)
└── schemas/          (Complete - Phase 3)
```

### Time Estimate: 1-2 hours

---

## Phase 6: Documentation Updates

### Update All Module Documentation

Add/update `@moduledoc` for:
- All 24 root modules
- All large modules in Phase 4
- All reorganized modules in Phases 2-3

### AI Documentation Priority

Add AI metadata to critical modules:
1. Orchestrators (GenerationOrchestrator, etc.)
2. Entry points (tools/code_generation.ex)
3. Service modules

### Time Estimate: 2-3 hours

---

## Phase 7: Verification & Cleanup

### Testing

```bash
mix compile        # Full compilation
mix test          # Run test suite
mix quality       # Run all quality checks
mix credo --strict  # Linting
mix dialyzer      # Type checking
```

### Cleanup

- Remove orphaned files
- Verify all imports resolved
- Update documentation
- Final commit with comprehensive message

### Time Estimate: 1-2 hours

---

## Complete Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| 2a (Files) | - | ✓ COMPLETE |
| 2b (Names) | 1-2h | PENDING |
| 2c (Imports) | 2-3h | PENDING |
| 2d (Test) | 0.5h | PENDING |
| 3 (Root) | 2-3h | PENDING |
| 4 (Decompose) | 3-4h | PENDING |
| 5 (Sub-dirs) | 1-2h | PENDING |
| 6 (Docs) | 2-3h | PENDING |
| 7 (Verify) | 1-2h | PENDING |
| **Total** | **15-20h** | |

---

## Recommendations

### Session 1 (Complete Phase 2)
- Complete all Phase 2 steps (4-6 hours)
- Test compilation thoroughly
- Document learnings

### Session 2 (Phases 3-5)
- Complete Phase 3 (root consolidation)
- Complete Phase 4 (decomposition)
- Complete Phase 5 (sub-directory organization)
- Total: 6-9 hours

### Session 3 (Phases 6-7)
- Update documentation (Phase 6)
- Final testing and cleanup (Phase 7)
- Total: 3-5 hours

---

## Success Criteria

After completing all phases:

✓ Single unified home for all generator code
✓ 10-12 domain root modules (down from 24)
✓ No large modules (> 500 lines)
✓ Consistent sub-directory organization
✓ All modules documented with AI metadata
✓ All tests passing
✓ Clean compilation with no warnings
✓ Ready for billion-line scale AI navigation

---

## Resources

- Phase 2 Migration: See `PHASE_2_MIGRATION_GUIDE.md`
- Generator Audit: See `GENERATOR_AUDIT_REPORT.md`
- Phase 3 Guide: To be created
- All phases depend on: Ecto Schema consolidation (Phase 3 Ecto) ✓ COMPLETE

