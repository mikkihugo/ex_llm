# Singularity Codebase Reorganization Checklist

Use this checklist to track progress on codebase reorganization.

---

## Phase 1: Duplicate Analyzer Elimination (URGENT)

- [ ] **Audit Phase**
  - [ ] Document which analyzers are actually used by production code
  - [ ] Identify all analyzer locations (architecture_engine, storage/code, code_quality, refactoring, execution)
  - [ ] Check which orchestrator uses which version
  - [ ] Verify test coverage for each analyzer

- [ ] **Consolidation: Architecture Engine**
  - [ ] Verify `architecture_engine/analyzers/` has all needed analyzers (Feedback, Quality, Refactoring, Microservice)
  - [ ] Merge any missing logic from other locations
  - [ ] Update all imports to use architecture_engine version
  - [ ] Run tests: `mix test architecture_engine`

- [ ] **Deletion: Storage Code**
  - [ ] Backup: Verify `storage/code/analyzers/microservice_analyzer.ex` is redundant
  - [ ] Delete: `storage/code/analyzers/` directory
  - [ ] Check for any remaining references
  - [ ] Update config if needed

- [ ] **Consolidation: Code Quality**
  - [ ] Move AST analyzers to `code_analysis/ast/` subdirectory
  - [ ] Update namespace: `CodeQuality.AstQualityAnalyzer` → `CodeAnalysis.Ast.QualityAnalyzer`
  - [ ] Rename to `*_scanner.ex` to follow ScannerType behavior
  - [ ] Delete: `code_quality/` directory

- [ ] **Consolidation: Other Locations**
  - [ ] Check `refactoring/analyzer.ex` - is it used?
  - [ ] Check `execution/feedback/analyzer.ex` - is it used?
  - [ ] Check `shared/issue_analyzer.ex` - is it used?
  - [ ] Merge or delete as appropriate

- [ ] **Testing**
  - [ ] Run full test suite: `mix test`
  - [ ] Check for import errors: `mix deps.compile --all-warnings`
  - [ ] Verify orchestrator still works: test AnalysisOrchestrator
  - [ ] Update all analyzer references in docs

---

## Phase 2: Duplicate Generator Elimination (URGENT)

- [ ] **Audit Phase**
  - [ ] Document which generators are in orchestrator vs standalone
  - [ ] Identify all generator locations
  - [ ] Check root-level wrappers (code_generator.ex, embedding_engine.ex)
  - [ ] Verify test coverage

- [ ] **Consolidation: Code Generation**
  - [ ] Verify `code_generation/generators/` has all implementations
  - [ ] Move `storage/code/generators/pseudocode_generator.ex` to `code_generation/generators/`
  - [ ] Move `storage/code/generators/code_synthesis_pipeline.ex` to `code_generation/generators/`
  - [ ] Update all imports
  - [ ] Run tests: `mix test code_generation`

- [ ] **Consolidation: Utilities**
  - [ ] Create `code_generation/utilities/` subdirectory
  - [ ] Move from `generator_engine/` to `code_generation/utilities/`:
    - [ ] naming.ex
    - [ ] structure.ex
    - [ ] pseudocode.ex
    - [ ] (others as needed)
  - [ ] Update imports

- [ ] **Deletion: Storage and Root**
  - [ ] Delete: `storage/code/generators/` (moved to code_generation)
  - [ ] Delete: `generator_engine/` directory (moved utilities out)
  - [ ] Deprecate: `code_generator.ex` at root (use GenerationOrchestrator instead)
  - [ ] Move/consolidate: `embedding_engine.ex` (move to embedding/ or merge into code_generation)
  - [ ] Delete: `engines/generator_engine.ex` if duplicative

- [ ] **Update Imports**
  - [ ] Find all `require Singularity.RAGCodeGenerator` → `Singularity.CodeGeneration.Generators.RAGGeneratorImpl`
  - [ ] Find all `require Singularity.QualityCodeGenerator` → `Singularity.CodeGeneration.Generators.QualityGenerator`
  - [ ] Find all `require Singularity.PseudocodeGenerator` → `Singularity.CodeGeneration.Generators.PseudocodeGenerator`
  - [ ] Update config.exs for any generator references

- [ ] **Testing**
  - [ ] Run full test suite: `mix test`
  - [ ] Verify GenerationOrchestrator discovers all generators
  - [ ] Test all generator implementations
  - [ ] Update root-level entry point tests

---

## Phase 3: Root-Level Module Cleanup (MEDIUM)

- [ ] **Large Files to Move**
  - [ ] Move: `runner.ex` (1,190 LOC) → `execution/runner.ex`
  - [ ] Move: `code_analyzer.ex` (734 LOC) → `code_analysis/analyzer.ex` or similar
  - [ ] Move: `code_generator.ex` (598 LOC) → DELETE (use GenerationOrchestrator)
  - [ ] Move: `template_performance_tracker.ex` (430 LOC) → `templates/performance_tracker.ex`
  - [ ] Move: `embedding_engine.ex` (308 LOC) → `embedding/service.ex`
  - [ ] Move: `language_detection.ex` (309 LOC) → `detection/language_detection.ex`

