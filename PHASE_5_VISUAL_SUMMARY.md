# Phase 5: Directory Standardization - Visual Summary

## Current vs. Target Architecture

### execution/ Domain (52 files)

```
CURRENT (Messy)                          TARGET (Clean)
├── execution_orchestrator.ex            ├── orchestrator/
├── execution_strategy_orchestrator.ex   │   ├── execution_orchestrator.ex
├── execution_strategy.ex                │   ├── execution_strategy_orchestrator.ex
├── task_adapter.ex                      │   ├── execution_strategy.ex
├── task_adapter_orchestrator.ex         │   └── execution_type.ex (NEW)
├── runner.ex                            ├── runners/
├── control.ex                           │   ├── runner.ex
├── evolution.ex                         │   ├── lua_runner.ex
├── lua_runner.ex                        │   └── control.ex
├── planning/                            ├── adapters/
│   └── (good - 15 files)                │   ├── task_adapter.ex
├── sparc/                               │   └── task_adapter_orchestrator.ex
│   └── (good - 2 files)                 ├── strategies/ (NEW)
├── autonomy/                            │   ├── task_dag_strategy.ex
│   └── (good - 8 files)                 │   ├── sparc_strategy.ex
├── task_graph/                          │   ├── methodology_strategy.ex
│   └── (good - 8 files)                 │   └── evolution.ex
├── feedback/                            ├── planning/
│   └── analyzer.ex                      │   └── (unchanged - 15 files)
└── todos/                               ├── sparc/
    └── (good - 5 files)                 │   └── (unchanged - 2 files)
                                         ├── autonomy/
[11 FILES AT ROOT - NEEDS MOVING]        │   └── (unchanged - 8 files)
                                         ├── task_graph/
                                         │   └── (unchanged - 8 files)
                                         ├── feedback/
                                         │   └── analyzer.ex
                                         └── todos/
                                             └── (unchanged - 5 files)
```

**Changes:**
- Move 11 root files to 3 subdirectories (orchestrator/, runners/, adapters/)
- Add delegation modules at old paths for backward compatibility
- Subsystems (planning/, sparc/, autonomy/) remain unchanged
- Result: Clear 2-level hierarchy

---

### tools/ Domain (40+ files)

```
CURRENT (Flat)                           TARGET (Categorized)
├── code_analysis.ex                     ├── analysis/
├── quality.ex                           │   ├── code_analysis.ex
├── quality_assurance.ex                 │   └── quality.ex (merged)
├── codebase_understanding.ex            │   └── codebase_understanding.ex
├── code_generation.ex                   ├── generation/
├── code_naming.ex                       │   ├── code_generation.ex
├── validated_code_generation.ex         │   ├── code_naming.ex
├── emergency_llm.ex                     │   └── validated_code_generation.ex
├── analytics.ex                         ├── operations/
├── deployment.ex                        │   ├── analytics.ex
├── monitoring.ex                        │   ├── deployment.ex
├── performance.ex                       │   ├── monitoring.ex
├── process_system.ex                    │   ├── performance.ex
├── backup.ex                            │   ├── process_system.ex
├── integration.ex                       │   └── backup.ex
├── database_tools_executor.ex           ├── integration/
├── nats.ex                              │   ├── integration.ex
├── git.ex                               │   ├── database_tools_executor.ex
├── instructor_adapter.ex                │   ├── nats.ex
├── knowledge.ex                         │   ├── git.ex
├── planning.ex                          │   └── instructor_adapter.ex
├── development.ex                       ├── knowledge/
├── security.ex                          │   └── knowledge.ex
├── security_policy.ex                   ├── planning/
├── testing.ex                           │   └── planning.ex (merged)
├── todos.ex                             ├── security/
├── validation.ex                        │   └── security.ex (merged)
├── final_validation.ex                  ├── testing/
├── validation_middleware.ex             │   ├── testing.ex
├── web_search.ex                        │   └── todos.ex
├── communication.ex                     ├── web/
├── documentation.ex                     │   ├── web_search.ex
├── agent_guide.ex                       │   ├── communication.ex
├── package_search.ex                    │   ├── documentation.ex
├── catalog.ex                           │   └── agent_guide.ex
├── tool_mapping.ex                      └── validation/
├── tool_selector.ex                         ├── validation.ex (merged)
├── default.ex                               ├── final_validation.ex
└── basic.ex                                 ├── validation_middleware.ex
                                            └── package_search.ex

[40+ FILES UNORGANIZED]                 [GROUPED INTO 10 CATEGORIES]
                                         [WITH DELEGATION MODULES]
```

**Changes:**
- Group 40+ files into 10 logical categories
- Consolidate duplicates (quality.ex + quality_assurance.ex, etc.)
- Create category modules (analysis.ex, generation.ex) as unified APIs
- Keep delegation modules at root for backward compatibility
- Result: Clear category hierarchy, no breaking changes

---

### storage/code/ Domain (26 files)

