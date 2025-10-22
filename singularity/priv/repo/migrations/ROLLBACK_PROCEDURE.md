# Schema Alignment Migration - Rollback Procedure

This document provides detailed rollback procedures for migration `20250101000014_align_schema_table_names.exs`.

## Quick Rollback

```bash
cd singularity
mix ecto.rollback --step 1
```

This executes the `down()` function which reverses all changes.

---

## What the Rollback Does

### 1. Restores detection_events from codebase_snapshots

**Operations:**
- Renames `codebase_snapshots` back to `detection_events`
- Restores old columns: `event_type`, `detector`, `confidence`, `data`
- Migrates data from new schema back to old schema
- Drops new columns: `codebase_id`, `snapshot_id`, `summary`, `detected_technologies`, `features`
- Recreates original indexes

**Data Migration:**
```sql
-- New → Old field mapping
metadata->>'event_type' → event_type
metadata->>'detector' → detector
metadata->>'confidence' → confidence
metadata → data
```

### 2. Restores git_sessions from git_agent_sessions

**Operations:**
- Renames `git_agent_sessions` back to `git_sessions`
- Restores old columns: `session_type`, `base_branch`, `metadata`
- Renames `branch` back to `branch_name`
- Migrates data from new schema back to old schema
- Drops new columns: `agent_id`, `workspace_path`, `correlation_id`, `meta`
- Drops new tables: `git_pending_merges`, `git_merge_history`
- Recreates original indexes

**Data Migration:**
```sql
-- New → Old field mapping
meta->>'session_type' → session_type
meta->>'base_branch' → base_branch
meta → metadata
branch → branch_name
```

### 3. Restores technology_knowledge from split tables

**Operations:**
- Recreates unified `technology_knowledge` table
- Merges data from `technology_templates` and `technology_patterns`
- Drops split tables: `technology_templates`, `technology_patterns`
- Recreates original indexes

**Data Migration:**
```sql
-- technology_patterns → technology_knowledge
technology_name → technology
technology_type → category
technology_name → name
extended_metadata->>'description' → description
extended_metadata → metadata
```

---

## Manual Rollback (if mix ecto.rollback fails)

### Prerequisites
```bash
# Connect to database
psql singularity_dev

# Check migration status
SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 5;
```

### Step 1: Restore detection_events

```sql
-- Drop new indexes
DROP INDEX IF EXISTS codebase_snapshots_codebase_id_index;
DROP INDEX IF EXISTS codebase_snapshots_codebase_id_snapshot_id_index;
DROP INDEX IF EXISTS codebase_snapshots_inserted_at_index;

-- Rename table
ALTER TABLE codebase_snapshots RENAME TO detection_events;

-- Restore old columns
ALTER TABLE detection_events
  ADD COLUMN event_type VARCHAR(255),
  ADD COLUMN detector VARCHAR(255),
  ADD COLUMN confidence FLOAT,
  ADD COLUMN data JSONB;

-- Migrate data back
UPDATE detection_events
SET
  event_type = COALESCE(metadata->>'event_type', 'unknown'),
  detector = COALESCE(metadata->>'detector', 'unknown'),
  confidence = COALESCE((metadata->>'confidence')::float, 1.0),
  data = metadata
WHERE event_type IS NULL;

-- Set NOT NULL constraints
UPDATE detection_events SET event_type = 'unknown' WHERE event_type IS NULL;
UPDATE detection_events SET detector = 'unknown' WHERE detector IS NULL;
UPDATE detection_events SET confidence = 1.0 WHERE confidence IS NULL;
UPDATE detection_events SET data = '{}'::jsonb WHERE data IS NULL;

ALTER TABLE detection_events
  ALTER COLUMN event_type SET NOT NULL,
  ALTER COLUMN detector SET NOT NULL,
  ALTER COLUMN confidence SET NOT NULL,
  ALTER COLUMN data SET NOT NULL;

-- Drop new columns
ALTER TABLE detection_events
  DROP COLUMN codebase_id,
  DROP COLUMN snapshot_id,
  DROP COLUMN summary,
  DROP COLUMN detected_technologies,
  DROP COLUMN features;

-- Recreate indexes
CREATE INDEX detection_events_event_type_index ON detection_events(event_type);
CREATE INDEX detection_events_detector_index ON detection_events(detector);
CREATE INDEX detection_events_inserted_at_index ON detection_events(inserted_at);
```

