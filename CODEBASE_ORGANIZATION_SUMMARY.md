# Singularity Codebase Organization - Quick Summary

## Key Statistics
- **450 Elixir files** across 86 directories
- **24 root-level modules** (5,961 LOC)
- **8 excellent orchestration systems** following consistent patterns
- **~50 duplicate files** across multiple locations
- **Improvement potential:** 20% file reduction + 30% navigation improvement

---

## What's Working Well (Copy This Pattern!)

### Config-Driven Orchestration Pattern
Eight systems correctly implement this pattern:
1. Pattern Detection - PatternDetector orchestrates 3 detectors
2. Code Analysis - AnalysisOrchestrator orchestrates 4 analyzers
3. Code Scanning - ScanOrchestrator orchestrates 2 scanners
4. Code Generation - GenerationOrchestrator orchestrates 4 generators
5. Extraction - DetectionOrchestrator orchestrates 3 extractors
6. Search - SearchOrchestrator orchestrates 4 searchers
7. Jobs - JobOrchestrator orchestrates 16+ workers
8. Execution - ExecutionOrchestrator orchestrates execution strategies

**Pattern:**
- Behavior contract (e.g., `AnalyzerType`)
- Config-driven orchestrator
- Implementations grouped in subdirectory
- Utilities co-located
- All in single domain directory

**Examples:** `code_analysis/`, `code_generation/`, `search/`, `jobs/`, `architecture_engine/`

---

## Critical Problems to Fix

### Problem 1: Duplicate Analyzers (URGENT)
```
Singularity.Architecture.Analyzers.MicroserviceAnalyzer (primary)
Singularity.Code.Analyzers.MicroserviceAnalyzer (duplicate!)
Singularity.CodeQuality.* (related)
Singularity.Refactoring.Analyzer (another copy?)
Singularity.Execution.Feedback.Analyzer (yet another?)
```
**Fix:** Keep only architecture_engine version, delete duplicates

### Problem 2: Duplicate Generators (URGENT)
```
code_generation/generators/ (primary - in orchestrator)
storage/code/generators/ (duplicate - not in orchestrator)
Root-level code_generator.ex (wrapper - 598 LOC)
Root-level embedding_engine.ex (related - 308 LOC)
engines/generator_engine.ex vs generator_engine/ (directory duplication!)
```
**Fix:** Consolidate into code_generation/, remove duplicates

### Problem 3: Kitchen Sink `storage/code/` Directory
31 files mixing 8 different concerns:
- analyzers, generators, patterns, quality, session, storage, training, visualizers
**Fix:** Decompose into: analysis, generation, patterns/, training/, storage/

### Problem 4: Root-Level Module Chaos
24 files at root with no clear organization
- 1,190 LOC in runner.ex
- 734 LOC in code_analyzer.ex
- 598 LOC in code_generator.ex
- 5,961 LOC total
**Fix:** Move to proper subsystems (execution/, code_analysis/, code_generation/)

### Problem 5: Quality Scattered Across 3 Namespaces
```
quality.ex (root)
code_quality/ast_quality_analyzer.ex
code_analysis/scanners/quality_scanner.ex
```
**Fix:** Consolidate under code_analysis/ using orchestrator pattern

### Problem 6: Multiple Engine Directories
```
engines/generator_engine.ex
generator_engine/ (directory!)
engines/ (9 other engines)
architecture_engine/ (well-organized)
```
**Fix:** Clarify engine namespace, remove duplicates

---

## Detailed Fixes (Priority Order)

### PHASE 1: Duplicate Elimination (2-3 days, HIGH VALUE)
1. **Analyzer deduplication** (~20 files)
   - Keep: `architecture_engine/analyzers/` (used by orchestrator)
   - Delete: `storage/code/analyzers/`, `code_quality/`, `refactoring/analyzer.ex`
   - Merge: `execution/feedback/analyzer.ex` logic into architecture version

2. **Generator deduplication** (~15 files)
   - Keep: `code_generation/generators/` (used by orchestrator)
   - Delete: `storage/code/generators/`, `generator_engine/` directory
   - Consolidate: `code_generator.ex` → delete (use orchestrator)
   - Consolidate: `embedding_engine.ex` → move to embedding/ or code_generation/

