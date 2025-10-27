# Schema/Table Name Alignment Summary

This document summarizes the schema/migration mismatches fixed by migration `20250101000014_align_schema_table_names.exs`.

## Overview

Three categories of schema/table name mismatches were identified and fixed using **Option A (Rename Tables)** for all cases, since all schemas are actively used in production code.

---

## 1. Detection Events → Codebase Snapshots

### Mismatch
- **Migration Created**: `detection_events` table (in `20240101000004_create_code_analysis_tables.exs`)
- **Schema Expects**: `codebase_snapshots` table
- **Schema File**: `/home/mhugo/code/singularity/singularity/lib/singularity/schemas/codebase_snapshot.ex`

### Active Usage
- `Singularity.CodebaseSnapshots` - Main persistence module
- `Singularity.Detection.TechnologyDetector` - Stores technology detection results
- Referenced in multiple detection workflows

### Resolution: Rename Table
```sql
ALTER TABLE detection_events RENAME TO codebase_snapshots;
```

### Schema Changes
**Old Schema (detection_events):**
```elixir
field :event_type, :string       # Generic event type
field :detector, :string          # Detector name
field :confidence, :float         # Detection confidence
field :data, :map                 # Generic data blob
```

**New Schema (codebase_snapshots):**
```elixir
field :codebase_id, :string              # Identifies codebase
field :snapshot_id, :integer             # Snapshot version
field :summary, :map                     # Detection summary
field :detected_technologies, [:string]  # List of technologies
field :features, :map                    # Extracted features
```

### Data Migration
- Old fields (`event_type`, `detector`, `confidence`) migrated to `metadata` JSONB
- New fields added with defaults
- Indexes recreated for new schema

---

## 2. Git Sessions → Git Agent Sessions (+ New Tables)

### Mismatch
- **Migration Created**: `git_sessions` and `git_commits` tables (in `20240101000005_create_git_and_cache_tables.exs`)
- **Schema Expects**: `git_agent_sessions`, `git_pending_merges`, `git_merge_history` tables
- **Schema File**: `/home/mhugo/code/singularity/singularity/lib/singularity/git/git_state_store.ex`

### Active Usage
- `Singularity.Git.GitStateStore` - Git coordination persistence
- Used for multi-agent git workflow coordination
- Embedded schemas: `GitStateStore.PendingMerge`, `GitStateStore.MergeHistory`

### Resolution: Rename + Create New Tables

#### Table Renames
```sql
ALTER TABLE git_sessions RENAME TO git_agent_sessions;
ALTER TABLE git_agent_sessions RENAME COLUMN branch_name TO branch;
```

#### New Tables Created
1. **git_pending_merges** - Track pending PRs waiting for merge
2. **git_merge_history** - Audit log of merge attempts

#### Schema Changes
**Old Schema (git_sessions):**
```elixir
field :session_type, :string   # Type of session
field :branch_name, :string    # Branch name
field :base_branch, :string    # Base branch
field :status, :string         # Session status
field :metadata, :map          # Generic metadata
```

**New Schema (git_agent_sessions):**
```elixir
field :agent_id, :string         # Unique agent identifier
field :branch, :string           # Branch name (renamed)
field :workspace_path, :string   # Local workspace path
field :correlation_id, :string   # For distributed tracing
field :status, :string           # Session status
field :meta, :map                # Renamed from metadata
```

### Data Migration
- Old fields migrated to `meta` JSONB
- `branch_name` → `branch`
- `metadata` → `meta`
- `git_commits` table dropped (superseded by `git_merge_history`)

---

## 3. Technology Knowledge → Technology Templates + Technology Patterns

### Mismatch
- **Migration Created**: `technology_knowledge` unified table (in `20240101000003_create_knowledge_tables.exs`)
- **Schema Expects**: TWO separate tables: `technology_templates` AND `technology_patterns`
- **Schema Files**:
  - `/home/mhugo/code/singularity/singularity/lib/singularity/schemas/technology_template.ex`
  - `/home/mhugo/code/singularity/singularity/lib/singularity/schemas/technology_pattern.ex`

### Active Usage
- `Singularity.TechnologyTemplateStore` - Template storage and retrieval
- `Singularity.Detection.TechnologyDetector` - Uses patterns for detection
- `Singularity.Detection.TechnologyTemplateLoader` - Loads from JSON
- Multiple other modules for quality, methodology, training

### Resolution: Split Table

#### Original Unified Table
**technology_knowledge** - Mixed templates and patterns in one table

#### Split Into Two Tables

**1. technology_templates** - Technology scaffolding templates
```elixir
schema "technology_templates" do
  field :identifier, :string       # Unique template ID
  field :category, :string         # Template category
  field :version, :string          # Template version
  field :source, :string           # Source (filesystem/seed/user)
  field :template, :map            # Template JSONB data
  field :metadata, :map            # Additional metadata
  field :checksum, :string         # SHA256 checksum
  timestamps()
end
```

**2. technology_patterns** - Technology detection patterns
```elixir
schema "technology_patterns" do
  field :technology_name, :string
  field :technology_type, :string
  field :version_pattern, :string
  field :file_patterns, {:array, :string}
  field :directory_patterns, {:array, :string}
  field :config_files, {:array, :string}
  field :build_command, :string
  field :dev_command, :string
  field :install_command, :string
  field :test_command, :string
  field :output_directory, :string
  field :confidence_weight, :float
  field :detection_count, :integer
  field :success_rate, :float
  field :last_detected_at, :utc_datetime
  field :extended_metadata, :map
  timestamps()
end
```

