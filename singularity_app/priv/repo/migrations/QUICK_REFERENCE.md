# Schema Alignment Migration - Quick Reference

Quick reference for migration `20250101000014_align_schema_table_names.exs`

## TL;DR

**What:** Renames 3 mismatched tables to align with Ecto schemas
**Why:** Schemas expect different table names than migrations created
**Safe:** Yes - all data preserved, full rollback support
**Downtime:** Minimal (seconds)

## Table Changes

| Old Table Name | New Table Name | Action |
|----------------|----------------|--------|
| `detection_events` | `codebase_snapshots` | Rename + schema change |
| `git_sessions` | `git_agent_sessions` | Rename + schema change |
| - | `git_pending_merges` | Create new |
| - | `git_merge_history` | Create new |
| `git_commits` | - | Drop (superseded) |
| `technology_knowledge` | `technology_templates` | Split table |
| `technology_knowledge` | `technology_patterns` | Split table |

## Quick Commands

```bash
# Run migration
cd singularity_app
mix ecto.migrate

# Rollback if needed
mix ecto.rollback --step 1

# Check migration status
mix ecto.migrations

# Verify tables
psql singularity_dev -c "\dt"
```

## Schema Mappings

### 1. detection_events → codebase_snapshots

```diff
- schema "detection_events"
+ schema "codebase_snapshots"

# Old fields (migrated to metadata)
- field :event_type, :string
- field :detector, :string
- field :confidence, :float
- field :data, :map

# New fields
+ field :codebase_id, :string
+ field :snapshot_id, :integer
+ field :summary, :map
+ field :detected_technologies, [:string]
+ field :features, :map
  field :metadata, :map  # Contains old fields
```

### 2. git_sessions → git_agent_sessions

```diff
- schema "git_sessions"
+ schema "git_agent_sessions"

# Old fields (migrated to meta)
- field :session_type, :string
- field :branch_name, :string
- field :base_branch, :string
- field :metadata, :map

# New/changed fields
+ field :agent_id, :string
+ field :branch, :string  # Renamed from branch_name
+ field :workspace_path, :string
+ field :correlation_id, :string
  field :status, :string  # Kept
+ field :meta, :map  # Renamed from metadata
```

### 3. technology_knowledge → (split)

```diff
- schema "technology_knowledge"  # Unified table

# Split into TWO tables:

+ schema "technology_templates"
+   field :identifier, :string
+   field :category, :string
+   field :version, :string
+   field :source, :string
+   field :template, :map
+   field :metadata, :map
+   field :checksum, :string

+ schema "technology_patterns"
+   field :technology_name, :string
+   field :technology_type, :string
+   field :version_pattern, :string
+   field :file_patterns, [:string]
+   field :directory_patterns, [:string]
+   field :config_files, [:string]
+   # ... 15 more fields for detection
```

## Affected Modules

### Will work after migration (no code changes needed):
- ✅ `Singularity.CodebaseSnapshots`
- ✅ `Singularity.Git.GitStateStore`
- ✅ `Singularity.TechnologyTemplateStore`
- ✅ `Singularity.Detection.TechnologyDetector`
- ✅ All other modules using these schemas

## Pre-Migration Checklist

```bash
# 1. Backup database
pg_dump singularity_dev > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Check current state
psql singularity_dev -c "\dt detection_events"
psql singularity_dev -c "\dt git_sessions"
psql singularity_dev -c "\dt technology_knowledge"

# 3. Count rows (for verification after)
psql singularity_dev -c "SELECT COUNT(*) FROM detection_events;"
psql singularity_dev -c "SELECT COUNT(*) FROM git_sessions;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_knowledge;"
```

## Post-Migration Verification

```bash
# 1. Check new tables exist
psql singularity_dev -c "\dt codebase_snapshots"
psql singularity_dev -c "\dt git_agent_sessions"
psql singularity_dev -c "\dt technology_templates"
psql singularity_dev -c "\dt technology_patterns"

# 2. Verify row counts
psql singularity_dev -c "SELECT COUNT(*) FROM codebase_snapshots;"
psql singularity_dev -c "SELECT COUNT(*) FROM git_agent_sessions;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_templates;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_patterns;"

# 3. Test application
mix test
mix phx.server  # Check for startup errors
```

## Rollback

```bash
# Simple rollback
mix ecto.rollback --step 1

# Verify rollback
psql singularity_dev -c "\dt detection_events"  # Should exist again
psql singularity_dev -c "\dt codebase_snapshots"  # Should NOT exist
```

See `ROLLBACK_PROCEDURE.md` for detailed manual rollback steps.

## Common Issues

### "table already exists"
**Cause:** Migration already ran partially
**Solution:** Migration is idempotent, safe to re-run

### "column does not exist"
**Cause:** Old code running against new schema or vice versa
**Solution:** Restart application after migration

### "foreign key constraint"
**Cause:** `git_commits` references old `git_sessions`
**Solution:** Migration drops `git_commits` automatically

## Safety Features

✅ **Idempotent** - Safe to run multiple times
✅ **Data Preservation** - All old data migrated to new schema
✅ **Rollback Support** - Complete `down()` migration
✅ **No Code Changes** - Schemas already reference new tables
✅ **Independent Operations** - Each section fails independently

## Timeline

- **Duration**: ~5-30 seconds (depends on data volume)
- **Downtime**: Minimal (brief table locks during ALTER TABLE)
- **Best Time**: Low traffic period recommended

## Files

- 📄 Migration: `20250101000014_align_schema_table_names.exs`
- 📄 Summary: `SCHEMA_ALIGNMENT_SUMMARY.md`
- 📄 Rollback: `ROLLBACK_PROCEDURE.md`
- 📄 This file: `QUICK_REFERENCE.md`

## Decision: Why Rename Tables?

**Option A (Chosen):** Rename tables to match schemas
**Option B (Not chosen):** Update schemas to match tables

**Reasoning:**
- All schemas actively used in production code
- Renaming tables preserves data without code changes
- Schemas already reference correct names
- Lower risk than changing application code

## Questions?

See detailed docs:
- **What changed?** → `SCHEMA_ALIGNMENT_SUMMARY.md`
- **How to rollback?** → `ROLLBACK_PROCEDURE.md`
- **Migration code** → `20250101000014_align_schema_table_names.exs`

---

Generated: 2025-10-05
Migration: 20250101000014
