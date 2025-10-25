# All Automated Tasks (Zero Manual Intervention)

**Complete automation** - No more manual tasks at all! Every task runs automatically, including smart re-runs when needed.

## Schedule Summary

| Category | Task | Schedule | Frequency | Purpose |
|----------|------|----------|-----------|---------|
| **Backup** | Hourly DB Backup | `0 * * * *` | Every hour | Keep 6 backups (last 6 hours) |
| **Backup** | Daily DB Backup | `0 1 * * *` | Daily 1 AM | Keep 7 backups (last 7 days) |
| **Setup** | Knowledge Migration | Startup | Once ever | Load JSON templates to DB |
| **Setup** | Templates Data Load | Startup | Once ever | Load templates_data/ to JSONB |
| **Setup** | Planning Seed | Startup | Once ever | Seed work plan roadmap |
| **Setup** | Graph Populate | Startup + Weekly | On startup + Sundays 7 AM | Optimize dependency queries |
| **Setup** | Code Ingest | Startup + Weekly | On startup + Sundays 6 AM | Parse codebase, generate embeddings |
| **Setup** | RAG Setup | Startup | Once ever | Full RAG system initialization |
| **Maintenance** | Template Sync | Daily 2 AM | Every day | Sync templates_data/ changes |
| **Maintenance** | Cache Cleanup | Daily 3 AM | Every day | Clear stale analysis cache |
| **Maintenance** | Registry Sync | Daily 4 AM | Every day | Run analyzers, store snapshots |
| **Maintenance** | Template Embed | Weekly | Sundays 5 AM | Regenerate embeddings |

## Task Types

### 1. One-Time Setup (Run on Startup)

These run **once on application startup**, then never again (unless DB reset):

- **Knowledge Migration** - Loads JSON templates from `templates_data/**/*.json`
- **Templates Data Load** - Syncs `templates_data/` to PostgreSQL JSONB
- **Planning Seed** - Seeds work plan themes, epics, capabilities
- **RAG Setup** - Orchestrates full RAG initialization

```elixir
# Startup flow (automatically runs in order):
1. Knowledge Migration
2. Templates Data Load
3. Planning Seed
4. Code Ingest
5. Graph Populate
6. RAG Setup
```

### 2. Smart Re-Runnable Setup (Run on Startup + Periodic)

These run **on startup** AND **periodically when needed**:

- **Code Ingest** - Startup + Weekly (Sundays 6 AM)
  - Re-parses codebase for semantic search
  - Detects code changes automatically
  - Useful when your project evolves

- **Graph Populate** - Startup + Weekly (Sundays 7 AM)
  - Re-optimizes dependency indexes
  - Necessary after major refactors
  - Improves query performance 5-100x

### 3. Daily Maintenance (Always Recurring)

These run **daily on schedule**:

- **Template Sync** - Daily 2 AM - Sync `templates_data/` changes to database
- **Cache Cleanup** - Daily 3 AM - Clear stale CodeAnalysis cache
- **Registry Sync** - Daily 4 AM - Run analyzers, store architecture snapshot

### 4. Weekly Maintenance (Periodically)

These run **weekly on schedule**:

- **Template Embed** - Sundays 5 AM - Regenerate embeddings

### 5. Backup (Continuous)

- **Hourly Backup** - Every hour - Keeps 6 (last 6 hours)
- **Daily Backup** - Daily 1 AM - Keeps 7 (last 7 days)

## Architecture: Startup Flow

```
Application Starts
    ↓
Oban Started
    ↓
SetupBootstrap GenServer Starts
    ↓ (schedules all one-time jobs with unique constraints)
Job Queue:
    1. Knowledge Migration (priority 100) - Run once
    2. Templates Data Load (priority 95) - Run once
    3. Planning Seed (priority 90) - Run once
    4. Code Ingest (priority 85) - Run once + weekly
    5. Graph Populate (priority 80) - Run once + weekly
    6. RAG Setup (priority 70) - Run once
    ↓
Oban Cron Plugin
    ↓ (continuous scheduling)
Daily tasks:
    - 2:00 AM: Template Sync
    - 3:00 AM: Cache Cleanup
    - 4:00 AM: Registry Sync
Weekly tasks:
    - Sundays 5:00 AM: Template Embed
    - Sundays 6:00 AM: Code Ingest
    - Sundays 7:00 AM: Graph Populate
Hourly/Daily:
    - Every hour: Database Backup (hourly)
    - Daily 1:00 AM: Database Backup (daily)
```

## Running Tasks Manually (Optional)

You can trigger any task manually from IEx if needed:

