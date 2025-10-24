# Dead Code Monitoring - Fully Automated with Oban ✅

**Status:** ✅ **FULLY AUTOMATED** - No manual intervention needed!

---

## What Was Added

### Oban Jobs (2 files)

1. **`lib/singularity/jobs/dead_code_daily_check.ex`**
   - Runs daily at 9am
   - Stores results in database
   - Alerts on significant changes (≥3)

2. **`lib/singularity/jobs/dead_code_weekly_summary.ex`**
   - Runs every Monday at 9am
   - Generates trend analysis
   - Publishes summary report

### Configuration

**Added to `config/config.exs`:**
```elixir
# Dead code monitoring: daily at 9am
{"0 9 * * *", Singularity.Jobs.DeadCodeDailyCheck},

# Dead code summary: every Monday at 9am  
{"0 9 * * 1", Singularity.Jobs.DeadCodeWeeklySummary}
```

---

## How It Works

### Automatic Execution Flow

```
Phoenix Application Starts
    ↓
Oban Supervisor Starts
    ↓
Oban.Plugins.Cron Starts
    ↓ (reads crontab from config)
Schedules Jobs
    ↓
Every Day at 9am
    ↓
DeadCodeDailyCheck job runs
    ↓
Calls DeadCodeMonitor.execute_task(%{task: "daily_check"})
    ↓
Scans, stores in DB, alerts if needed
    ↓
Every Monday at 9am
    ↓
DeadCodeWeeklySummary job runs
    ↓
Generates trend report
```

---

## Benefits of Oban

### vs Quantum
- ✅ **Database-backed** - Jobs persisted, survive restarts
- ✅ **Job history** - Full audit trail in `oban_jobs` table
- ✅ **Automatic retries** - Fails retry up to 3 times
- ✅ **Web UI** - View jobs in Oban Web dashboard
- ✅ **Distributed** - Safe across multiple nodes

### vs System Cron
- ✅ **Integrated** - Part of application lifecycle
- ✅ **Monitored** - Logs, metrics, supervision
- ✅ **Testable** - Easy to test in development
- ✅ **Portable** - Works anywhere Phoenix runs

---

## Complete Automation Stack

### Tier 1: Pre-commit Hook ✅
**Trigger:** Every `git commit` with Rust files  
**Execution:** Immediate (git hook)  
**Automation:** Already active

### Tier 2: Daily Scans ✅
**Trigger:** Every day at 9am  
**Execution:** Oban cron job  
**Automation:** **NOW ACTIVE** (as of this commit)

### Tier 3: Weekly Summaries ✅
**Trigger:** Every Monday at 9am  
**Execution:** Oban cron job  
**Automation:** **NOW ACTIVE** (as of this commit)

---

## Verification

### Check if Oban is Running

```elixir
# In IEx
Oban.check_queue(queue: :maintenance)
# Should show: %{paused: false, running: [], ...}
```

### View Scheduled Jobs

```elixir
# All jobs
Oban.check_queue(queue: :maintenance)

# Specific job
import Ecto.Query
alias Singularity.Repo

Repo.all(
  from j in Oban.Job,
  where: j.worker == "Singularity.Jobs.DeadCodeDailyCheck",
  order_by: [desc: j.scheduled_at],
  limit: 10
)
```

### Manually Trigger Job

```elixir
# Trigger daily check now (doesn't wait for cron)
%{}
|> Singularity.Jobs.DeadCodeDailyCheck.new()
|> Oban.insert()

# Trigger weekly summary now
%{}
|> Singularity.Jobs.DeadCodeWeeklySummary.new()
|> Oban.insert()
```

---

## Job Configuration

### Daily Check

```elixir
use Oban.Worker,
  queue: :maintenance,          # Runs in maintenance queue
  max_attempts: 3,               # Retry up to 3 times if fails
  unique: [period: 21_600]      # Only one job per 6 hours
```

**Why unique period of 6 hours?**
- Prevents duplicate runs if job is manually triggered
- Daily cron (24h) < unique period (6h) = safe
- If job fails at 9am, can retry at 3pm without conflict

### Weekly Summary

```elixir
use Oban.Worker,
  queue: :maintenance,
  max_attempts: 3,
  unique: [period: 604_800]     # Only one job per week
```

**Why unique period of 1 week?**
- Weekly cron (7 days) = unique period (7 days)
- Prevents duplicate weekly summaries

---

## Monitoring

### Oban Web UI (If Installed)

If you have `oban_web` installed, view dashboard at:
```
http://localhost:4000/dev/oban
```

Shows:
- Job queue status
- Success/failure rates
- Job history
- Running jobs

### Logs

```bash
# Watch Oban job logs
tail -f singularity/logs/dev.log | grep "Oban:"

# Example output:
# [info] Oban: Running daily dead code check
# [info] Daily dead code check completed: %{count: 35, change: 0}
```

