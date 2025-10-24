defmodule CentralCloud.Repo.Migrations.EnablePg17Extensions do
  use Ecto.Migration

  def up do
    # Modern encryption & hashing (replaces pgcrypto)
    execute("CREATE EXTENSION IF NOT EXISTS pgsodium CASCADE")

    # Distributed ULID generation (sortable, monotonic IDs)
    # Note: Future PostgreSQL 18 migration path is UUIDv7
    execute("CREATE EXTENSION IF NOT EXISTS pgx_ulid CASCADE")

    # In-database message queue (alternative to external NATS for some use cases)
    execute("CREATE EXTENSION IF NOT EXISTS pgmq CASCADE")

    # JSON WAL decoding for event streaming
    execute("CREATE EXTENSION IF NOT EXISTS wal2json CASCADE")

    # HTTP client from SQL for external API calls
    execute("CREATE EXTENSION IF NOT EXISTS pg_net CASCADE")

    # Alternative vector search engine
    execute("CREATE EXTENSION IF NOT EXISTS lantern CASCADE")

    # Hexagonal hierarchical geospatial indexing
    execute("CREATE EXTENSION IF NOT EXISTS h3 CASCADE")

    # TimescaleDB analytics extension
    execute("CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE")
  end

  def down do
    # Drop extensions in reverse order (respecting dependencies)
    execute("DROP EXTENSION IF EXISTS timescaledb_toolkit CASCADE")
    execute("DROP EXTENSION IF EXISTS h3 CASCADE")
    execute("DROP EXTENSION IF EXISTS lantern CASCADE")
    execute("DROP EXTENSION IF EXISTS pg_net CASCADE")
    execute("DROP EXTENSION IF EXISTS wal2json CASCADE")
    execute("DROP EXTENSION IF EXISTS pgmq CASCADE")
    execute("DROP EXTENSION IF EXISTS pgx_ulid CASCADE")
    execute("DROP EXTENSION IF EXISTS pgsodium CASCADE")
  end
end
