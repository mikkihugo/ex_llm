defmodule CentralCloud.Repo.Migrations.CreateQueueRegistry do
  use Ecto.Migration

  @doc """
  Creates the queue_registry table in the shared_queue database.

  This table is the single source of truth for all pgmq queues used by
  Singularity, CentralCloud, Genesis, external LLM router, and other services.

  All services can query this table to discover available queues, their
  purpose, message schemas, and retention policies.

  Note: This migration runs in CentralCloud but creates table in shared_queue DB.
  Use target: :shared_queue if available, otherwise execute raw SQL.
  """

  def up do
    # Create queue_registry table in shared_queue schema
    execute("""
    CREATE TABLE IF NOT EXISTS queue_registry (
      id BIGSERIAL PRIMARY KEY,
      queue_name VARCHAR(255) NOT NULL UNIQUE,
      purpose TEXT NOT NULL,
      direction VARCHAR(50) NOT NULL CHECK (direction IN ('send', 'receive', 'bidirectional')),
      source VARCHAR(255) NOT NULL,
      consumer VARCHAR(255) NOT NULL,
      message_schema JSONB NOT NULL,
      retention_days INTEGER NOT NULL DEFAULT 90,
      enabled BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """)

    # Create index on queue_name for fast lookups
    execute("""
    CREATE INDEX IF NOT EXISTS idx_queue_registry_queue_name
    ON queue_registry(queue_name);
    """)

    # Create index on enabled for filtering
    execute("""
    CREATE INDEX IF NOT EXISTS idx_queue_registry_enabled
    ON queue_registry(enabled);
    """)

    # Create index on source for service discovery
    execute("""
    CREATE INDEX IF NOT EXISTS idx_queue_registry_source
    ON queue_registry(source);
    """)

    # Create index on consumer for service discovery
    execute("""
    CREATE INDEX IF NOT EXISTS idx_queue_registry_consumer
    ON queue_registry(consumer);
    """)

    # Create trigger to update updated_at timestamp
    execute("""
    CREATE OR REPLACE FUNCTION update_queue_registry_timestamp()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER queue_registry_update_timestamp
    BEFORE UPDATE ON queue_registry
    FOR EACH ROW
    EXECUTE FUNCTION update_queue_registry_timestamp();
    """)
  end

  def down do
    # Drop trigger and function
    execute("DROP TRIGGER IF EXISTS queue_registry_update_timestamp ON queue_registry;")
    execute("DROP FUNCTION IF EXISTS update_queue_registry_timestamp();")

    # Drop indexes
    execute("DROP INDEX IF EXISTS idx_queue_registry_consumer;")
    execute("DROP INDEX IF EXISTS idx_queue_registry_source;")
    execute("DROP INDEX IF EXISTS idx_queue_registry_enabled;")
    execute("DROP INDEX IF EXISTS idx_queue_registry_queue_name;")

    # Drop table
    execute("DROP TABLE IF EXISTS queue_registry;")
  end
end
