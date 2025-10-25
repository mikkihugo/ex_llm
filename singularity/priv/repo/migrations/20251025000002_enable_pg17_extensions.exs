defmodule Singularity.Repo.Migrations.EnablePg17Extensions do
  use Ecto.Migration

  def up do
    # Modern encryption & hashing (replaces pgcrypto)
    execute("CREATE EXTENSION IF NOT EXISTS pgsodium CASCADE")

    # In-database message queue (alternative to external NATS for some use cases)
    execute("CREATE EXTENSION IF NOT EXISTS pgmq CASCADE")

    # Hexagonal hierarchical geospatial indexing
    execute("CREATE EXTENSION IF NOT EXISTS h3 CASCADE")

    # NOTE: The following extensions are not available in this Nix environment:
    # - pgx_ulid: Use native PostgreSQL UUID or custom ID generation instead
    # - wal2json: Event streaming via NATS is preferred
    # - pg_net: Use Elixir HTTP client (HTTPoison, Finch) instead
    # - lantern: Using pgvector instead (more compatible)
    # - timescaledb_toolkit: Full TimescaleDB not enabled; use basic aggregations
  end

  def down do
    # Drop extensions in reverse order (respecting dependencies)
    execute("DROP EXTENSION IF EXISTS h3 CASCADE")
    execute("DROP EXTENSION IF EXISTS pgmq CASCADE")
    execute("DROP EXTENSION IF EXISTS pgsodium CASCADE")
  end
end
