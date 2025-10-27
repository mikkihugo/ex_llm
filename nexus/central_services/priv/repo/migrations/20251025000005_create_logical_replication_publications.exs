defmodule CentralCloud.Repo.Migrations.CreateLogicalReplicationPublications do
  use Ecto.Migration

  def change do
    # ===================================
    # 1. Publication for Approved Patterns
    # ===================================
    # All approved patterns replicate to Singularity instances in real-time
    # Using native PostgreSQL logical replication
    execute("""
    CREATE PUBLICATION IF NOT EXISTS approved_patterns_pub
    FOR TABLE approved_patterns
    WITH (publish = 'insert,update,delete');
    """)

    # ===================================
    # 2. Publication for Execution Metrics
    # ===================================
    # Job statistics and aggregated metrics replicate automatically
    execute("""
    CREATE PUBLICATION IF NOT EXISTS job_statistics_pub
    FOR TABLE job_statistics
    WITH (publish = 'insert');
    """)

    execute("""
    CREATE PUBLICATION IF NOT EXISTS execution_metrics_pub
    FOR TABLE execution_metrics
    WITH (publish = 'insert');
    """)

    # ===================================
    # 3. Publication for Sync Audit Log (optional)
    # ===================================
    # For monitoring which patterns were synced
    execute("""
    CREATE PUBLICATION IF NOT EXISTS sync_log_pub
    FOR TABLE sync_log
    WITH (publish = 'insert');
    """)

    # ===================================
    # 4. Replication Slot for Each Subscriber
    # ===================================
    # Reserve logical decoding slots to prevent WAL cleanup
    # if subscribers get disconnected
    # (slots are created when subscription is activated, not here)
    # This is automatic - PostgreSQL creates slots when subscriptions connect

    # ===================================
    # 5. Note: Subscriptions are created on SINGULARITY/GENESIS side
    # ===================================
    # See LOGICAL_REPLICATION_SETUP.md for how to:
    # - Create SUBSCRIPTION on Singularity for approved_patterns_pub
    # - Create SUBSCRIPTION on Genesis for metrics publications
  end

  def down do
    execute("DROP PUBLICATION IF EXISTS sync_log_pub CASCADE;")
    execute("DROP PUBLICATION IF EXISTS execution_metrics_pub CASCADE;")
    execute("DROP PUBLICATION IF EXISTS job_statistics_pub CASCADE;")
    execute("DROP PUBLICATION IF EXISTS approved_patterns_pub CASCADE;")
  end
end
