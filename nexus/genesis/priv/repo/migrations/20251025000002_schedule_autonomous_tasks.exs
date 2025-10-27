defmodule Genesis.Repo.Migrations.ScheduleAutonomousTasks do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled tasks for autonomous Genesis operations.

  Schedules essential maintenance tasks that run independently of the Elixir
  application, providing true autonomous operation:

  - Experiment cleanup every 1 hour
  - Metrics aggregation every 30 minutes
  - Sandbox reset every 6 hours
  """

  def up do
    # Schedule experiment cleanup every 1 hour
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'genesis-cleanup-experiments-hourly'
        ) THEN
          PERFORM cron.schedule(
            'genesis-cleanup-experiments-hourly',
            '0 * * * *',
            'DELETE FROM experiment_records WHERE created_at < NOW() - INTERVAL ''30 days'' AND status = ''completed'''
          );
        END IF;
      END $$;
    """)

    # Schedule metrics aggregation every 30 minutes
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'genesis-aggregate-metrics-30min'
        ) THEN
          PERFORM cron.schedule(
            'genesis-aggregate-metrics-30min',
            '*/30 * * * *',
            'INSERT INTO experiment_metrics_summary SELECT DATE_TRUNC(''hour'', created_at) as hour, COUNT(*) as count, AVG(execution_time) as avg_time FROM experiment_metrics GROUP BY hour ON CONFLICT DO NOTHING'
          );
        END IF;
      END $$;
    """)

    # Schedule sandbox reset every 6 hours
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM cron.job WHERE jobname = 'genesis-reset-sandbox-6h'
        ) THEN
          PERFORM cron.schedule(
            'genesis-reset-sandbox-6h',
            '0 */6 * * *',
            'DELETE FROM sandbox_history WHERE created_at < NOW() - INTERVAL ''72 hours'''
          );
        END IF;
      END $$;
    """)
  end

  def down do
    # Unschedule all Genesis autonomous tasks
    execute("SELECT cron.unschedule('genesis-cleanup-experiments-hourly')")
    execute("SELECT cron.unschedule('genesis-aggregate-metrics-30min')")
    execute("SELECT cron.unschedule('genesis-reset-sandbox-6h')")
  rescue
    _ -> :ok
  end
end
