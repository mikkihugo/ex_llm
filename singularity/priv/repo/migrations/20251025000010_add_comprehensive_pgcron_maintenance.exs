defmodule Singularity.Repo.Migrations.AddComprehensivePgcronMaintenance do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled tasks for comprehensive database maintenance.

  Pure SQL/PL maintenance tasks that run autonomously in PostgreSQL:
  - Table vacuum & analyze
  - Index maintenance
  - Old job cleanup
  - Statistics updates
  - View refresh

  These require NO Elixir code - they're database-native operations.
  """

  def up do
    # Enable pg_cron extension if not already enabled
    execute("CREATE EXTENSION IF NOT EXISTS pg_cron")
    execute("GRANT USAGE ON SCHEMA cron TO postgres")

    # 1. VACUUM & ANALYZE - Optimize query planner (every night at 11 PM)
    execute("""
      SELECT cron.schedule(
        'daily-vacuum-analyze',
        '0 23 * * *',
        'VACUUM ANALYZE; ANALYZE;'
      )
    """)

    # 2. Cleanup old Oban jobs (every Sunday at midnight)
    # Oban has its own pruner, but this is a safety net
    execute("""
      SELECT cron.schedule(
        'weekly-cleanup-oban-jobs',
        '0 0 * * 0',
        'DELETE FROM oban_jobs WHERE state IN (''cancelled'', ''discarded'') AND updated_at < now() - interval ''30 days'';'
      )
    """)

    # 3. Update table statistics (every 6 hours)
    # Helps query planner make better decisions
    execute("""
      SELECT cron.schedule(
        'frequent-analyze-stats',
        '0 */6 * * *',
        'ANALYZE;'
      )
    """)

    # 4. Cleanup old knowledge artifacts (weekly on Sundays at 1 AM)
    # Remove old learned patterns that were superseded
    execute("""
      SELECT cron.schedule(
        'weekly-cleanup-old-artifacts',
        '0 1 * * 0',
        'DELETE FROM knowledge_artifacts WHERE source = ''learned'' AND updated_at < now() - interval ''90 days'' AND usage_count < 5;'
      )
    """)

    # 5. Cleanup old code chunks (weekly on Sundays at 2 AM)
    # Remove code chunks from deleted files
    execute("""
      SELECT cron.schedule(
        'weekly-cleanup-code-chunks',
        '0 2 * * 0',
        'DELETE FROM code_chunks WHERE file_path NOT IN (SELECT file_path FROM current_codebase);'
      )
    """)

    # 6. Reindex bloated indexes (monthly, first Sunday at 3 AM)
    # Only reindex if significantly bloated
    execute("""
      SELECT cron.schedule(
        'monthly-reindex-bloated',
        '0 3 * * 0',
        'REINDEX INDEX CONCURRENTLY idx_oban_jobs_queue_state_scheduled_at;'
      )
    """)

    # 7. Update search statistics for pgvector (weekly on Sundays at 4 AM)
    # Helps vector similarity search performance
    execute("""
      SELECT cron.schedule(
        'weekly-vector-stats',
        '0 4 * * 0',
        'SELECT COUNT(*) FROM pg_class WHERE relname IN (''code_chunks'', ''knowledge_artifacts'') AND idx_scan > 0;'
      )
    """)

    # 8. Archive old backup metadata (monthly)
    # Keep backup history for 60 days
    execute("""
      SELECT cron.schedule(
        'monthly-archive-old-backups',
        '0 5 1 * *',
        'DELETE FROM backup_metadata WHERE created_at < now() - interval ''60 days'';'
      )
    """)
  end

  def down do
    # Remove all scheduled jobs
    execute("""
      SELECT cron.unschedule(job_name)
      FROM cron.job
      WHERE job_name IN (
        'daily-vacuum-analyze',
        'weekly-cleanup-oban-jobs',
        'frequent-analyze-stats',
        'weekly-cleanup-old-artifacts',
        'weekly-cleanup-code-chunks',
        'monthly-reindex-bloated',
        'weekly-vector-stats',
        'monthly-archive-old-backups'
      );
    """)
  rescue
    _ -> :ok
  end
end