### Step 2: Restore git_sessions

```sql
-- Drop new indexes
DROP INDEX IF EXISTS git_agent_sessions_agent_id_index;
DROP INDEX IF EXISTS git_agent_sessions_status_index;
DROP INDEX IF EXISTS git_agent_sessions_correlation_id_index;

-- Rename table
ALTER TABLE git_agent_sessions RENAME TO git_sessions;

-- Restore old columns
ALTER TABLE git_sessions
  ADD COLUMN session_type VARCHAR(255),
  ADD COLUMN base_branch VARCHAR(255),
  ADD COLUMN metadata JSONB;

-- Migrate data back
UPDATE git_sessions
SET
  session_type = COALESCE(meta->>'session_type', 'unknown'),
  base_branch = meta->>'base_branch',
  metadata = meta
WHERE session_type IS NULL;

-- Set NOT NULL constraints
UPDATE git_sessions SET session_type = 'unknown' WHERE session_type IS NULL;
UPDATE git_sessions SET status = 'unknown' WHERE status IS NULL;
UPDATE git_sessions SET metadata = '{}'::jsonb WHERE metadata IS NULL;

ALTER TABLE git_sessions
  ALTER COLUMN session_type SET NOT NULL,
  ALTER COLUMN status SET NOT NULL;

-- Rename branch back to branch_name
ALTER TABLE git_sessions RENAME COLUMN branch TO branch_name;

-- Restore NOT NULL on branch_name
UPDATE git_sessions SET branch_name = 'unknown' WHERE branch_name IS NULL;
ALTER TABLE git_sessions ALTER COLUMN branch_name SET NOT NULL;

-- Drop new columns
ALTER TABLE git_sessions
  DROP COLUMN agent_id,
  DROP COLUMN workspace_path,
  DROP COLUMN correlation_id,
  DROP COLUMN meta;

-- Recreate indexes
CREATE INDEX git_sessions_session_type_index ON git_sessions(session_type);
CREATE INDEX git_sessions_status_index ON git_sessions(status);

-- Drop new tables
DROP TABLE IF EXISTS git_merge_history;
DROP TABLE IF EXISTS git_pending_merges;
```

### Step 3: Restore technology_knowledge

```sql
-- Recreate unified table
CREATE TABLE technology_knowledge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  technology VARCHAR(255) NOT NULL,
  category VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  template TEXT,
  examples TEXT[] DEFAULT ARRAY[]::text[],
  best_practices TEXT,
  antipatterns TEXT[] DEFAULT ARRAY[]::text[],
  metadata JSONB DEFAULT '{}'::jsonb,
  embedding vector(768),
  inserted_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

-- Merge data from patterns
INSERT INTO technology_knowledge (
  technology, category, name, description, template, examples,
  best_practices, antipatterns, metadata, inserted_at, updated_at
)
SELECT
  technology_name AS technology,
  technology_type AS category,
  technology_name AS name,
  extended_metadata->>'description' AS description,
  NULL AS template,
  ARRAY[]::text[] AS examples,
  NULL AS best_practices,
  ARRAY[]::text[] AS antipatterns,
  extended_metadata AS metadata,
  created_at,
  updated_at
FROM technology_patterns;

-- Recreate indexes
CREATE INDEX technology_knowledge_technology_category_index
  ON technology_knowledge(technology, category);
CREATE INDEX technology_knowledge_name_index ON technology_knowledge(name);

-- Drop split tables
DROP TABLE technology_templates;
DROP TABLE technology_patterns;
```

### Step 4: Remove migration record

```sql
DELETE FROM schema_migrations WHERE version = '20250101000014';
```

---

## Verification After Rollback

### Check Tables Restored
```sql
\dt detection_events
\dt git_sessions
\dt technology_knowledge

-- Should NOT exist:
\dt codebase_snapshots
\dt git_agent_sessions
\dt git_pending_merges
\dt git_merge_history
\dt technology_templates
\dt technology_patterns
```

