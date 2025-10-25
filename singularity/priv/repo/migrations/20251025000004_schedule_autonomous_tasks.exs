defmodule Singularity.Repo.Migrations.ScheduleAutonomousTasks do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled tasks for autonomous system operations.

  ## TEMPORARILY DISABLED FOR DEVELOPMENT
  This migration is disabled because pg_cron is not enabled in development.
  Re-enable once pg_cron is properly configured.
  """

  def up do
    # Schedule autonomous system health checks every 30 minutes
    execute("""
      SELECT cron.schedule(
        'autonomous-health-check',
        '*/30 * * * *',
        'SELECT Singularity.Autonomy.HealthCheck.run()'
      );
    """)

    # Schedule autonomous learning aggregation every 6 hours
    execute("""
      SELECT cron.schedule(
        'autonomous-learning-aggregate',
        '0 */6 * * *',
        'SELECT Singularity.Autonomy.LearningAggregator.aggregate_all()'
      );
    """)

    # Schedule autonomous cost optimization analysis daily at 2 AM UTC
    execute("""
      SELECT cron.schedule(
        'autonomous-cost-optimization',
        '0 2 * * *',
        'SELECT Singularity.Autonomy.CostOptimizer.analyze_and_optimize()'
      );
    """)
  end

  def down do
    # Unschedule all autonomous tasks
    execute("SELECT cron.unschedule('autonomous-health-check')")
    execute("SELECT cron.unschedule('autonomous-learning-aggregate')")
    execute("SELECT cron.unschedule('autonomous-cost-optimization')")
  rescue
    _ -> :ok
  end
end