### PHASE 2: Root-Level Cleanup (1-2 days, MEDIUM VALUE)
Move 20 root files to proper subsystems:
- runner.ex → execution/runner.ex
- code_analyzer.ex → code_analysis/
- code_generator.ex → code_generation/ (delete - use orchestrator)
- language_detection.ex → detection/
- embedding_*.ex → embedding/
- quality.ex → code_analysis/quality_coordinator.ex
- lua_runner.ex → runtime/ (NEW)
- central_cloud.ex → central_cloud/
- etc.

Keep at root: application.ex, application_supervisor.ex, repo.ex, telemetry.ex, tools.ex, control.ex

### PHASE 3: Kitchen Sink Decomposition (2-3 days, HIGH VALUE)
Split `storage/code/` (31 files) into:
1. **patterns/** (NEW) - pattern mining, consolidation, indexing
2. **training/** (NEW) - ML model training (code models, T5, etc.)
3. **storage/code/** - only code store, index, registry
4. **storage/quality/** - deduplicator, refactoring agent, template validator
5. **code_analysis/storage/** - move analyzers
6. **code_generation/storage/** - move generators

### PHASE 4: Quality Consolidation (1-2 days, MEDIUM VALUE)
```
code_analysis/ (SINGLE NAMESPACE)
├── scanner_type.ex
├── scan_orchestrator.ex
└── scanners/
    ├── quality_scanner.ex
    ├── security_scanner.ex
    ├── performance_scanner.ex
    └── complexity_scanner.ex

code_analysis/ast/
├── ast_quality_analyzer.ex (from code_quality/)
├── ast_security_analyzer.ex
└── ...

REMOVE:
- code_quality/ (entire dir)
- quality.ex (at root)
```

### PHASE 5: Engine Organization (1 day, LOW VALUE)
```
engines/ - central hub for Rust NIF wrappers
├── code_engine.ex
├── code_generation_engine.ex
├── quality_engine.ex
├── parser_engine.ex
└── ...

REMOVE:
- Duplicate generator_engine/ directory
- Update imports to use consistent naming
```

### PHASE 6: Execution Subsystem (1-2 days, LOW VALUE)
Clarify execution strategy organization with new `execution/strategies/` subdirectory

---

## Expected Outcomes

### Before
```
450 files | 86 dirs | 24 root modules | 5,961 root LOC
~50 duplicate files | 8 unclear namespaces | 31-file kitchen sink
```

### After
```
~430 files | ~65 dirs | 6 root modules | ~500 root LOC
0 duplicates | 1 namespace per concern | Proper subsystems
```

### Impact
- 20 files consolidated/deleted (4% reduction)
- 5,461 LOC moved from root to proper homes (92% reduction in root)
- ~50 duplicate files eliminated
- Clear navigation: "To work with X, go to X/"
- Consistent pattern across all systems
- Single source of truth for each capability

---

## Navigation Rule (After Reorganization)

**For ANY functionality, follow this pattern:**

1. **Behavior Contract** - Defines the interface
   ```
   code_analysis/scanner_type.ex
   code_generation/generator_type.ex
   jobs/job_type.ex
   ```

2. **Orchestrator** - Public API that runs all/selected implementations
   ```
   code_analysis/scan_orchestrator.ex
   code_generation/generation_orchestrator.ex
   jobs/job_orchestrator.ex
   ```

3. **Implementations** - Specific implementations
   ```
   code_analysis/scanners/quality_scanner.ex
   code_generation/generators/rag_generator.ex
   jobs/metrics_aggregation_worker.ex
   ```

4. **Utilities** - Supporting modules (storage, caching, etc.)
   ```
   code_analysis/postgres_vector_search.ex
   code_generation/llm_service.ex
   jobs/job_registry.ex
   ```

**Rule:** Everything for a feature lives in ONE directory!

---

## File Locations

The complete analysis is in: `/CODEBASE_ORGANIZATION_ANALYSIS.md`

It contains:
- Detailed statistics and directory breakdowns
- Complete list of well-organized systems (examples to follow)
- Detailed problems with code snippets
- Step-by-step reorganization recommendations
- Implementation roadmap with phases
- Expected outcomes and metrics

