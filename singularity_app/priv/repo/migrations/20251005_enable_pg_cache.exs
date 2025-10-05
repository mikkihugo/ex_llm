defmodule Singularity.Repo.Migrations.EnablePgCache do
  use Ecto.Migration

  def up do
    # Enable caching extensions
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "CREATE EXTENSION IF NOT EXISTS pg_buffercache"
    execute "CREATE EXTENSION IF NOT EXISTS pg_prewarm"

    # Configure shared memory cache
    execute "ALTER SYSTEM SET shared_buffers = '4GB'"
    execute "ALTER SYSTEM SET effective_cache_size = '12GB'"
    execute "ALTER SYSTEM SET work_mem = '256MB'"
    execute "ALTER SYSTEM SET maintenance_work_mem = '1GB'"
    execute "ALTER SYSTEM SET max_prepared_transactions = 100"
    execute "ALTER SYSTEM SET max_connections = 200"

    # Reload config
    execute "SELECT pg_reload_conf()"

    # Create query cache table
    execute """
    CREATE TABLE IF NOT EXISTS query_cache (
      query_hash TEXT PRIMARY KEY,
      query_text TEXT NOT NULL,
      result JSONB NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      access_count INTEGER DEFAULT 1,
      execution_time_ms INTEGER
    )
    """

    execute """
    CREATE INDEX IF NOT EXISTS idx_query_cache_accessed
    ON query_cache(accessed_at DESC)
    """

    # Prewarm tables if they exist
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_prewarm') THEN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'code_files') THEN
          PERFORM pg_prewarm('code_files');
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'embeddings') THEN
          PERFORM pg_prewarm('embeddings');
        END IF;
      END IF;
    END $$
    """

    # Cache monitoring view
    execute """
    CREATE OR REPLACE VIEW cache_performance AS
    SELECT
      'Shared Buffer Hit Ratio' as metric,
      ROUND(
        100.0 * SUM(blks_hit) /
        NULLIF(SUM(blks_hit + blks_read), 0),
        2
      ) as percentage
    FROM pg_stat_database
    """
  end

  def down do
    execute "DROP VIEW IF EXISTS cache_performance"
    execute "DROP TABLE IF EXISTS query_cache"

    # Reset to defaults
    execute "ALTER SYSTEM RESET shared_buffers"
    execute "ALTER SYSTEM RESET effective_cache_size"
    execute "ALTER SYSTEM RESET work_mem"
    execute "ALTER SYSTEM RESET maintenance_work_mem"
    execute "SELECT pg_reload_conf()"
  end
end