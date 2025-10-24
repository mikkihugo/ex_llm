defmodule Singularity.Repo.Migrations.ScheduleAutonomousTasks do
  use Ecto.Migration

  def up do
    # ============================================================================
    # SCHEDULE AUTONOMOUS TASKS WITH pg_cron
    # ============================================================================
    
    # Every 5 minutes: Learn patterns from analysis results
    execute("""
    SELECT cron.schedule(
      'learn-patterns-every-5min',
      '*/5 * * * *',
      'SELECT learn_patterns_from_analysis()'
    );
    """)

    # Every 10 minutes: Sync learning to CentralCloud
    execute("""
    SELECT cron.schedule(
      'sync-learning-every-10min',
      '*/10 * * * *',
      'SELECT sync_learning_to_centralcloud()'
    );
    """)

    # Every hour: Update agent knowledge
    execute("""
    SELECT cron.schedule(
      'update-knowledge-hourly',
      '0 * * * *',
      'SELECT update_agent_knowledge()'
    );
    """)

    # Every 2 minutes: Assign pending tasks to agents
    execute("""
    SELECT cron.schedule(
      'assign-tasks-every-2min',
      '*/2 * * * *',
      'SELECT assign_pending_tasks()'
    );
    """)

    # Every 30 minutes: Refresh performance metrics
    execute("""
    SELECT cron.schedule(
      'refresh-metrics-every-30min',
      '*/30 * * * *',
      'REFRESH MATERIALIZED VIEW agent_performance_5min'
    );
    """)

    # Every 6 hours: Cleanup old learning sync logs
    execute("""
    SELECT cron.schedule(
      'cleanup-sync-logs-every-6h',
      '0 */6 * * *',
      'DELETE FROM learning_sync_log WHERE synced_at < NOW() - INTERVAL ''30 days'''
    );
    """)

    # Every 24 hours: Archive completed agent tasks
    execute("""
    SELECT cron.schedule(
      'archive-tasks-daily',
      '0 2 * * *',
      $$DELETE FROM agent_tasks 
        WHERE status = 'completed' 
          AND completed_at < NOW() - INTERVAL '90 days'$$
    );
    """)
  end

  def down do
    # Unschedule all cron jobs
    execute("SELECT cron.unschedule('learn-patterns-every-5min');")
    execute("SELECT cron.unschedule('sync-learning-every-10min');")
    execute("SELECT cron.unschedule('update-knowledge-hourly');")
    execute("SELECT cron.unschedule('assign-tasks-every-2min');")
    execute("SELECT cron.unschedule('refresh-metrics-every-30min');")
    execute("SELECT cron.unschedule('cleanup-sync-logs-every-6h');")
    execute("SELECT cron.unschedule('archive-tasks-daily');")
  end
end