### Data Migration Strategy

**To technology_templates:**
- Records with `template` field → `technology_templates`
- `identifier` = `technology || '/' || name`
- Template data stored in JSONB `template` field

**To technology_patterns:**
- All records → `technology_patterns` (detection patterns)
- Metadata stored in `extended_metadata` JSONB
- New fields added for detection tracking

**After Migration:**
- `technology_knowledge` table dropped (data preserved in both new tables)

---

## Migration Safety Features

### Idempotency
All operations wrapped in `DO $$ BEGIN ... END $$;` blocks with existence checks:
```sql
IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'old_name')
   AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'new_name') THEN
  -- perform migration
END IF;
```

### Data Preservation
- All old data migrated to new schema
- Old columns preserved in JSONB `metadata`/`meta` fields
- No data loss during migration

### Rollback Support
Complete `down()` migration that:
- Restores original table names
- Restores original schema structure
- Migrates data back from new schema
- Recreates original indexes

### Error Handling
- Each section independent (uses separate `DO` blocks)
- Failures don't cascade
- `RAISE NOTICE` for successful operations
- `RAISE WARNING` for skipped operations

---

## Testing the Migration

### Before Running Migration
```bash
# Check current tables
psql singularity_dev -c "\dt"

# Check for existing data
psql singularity_dev -c "SELECT COUNT(*) FROM detection_events;"
psql singularity_dev -c "SELECT COUNT(*) FROM git_sessions;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_knowledge;"
```

### Run Migration
```bash
cd singularity
mix ecto.migrate
```

### Verify Migration
```bash
# Check renamed tables exist
psql singularity_dev -c "\dt codebase_snapshots"
psql singularity_dev -c "\dt git_agent_sessions"
psql singularity_dev -c "\dt git_pending_merges"
psql singularity_dev -c "\dt git_merge_history"
psql singularity_dev -c "\dt technology_templates"
psql singularity_dev -c "\dt technology_patterns"

# Verify data migrated
psql singularity_dev -c "SELECT COUNT(*) FROM codebase_snapshots;"
psql singularity_dev -c "SELECT COUNT(*) FROM git_agent_sessions;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_templates;"
psql singularity_dev -c "SELECT COUNT(*) FROM technology_patterns;"

# Check indexes
psql singularity_dev -c "\di codebase_snapshots*"
psql singularity_dev -c "\di git_agent_sessions*"
psql singularity_dev -c "\di technology_*"
```

### Rollback (if needed)
```bash
mix ecto.rollback --step 1
```

---

## Impact Assessment

### Application Code
**No code changes required** - All schema files already reference correct table names.

### Affected Modules
All modules using these schemas will work correctly after migration:

**Codebase Snapshots:**
- `Singularity.CodebaseSnapshots`
- `Singularity.Detection.TechnologyDetector`

**Git Agent Sessions:**
- `Singularity.Git.GitStateStore`
- All git coordination workflows

**Technology Templates/Patterns:**
- `Singularity.TechnologyTemplateStore`
- `Singularity.Detection.TechnologyDetector`
- `Singularity.Detection.TechnologyTemplateLoader`
- `Singularity.Quality.MethodologyExecutor`
- `Singularity.Code.Training.DomainVocabularyTrainer`
- And others

### Database Operations
- **Downtime**: Minimal (seconds for table renames)
- **Lock Duration**: Brief table-level locks during ALTER TABLE
- **Data Size**: No impact (structure changes only)

---

## Production Deployment Checklist

- [ ] Backup database before migration
- [ ] Test migration on staging environment
- [ ] Verify all indexes recreated correctly
- [ ] Check application logs for Ecto errors
- [ ] Monitor query performance (new indexes)
- [ ] Verify data integrity (row counts match)
- [ ] Test rollback procedure on staging
- [ ] Update any external tools/scripts referencing old table names

---

## Notes

### Why Option A (Rename Tables) Was Chosen

All three schema categories are **actively used in production code**:

1. **CodebaseSnapshot** - Core technology detection system
2. **GitStateStore** - Multi-agent git coordination
3. **TechnologyTemplate/Pattern** - Template storage and detection patterns

Renaming tables preserves existing data and maintains compatibility with existing code without requiring application changes.

### Alternative Considered (Option B)

Updating schemas to match migration table names would have required:
- Changing schema `@table_name` in 3+ files
- Updating all code references
- Modifying queries and function calls
- Higher risk of breaking changes

Option A was safer and more maintainable.

---

## Related Files

- **Migration**: `/home/mhugo/code/singularity/singularity/priv/repo/migrations/20250101000014_align_schema_table_names.exs`
- **Original Migrations**:
  - `20240101000003_create_knowledge_tables.exs`
  - `20240101000004_create_code_analysis_tables.exs`
  - `20240101000005_create_git_and_cache_tables.exs`
- **Schemas**:
  - `lib/singularity/schemas/codebase_snapshot.ex`
  - `lib/singularity/git/git_state_store.ex`
  - `lib/singularity/schemas/technology_template.ex`
  - `lib/singularity/schemas/technology_pattern.ex`

---

Generated: 2025-10-05
Migration Version: 20250101000014