- [ ] **Medium Files to Move**
  - [ ] Move: `lua_runner.ex` (241 LOC) → `runtime/lua_runner.ex` (NEW subsystem)
  - [ ] Move: `central_cloud.ex` (237 LOC) → `central_cloud/coordinator.ex`
  - [ ] Move: `control.ex` (215 LOC) → KEEP at root (control system entry)
  - [ ] Move: `quality.ex` (193 LOC) → `code_analysis/quality_coordinator.ex`
  - [ ] Move: `tools.ex` (168 LOC) → KEEP at root (tool orchestration facade)
  - [ ] Move: `embedding_model_loader.ex` (161 LOC) → `embedding/model_loader.ex`

- [ ] **Small Files to Move**
  - [ ] Move: `startup_warmup.ex` (138 LOC) → `startup/warmup.ex` (NEW)
  - [ ] Move: `analysis_runner.ex` (70 LOC) → `analysis/runner.ex`
  - [ ] Move: `health.ex` (63 LOC) → `health/service.ex` (or keep at root?)
  - [ ] Move: `system_status_monitor.ex` (62 LOC) → `monitoring/system_status.ex` (NEW)
  - [ ] Move: `web.ex` (50 LOC) → already in `web/` - consolidate
  - [ ] Move: `prometheus_exporter.ex` (23 LOC) → `monitoring/prometheus.ex`
  - [ ] Move: `process_registry.ex` (10 LOC) → `runtime/process_registry.ex`

- [ ] **Files to Keep at Root**
  - [ ] KEEP: `application.ex` (OTP setup)
  - [ ] KEEP: `application_supervisor.ex` (Supervisor setup)
  - [ ] KEEP: `repo.ex` (Database setup)
  - [ ] KEEP: `telemetry.ex` (Telemetry setup)
  - [ ] KEEP: `control.ex` (Control entry point)
  - [ ] KEEP: `tools.ex` (Tool orchestration facade)

- [ ] **Testing and Updates**
  - [ ] Update `application.ex` to import from new locations
  - [ ] Update all test imports
  - [ ] Run: `mix compile` to find any remaining import errors
  - [ ] Run: `mix test` to verify functionality
  - [ ] Update documentation with new module paths

---

## Phase 4: Kitchen Sink Decomposition (HIGH VALUE)

- [ ] **Create New Subsystems**
  - [ ] Create: `patterns/` directory with structure
  - [ ] Create: `training/` directory with structure
  - [ ] Create: `runtime/` directory for utilities
  - [ ] Create: `monitoring/` directory for system monitoring

- [ ] **Move Pattern Files**
  - [ ] Move: `storage/code/patterns/pattern_miner.ex` → `patterns/mining/pattern_miner.ex`
  - [ ] Move: `storage/code/patterns/pattern_consolidator.ex` → `patterns/mining/pattern_consolidator.ex`
  - [ ] Move: `storage/code/patterns/pattern_indexer.ex` → `patterns/mining/pattern_indexer.ex`
  - [ ] Move: `storage/code/patterns/code_pattern_extractor.ex` → `patterns/extractors/code_pattern_extractor.ex`
  - [ ] Create: `patterns/pattern_type.ex` (behavior contract)
  - [ ] Create: `patterns/pattern_orchestrator.ex` (if needed)

- [ ] **Move Training Files**
  - [ ] Move: `storage/code/training/code_model.ex` → `training/models/code_model.ex`
  - [ ] Move: `storage/code/training/code_trainer.ex` → `training/code_trainer.ex`
  - [ ] Move: `storage/code/training/code_model_trainer.ex` → `training/models/code_model_trainer.ex`
  - [ ] Move: `storage/code/training/t5_fine_tuner.ex` → `training/models/t5_fine_tuner.ex`
  - [ ] Move: `storage/code/training/domain_vocabulary_trainer.ex` → `training/models/domain_vocabulary_trainer.ex`
  - [ ] Move: `storage/code/training/rust_elixir_t5_trainer.ex` → `training/models/rust_elixir_t5_trainer.ex`
  - [ ] Create: `training/training_type.ex` (behavior contract)
  - [ ] Create: `training/training_orchestrator.ex` (if needed)

- [ ] **Move Quality Files**
  - [ ] Move: `storage/code/quality/code_deduplicator.ex` → `storage/quality/code_deduplicator.ex`
  - [ ] Move: `storage/code/quality/refactoring_agent.ex` → `storage/quality/refactoring_agent.ex`
  - [ ] Move: `storage/code/quality/template_validator.ex` → `storage/quality/template_validator.ex`

- [ ] **Move Storage/Analyzer/Generator Files**
  - [ ] Move: `storage/code/analyzers/` → `code_analysis/storage/` (or delete if duplicate)
  - [ ] Move: `storage/code/generators/` → `code_generation/storage/` (or delete if duplicate)

