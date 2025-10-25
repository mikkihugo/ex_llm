# pg_cron JSONB Import/Export Reference

Complete guide to what pg_cron **can** and **cannot** do with JSONB data.

## Quick Answer

**Can pg_cron import/export JSONB?**

- ✅ **YES** - From server files or remote URLs
- ❌ **NO** - From client stdin or complex transformations
- ⚠️ **PARTIAL** - Git operations need additional scripts

## What Works ✅

### 1. Import from Server File
```sql
CREATE OR REPLACE PROCEDURE import_jsonb_from_file()
LANGUAGE SQL
AS $$
  COPY my_table (json_column)
  FROM '/var/lib/postgresql/data.jsonl'
  WITH (FORMAT 'json');
$$;

-- Schedule with pg_cron
SELECT cron.schedule('import-jsonb', '0 2 * * *', 'CALL import_jsonb_from_file();');
```

**Works because:** File is on server, absolute path, simple COPY command

### 2. Import from URL
```sql
CREATE OR REPLACE PROCEDURE import_from_remote_api()
LANGUAGE SQL
AS $$
  COPY templates (content)
  FROM PROGRAM 'curl -s https://api.example.com/templates.jsonl'
  WITH (FORMAT 'json');
$$;

SELECT cron.schedule('fetch-api', '0 2 * * *', 'CALL import_from_remote_api();');
```

**Works because:** `curl` is available, outputs to stdout, simple command

### 3. Import from GitHub
```sql
CREATE OR REPLACE PROCEDURE import_from_github()
LANGUAGE SQL
AS $$
  COPY templates (content)
  FROM PROGRAM 'curl -s https://raw.githubusercontent.com/owner/repo/main/templates.jsonl'
  WITH (FORMAT 'json');
$$;

SELECT cron.schedule('sync-github', '0 2 * * 0', 'CALL import_from_github();');
```

**Works because:** Raw GitHub URLs output JSON directly

### 4. Export to Server File
```sql
CREATE OR REPLACE PROCEDURE export_jsonb_to_file()
LANGUAGE SQL
AS $$
  COPY (
    SELECT row_to_json(t) FROM templates t
  )
  TO '/var/lib/postgresql/templates_export.jsonl';
$$;

SELECT cron.schedule('export-jsonb', '0 22 * * *', 'CALL export_jsonb_to_file();');
```

**Works because:** Writes to server file directly, no client needed

### 5. Export with Compression
```sql
CREATE OR REPLACE PROCEDURE export_compressed()
LANGUAGE SQL
AS $$
  COPY (
    SELECT row_to_json(t) FROM templates t
  )
  TO PROGRAM 'gzip > /var/lib/postgresql/templates.jsonl.gz';
$$;

SELECT cron.schedule('export-gz', '0 22 * * *', 'CALL export_compressed();');
```

**Works because:** `gzip` command is simple, takes data from stdin

### 6. Validate & Import
```sql
CREATE OR REPLACE PROCEDURE import_and_validate()
LANGUAGE SQL
AS $$
  -- Import to temp table
  CREATE TEMP TABLE temp_json (data jsonb);

  COPY temp_json FROM '/var/lib/postgresql/templates.jsonl';

  -- Validate and copy to production
  INSERT INTO templates (name, content, valid)
  SELECT
    data->>'name',
    data->'content'::jsonb,
    jsonb_typeof(data) = 'object' AS valid
  FROM temp_json
  WHERE jsonb_typeof(data) = 'object';

  DROP TABLE temp_json;
$$;

SELECT cron.schedule('import-validate', '0 2 * * *', 'CALL import_and_validate();');
```

---

## What Doesn't Work ❌

### 1. ❌ Interactive stdin (No Client Connection)
```sql
-- This WON'T work in pg_cron
COPY templates FROM STDIN;  -- Where's the input coming from?

-- Use file instead
COPY templates FROM '/path/to/file.jsonl';
```

**Why:** pg_cron runs on server with no client connection

### 2. ❌ Complex Shell Pipelines
```sql
-- ❌ Won't work - pipes not supported
COPY data FROM PROGRAM 'cat file.json | jq .name | gzip';

-- ✅ Use simpler approach
COPY data FROM PROGRAM 'curl https://example.com/data.json';
```

**Why:** PROGRAM takes single command, no pipes/redirects

### 3. ❌ Relative Paths
```sql
-- ❌ Won't work
COPY templates FROM './templates.jsonl';  -- Relative to what?

-- ✅ Use absolute paths
COPY templates FROM '/var/lib/postgresql/templates.jsonl';
```

**Why:** Server can't know current working directory in cron context

### 4. ❌ Git Operations
```sql
-- ❌ Won't work - git needs multiple commands
COPY data FROM PROGRAM 'git clone && git add && git commit && git push';

-- ✅ Keep this in Oban + Elixir
def sync_git do
  File.read!("templates.jsonl")
  |> import_to_db()
  Git.commit_and_push()
end
```

**Why:** Git needs multi-step process, authentication, error handling

### 5. ❌ JSON Transformation
```sql
-- ❌ Can't transform in PROGRAM
COPY data FROM PROGRAM 'transform_json.sh';

-- ✅ Validate/transform in pure SQL
INSERT INTO templates (content)
SELECT jsonb_set(data, '{validated}', 'true')
FROM imported_raw_data;
```

**Why:** No easy way to execute arbitrary scripts

---

## Permission Requirements

### For COPY FROM FILE
```sql
-- Grant needed role
GRANT pg_read_server_files TO singularity_user;

-- Or use superuser
ALTER USER singularity_user WITH SUPERUSER;
```

