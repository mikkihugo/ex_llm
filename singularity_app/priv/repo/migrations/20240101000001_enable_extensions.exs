defmodule Singularity.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    # Core PostgreSQL extensions
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute "CREATE EXTENSION IF NOT EXISTS uuid-ossp"

    # Vector and similarity search
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Text search and fuzzy matching
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch"
    execute "CREATE EXTENSION IF NOT EXISTS unaccent"

    # JSONB indexing
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist"

    # Time-series data
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # Performance monitoring
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "CREATE EXTENSION IF NOT EXISTS pg_buffercache"
    execute "CREATE EXTENSION IF NOT EXISTS pg_prewarm"

    # Additional useful extensions
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
    execute "CREATE EXTENSION IF NOT EXISTS ltree"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS ltree"
    execute "DROP EXTENSION IF EXISTS hstore"
    execute "DROP EXTENSION IF EXISTS pg_prewarm"
    execute "DROP EXTENSION IF EXISTS pg_buffercache"
    execute "DROP EXTENSION IF EXISTS pg_stat_statements"
    execute "DROP EXTENSION IF EXISTS timescaledb"
    execute "DROP EXTENSION IF EXISTS btree_gist"
    execute "DROP EXTENSION IF EXISTS btree_gin"
    execute "DROP EXTENSION IF EXISTS unaccent"
    execute "DROP EXTENSION IF EXISTS fuzzystrmatch"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
    execute "DROP EXTENSION IF EXISTS vector"
    execute "DROP EXTENSION IF EXISTS uuid-ossp"
    execute "DROP EXTENSION IF EXISTS pgcrypto"
  end
end