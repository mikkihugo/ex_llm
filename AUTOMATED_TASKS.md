# Automated Tasks (via Oban Cron)

**No more manual tasks!** All recurring maintenance is now automated via Oban job scheduler.

## Overview

Previously, you had to manually run Mix tasks like:
```bash
mix templates.sync --force
mix analyze.cache clear
mix registry.sync
mix templates.embed --missing
```

Now these **run automatically on a schedule** via Oban:

| Task | Schedule | Frequency | Previously |
|------|----------|-----------|-----------|
| **Database Backup (Hourly)** | `0 * * * *` | Every hour | Manual script |
| **Database Backup (Daily)** | `0 1 * * *` | Every day at 1:00 AM | Manual script |
| **Template Sync** | `0 2 * * *` | Every day at 2:00 AM | `mix templates.sync --force` |
| **Cache Cleanup** | `0 3 * * *` | Every day at 3:00 AM | `mix analyze.cache clear` |
| **Registry Sync** | `0 4 * * *` | Every day at 4:00 AM | `mix registry.sync` |
| **Template Embed** | `0 5 * * 0` | Sundays at 5:00 AM | `mix templates.embed --missing` |

## Architecture

```
Oban Cron Plugin (singularity/config/config.exs)
    ↓ Schedule every hour/day/week
Oban.Worker (singularity/lib/singularity/jobs/*.ex)
    ↓ Execute
Core Module (existing Singularity modules)
    ↓ Perform actual work
Result → PostgreSQL + Logs
```

## Job Workers

### 1. BackupWorker
**File:** `singularity/lib/singularity/database/backup_worker.ex`

Backs up `singularity`, `centralcloud`, `genesis_db` databases.

- **Hourly:** Keeps last 6 backups (~last 6 hours)
- **Daily:** Keeps last 7 backups (~last 7 days)
- **Storage:** `.db-backup/{hourly,daily}/backup_YYYYMMDD_HHMMSS/{db}.sql`

### 2. TemplateSyncWorker
**File:** `singularity/lib/singularity/jobs/template_sync_worker.ex`

Syncs templates from `templates_data/` to PostgreSQL.

Replaces: `mix templates.sync --force`

### 3. TemplateEmbedWorker
**File:** `singularity/lib/singularity/jobs/template_embed_worker.ex`

Regenerates Qodo-Embed-1 embeddings for all templates.

Replaces: `mix templates.embed --missing`

**Run:** Sundays at 5:00 AM (after template sync)

### 4. CacheClearWorker
**File:** `singularity/lib/singularity/jobs/cache_clear_worker.ex`

Clears stale CodeAnalysis.Analyzer cache entries.

Replaces: `mix analyze.cache clear`

### 5. RegistrySyncWorker
**File:** `singularity/lib/singularity/jobs/registry_sync_worker.ex`

Runs all code analyzers and persists snapshot to registry.

Replaces: `mix registry.sync`

Analyzes:
- Architecture patterns
- Quality metrics
- Dependencies
- Performance trends

## Monitoring Jobs

### Check Job Status

```elixir
# In iex -S mix
alias Singularity.Repo

# See last 10 successful jobs
Oban.select_jobs(Repo,
  state: "success",
  order_by: {:desc, :completed_at},
  limit: 10
)

# See jobs by worker
Oban.select_jobs(Repo,
  where: [worker: "Singularity.Jobs.TemplateSyncWorker"],
  order_by: {:desc, :completed_at},
  limit: 5
)

# See failed jobs
Oban.select_jobs(Repo,
  state: "failed",
  order_by: {:desc, :attempted_at}
)
```

### View Logs

```bash
tail -f logs/singularity.log | grep -E "Syncing templates|Clearing cache|Registry sync|backup"
```

### Check Next Scheduled Run

```elixir
# In iex -S mix
Oban.select_jobs(Repo,
  state: "scheduled",
  order_by: {:asc, :scheduled_at}
) |> Enum.map(&{&1.worker, &1.scheduled_at})
```

## Running Manually (if needed)

You can still trigger jobs manually from IEx:

```elixir
# Manual template sync
%{} |> Singularity.Jobs.TemplateSyncWorker.new() |> Oban.insert()

# Manual cache clear
%{} |> Singularity.Jobs.CacheClearWorker.new() |> Oban.insert()

# Manual registry sync
%{} |> Singularity.Jobs.RegistrySyncWorker.new() |> Oban.insert()

# Manual database backup
%{"type" => "hourly"} |> Singularity.Database.BackupWorker.new() |> Oban.insert()
```

## Scheduling Changes

To modify schedules, edit `singularity/config/config.exs`:

```elixir
config :oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Change from "0 2 * * *" to "0 22 * * *" for 10 PM instead
       {"0 22 * * *", Singularity.Jobs.TemplateSyncWorker},
       # ... rest of crontab
     ]}
  ]
```

Then restart Singularity for changes to take effect.

### Cron Schedule Format

```
minute   hour   day_of_month   month   day_of_week
  0       *          *          *           *        ← Every hour
  0       1          *          *           *        ← Daily at 1:00 AM
  0       2          *          *           1        ← Mondays at 2:00 AM
  */30    *          *          *           *        ← Every 30 minutes
  */15    9-17       *          *        1-5        ← Every 15 mins, 9 AM-5 PM, weekdays
```

## One-Time Setup Tasks (not scheduled)

These run once on fresh database - they're NOT scheduled:

```bash
# Only run on first setup:
cd singularity
mix ecto.create           # Create database
mix ecto.migrate          # Run migrations
mix knowledge.migrate     # Load templates
mix rag.setup            # Initialize RAG system
mix graph.populate       # Optimize graph queries
```

These are one-time setup tasks because they:
- Populate initial data from Git
- Build base indexes and embeddings
- Set up system state

No need to run them again unless resetting the database.

## Troubleshooting

### Job not running
1. Check Oban is alive: `Oban.alive?()`
2. Check job state: `Oban.select_jobs(Repo, state: "discarded")`
3. Check PostgreSQL: `pg_isready`

### Job failed
1. Check error: `job.errors` in IEx
2. Check logs: `tail -f logs/singularity.log`
3. Check module exists: `Code.ensure_loaded(Singularity.Jobs.TemplateSyncWorker)`

### Job running too slowly
1. Check database load: `SELECT count(*) FROM oban_jobs WHERE state='executing'`
2. Check queue concurrency in config
3. Increase `maintenance: [concurrency: 5]` if needed

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Manual runs** | Every day | Never |
| **Accidental skips** | Common | Impossible |
| **Monitoring** | Terminal logs | Oban dashboard + Repo queries |
| **Scheduling** | External cron | Built-in Oban |
| **Failures** | Lost data | Persisted in `oban_jobs` table with retry logic |
| **Complex schedules** | Hard to setup | Simple CRON format |

**Result:** All maintenance tasks run automatically. No more forgetting to run tasks!
