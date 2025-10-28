defmodule Singularity.Repo.Migrations.EnablePg17Extensions do
  use Ecto.Migration

  def up do
    # Try to enable optional extensions (may not be available)
    execute("""
    DO $$
    BEGIN
      -- Modern encryption & hashing (replaces pgcrypto)
      CREATE EXTENSION IF NOT EXISTS pgsodium CASCADE;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgsodium extension not available - skipping';
    END $$
    """)

    execute("""
    DO $$
    BEGIN
      -- In-database message queue (alternative to external NATS for some use cases)
      CREATE EXTENSION IF NOT EXISTS pgmq CASCADE;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgmq extension not available - skipping';
    END $$
    """)

    execute("""
    DO $$
    BEGIN
      -- Hexagonal hierarchical geospatial indexing
      CREATE EXTENSION IF NOT EXISTS h3 CASCADE;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'h3 extension not available - skipping';
    END $$
    """)

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