### Verify Data Integrity
```sql
-- Check row counts match
SELECT 'detection_events' AS table_name, COUNT(*) FROM detection_events
UNION ALL
SELECT 'git_sessions', COUNT(*) FROM git_sessions
UNION ALL
SELECT 'technology_knowledge', COUNT(*) FROM technology_knowledge;

-- Check for NULL values in required fields
SELECT 'detection_events - NULL event_type' AS issue, COUNT(*)
FROM detection_events WHERE event_type IS NULL
UNION ALL
SELECT 'detection_events - NULL detector', COUNT(*)
FROM detection_events WHERE detector IS NULL
UNION ALL
SELECT 'git_sessions - NULL session_type', COUNT(*)
FROM git_sessions WHERE session_type IS NULL;
```

### Check Indexes
```sql
\di detection_events*
\di git_sessions*
\di technology_knowledge*
```

Expected indexes:
- `detection_events_event_type_index`
- `detection_events_detector_index`
- `detection_events_inserted_at_index`
- `git_sessions_session_type_index`
- `git_sessions_status_index`
- `technology_knowledge_technology_category_index`
- `technology_knowledge_name_index`

---

## Troubleshooting Rollback Issues

### Issue: Rollback fails with "table does not exist"

**Cause:** Migration already partially rolled back or never fully ran.

**Solution:**
```sql
-- Check what tables exist
\dt

-- Manually run only the sections that need rollback
-- (See manual rollback steps above)
```

### Issue: Data loss after rollback

**Cause:** Data was only in new columns that got dropped.

**Solution:**
If you have a backup:
```bash
pg_restore -d singularity_dev /path/to/backup.dump
```

If no backup but migration just ran:
```bash
# Re-run migration forward
mix ecto.migrate

# Data should be back in new tables
```

### Issue: Foreign key constraint violations

**Cause:** `git_commits` table still exists with FK to old `git_sessions`.

**Solution:**
```sql
-- Drop the FK constraint first
ALTER TABLE git_commits DROP CONSTRAINT IF EXISTS git_commits_session_id_fkey;

-- Then continue rollback
```

### Issue: Application errors after rollback

**Cause:** Code expects new schema, but tables rolled back to old schema.

**Solution:**
You must update schema files to match old table names:

```elixir
# lib/singularity/schemas/codebase_snapshot.ex
schema "detection_events" do  # Change from codebase_snapshots
  field :event_type, :string
  field :detector, :string
  # ... old fields
end

# lib/singularity/git/git_state_store.ex
schema "git_sessions" do  # Change from git_agent_sessions
  field :session_type, :string
  # ... old fields
end
```

**Better solution:** Don't rollback - fix migration issues forward.

---

## When to Rollback vs. Fix Forward

### Rollback if:
- Migration ran within last few hours
- No production data created with new schema
- Application not yet deployed with new schema
- Simple schema issue that's easier to fix and re-migrate

### Fix Forward if:
- Migration ran days/weeks ago
- Production data exists in new schema
- Application already deployed and running
- Rolling back would cause more disruption than fixing

---

## Emergency Contact / Escalation

If rollback fails catastrophically:

1. **Stop all writes to database**
   ```bash
   # Stop application
   ./stop-all.sh
   ```

2. **Restore from backup**
   ```bash
   # Drop corrupted database
   dropdb singularity_dev

   # Restore from latest backup
   createdb singularity_dev
   pg_restore -d singularity_dev /path/to/backup.dump
   ```

3. **Check migration status**
   ```sql
   SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 10;
   ```

4. **Re-run migrations from clean state**
   ```bash
   mix ecto.migrate
   ```

---

## Post-Rollback Actions

After successful rollback:

- [ ] Verify application starts without errors
- [ ] Run test suite: `mix test`
- [ ] Check logs for Ecto query errors
- [ ] Verify affected features work (detection, git coordination, templates)
- [ ] Update documentation if schema changes are permanent
- [ ] Plan forward migration fix if needed

---

## Related Documents

- **Migration File**: `20250101000014_align_schema_table_names.exs`
- **Summary**: `SCHEMA_ALIGNMENT_SUMMARY.md`
- **Original Migrations**:
  - `20240101000003_create_knowledge_tables.exs`
  - `20240101000004_create_code_analysis_tables.exs`
  - `20240101000005_create_git_and_cache_tables.exs`

---

Generated: 2025-10-05
For Migration: 20250101000014
