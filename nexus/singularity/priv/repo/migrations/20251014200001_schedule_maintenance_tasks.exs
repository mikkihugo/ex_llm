defmodule Singularity.Repo.Migrations.ScheduleMaintenanceTasks do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled tasks for database maintenance.

  ## TEMPORARILY DISABLED FOR DEVELOPMENT
  This migration is disabled because pg_cron is not enabled in development.
  Re-enable once pg_cron is properly configured.
  """

  def up do
    # pg_cron scheduling is disabled - extension not available in development
    # To enable:
    # 1. Ensure pg_cron is installed in PostgreSQL: CREATE EXTENSION pg_cron
    # 2. Uncomment the execute statements below

    # Schedule weekly index health checks (every Sunday at 2 AM)
    # execute("""
    #   SELECT cron.schedule('weekly-index-health-check', '0 2 * * 0', 'SELECT pg_stat_get_live_tuples(relid) FROM pg_stat_user_indexes WHERE idx_scan > 0');
    # """)

    # Schedule weekly VACUUM ANALYZE (every Wednesday at 3 AM)
    # execute("""
    #   SELECT cron.schedule('weekly-vacuum', '0 3 * * 3', 'VACUUM ANALYZE');
    # """)

    # Schedule daily bloat check (every day at 4 AM)
    # execute("""
    #   SELECT cron.schedule('daily-bloat-check', '0 4 * * *', 'SELECT schemaname, tablename, round(100.0 * (CASE WHEN otta > 0 THEN sml_heap_size::float/otta ELSE 0.0 END), 2) AS table_waste_ratio FROM pgstattuple_approx(''public.knowledge_artifacts'')');
    # """)
  end

  def down do
    # Unschedule all maintenance tasks (if pg_cron is available)
    # execute("SELECT cron.unschedule('weekly-index-health-check')")
    # execute("SELECT cron.unschedule('weekly-vacuum')")
    # execute("SELECT cron.unschedule('daily-bloat-check')")
  rescue
    _ -> :ok
  end
end