### One-Time Setup Tasks
```elixir
# Force re-run setup tasks (normally run on startup)
%{} |> Singularity.Jobs.KnowledgeMigrateWorker.new() |> Oban.insert()
%{} |> Singularity.Jobs.TemplatesDataLoadWorker.new() |> Oban.insert()
%{} |> Singularity.Jobs.CodeIngestWorker.new() |> Oban.insert()
%{} |> Singularity.Jobs.GraphPopulateWorker.new() |> Oban.insert()
```

### Daily Maintenance Tasks
```elixir
%{} |> Singularity.Jobs.TemplateSyncWorker.new() |> Oban.insert()
%{} |> Singularity.Jobs.CacheClearWorker.new() |> Oban.insert()
%{} |> Singularity.Jobs.RegistrySyncWorker.new() |> Oban.insert()
```

### Database Backups
```elixir
# Hourly backup
%{"type" => "hourly"} |> Singularity.Database.BackupWorker.new() |> Oban.insert()

# Daily backup
%{"type" => "daily"} |> Singularity.Database.BackupWorker.new() |> Oban.insert()
```

## Monitoring All Jobs

### View Successful Jobs
```elixir
Oban.select_jobs(Singularity.Repo, state: "success", order_by: {:desc, :completed_at}, limit: 20)
```

### View Failed Jobs
```elixir
Oban.select_jobs(Singularity.Repo, state: "failed")
```

### View Scheduled Jobs (Future)
```elixir
Oban.select_jobs(Singularity.Repo, state: "scheduled", order_by: {:asc, :scheduled_at})
```

### View Jobs by Worker
```elixir
Oban.select_jobs(Singularity.Repo,
  where: [worker: "Singularity.Jobs.TemplateSyncWorker"],
  order_by: {:desc, :completed_at},
  limit: 5
)
```

### Check System Health
```elixir
# Is Oban running?
Oban.alive?()

# How many jobs are executing right now?
Oban.select_jobs(Singularity.Repo, state: "executing") |> length()

# Job queue stats
Singularity.Repo.aggregate(:oban_jobs, :count)
```

## Logs & Debugging

### View recent task logs
```bash
tail -f logs/singularity.log | grep -E "Knowledge Migration|Template Sync|Registry Sync|Code Ingest|backup"
```

### Search for specific task
```bash
grep "Template Sync" logs/singularity.log
grep "✅" logs/singularity.log  # Show successes
grep "❌" logs/singularity.log  # Show failures
```

## Customizing Schedules

All schedules are in `singularity/config/config.exs` under `Oban.Plugins.Cron`:

```elixir
crontab: [
  # Change from daily 2 AM to daily 10 PM:
  {"0 22 * * *", Singularity.Jobs.TemplateSyncWorker},

  # Change from weekly Sunday to daily:
  {"0 6 * * *", Singularity.Jobs.CodeIngestWorker},  # Daily at 6 AM

  # Disable by commenting out:
  # {"0 3 * * *", Singularity.Jobs.CacheClearWorker},
]
```

Then restart Singularity:
```bash
./stop-all.sh
./start-all.sh
```

## Cron Format

```
minute   hour   day_of_month   month   day_of_week
  0       *          *          *           *        ← Every hour
  0       1          *          *           *        ← Daily at 1:00 AM
  0       2          *          *           1        ← Mondays at 2:00 AM
  */30    *          *          *           *        ← Every 30 minutes
  0       6          *          *        0-5        ← Weekdays at 6 AM (Mon-Fri)
  0      22          1          *           *        ← First day of month at 10 PM
```

## Troubleshooting

### Task didn't run
1. Check Oban is alive: `Oban.alive?()`
2. Check logs: `tail -f logs/singularity.log`
3. Check job state: `Oban.select_jobs(Singularity.Repo, state: "failed")`

### Task is slow
1. Check queue concurrency: `config :oban, queues: [maintenance: [concurrency: 3]]`
2. Increase if needed: `maintenance: [concurrency: 10]`

### Task keeps failing
1. Check error details in IEx: `job.errors |> inspect()`
2. Check PostgreSQL: `pg_isready`
3. Check module exists: `Code.ensure_loaded(Singularity.Jobs.TemplateSyncWorker)`

## Summary

| Before | After |
|--------|-------|
| Manual `mix` tasks daily | Automatic via Oban |
| Risk of forgetting tasks | Impossible to forget |
| No visibility into runs | Full audit trail in DB |
| External cron needed | Built-in scheduling |
| One-time tasks hardcoded | Smart re-runnable setup |
| Manual debugging | Oban dashboard + Repo queries |

**Result:** Complete automation. System maintains itself. Zero manual intervention needed.
