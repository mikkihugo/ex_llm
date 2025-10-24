# Code Generation Systems - Quick Reference

## At a Glance

4 competing systems with **significant overlap**:

| System | Location | Refs | Status | Key Strength |
|--------|----------|------|--------|---|
| **CodeGenerator** | `code_generator.ex` | **15** | MAIN | Orchestration + RAG |
| **RAGCodeGenerator** | `storage/code/generators/rag_code_generator.ex` | **13** | CORE | Vector search |
| **GeneratorEngine** | `engines/generator_engine.ex` | **7** | SECONDARY | NIF-based, naming |
| **GenerationOrchestrator** | `code_generation/generation_orchestrator.ex` | **2** | ORPHANED | Config-driven |

## The Problem

```
CodeGenerator (main entry point)
    ↓ direct call
RAGCodeGenerator (heavily used)
    ↓ no pluggability
GeneratorEngine (not integrated)
    ↓ unused NIF features
GenerationOrchestrator (orphaned config framework)
    ↓ only 1 generator configured
```

## Recommended Solution

**Unify under GenerationOrchestrator** (follows CLAUDE.md pattern):

```elixir
# Before:
CodeGenerator.generate("create GenServer", language: "elixir")
  └─> calls RAGCodeGenerator directly

# After:
GenerationOrchestrator.generate(spec, generators: [:code_generator, :quality])
  └─> pluggable, config-driven, parallel execution
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  User Code (Agents, Tools)                  │
└─────────────┬───────────────────────────────┘
              │
        ┌─────┴─────┐
        ▼           ▼
    GenerationOrchestrator (NEW UNIFIED)
        │
    ┌───┼───┬────┐
    ▼   ▼   ▼    ▼
   Code RAG Eng Quality  (implementations)
    Gen Gen    impl
```

## Implementation Strategy

### Phase 1: Create GeneratorType Implementations
```elixir
# New files:
Singularity.CodeGeneration.Generators.CodeGeneratorImpl
Singularity.CodeGeneration.Generators.RAGGeneratorImpl
Singularity.CodeGeneration.Generators.GeneratorEngineImpl
Singularity.CodeGeneration.Generators.QualityGeneratorImpl  # (already exists)
```

### Phase 2: Register in Config
```elixir
config :singularity, :generator_types,
  code_generator: %{
    module: Singularity.CodeGeneration.Generators.CodeGeneratorImpl,
    enabled: true
  },
  rag: %{
    module: Singularity.CodeGeneration.Generators.RAGGeneratorImpl,
    enabled: true
  },
  # ... etc
```

### Phase 3: Migrate Callers
Update 15+ files to use:
```elixir
GenerationOrchestrator.generate(spec, generators: [:code_generator])
```
Instead of:
```elixir
CodeGenerator.generate(spec)
```

### Phase 4-5: Deprecate & Test
- Keep old modules as wrappers (backward compat)
- Update tests
- Validation

## Files to Touch

### Core (Refactor)
- `code_generator.ex`
- `storage/code/generators/rag_code_generator.ex`
- `engines/generator_engine.ex`

### Integration (Expand)
- `code_generation/generation_orchestrator.ex`
- `code_generation/generator_type.ex`

### Dead Code (Delete)
- `code_generation/inference_engine.ex`
- `code_generation/llm_service.ex`
- `code_generation/model_loader.ex`

### Callers (Update)
- `tools/code_generation.ex`
- `tools/code_naming.ex`
- `quality/methodology_executor.ex`
- `code_analyzer.ex`
- `agents/remediation_engine.ex`
- `execution/planning/task_graph_executor.ex`
- And 9+ more

## Benefits

- ✅ Follows CLAUDE.md unified orchestration pattern
- ✅ Config-driven extensibility
- ✅ Parallel execution support
- ✅ Learning loop integration
- ✅ Clear deprecation path
- ✅ No duplicate abstractions

## Estimated Timeline

- **2 days**: Create implementations
- **2 days**: Config + registration
- **2 days**: Migrate callers
- **1 day**: Deprecation + backward compat
- **1 day**: Testing
- **Total: 1 week** with tests & backward compat

## Key Files to Review

1. **Current Status**: `/CODE_GENERATION_SYSTEMS_ANALYSIS.md`
2. **Primary Entry**: `/singularity/lib/singularity/code_generator.ex`
3. **Core RAG**: `/singularity/lib/singularity/storage/code/generators/rag_code_generator.ex`
4. **Orphaned Framework**: `/singularity/lib/singularity/code_generation/generation_orchestrator.ex`
5. **NIF Implementation**: `/singularity/lib/singularity/engines/generator_engine.ex`
6. **Pattern Reference**: `/singularity/lib/singularity/analysis/analysis_orchestrator.ex` (similar system)

## Next Steps

1. Read full analysis: `CODE_GENERATION_SYSTEMS_ANALYSIS.md`
2. Review `CLAUDE.md` unified orchestration pattern
3. Study `AnalysisOrchestrator` as reference implementation
4. Design implementation approach
5. Create PR with phased consolidation