- [ ] **Handle Remaining Files**
  - [ ] Move/delete: `storage/code/session/code_session.ex`
  - [ ] Move/delete: `storage/code/visualizers/flow_visualizer.ex` → `visualization/` (NEW)

- [ ] **Delete storage/code/ Directory**
  - [ ] Verify all files have been moved
  - [ ] Delete: `storage/code/` directory
  - [ ] Update imports everywhere

---

## Phase 5: Quality Operations Consolidation (MEDIUM)

- [ ] **Consolidate Under code_analysis/**
  - [ ] Create: `code_analysis/ast/` subdirectory
  - [ ] Move: `code_quality/ast_quality_analyzer.ex` → `code_analysis/ast/ast_quality_analyzer.ex`
  - [ ] Move: `code_quality/ast_security_scanner.ex` → `code_analysis/ast/ast_security_scanner.ex`
  - [ ] Rename: To follow ScannerType behavior contract
  - [ ] Delete: `code_quality/` directory
  - [ ] Delete: `quality.ex` from root (already moved in Phase 2)

- [ ] **Update Configuration**
  - [ ] Add new scanners to config.exs scanner_types:
    - [ ] performance_scanner
    - [ ] complexity_scanner
  - [ ] Verify all AST scanners registered in config

- [ ] **Testing**
  - [ ] Test ScanOrchestrator with all scanners
  - [ ] Run: `mix test code_analysis`
  - [ ] Verify quality scan operations work

---

## Phase 6: Engine Organization (LOW PRIORITY)

- [ ] **Consolidate Engine Namespace**
  - [ ] Document: Which engines are Rust NIF wrappers
  - [ ] Document: Which engines are pure Elixir
  - [ ] Plan: Clearer naming (e.g., code_analysis_engine vs CodeAnalysis.Engine)

- [ ] **Fix Duplicate Directories**
  - [ ] Delete: `generator_engine/` (utilities moved to code_generation)
  - [ ] Delete: `engine.ex` if not used (28 LOC at root)
  - [ ] Consolidate: `engines/` to only have Rust NIF engine wrappers

- [ ] **Documentation**
  - [ ] Document engine purpose and usage
  - [ ] Add navigation guide for which engine to use

---

## Phase 7: Execution Subsystem Clarification (LOW PRIORITY)

- [ ] **Create Strategy Organization**
  - [ ] Create: `execution/strategies/` subdirectory
  - [ ] Create: `execution/strategies/strategy_type.ex` (behavior contract)
  - [ ] Create: `execution/strategies/implementations/` for implementations

- [ ] **Organize Strategies**
  - [ ] Move: Task DAG executor into strategies
  - [ ] Move: SPARC executor into strategies
  - [ ] Move: Methodology executor into strategies
  - [ ] Keep: Other execution subsystems (planning, autonomy, todos) as-is

- [ ] **Documentation**
  - [ ] Document execution strategy pattern
  - [ ] Clarify relationship between ExecutionOrchestrator and strategies
  - [ ] Document feedback analyzer placement (analysis vs execution)

---

## Verification and Testing

- [ ] **Full Test Suite**
  - [ ] Run: `mix test` (all tests pass)
  - [ ] Run: `mix test.ci` (with coverage)
  - [ ] Run: `mix format` (code formatting)
  - [ ] Run: `mix credo --strict` (linting)

- [ ] **Import Verification**
  - [ ] Run: `mix compile --all-warnings` (find unused imports)
  - [ ] Scan: Logs for deprecation warnings
  - [ ] Check: All modules still exported from behavior contracts

- [ ] **Documentation Updates**
  - [ ] Update: CLAUDE.md with new structure
  - [ ] Update: SYSTEM_STATE_* docs if needed
  - [ ] Add: Navigation guide for new organization
  - [ ] Update: Any generated documentation

- [ ] **Git Verification**
  - [ ] Check: All moved files are properly tracked
  - [ ] Check: No broken symlinks
  - [ ] Verify: .gitignore is correct

---

## Final Cleanup

- [ ] **Review**
  - [ ] Walk through new structure
  - [ ] Verify consistency with orchestration pattern
  - [ ] Check: "Everything for feature X is in directory X"

- [ ] **Documentation**
  - [ ] Update: Main README if it documents structure
  - [ ] Create: CODEBASE_STRUCTURE.md if helpful
  - [ ] Add: Examples of how to add new analyzers/generators/etc.

- [ ] **Commit**
  - [ ] Create: Comprehensive git commit
  - [ ] Note: Files moved (with --follow for git blame)
  - [ ] Reference: This checklist as completion record

---

## Summary of Changes

- **Total files moved:** ~40 files
- **Duplicate files deleted:** ~50 files
- **New subsystems created:** 4-5 (patterns, training, runtime, monitoring, visualization)
- **Root-level reduction:** 5,961 LOC → ~500 LOC (92% reduction)
- **Total files after:** ~430 files (from 450)
- **Total directories after:** ~65 directories (from 86)

