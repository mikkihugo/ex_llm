defmodule Singularity.Repo.Migrations.AddPageRankPgCronSchedule do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled task for automatic daily PageRank recalculation.

  This migration creates a pg_cron job that:
  - Runs every day at 4:00 AM UTC (after midnight backups)
  - Triggers the PageRank calculation via Elixir job system
  - Requires pg_cron extension to be enabled

  ## Why pg_cron instead of Oban?

  For internal tooling, pg_cron is better because:
  - ✅ Database-native (no app-level coordination needed)
  - ✅ Always runs (even if app is down briefly)
  - ✅ Idempotent (PageRank calculation is safe to retry)
  - ✅ Simple SQL-based management
  - ✅ Already installed and configured in PostgreSQL 16

  Oban is still used for other job types that need:
  - Retry logic with exponential backoff
  - Complex error handling
  - App-level coordination
  - Job status tracking

  ## Schedule

  Cron expression: "0 4 * * *"
  Meaning: Every day at 4:00 AM UTC
  Why 4 AM: After typical midnight backups, before morning usage

  ## Manual Trigger (if needed)

  ```sql
  -- Run PageRank calculation now
  SELECT cron.schedule('run-pagerank-now', '* * * * *',
    'SELECT pg_sleep(0)'); -- placeholder, then delete

  -- View scheduled jobs
  SELECT jobid, schedule, command FROM cron.job;

  -- Delete a job
  SELECT cron.unschedule('pagerank-daily');
  ```
  """

  def up do
    # Enable pg_cron extension (should already be enabled)
    execute("CREATE EXTENSION IF NOT EXISTS pg_cron;")

    # Create a SQL function that triggers PageRank calculation via app event
    execute("""
    CREATE OR REPLACE FUNCTION pagerank_daily_refresh()
    RETURNS void AS $$
    BEGIN
      -- Insert a background job record that Elixir will process
      -- The PageRankBootstrap.ensure_initialized() will check for this
      -- and enqueue the calculation job if needed

      INSERT INTO oban_jobs (
        worker,
        args,
        state,
        queue,
        priority,
        inserted_at,
        scheduled_at
      ) VALUES (
        'Singularity.Jobs.PageRankCalculationJob',
        '{"codebase_id": "singularity", "context": "pg_cron_daily"}',
        'scheduled',
        'default',
        0,
        now(),
        now()
      );

      -- Log the scheduled job
      RAISE NOTICE 'PageRank daily refresh scheduled via pg_cron at %', now();
    END;
    $$ LANGUAGE plpgsql;
    """)

    # Schedule the job to run daily at 4:00 AM UTC
    execute("""
    SELECT cron.schedule(
      'pagerank-daily',           -- job name
      '0 4 * * *',                -- every day at 4:00 AM UTC
      'SELECT pagerank_daily_refresh();'
    );
    """)

    IO.puts("✅ PageRank daily refresh scheduled via pg_cron")
    IO.puts("   • Schedule: Every day at 4:00 AM UTC")
    IO.puts("   • Database-native scheduling (independent of Oban)")
    IO.puts("   • Job will be processed by PageRankCalculationJob")
    IO.puts("")
    IO.puts("View scheduled jobs:")
    IO.puts("  SELECT jobid, schedule, command FROM cron.job;")
  end

  def down do
    # Remove the pg_cron job
    execute("SELECT cron.unschedule('pagerank-daily');")

    # Drop the function
    execute("DROP FUNCTION IF EXISTS pagerank_daily_refresh();")

    IO.puts("Removed PageRank pg_cron schedule")
  end
end
