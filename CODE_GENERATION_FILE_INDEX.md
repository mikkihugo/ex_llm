# Complete Code Generation File Index

## 📋 Document Index

- **CODE_GENERATION_SYSTEMS_ANALYSIS.md** - Comprehensive 20KB analysis of all 4 systems
- **CODE_GENERATION_QUICK_REFERENCE.md** - One-page summary with solution
- **CODE_GENERATION_FILE_INDEX.md** - This file

---

## 🎯 Primary Systems (Active)

### 1. CodeGenerator - HIGH-LEVEL ORCHESTRATION
- **Path**: `/singularity/lib/singularity/code_generator.ex`
- **Lines**: 599
- **References**: 15 files
- **Purpose**: Main entry point for code generation
- **Key Exports**: `generate/2`, `t5_available?/0`, `recommended_method/1`
- **Dependencies**: 
  - RAGCodeGenerator
  - EmbeddingEngine
  - Knowledge.TemplateService
  - LLM.Service
  - TemplateValidator
- **Strengths**: RAG integration, quality enforcement, complexity-aware
- **Weaknesses**: Hardcoded RAG calls, not pluggable, duplicates GenerationOrchestrator

### 2. RAGCodeGenerator - VECTOR SEARCH ENGINE
- **Path**: `/singularity/lib/singularity/storage/code/generators/rag_code_generator.ex`
- **Size**: 31KB
- **References**: 13 files (most heavily used)
- **Purpose**: Retrieve similar code patterns using pgvector
- **Key Exports**: `generate/2`, `find_best_examples/7`, `search_similar_code/3`
- **Dependencies**:
  - Singularity.Store
  - Singularity.CodeModel
  - PostgreSQL pgvector
- **Strengths**: Fast semantic search, quality ranking, multi-repo support
- **Weaknesses**: Standalone, no integration with naming/quality validators

### 3. QualityCodeGenerator - PRODUCTION ENFORCEMENT
- **Path**: `/singularity/lib/singularity/storage/code/generators/quality_code_generator.ex`
- **Size**: 28KB
- **References**: 6 files
- **Purpose**: Generate code meeting quality standards
- **Key Exports**: `generate/2`, `validate_code/2`
- **Dependencies**: RAGCodeGenerator
- **Strengths**: Quality metrics, template enforcement, multi-language
- **Weaknesses**: Depends on RAGCodeGenerator, not config-driven

---

## 🔧 Secondary Systems (NIF-Based)

### 4. GeneratorEngine - RUST NIF WRAPPER
- **Path**: `/singularity/lib/singularity/engines/generator_engine.ex`
- **Lines**: 357
- **References**: 7 files (mostly internal)
- **Purpose**: Rust NIF-based code generation without LLM calls
- **Key Exports**: 
  - `generate_clean_code/2`
  - `generate_pseudocode/2`
  - `suggest_microservice_structure/2`
  - `validate_naming_compliance/2`
- **Implements**: `@behaviour Singularity.Engine`
- **Submodules** (5 files):
  - `generator_engine/code.ex` - Code generation
  - `generator_engine/naming.ex` - Naming validation
  - `generator_engine/pseudocode.ex` - Pseudocode planning
  - `generator_engine/structure.ex` - Architecture suggestions
  - `generator_engine/util.ex` - Helper functions
- **Strengths**: Local NIF-based (no API calls), architecture-aware
- **Weaknesses**: Not integrated with RAG/Quality, minimal usage

---

## 🏗️ Config-Driven Framework (Orphaned)

### 5. CodeGeneration.GenerationOrchestrator - CONFIG FRAMEWORK
- **Path**: `/singularity/lib/singularity/code_generation/generation_orchestrator.ex`
- **Lines**: 116
- **References**: 2 files (ORPHANED - only self + QualityGenerator)
- **Purpose**: Unified orchestration pattern (follows CLAUDE.md)
- **Key Exports**: `generate/2`, `learn_from_generation/2`
- **Configuration**: `config :singularity, :generator_types`
- **Currently Configured**: Only QualityGenerator (1 of 4 systems)
- **Strengths**: Clean pattern, parallel execution, learning loop
- **Weaknesses**: Barely used, disconnected from main systems