```
CURRENT (Over-Nested)                    TARGET (Cleaner)
├── ai_metadata_extractor.ex             ├── core/
├── code_location_index.ex               │   ├── code_location_index.ex
├── code_location_index_service.ex       │   ├── code_location_index_service.ex
├── analyzers/                           │   └── code_session.ex
│   ├── consolidation_engine.ex          ├── analyzers/
│   ├── dependency_mapper.ex             │   ├── analyzer_type.ex (NEW)
│   └── microservice_analyzer.ex         │   ├── consolidation_engine.ex
├── generators/ (DUPLICATE!)             │   ├── dependency_mapper.ex
│   ├── pseudocode_generator.ex          │   └── microservice_analyzer.ex
│   └── code_synthesis_pipeline.ex       ├── extractors/
├── patterns/                            │   ├── extractor_type.ex (NEW)
│   ├── code_pattern_extractor.ex        │   ├── ai_metadata_extractor.ex
│   ├── pattern_consolidator.ex          │   ├── code_pattern_extractor.ex
│   ├── pattern_indexer.ex               │   └── pattern_miner.ex
│   └── pattern_miner.ex                 ├── indexes/
├── quality/                             │   ├── pattern_indexer.ex
│   ├── code_deduplicator.ex             │   ├── pattern_consolidator.ex
│   ├── refactoring_agent.ex             │   └── code_store.ex
│   └── template_validator.ex            ├── quality/
├── session/                             │   ├── code_deduplicator.ex
│   └── code_session.ex                  │   ├── refactoring_agent.ex
├── storage/ (REDUNDANT!)                │   └── template_validator.ex
│   ├── code_store.ex                    ├── synthesis/
│   └── codebase_registry.ex             │   ├── pseudocode_generator.ex
├── training/                            │   └── code_synthesis_pipeline.ex
│   ├── code_model.ex                    ├── training/
│   ├── code_model_trainer.ex            │   ├── code_model.ex
│   ├── code_trainer.ex                  │   ├── code_model_trainer.ex
│   ├── domain_vocabulary_trainer.ex     │   ├── code_trainer.ex
│   ├── rust_elixir_t5_trainer.ex        │   ├── domain_vocabulary_trainer.ex
│   └── t5_fine_tuner.ex                 │   ├── rust_elixir_t5_trainer.ex
└── visualizers/                         │   └── t5_fine_tuner.ex
    └── flow_visualizer.ex               └── visualizers/
                                             └── flow_visualizer.ex

[7 CATEGORIES, 26 FILES]                 [7 CATEGORIES, 26 FILES]
[ROOT FILES SCATTERED]                   [ORGANIZED IN core/, NEW CONTRACTS]
```

**Changes:**
- Move root-level files to `core/` directory
- Create `analyzer_type.ex` and `extractor_type.ex` for config-driven discovery
- Create `synthesis/` for code generation (separate from code_generation/)
- Move `code_store.ex` from `storage/storage/` to `indexes/`
- Result: Clearer structure, config support, 2-3 level hierarchy

---

### architecture_engine/ Domain (35 files)

```
CURRENT (Good, needs cleanup)           TARGET (Optimized)
├── pattern_detector.ex                  ├── orchestrator/ (NEW)
├── pattern_type.ex                      │   ├── pattern_detector.ex
├── analysis_orchestrator.ex             │   ├── pattern_type.ex
├── analyzer_type.ex                     │   ├── analysis_orchestrator.ex
├── detectors/                           │   └── analyzer_type.ex
│   ├── framework_detector.ex            ├── detectors/ (unchanged)
│   ├── technology_detector.ex           │   ├── framework_detector.ex
│   └── service_architecture_detector.ex │   ├── technology_detector.ex
├── analyzers/                           │   └── service_architecture_detector.ex
│   ├── feedback_analyzer.ex             ├── analyzers/ (unchanged)
│   ├── quality_analyzer.ex              │   ├── feedback_analyzer.ex
│   ├── refactoring_analyzer.ex          │   ├── quality_analyzer.ex
│   └── microservice_analyzer.ex         │   ├── refactoring_analyzer.ex
├── pattern_store.ex (MOVE!)             │   └── microservice_analyzer.ex
├── framework_pattern_store.ex (MOVE!)   ├── meta_registry/ (unchanged - good!)
├── technology_pattern_store.ex (MOVE!)  │   ├── supervisor.ex
├── package_registry_knowledge.ex (MOVE!)│   ├── framework_registry.ex
├── package_registry_collector.ex (MOVE!)│   └── ...frameworks/
├── framework_pattern_sync.ex (MOVE!)    └── knowledge/ (NEW)
├── config_cache.ex (MOVE!)                  ├── pattern_store.ex
├── agent.ex (MOVE!)                        ├── framework_pattern_store.ex
└── meta_registry/                           ├── technology_pattern_store.ex
    ├── supervisor.ex                        ├── package_registry_knowledge.ex
    ├── framework_registry.ex                └── ...sync/cache
    ├── framework_learning.ex
    ├── singularity_learning.ex
    ├── query_system.ex
    ├── nats_subjects.ex
    ├── nats_subscription_router.ex
    └── frameworks/ (good - 9 files)

[ROOT LEVEL: 11 FILES - SHOULD MOVE]     [ROOT LEVEL: 2 FILES - ORCHESTRATOR]
[GOOD SUBSYSTEMS - meta_registry/]       [CLEAR: Orchestrator + Detectors + Analyzers + Knowledge]
```

