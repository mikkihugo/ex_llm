defmodule Singularity.Repo.Migrations.SubscribeToCentralcloudPatterns do
  @moduledoc """
  Create subscription to CentralCloud approved_patterns publication.

  ## What This Does

  This migration creates a PostgreSQL Logical Replication SUBSCRIPTION that:
  - Subscribes to the `approved_patterns_pub` publication on CentralCloud
  - Creates a replication slot (automatically cleaned up if subscription is dropped)
  - Begins streaming changes in real-time
  - Enables the subscription immediately

  ## Replication Connection

  The subscription uses environment variables for connection details:
  - CENTRALCLOUD_REPLICATION_HOST - CentralCloud PostgreSQL host
  - CENTRALCLOUD_REPLICATION_PORT - CentralCloud PostgreSQL port (default 5432)
  - CENTRALCLOUD_REPLICATION_USER - Replication user (replication_user)
  - CENTRALCLOUD_REPLICATION_PASSWORD - Replication user password
  - CENTRALCLOUD_REPLICATION_DB - CentralCloud database (central_services)

  ## Admin Commands

  View subscription status:
  ```sql
  SELECT subname, subenabled, subconninfo FROM pg_subscription;
  ```

  Disable subscription (for maintenance):
  ```sql
  ALTER SUBSCRIPTION patterns_sub DISABLE;
  ```

  Re-enable subscription:
  ```sql
  ALTER SUBSCRIPTION patterns_sub ENABLE;
  ```

  Refresh publication list:
  ```sql
  ALTER SUBSCRIPTION patterns_sub REFRESH PUBLICATION;
  ```

  Drop subscription:
  ```sql
  DROP SUBSCRIPTION patterns_sub;
  ```

  ## Monitoring

  Check replication status from Singularity:
  ```sql
  SELECT pid, usename, application_name, state, sync_state, write_lsn, flush_lsn, replay_lsn
  FROM pg_stat_replication
  WHERE application_name LIKE 'patterns%';
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

    # Create subscription
    execute("""
    CREATE SUBSCRIPTION patterns_sub
    CONNECTION '#{connection_string}'
    PUBLICATION approved_patterns_pub
    WITH (create_slot = true, enabled = true);
    """)
  end

  def down do
    execute("DROP SUBSCRIPTION IF EXISTS patterns_sub;")
  end
end
