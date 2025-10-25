# Oban Database Backups

Automated database backups via Oban job scheduler.

## Overview

- **Hourly backups**: Every hour at :00 (keeps 6 backups = last 6 hours)
- **Daily backups**: Every day at 1:00 AM UTC (keeps 7 backups = last 7 days)
- **Databases**: singularity, centralcloud, genesis_db
- **Format**: SQL dumps (portable, human-readable)
- **Storage**: `.db-backup/{hourly,daily}/backup_YYYYMMDD_HHMMSS/{db}.sql`

## How It Works

1. **Oban Cron Plugin** - Schedules jobs based on crontab in `singularity/config/config.exs`
2. **BackupWorker** - Elixir worker that executes `pg_dump` commands
3. **Automatic cleanup** - Deletes old backups after retention period

## Configuration

Backups are scheduled in `singularity/config/config.exs`:

```elixir
# Database backup: hourly (keep 6)
{"0 * * * *", Singularity.Database.BackupWorker, args: %{"type" => "hourly"}},
# Database backup: daily at 1:00 AM (keep 7)
{"0 1 * * *", Singularity.Database.BackupWorker, args: %{"type" => "daily"}}
```

## Starting Backups

### Automatic (Recommended)

Backups start automatically when Singularity application boots:

```bash
./start-all.sh       # Starts Singularity, Oban kicks in with schedule
cd singularity
mix phx.server       # Start just Singularity
```

### Manual

Trigger a backup job from IEx:

```elixir
# In iex -S mix
alias Singularity.Database.BackupWorker

# Hourly backup
%{"type" => "hourly"}
|> BackupWorker.new()
|> Oban.insert()

# Daily backup
%{"type" => "daily"}
|> BackupWorker.new()
|> Oban.insert()
```

## Monitoring Backups

### Check backup files

```bash
ls -lah .db-backup/

# Hourly backups
ls -lah .db-backup/hourly/

# Daily backups
ls -lah .db-backup/daily/

# Check specific backup
ls -lah .db-backup/hourly/backup_20251025_053945/
```

### View Oban job status

In IEx:

```elixir
# List all jobs
Oban.select_jobs(Singularity.Repo, state: "success")

# List backup jobs specifically
Oban.select_jobs(Singularity.Repo,
  where: [worker: "Singularity.Database.BackupWorker"],
  state: "success",
  order_by: {:desc, :scheduled_at},
  limit: 10
)

# See failed jobs
Oban.select_jobs(Singularity.Repo,
  where: [worker: "Singularity.Database.BackupWorker"],
  state: "failed"
)
```

### View logs

```bash
tail -f logs/singularity.log | grep -i backup
```

## Backup Size Management

Estimate storage for 3 databases × ~100MB each:

- **Hourly** (6 backups): 6 × 300MB = ~1.8GB
- **Daily** (7 backups): 7 × 300MB = ~2.1GB
- **Total**: ~4GB (adjust based on actual database sizes)

Check actual size:

```bash
du -sh .db-backup/
du -sh .db-backup/hourly/
du -sh .db-backup/daily/
```

## Restore from Backup

### Option 1: Using psql directly

```bash
# Restore a specific database from a backup
psql -U mhugo singularity < .db-backup/hourly/backup_20251025_053945/singularity.sql
psql -U mhugo centralcloud < .db-backup/hourly/backup_20251025_053945/centralcloud.sql
psql -U mhugo genesis_db < .db-backup/hourly/backup_20251025_053945/genesis_db.sql
```

### Option 2: Automated restore (recommended)

Create a restore worker if needed:

```elixir
# In IEx
%{"backup_dir" => ".db-backup/hourly/backup_20251025_053945"}
|> Singularity.Database.RestoreWorker.new()
|> Oban.insert()
```

## Troubleshooting

### Backup job not running

1. **Check Oban is running**:
   ```elixir
   Oban.alive?()  # Should return true
   ```

2. **Check Oban supervisor**:
   ```elixir
   Singularity.Application  # Check supervision tree
   ```

3. **Check PostgreSQL connection**:
   ```bash
   pg_isready -h localhost -p 5432
   ```

### Backup job failed

1. **Check job logs**:
   ```elixir
   job = Oban.select_jobs(Singularity.Repo,
     where: [worker: "Singularity.Database.BackupWorker"],
     state: "failed",
     limit: 1
   ) |> List.first()

   IO.inspect(job.errors)
   ```

2. **Check pg_dump availability**:
   ```bash
   which pg_dump
   pg_dump --version
   ```

3. **Check database permissions**:
   ```bash
   psql -U mhugo -l  # List databases
   ```

### Backup is slow

- Large databases may take time to dump
- Check system resources: `top`, `htop`, `vmstat`
- Consider compressing backups (modify `BackupWorker` to pipe through `gzip`)

## Advanced: Customize Backup Retention

Edit `singularity/lib/singularity/database/backup_worker.ex`:

```elixir
defp cleanup_old_backups(backup_type) do
  # ...
  keep_count = if backup_type == "hourly", do: 24, else: 30  # Change here
  # ...
end
```

Then recompile:
```bash
mix compile
```

## Advanced: Compress Backups

Modify BackupWorker to compress with gzip:

```elixir
defp backup_database(db_name, backup_dir) do
  # ... existing code ...
  case System.cmd("pg_dump", [...]) do
    {output, 0} ->
      # Compress to .sql.gz
      backup_file = Path.join(backup_dir, "#{db_name}.sql.gz")
      File.write!(backup_file, :zlib.gzip(output))
      # ... rest of code ...
```

## Best Practices

1. **Test restores periodically** - Verify backups are valid and restorable
2. **Monitor disk space** - Set up alerts if `.db-backup/` grows beyond threshold
3. **Archive old backups** - Move backups older than 30 days to external storage
4. **Export to external storage** - Backup `.db-backup/` directory regularly
5. **Document restore procedures** - Keep restore instructions up to date

## Architecture

```
Oban Cron Plugin
    ↓ Every hour at :00 / Daily at 1:00 AM
Singularity.Database.BackupWorker
    ↓ Executes via System.cmd
pg_dump (PostgreSQL)
    ↓ Writes SQL dump
.db-backup/{hourly,daily}/backup_YYYYMMDD_HHMMSS/
    ├── singularity.sql
    ├── centralcloud.sql
    └── genesis_db.sql
```

## Related Files

- **Worker**: `singularity/lib/singularity/database/backup_worker.ex`
- **Config**: `singularity/config/config.exs` (Oban crontab)
- **Backups**: `.db-backup/` directory (created automatically)