**Changes (Phase 5C - Deferred):**
- Move orchestrators to `orchestrator/`
- Move storage concerns to new `knowledge/`
- Move agents to `agents/` domain
- Result: Clear 2-3 level hierarchy, better separation of concerns

**Status:** Phase 5A+5B focuses on execution/ and tools/, defer architecture_engine/ to Phase 5C

---

## Implementation Roadmap

```
DAY 1 - Phase 5A + B1 (2.5 hours)
├── Create execution/orchestrator/ (15 min) ✓
├── Create execution/runners/ (10 min) ✓
├── Add tools/ category documentation (20 min) ✓
├── Create storage/code/core/ (15 min) ✓
├── Consolidate tools/ categories (60 min) ✓
└── Test & verify (15 min) ✓

DAY 2 - Phase 5B2 + B3 (2 hours)
├── Consolidate execution/ root files (60 min) ✓
├── Dedup storage/code/ (60 min) ✓
└── Test & verify (20 min) ✓

WEEK 2 - Phase 5C (Deferred)
├── Reconcile task_graph concepts
└── Split architecture_engine concerns

TOTAL COMMITMENT: 4-5 hours over 2-3 sessions
```

---

## Key Metrics

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| **Max root files in domain** | 40 (tools) | 5 | 87% reduction |
| **Max nesting depth** | 4 (storage) | 3 | 25% reduction |
| **Flat domains** | 2 (tools, quality) | 0 | All structured |
| **Clear subsystems** | 3 (execution) | 6 | 100% improvement |
| **Behavior contracts** | 8 | 12 | 50% increase |
| **Config-driven modules** | 60% | 100% | Complete |
| **Lines of code** | Same | Same | 0% change |
| **Breaking changes** | N/A | 0 | None! |

---

## File Movement Summary

### Phase 5A (1.5 hours)

**execution/**
- execution_orchestrator.ex → execution/orchestrator/
- execution_strategy_orchestrator.ex → execution/orchestrator/
- execution_strategy.ex → execution/orchestrator/
- runner.ex → execution/runners/
- lua_runner.ex → execution/runners/
- control.ex → execution/runners/
- (Add delegation modules at old paths)

**storage/code/**
- code_location_index.ex → storage/code/core/
- code_location_index_service.ex → storage/code/core/
- code_session.ex → storage/code/core/
- (Add delegation modules at old paths)

**NEW FILES**
- storage/code/analyzer_type.ex
- storage/code/extractor_type.ex
- tools/CATEGORIES.md

**Total files moved: 9**
**New files: 3**
**Delegation modules: 9**

---

### Phase 5B (2.5 hours)

**tools/**
- Consolidate quality.ex + quality_assurance.ex
- Consolidate development.ex + planning.ex
- Consolidate security.ex + security_policy.ex
- Create tools/analysis/, tools/generation/, etc.
- Move category-specific files to subdirectories
- (Add delegation modules at old paths)

**execution/**
- evolution.ex → execution/strategies/
- Consolidate adapters into execution/adapters/

**storage/code/**
- pseudocode_generator.ex → storage/code/synthesis/
- code_synthesis_pipeline.ex → storage/code/synthesis/
- code_store.ex → storage/code/indexes/ (from storage/storage/)
- (Add delegation modules at old paths)

**Total files moved: 15+**
**Consolidations: 6 duplicate pairs merged**
**Delegation modules: 15+**

---

## Risk Assessment

### Low Risk (✅ Safe)
- Moving files with git mv (preserves history)
- Adding new files (zero impact)
- Creating delegation modules (backward compatible)
- Creating new directories (no import changes)

### Medium Risk (🟡 Manageable)
- Updating imports in 20-30 files
- Consolidating duplicate modules (careful merging)
- Mitigated by: Phased approach + testing after each change

### High Risk (❌ Avoid)
- Changing behavior of any module (✓ NOT DOING THIS)
- Removing files without alternatives (✓ NOT DOING THIS)
- Breaking public APIs (✓ NOT DOING THIS)

---

## Success Criteria

✅ Phase 5A success:
- execution/ and tools/ have clear structure
- All tests pass
- No compilation errors
- All old imports still work (delegation modules)

✅ Phase 5B success:
- storage/code/ deduplication complete
- No duplicate modules
- All tests pass
- All old imports still work

✅ Overall success:
- Consistent patterns across all domains
- New modules added to correct directories
- Onboarding time for new developers reduced
- No breaking changes to user code

