# Archived Rust Code

This directory contains deprecated/old Rust code that is no longer actively used.

## Archived (2025-10-09) - Initial Cleanup

### Legacy Servers & Tools
- **codeintelligence_server** - Old monolithic code intelligence server
- **consolidated_detector** - Old consolidated framework detector
- **mozilla-code-analysis** - Mozilla's rust-code-analysis integration
- **unified_server** - Old unified server attempt
- **singularity_app** - Old embedded Elixir app (duplicate)
- **src/** - Old shared source code

## Archived (2025-10-09) - Duplicate Removal

### Duplicate Modules (Now in rust/ or rust/service/)

**analysis_engine**
- Duplicate of: `rust/code_analysis/` + `rust/service/code_service/`
- Reason: Heavy code analysis should be local, not global
- Use instead: Local rust/code_analysis/ for fast analysis

**dependency_parser**
- Duplicate of: `rust/parser/formats/dependency/`
- Reason: Dependency parsing is per-project, not global
- Use instead: Local rust/parser/ for parsing

**intelligent_namer**
- Duplicate of: `rust/architecture/naming_*` + `rust/service/architecture_service/`
- Reason: Naming is context-specific, should be local with AI via NATS
- Use instead: Local rust/architecture/ for naming, call AI via NATS if needed

**semantic_embedding_engine**
- Duplicate of: `rust/code_analysis/embeddings/` + `rust/service/embedding_service/`
- Reason: Embeddings should be generated locally, AI models via NATS
- Use instead: Local rust/code_analysis/embeddings/, call AI via NATS if needed

**tech_detection_engine**
- Duplicate of: `rust/architecture/technology_detection/` + `rust/service/framework_service/`
- Reason: Framework detection is per-project, AI fallback via NATS
- Use instead: Local rust/architecture/technology_detection/, call AI via NATS if needed

## Active Code (in rust_global/)

- **package_registry** - External package analysis (npm, cargo, hex, pypi)
  - This is the ONLY truly global module
  - Indexes external packages for all Singularity instances

## Why These Were Duplicates

Global should be **lightweight aggregated intelligence**, not heavy processing:
- ✅ Global: External package metadata, learned patterns, quality benchmarks
- ❌ Global: Per-project code analysis, parsing, embeddings

Architecture:
- **Local (rust/)**: Heavy processing, fast local analysis
- **Services (rust/service/)**: AI coordination via NATS
- **Global (rust_global/)**: Only external package registry

## Restoration

To restore archived code:
```bash
mv rust_global/_archive/module_name rust_global/
```

## Permanent Deletion

After confirming code is no longer needed (6+ months):
```bash
rm -rf rust_global/_archive/module_name
```
