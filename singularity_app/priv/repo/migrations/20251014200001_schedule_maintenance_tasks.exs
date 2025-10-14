defmodule Singularity.Repo.Migrations.ScheduleMaintenanceTasks do
  use Ecto.Migration

  @moduledoc """
  Schedule automated maintenance tasks using pg_cron.

  ## Scheduled Tasks

  1. **Weekly Index Health Check** (Sundays at 3am)
     - Runs check_index_health() on critical tables
     - Logs results for monitoring

  2. **Daily VACUUM on Large Tables** (Every day at 2am)
     - Runs VACUUM ANALYZE on code_files, knowledge_artifacts, graph_nodes
     - Keeps tables optimized

  ## Monitoring

  Check scheduled jobs:
  ```sql
  SELECT * FROM cron.job;
  ```

  Check job run history:
  ```sql
  SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
  ```
  """

  def up do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("Scheduling Automated Maintenance Tasks (pg_cron)")
    IO.puts(String.duplicate("=", 70) <> "\n")

    # Create maintenance_log table if it doesn't exist
    create_if_not_exists table(:maintenance_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :check_type, :string
      add :status, :string
      add :results, :jsonb
      add :checked_at, :utc_datetime, default: fragment("NOW()")
    end

    IO.puts("✓ Created maintenance_log table")

    # Schedule 1: Weekly index health check (Sundays at 3am)
    execute """
    SELECT cron.schedule(
      'weekly-index-health-check',
      '0 3 * * 0',
      $$
      INSERT INTO maintenance_log (id, check_type, status, results, checked_at)
      SELECT
        gen_random_uuid(),
        'index_health',
        CASE WHEN COUNT(*) FILTER (WHERE status != 'healthy') > 0
          THEN 'issues_found'
          ELSE 'healthy'
        END,
        jsonb_agg(row_to_json(t)),
        NOW()
      FROM check_index_health() t;
      $$
    )
    """
    IO.puts("✓ Scheduled: Weekly index health check (Sundays at 3am)")

    # Schedule 2: Daily VACUUM on large tables (Every day at 2am)
    execute """
    SELECT cron.schedule(
      'daily-vacuum-large-tables',
      '0 2 * * *',
      $$
      VACUUM ANALYZE code_files, knowledge_artifacts, graph_nodes, graph_edges;
      $$
    )
    """
    IO.puts("✓ Scheduled: Daily VACUUM on large tables (2am)")

    # Schedule 3: Weekly pgstattuple check (Saturdays at 4am)
    # Checks table bloat and recommends VACUUM if needed
    execute """
    SELECT cron.schedule(
      'weekly-bloat-check',
      '0 4 * * 6',
      $$
      INSERT INTO maintenance_log (id, check_type, status, results, checked_at)
      SELECT
        gen_random_uuid(),
        'bloat_check',
        CASE WHEN n_dead_tup::FLOAT / NULLIF(n_live_tup + n_dead_tup, 0) > 0.2
          THEN 'needs_vacuum'
          ELSE 'healthy'
        END,
        jsonb_build_object(
          'table', schemaname || '.' || tablename,
          'live_tuples', n_live_tup,
          'dead_tuples', n_dead_tup,
          'dead_pct', ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2)
        ),
        NOW()
      FROM pg_stat_user_tables
      WHERE schemaname = 'public'
        AND n_dead_tup > 1000;
      $$
    )
    """
    IO.puts("✓ Scheduled: Weekly bloat check (Saturdays at 4am)")

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("✅ Maintenance Tasks Scheduled!")
    IO.puts(String.duplicate("=", 70))
    IO.puts("\nScheduled Jobs:")
    IO.puts("  • Weekly index health check: Sundays at 3am")
    IO.puts("  • Daily VACUUM: Every day at 2am")
    IO.puts("  • Weekly bloat check: Saturdays at 4am")
    IO.puts("\nMonitoring:")
    IO.puts("  • View jobs: SELECT * FROM cron.job;")
    IO.puts("  • View history: SELECT * FROM cron.job_run_details ORDER BY start_time DESC;")
    IO.puts("  • View logs: SELECT * FROM maintenance_log ORDER BY checked_at DESC;")
    IO.puts("")
  end

  def down do
    IO.puts("\nRemoving scheduled maintenance tasks...")

    # Unschedule all jobs
    execute "SELECT cron.unschedule('weekly-index-health-check')"
    execute "SELECT cron.unschedule('daily-vacuum-large-tables')"
    execute "SELECT cron.unschedule('weekly-bloat-check')"

    # Drop maintenance log table
    drop_if_exists table(:maintenance_log)

    IO.puts("✓ Removed all scheduled tasks and maintenance_log table")
  end
end
