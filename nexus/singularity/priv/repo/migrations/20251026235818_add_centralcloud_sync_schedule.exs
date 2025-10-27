defmodule Singularity.Repo.Migrations.AddCentralcloudSyncSchedule do
  use Ecto.Migration

  @moduledoc """
  Add CentralCloud sync scheduling via pg_cron.

  Schedules periodic synchronization of failure patterns and validation metrics
  with CentralCloud for cross-instance learning and pattern aggregation.
  """

  def up do
    # Enable pg_cron extension if not already enabled
    execute("CREATE EXTENSION IF NOT EXISTS pg_cron")
    execute("GRANT USAGE ON SCHEMA cron TO postgres")

    # 1. Sync failure patterns to CentralCloud (every 2 hours)
    execute("""
      SELECT cron.schedule(
        'centralcloud-sync-failure-patterns',
        '0 */2 * * *',
        'SELECT Singularity.Storage.FailurePatternStore.sync_with_centralcloud();'
      )
    """)

    # 2. Sync validation metrics to CentralCloud (every hour)
    execute("""
      SELECT cron.schedule(
        'centralcloud-sync-validation-metrics',
        '0 * * * *',
        'SELECT Singularity.Storage.ValidationMetricsStore.sync_with_centralcloud();'
      )
    """)

    # 3. Publish Genesis rules (every 6 hours)
    execute("""
      SELECT cron.schedule(
        'genesis-publish-rules',
        '0 */6 * * *',
        'SELECT Singularity.Evolution.GenesisPublisher.publish_rules();'
      )
    """)

    # 4. Import Genesis rules (every 4 hours)
    execute("""
      SELECT cron.schedule(
        'genesis-import-rules',
        '0 */4 * * *',
        'SELECT Singularity.Evolution.GenesisPublisher.import_rules_from_genesis();'
      )
    """)
  end

  def down do
    # Remove all CentralCloud sync jobs
    execute("""
      SELECT cron.unschedule(job_name)
      FROM cron.job
      WHERE job_name IN (
        'centralcloud-sync-failure-patterns',
        'centralcloud-sync-validation-metrics',
        'genesis-publish-rules',
        'genesis-import-rules'
      );
    """)
  rescue
    _ -> :ok
  end
end