### 6. CodeGeneration.GeneratorType - BEHAVIOR CONTRACT
- **Path**: `/singularity/lib/singularity/code_generation/generator_type.ex`
- **Lines**: 56
- **Purpose**: Define behavior contract for generators
- **Key Exports**: `load_enabled_generators/0`, `enabled?/1`, `get_generator_module/1`
- **Callbacks**: `generator_type/0`, `description/0`, `capabilities/0`, `generate/2`, `learn_from_generation/1`
- **Usage**: Only QualityGenerator implements this
- **Issue**: CodeGenerator, RAGCodeGenerator, GeneratorEngine don't implement it

### 7. CodeGeneration.InferenceEngine - TOKEN GENERATION
- **Path**: `/singularity/lib/singularity/code_generation/inference_engine.ex`
- **Size**: 5.7KB
- **Purpose**: Low-level token generation with sampling
- **Status**: DEAD CODE (exists but not integrated)

### 8. CodeGeneration.LLMService - LLM WRAPPER
- **Path**: `/singularity/lib/singularity/code_generation/llm_service.ex`
- **Size**: 5.5KB
- **Purpose**: LLM provider abstraction
- **Status**: DEAD CODE (exists but not integrated)

### 9. CodeGeneration.ModelLoader - MODEL MANAGEMENT
- **Path**: `/singularity/lib/singularity/code_generation/model_loader.ex`
- **Size**: 3.4KB
- **Purpose**: Model lifecycle management
- **Status**: DEAD CODE (exists but not integrated)

---

## 🔗 Generator Implementations

### Currently Registered Generators

```elixir
config :singularity, :generator_types,
  quality: %{
    module: Singularity.CodeGeneration.Generators.QualityGenerator,
    enabled: true,
    description: "Generate high-quality, production-ready code"
  }
```

### Should Be Registered (After Consolidation)

```
✅ CodeGeneratorImpl - from code_generator.ex
✅ RAGGeneratorImpl - from rag_code_generator.ex
✅ GeneratorEngineImpl - from engines/generator_engine.ex
✅ QualityGeneratorImpl - already exists
```

---

## 📁 Support & Integration Files

### Tools Interface
- `/singularity/lib/singularity/tools/code_generation.ex` - Tool registry
- `/singularity/lib/singularity/tools/validated_code_generation.ex` - Validation wrapper
- `/singularity/lib/singularity/tools/code_naming.ex` - Naming tool

### Knowledge Integration
- `/singularity/lib/singularity/knowledge/template_generation.ex` - Template support
- `/singularity/lib/singularity/knowledge/template_service.ex` - Template service

### LLM Integration
- `/singularity/lib/singularity/llm/embedding_generator.ex` - Embeddings
- `/singularity/lib/singularity/llm/service.ex` - LLM provider interface
- `/singularity/lib/singularity/llm/prompt/template_aware.ex` - Template-aware prompts

### Infrastructure
- `/singularity/lib/singularity/infrastructure/documentation_generator.ex` - Doc generation

### Code Storage Pipeline
- `/singularity/lib/singularity/storage/code/generators/code_synthesis_pipeline.ex`
- `/singularity/lib/singularity/storage/code/generators/pseudocode_generator.ex`
- `/singularity/lib/singularity/storage/code/session/code_session.ex`

---

## 🔍 All Files Containing "generator"

```
Total: 15 unique source files

Core Systems (4):
  code_generator.ex
  generator_engine.ex
  rag_code_generator.ex
  generation_orchestrator.ex

Support (11):
  documentation_generator.ex
  embedding_generator.ex
  pseudocode_generator.ex
  quality_code_generator.ex
  code_synthesis_pipeline.ex
  quality_generator.ex (impl)
  inference_engine.ex
  llm_service.ex
  model_loader.ex
  generator_type.ex
  named submodules (code, naming, pseudocode, structure, util)
```

---

## 📊 Reference Analysis

