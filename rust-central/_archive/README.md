# Archived Rust Engines

This directory contains deprecated/old Rust engines that are no longer actively used.

## Archived Engines:

- **analysis_suite** - Old analysis tools, superseded by specialized engines
  - Replaced by: architecture_engine, code_engine, quality_engine
  - Reason: Monolithic, hard to maintain
  - Archived: 2025-10-09

## Why Archive Instead of Delete?

- Preserve historical code for reference
- May contain useful algorithms to extract later
- Easier to restore if needed
- Git history preservation

## Restoration

To restore an archived engine:
```bash
mv rust-central/_archive/engine_name rust-central/
```