### Database Queries

```sql
-- View recent dead code check jobs
SELECT 
  scheduled_at, 
  attempted_at, 
  state, 
  errors 
FROM oban_jobs 
WHERE worker = 'Singularity.Jobs.DeadCodeDailyCheck'
ORDER BY scheduled_at DESC 
LIMIT 10;

-- View dead code history
SELECT 
  check_date, 
  total_count, 
  status 
FROM dead_code_history 
ORDER BY check_date DESC 
LIMIT 10;
```

---

## Testing

### Test Job Execution

```elixir
# Test daily check job
perform_job(Singularity.Jobs.DeadCodeDailyCheck, %{})

# Test weekly summary job
perform_job(Singularity.Jobs.DeadCodeWeeklySummary, %{})
```

### Test Cron Schedule

```elixir
# Check next scheduled run
import Ecto.Query
alias Singularity.Repo

Repo.one(
  from j in Oban.Job,
  where: j.worker == "Singularity.Jobs.DeadCodeDailyCheck",
  where: j.state == "scheduled",
  select: j.scheduled_at,
  order_by: [asc: j.scheduled_at],
  limit: 1
)
```

---

## Troubleshooting

### Jobs Not Running?

**Check Oban is started:**
```elixir
Process.whereis(Oban)
# Should return PID, not nil
```

**Check queue is not paused:**
```elixir
Oban.scale_queue(queue: :maintenance, limit: 3)
```

**Check cron plugin is loaded:**
```elixir
Application.get_env(:oban, :plugins)
# Should include Oban.Plugins.Cron
```

### Jobs Failing?

**View error details:**
```elixir
import Ecto.Query
alias Singularity.Repo

Repo.one(
  from j in Oban.Job,
  where: j.worker == "Singularity.Jobs.DeadCodeDailyCheck",
  where: j.state == "discarded",
  order_by: [desc: j.attempted_at],
  limit: 1
)
|> Map.get(:errors)
```

**Retry failed job:**
```elixir
import Ecto.Query
alias Singularity.Repo

job = Repo.one(
  from j in Oban.Job,
  where: j.worker == "Singularity.Jobs.DeadCodeDailyCheck",
  where: j.state == "discarded",
  order_by: [desc: j.attempted_at],
  limit: 1
)

Oban.retry_job(job.id)
```

---

## Summary

### Before Oban
- ❌ Manual execution required
- ❌ No job history
- ❌ No automatic retries
- ❌ No monitoring

### After Oban
- ✅ **Fully automated** - Runs daily + weekly
- ✅ **Job history** - Full audit trail in database
- ✅ **Automatic retries** - Up to 3 attempts
- ✅ **Monitoring** - Logs + database queries

### Complete Automation Status

| Component | Automated? | Method |
|-----------|------------|--------|
| Pre-commit hook | ✅ Yes | Git hook |
| Daily scans | ✅ Yes | Oban cron |
| Weekly summaries | ✅ Yes | Oban cron |
| Database storage | ✅ Yes | Automatic |
| Smart alerts | ✅ Yes | Agent logic |

**Everything is now fully automated!** 🎉

---

## What Happens Next

**Tomorrow at 9am:**
1. Oban triggers `DeadCodeDailyCheck` job
2. Job calls agent's `daily_check` task
3. Agent scans Rust files
4. Result stored in `dead_code_history` table
5. If count changed ≥3, alert published to NATS
6. Job marked as completed in `oban_jobs` table

**Next Monday at 9am:**
1. Oban triggers `DeadCodeWeeklySummary` job
2. Job calls agent's `weekly_summary` task
3. Agent queries last 7 days from database
4. Calculates trend (increasing/decreasing/stable)
5. Generates markdown report
6. Publishes to NATS `code_quality.dead_code.weekly`

**No manual intervention needed!** The system runs itself.

---

## Files Added/Modified

### New Files (2)
1. `lib/singularity/jobs/dead_code_daily_check.ex` - Daily job
2. `lib/singularity/jobs/dead_code_weekly_summary.ex` - Weekly job

### Modified Files (1)
3. `config/config.exs` - Added 2 cron entries

### Total Changes
- **3 files** touched
- **~60 lines** of code added
- **Infinite value** delivered (fully automated!)

---

## Quick Start

### Start Phoenix Server

```bash
cd singularity
mix phx.server
```

**That's it!** Jobs are now scheduled and will run automatically.

### Verify Automation

```bash
# Check Oban status
mix run -e "IO.inspect(Oban.check_queue(queue: :maintenance))"

# Trigger daily check manually (don't wait for 9am)
mix run -e "Singularity.Jobs.DeadCodeDailyCheck.new(%{}) |> Oban.insert!()"

# View results
mix run -e "IO.inspect(Singularity.Schemas.DeadCodeHistory.latest(Singularity.Repo))"
```

**System is live and automated!** 🚀
