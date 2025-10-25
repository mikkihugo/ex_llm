defmodule Singularity.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    # Core PostgreSQL extensions
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute ~s(CREATE EXTENSION IF NOT EXISTS "uuid-ossp")

    # Vector and similarity search (pgvector configured in Nix)
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Text search and fuzzy matching
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch CASCADE"
    execute "CREATE EXTENSION IF NOT EXISTS unaccent CASCADE"

    # JSONB indexing
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist"

    # Performance monitoring
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "CREATE EXTENSION IF NOT EXISTS pg_buffercache"
    execute "CREATE EXTENSION IF NOT EXISTS pg_prewarm"

    # Additional useful extensions
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
    execute "CREATE EXTENSION IF NOT EXISTS ltree"

    # TimescaleDB (time-series data) - configured in Nix
    # Disabled for now - causes connection issues in development
    # execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # PostGIS (geospatial) - configured in Nix
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    # Scheduled tasks (pg_cron - configured in setup-database.sh via cron.database_name)
    execute "CREATE EXTENSION IF NOT EXISTS pg_cron"

    # PostgreSQL testing (optional - skip for now)
    # execute "CREATE EXTENSION IF NOT EXISTS pgtap"
  end

  def down do
    # execute "DROP EXTENSION IF EXISTS pgtap"
    execute "DROP EXTENSION IF EXISTS pg_cron"
    execute "DROP EXTENSION IF EXISTS postgis"
    # execute "DROP EXTENSION IF EXISTS timescaledb"  # Disabled - not created in up migration
    execute "DROP EXTENSION IF EXISTS ltree"
    execute "DROP EXTENSION IF EXISTS hstore"
    execute "DROP EXTENSION IF EXISTS pg_prewarm"
    execute "DROP EXTENSION IF EXISTS pg_buffercache"
    execute "DROP EXTENSION IF EXISTS pg_stat_statements"
    execute "DROP EXTENSION IF EXISTS btree_gist"
    execute "DROP EXTENSION IF EXISTS btree_gin"
    execute "DROP EXTENSION IF EXISTS unaccent"
    execute "DROP EXTENSION IF EXISTS fuzzystrmatch"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
    execute "DROP EXTENSION IF EXISTS vector"
    execute ~s(DROP EXTENSION IF EXISTS "uuid-ossp")
    execute "DROP EXTENSION IF EXISTS pgcrypto"
  end
end