### By System
```
CodeGenerator:................... 15 references
RAGCodeGenerator:................ 13 references
GeneratorEngine:................. 7 references
GenerationOrchestrator:.......... 2 references (ORPHANED)
                               ────
                        Total: 37 references
```

### By Type of Referencing File
```
Tools (3 files):
  - tools/code_generation.ex
  - tools/code_naming.ex
  - tools/validated_code_generation.ex

Agents/Execution (5 files):
  - agents/remediation_engine.ex
  - execution/planning/task_graph_executor.ex
  - code_analyzer.ex
  - system/bootstrap.ex
  - code/full_repo_scanner.ex

Quality/Methodology (3 files):
  - quality/methodology_executor.ex
  - llm/prompt/template_aware.ex
  - llm/service.ex

Mix Tasks (2 files):
  - mix/tasks/rag.setup.ex
  - mix/tasks/rag.test.ex

Internal/Circular (remaining):
  - storage modules referencing each other
  - knowledge modules
```

---

## 🎨 Architecture Diagram

```
┌────────────────────────────────────────────────────┐
│              User Code & Tools                     │
│  (agents, code_generation tool, methodology_exec)  │
└─────────────────┬────────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
        ▼                    ▼
  ┌──────────────┐  ┌─────────────────┐
  │CodeGenerator │  │GeneratorEngine  │
  │   (15 refs)  │  │  (7 refs)      │
  └──────┬───────┘  └────────┬────────┘
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
         ┌──────────────────────┐
         │  RAGCodeGenerator    │
         │    (13 refs)         │
         │  [pgvector search]   │
         └──────────────────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
    ▼              ▼              ▼
[Quality]   [Template]     [Knowledge]
[Validator]   [Service]     [Base]
    │
    ▼
[GenerationOrchestrator]
   (2 refs - ORPHANED)
```

---

## ✅ Implementation Checklist for Consolidation

### Phase 1: Create Implementations
- [ ] Create `CodeGeneratorImpl` implementing `GeneratorType`
- [ ] Create `RAGGeneratorImpl` implementing `GeneratorType`
- [ ] Create `GeneratorEngineImpl` implementing `GeneratorType`
- [ ] Verify `QualityGenerator` implements `GeneratorType` correctly

### Phase 2: Register in Config
- [ ] Add all 4 generators to `:generator_types` config
- [ ] Test config loading
- [ ] Verify all enabled by default

### Phase 3: Migrate Callers
- [ ] Update `tools/code_generation.ex`
- [ ] Update `tools/code_naming.ex`
- [ ] Update `quality/methodology_executor.ex`
- [ ] Update `code_analyzer.ex`
- [ ] Update `agents/remediation_engine.ex`
- [ ] Update `execution/planning/task_graph_executor.ex`
- [ ] Update `code/full_repo_scanner.ex`
- [ ] Update `llm/prompt/template_aware.ex`
- [ ] Update `system/bootstrap.ex`
- [ ] Update `storage/code/generators/quality_code_generator.ex`
- [ ] Update all other callers (13 more)

### Phase 4: Deprecation
- [ ] Mark old modules as deprecated
- [ ] Create wrapper functions for backward compat
- [ ] Update CHANGELOG
- [ ] Announce deprecation timeline

### Phase 5: Cleanup
- [ ] Delete `inference_engine.ex`, `llm_service.ex`, `model_loader.ex`
- [ ] Consolidate docs
- [ ] Final testing

---

## 🚀 Key Metrics for Success

- **Before**: 37 file references across 4 competing systems
- **After**: Single `GenerationOrchestrator` with 4 pluggable implementations
- **Tests**: Update 13+ test files
- **Callers**: Migrate 15+ call sites
- **Timeline**: 1 week with backward compatibility
- **Benefits**: Config-driven, parallel execution, learning loop, extensibility

---

## 📚 Reference Files

See `/CLAUDE.md` section on **Unified Config-Driven Orchestration** for the pattern that should be applied here.

Similar systems already implemented:
- `AnalysisOrchestrator` - code analysis
- `ScanOrchestrator` - code scanning
- `ExecutionOrchestrator` - task execution

All follow the same pattern that `GenerationOrchestrator` should follow.
