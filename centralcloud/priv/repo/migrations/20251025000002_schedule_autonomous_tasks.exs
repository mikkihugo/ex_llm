defmodule CentralCloud.Repo.Migrations.ScheduleAutonomousTasks do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled tasks for autonomous CentralCloud operations.

  Schedules critical multi-instance learning and aggregation tasks that run
  independently of Elixir, enabling true continuous learning across all
  Singularity instances:

  - Knowledge aggregation every 10 minutes
  - Pattern consolidation every 1 hour
  - Package intelligence update every 6 hours
  - Metrics cleanup every 24 hours
  """

  def up do
    # Schedule knowledge aggregation from all Singularity instances every 10 minutes
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'centralcloud-aggregate-knowledge-10min'
        ) THEN
          PERFORM cron.schedule(
            'centralcloud-aggregate-knowledge-10min',
            '*/10 * * * *',
            'SELECT * FROM aggregate_learned_patterns_from_instances()'
          );
        END IF;
      END $$;
    """)

    # Schedule pattern consolidation every 1 hour
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'centralcloud-consolidate-patterns-hourly'
        ) THEN
          PERFORM cron.schedule(
            'centralcloud-consolidate-patterns-hourly',
            '0 * * * *',
            'SELECT * FROM consolidate_global_patterns()'
          );
        END IF;
      END $$;
    """)

    # Schedule package intelligence update every 6 hours
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'centralcloud-update-package-stats-6h'
        ) THEN
          PERFORM cron.schedule(
            'centralcloud-update-package-stats-6h',
            '0 */6 * * *',
            'SELECT * FROM update_package_intelligence()'
          );
        END IF;
      END $$;
    """)

    # Schedule metrics cleanup every 24 hours (keep only last 30 days)
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'centralcloud-cleanup-metrics-daily'
        ) THEN
          PERFORM cron.schedule(
            'centralcloud-cleanup-metrics-daily',
            '0 2 * * *',
            'DELETE FROM aggregated_metrics WHERE created_at < NOW() - INTERVAL ''30 days'''
          );
        END IF;
      END $$;
    """)

    # Schedule cross-instance sync log rotation every 12 hours
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'centralcloud-rotate-sync-logs-12h'
        ) THEN
          PERFORM cron.schedule(
            'centralcloud-rotate-sync-logs-12h',
            '0 */12 * * *',
            'INSERT INTO sync_logs_archive SELECT * FROM cdc_sync_logs WHERE created_at < NOW() - INTERVAL ''7 days''; DELETE FROM cdc_sync_logs WHERE created_at < NOW() - INTERVAL ''7 days'''
          );
        END IF;
      END $$;
    """)
  end

  def down do
    # Unschedule all CentralCloud autonomous tasks
    execute("SELECT cron.unschedule('centralcloud-aggregate-knowledge-10min')")
    execute("SELECT cron.unschedule('centralcloud-consolidate-patterns-hourly')")
    execute("SELECT cron.unschedule('centralcloud-update-package-stats-6h')")
    execute("SELECT cron.unschedule('centralcloud-cleanup-metrics-daily')")
    execute("SELECT cron.unschedule('centralcloud-rotate-sync-logs-12h')")
  rescue
    _ -> :ok
  end
end
