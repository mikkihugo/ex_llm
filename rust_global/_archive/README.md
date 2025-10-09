# Archived Rust Code

This directory contains deprecated/old Rust code that is no longer actively used.

## Archived (2025-10-09)

### Legacy Servers & Tools
- **codeintelligence_server** - Old monolithic code intelligence server
  - Superseded by: Specialized service modules
  - Reason: Monolithic design, hard to maintain

- **consolidated_detector** - Old consolidated framework detector
  - Superseded by: `tech_detection_engine`
  - Reason: Better separation of concerns

- **mozilla-code-analysis** - Mozilla's rust-code-analysis integration
  - Superseded by: Custom analysis tools
  - Reason: External dependency, limited customization

- **unified_server** - Old unified server attempt
  - Superseded by: Service-oriented architecture in `rust/service/`
  - Reason: Monolithic, hard to scale

- **singularity_app** - Old embedded Elixir app (???)
  - Superseded by: Main `singularity_app` at root
  - Reason: Wrong location, duplicate

- **src/** - Old shared source code
  - Superseded by: Proper crate organization
  - Reason: Unclear structure, poor organization

## Active Code (in rust_global/)

- **package_analysis_suite** - External package analysis (npm, cargo, hex)
- **semantic_embedding_engine** - Embedding generation
- **tech_detection_engine** - Framework/technology detection
- **analysis_engine** - Core analysis logic
- **dependency_parser** - Dependency parsing
- **intelligent_namer** - Intelligent naming suggestions

## Why Archive Instead of Delete?

- Preserve historical code for reference
- May contain useful algorithms to extract later
- Easier to restore if needed
- Git history preservation

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