### For COPY FROM PROGRAM
```sql
-- Grant needed role
GRANT pg_execute_server_program TO singularity_user;

-- Or use superuser
ALTER USER singularity_user WITH SUPERUSER;
```

### Check Current Permissions
```sql
SELECT datname, usename, usesuper FROM pg_user WHERE usename = 'singularity_user';
SELECT * FROM pg_roles WHERE rolname = 'singularity_user';
```

---

## Real-World Example: Living Knowledge Base

### Option 1: Pure pg_cron (Simple)
```sql
-- Weekly sync templates from GitHub
CREATE OR REPLACE PROCEDURE sync_templates_weekly()
LANGUAGE SQL
AS $$
  DELETE FROM templates WHERE source = 'github';

  COPY templates (name, content, source, synced_at)
  FROM PROGRAM E'curl -s https://raw.githubusercontent.com/user/singularity/main/templates_data/all.jsonl'
  WITH (FORMAT 'json');

  UPDATE templates SET synced_at = now() WHERE source = 'github';

  INSERT INTO audit_log (task, status, rows)
  SELECT 'template_sync', 'success', COUNT(*) FROM templates WHERE source = 'github';
$$;

SELECT cron.schedule('weekly-template-sync', '0 2 * * 0', 'CALL sync_templates_weekly();');
```

**Pros:** Simple, pure SQL, fast
**Cons:** No validation, no error handling, no Git push

### Option 2: Hybrid (pg_cron + Oban)
```elixir
# Oban worker - handles Git complexity
defmodule Singularity.Jobs.TemplatesGitSyncWorker do
  def perform(_job) do
    # Fetch from Git
    templates = fetch_from_github()

    # Validate (Elixir) - can't do in SQL
    validated = validate_json_schema(templates)

    # Import via stored procedure (pg_cron will use same table)
    Repo.query!("CALL import_validated_templates($1)", [validated])

    # Commit changes
    Git.commit_and_push("Auto-sync templates")

    :ok
  end
end
```

**Pros:** Full validation, Git integration, complex logic
**Cons:** Needs Oban overhead

---

## File Paths on Different Systems

### Linux (Standard)
```
/var/lib/postgresql/
/var/lib/postgresql/data/
```

### macOS (Homebrew)
```
/usr/local/var/postgres/
/usr/local/var/postgres/data/
```

### Docker
```
/var/lib/postgresql/data/
```

### Check Your Path
```sql
SHOW data_directory;
```

---

## Tested Combinations

| Scenario | Works | Method |
|----------|-------|--------|
| Import JSON from GitHub | ✅ | `curl` + `FROM PROGRAM` |
| Import JSON from API | ✅ | `curl` + `FROM PROGRAM` |
| Import from local file | ✅ | `FROM '/path/file'` |
| Export as JSONL | ✅ | `TO '/path/file'` |
| Export + compress | ✅ | `TO PROGRAM 'gzip'` |
| Validate JSON schema | ⚠️ | Pure SQL only, limited |
| Transform JSON | ⚠️ | Only simple `jsonb_*` functions |
| Git commit/push | ❌ | Use Oban worker instead |
| Database replication | ❌ | Use trigger + WAL2JSON |

---

## Troubleshooting

### "Permission denied" error
```sql
-- Check role has permissions
SELECT usesuper FROM pg_user WHERE usename = current_user;

-- Grant if needed
ALTER USER singularity_user WITH SUPERUSER;
-- OR
GRANT pg_read_server_files TO singularity_user;
```

### "File does not exist" error
```sql
-- Verify file exists on server
-- SSH into server and check:
ls -la /var/lib/postgresql/templates.jsonl

-- Check PostgreSQL can read it
SELECT pg_read_file('/var/lib/postgresql/templates.jsonl');
```

### "PROGRAM returned exit code 1" error
```sql
-- Test the command directly on server
curl -s https://example.com/file.jsonl | head -1

-- Check that command runs without errors
COPY test (data) FROM PROGRAM 'echo "{\"test\": true}"' WITH (FORMAT 'json');
```

### "No such table" in procedure
```sql
-- Procedures must reference existing tables
-- Create table first
CREATE TABLE IF NOT EXISTS templates (
  id SERIAL,
  name TEXT,
  content JSONB
);

-- Then create procedure
CREATE OR REPLACE PROCEDURE import_templates() ...
```

---

## Performance Notes

- **COPY is fast** - Optimized for bulk data
- **Parallel import** - Can import multiple files with separate procedures
- **Compression** - `gzip`/`bzip2` reduce network bandwidth
- **Indexes** - Disable during import, enable after

```sql
-- Disable indexes during large import
ALTER TABLE templates DISABLE TRIGGER ALL;

COPY templates FROM '/path/file.jsonl';

ALTER TABLE templates ENABLE TRIGGER ALL;
REINDEX TABLE templates;
```

---

## Best Practices

1. **Use absolute paths** - Never relative paths
2. **Test command manually** - Run on server first
3. **Monitor imports** - Log to audit table
4. **Handle errors** - Use ON CONFLICT for duplicates
5. **Keep exports simple** - Just dump to file, version in Git manually
6. **Use Oban for** - Validation, transformation, Git integration
7. **Use pg_cron for** - Simple COPY, backups, statistics

---

## Recommendation for Your System

**Use pg_cron for:**
- Weekly export of templates to file
- Daily backups of JSONB tables
- Importing from stable URLs (GitHub raw content)

**Keep in Oban for:**
- JSON schema validation
- Complex Git workflows (commit, push)
- Embedding generation (ML)
- Data transformation

This gives you **best of both worlds**:
- Fast, reliable scheduled imports/exports via pg_cron
- Complex logic, validation, Git integration via Oban
