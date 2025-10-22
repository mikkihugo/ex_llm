# Background Jobs & Scheduled Tasks Guide

## Overview

Singularity uses two complementary systems for background work:

1. **Quantum** - Cron-like scheduler for periodic maintenance tasks (runs every N minutes/hours)
2. **Oban** - Persistent job queue for long-running tasks like ML training (can be queued, retried, monitored)

## Auto-Running Jobs

All periodic maintenance jobs are **automatically scheduled and run** via Quantum. You don't need to manually trigger them.

### Currently Scheduled Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| Cache Cleanup | Every 15 minutes | Remove expired cache entries |
| Cache Refresh | Every 1 hour | Refresh materialized views with hot data |
| Cache Prewarm | Every 6 hours | Load frequently-used data into cache |
| Pattern Sync | Every 5 minutes | Sync framework patterns to ETS/NATS/JSON |

### How It Works

1. **Singularity.Scheduler** (Quantum process) starts when app launches
2. Scheduler reads cron jobs from `config/config.exs`
3. On schedule, Quantum executes the job function automatically
4. Job functions log their execution and results
5. If job fails, Quantum logs the error (retries handled at job level)

## Configuration

### Enable/Disable Auto-Execution

**To enable automatic job execution** (default in dev/prod):
```elixir
config :singularity, Singularity.Scheduler,
  global: true,
  debug: true,
  jobs: [
    # Your jobs here...
  ]
```

**To disable** (useful in tests):
```elixir
config :singularity, Singularity.Scheduler, debug: false
```

### Modify Job Schedule

Edit `config/config.exs` and change the cron expression:

```elixir
config :singularity, Singularity.Scheduler,
  jobs: [
    # Run every 30 minutes instead of 15
    {"*/30 * * * *", {Singularity.Jobs.CacheMaintenanceJob, :cleanup, []}},
    # Run at 2 AM daily
    {"0 2 * * *", {Singularity.Jobs.CacheMaintenanceJob, :prewarm, []}},
  ]
```

**Cron Expression Syntax:** `minute hour day month weekday`

- `*` - Any value
- `*/N` - Every N units
- `N` - Specific value
- `N,M` - Multiple values

Examples:
- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour (at :00)
- `0 2 * * *` - Every day at 2:00 AM
- `0 0 * * MON` - Every Monday at midnight

### Add New Scheduled Job

1. Create job module in `lib/singularity/jobs/your_job.ex`:

```elixir
defmodule Singularity.Jobs.YourJob do
  require Logger

  def run_task do
    Logger.info("Running your task...")
    # Your logic here
    :ok
  end
end
```

2. Add to config in `config/config.exs`:

```elixir
config :singularity, Singularity.Scheduler,
  jobs: [
    # ... existing jobs ...
    # Your new job: every 10 minutes
    {"*/10 * * * *", {Singularity.Jobs.YourJob, :run_task, []}}
  ]
```

3. Restart the app - new job automatically starts

## Monitoring

### View Scheduled Jobs

In `iex` (interactive Elixir shell):

```elixir
# See all scheduled jobs
Singularity.Scheduler.jobs()

# See next execution times
Singularity.Scheduler.jobs() |> Enum.map(&elem(&1, 0))
```

### View Execution Logs

Jobs log to standard output with `[info]` prefix. In development:

```bash
# Start app and watch logs
mix phx.server

# You'll see entries like:
# [info] ✅ Hot packages materialized view refreshed
# [info] 🧹 Cleaned up 15 expired cache entries
```

### Check Job Results

Most jobs log their results. Check logs for:
- `✅` - Job succeeded
- `❌` - Job failed (with reason)
- `🧹`, `🔄`, `🔥` - Specific job type indicators

## Oban Background Jobs (Future)

When we add long-running tasks like ML training, they'll use **Oban** instead of Quantum:

```elixir
# Queue a job
Oban.insert(Singularity.Jobs.TrainT5ModelJob.new(%{"codebase" => "/path"}))

# Job runs in background, can be retried if it fails
```

Benefits over Quantum:
- ✅ Persistent (survives app restart)
- ✅ Automatic retries on failure
- ✅ Fine-grained concurrency control
- ✅ Job history in database

## Troubleshooting

### Jobs Not Running

1. **Check Quantum is enabled:**
   ```elixir
   iex> Singularity.Scheduler.jobs() |> length()  # Should be > 0
   ```

2. **Check configuration:**
   ```bash
   grep -A 10 "Singularity.Scheduler" config/config.exs
   ```

3. **Check logs:**
   ```bash
   # Watch for [info] messages from Quantum
   mix phx.server 2>&1 | grep -i "quantum\|cache\|pattern"
   ```

4. **Manually trigger a job:**
   ```elixir
   iex> Singularity.Jobs.CacheMaintenanceJob.cleanup()
   ```

### Job Failing Silently

Add error handling:

```elixir
def cleanup do
  Logger.info("Starting cache cleanup...")

  case PostgresCache.cleanup_expired() do
    {:ok, count} ->
      Logger.info("Cleanup succeeded: #{count} entries")
      :ok

    {:error, reason} ->
      Logger.error("Cleanup failed: #{inspect(reason)}")
      {:error, reason}  # Will be logged by Quantum
  end
end
```

## Architecture Decisions

### Why Quantum for Periodic Tasks?

- Simple cron-like syntax
- No database overhead
- Perfect for maintenance tasks
- Easier to reason about vs timer-based GenServers

### Why Oban for Long-Running Tasks?

- Survives app restarts
- Automatic retries
- Concurrency limits (e.g., 1 GPU training job at a time)
- Job history for debugging
- Future: web dashboard for monitoring

## References

- [Quantum Documentation](https://hexdocs.pm/quantum/readme.html)
- [Oban Documentation](https://hexdocs.pm/oban/home.html)
- [Cron Expression Guide](https://en.wikipedia.org/wiki/Cron#CRON_expression)
