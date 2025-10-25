defmodule Genesis.Repo.Migrations.SubscribeToCentralcloudMetrics do
  @moduledoc """
  Create subscriptions to CentralCloud metrics publications.

  This migration creates two PostgreSQL Logical Replication SUBSCRIPTIONs:
  1. job_stats_sub - Subscribes to job_statistics_pub
  2. metrics_sub - Subscribes to execution_metrics_pub

  Both subscriptions stream changes from CentralCloud in real-time.

  ## Replication Connections

  Subscriptions use environment variables for connection details:
  - CENTRALCLOUD_REPLICATION_HOST - CentralCloud PostgreSQL host
  - CENTRALCLOUD_REPLICATION_PORT - CentralCloud PostgreSQL port (default 5432)
  - CENTRALCLOUD_REPLICATION_USER - Replication user (replication_user)
  - CENTRALCLOUD_REPLICATION_PASSWORD - Replication user password
  - CENTRALCLOUD_REPLICATION_DB - CentralCloud database (central_services)

  ## Admin Commands

  View all subscriptions:
  ```sql
  SELECT subname, subenabled, subconninfo FROM pg_subscription;
  ```

  View subscription status:
  ```sql
  SELECT subname, pid, relname, sstate FROM pg_stat_subscription_rel;
  ```

  Disable subscription (for maintenance):
  ```sql
  ALTER SUBSCRIPTION job_stats_sub DISABLE;
  ALTER SUBSCRIPTION metrics_sub DISABLE;
  ```

  Re-enable subscriptions:
  ```sql
  ALTER SUBSCRIPTION job_stats_sub ENABLE;
  ALTER SUBSCRIPTION metrics_sub ENABLE;
  ```

  Refresh publication list:
  ```sql
  ALTER SUBSCRIPTION job_stats_sub REFRESH PUBLICATION;
  ALTER SUBSCRIPTION metrics_sub REFRESH PUBLICATION;
  ```

  Drop subscriptions:
  ```sql
  DROP SUBSCRIPTION job_stats_sub;
  DROP SUBSCRIPTION metrics_sub;
  ```

  ## Monitoring

  Check slot status:
  ```sql
  SELECT slot_name, slot_type, restart_lsn, confirmed_flush_lsn
  FROM pg_replication_slots
  WHERE slot_name LIKE '%stats%' OR slot_name LIKE '%metrics%';
  ```

  Check replication lag:
  ```sql
  SELECT application_name, write_lsn - replay_lsn as lag_bytes
  FROM pg_stat_replication
  WHERE application_name LIKE 'job_stats%' OR application_name LIKE 'metrics%';
  ```
  """

  use Ecto.Migration

  def up do
    # Build connection string from environment variables
    host = System.get_env("CENTRALCLOUD_REPLICATION_HOST", "127.0.0.1")
    port = System.get_env("CENTRALCLOUD_REPLICATION_PORT", "5432")
    user = System.get_env("CENTRALCLOUD_REPLICATION_USER", "replication_user")
    password = System.get_env("CENTRALCLOUD_REPLICATION_PASSWORD", "")
    db = System.get_env("CENTRALCLOUD_REPLICATION_DB", "central_services")

    # Build connection URI
    connection_string =
      "host=#{host} port=#{port} user=#{user} password=#{password} dbname=#{db}"

    # Subscribe to job statistics
    execute("""
    CREATE SUBSCRIPTION job_stats_sub
    CONNECTION '#{connection_string}'
    PUBLICATION job_statistics_pub
    WITH (create_slot = true, enabled = true);
    """)

    # Subscribe to aggregated metrics
    execute("""
    CREATE SUBSCRIPTION metrics_sub
    CONNECTION '#{connection_string}'
    PUBLICATION execution_metrics_pub
    WITH (create_slot = true, enabled = true);
    """)
  end

  def down do
    execute("DROP SUBSCRIPTION IF EXISTS metrics_sub;")
    execute("DROP SUBSCRIPTION IF EXISTS job_stats_sub;")
  end
end
