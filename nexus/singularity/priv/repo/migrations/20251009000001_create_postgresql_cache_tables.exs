defmodule Singularity.Repo.Migrations.CreatePostgresqlCacheTables do
  use Ecto.Migration

  def up do
    # ============================================================================
    # UNLOGGED TABLE - Fast cache storage (volatile, like Redis)
    # ============================================================================

    execute """
    CREATE UNLOGGED TABLE package_cache (
      cache_key TEXT PRIMARY KEY,
      package_data JSONB NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      hit_count INTEGER DEFAULT 0
    )
    """

    # Index for expiration cleanup (index all rows for efficient cleanup queries)
    # Note: Can't use WHERE expires_at > NOW() because NOW() is not IMMUTABLE
    execute """
    CREATE INDEX idx_package_cache_expires
    ON package_cache(expires_at)
    """

    # Index for most accessed items
    execute """
    CREATE INDEX idx_package_cache_hits
    ON package_cache(hit_count DESC)
    """

    # ============================================================================
    # Cache cleanup function
    # ============================================================================

    execute """
    CREATE OR REPLACE FUNCTION cleanup_expired_cache()
    RETURNS INTEGER AS $$
    DECLARE
      deleted_count INTEGER;
    BEGIN
      DELETE FROM package_cache WHERE expires_at < NOW();
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RETURN deleted_count;
    END;
    $$ LANGUAGE plpgsql;
    """

    # ============================================================================
    # Cache statistics function
    # ============================================================================

    execute """
    CREATE OR REPLACE FUNCTION cache_stats()
    RETURNS TABLE(
      total_entries BIGINT,
      expired_entries BIGINT,
      valid_entries BIGINT,
      total_size_mb NUMERIC,
      avg_hit_count NUMERIC
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT
        COUNT(*)::BIGINT as total_entries,
        COUNT(*) FILTER (WHERE expires_at < NOW())::BIGINT as expired_entries,
        COUNT(*) FILTER (WHERE expires_at >= NOW())::BIGINT as valid_entries,
        ROUND(pg_total_relation_size('package_cache')::NUMERIC / 1024 / 1024, 2) as total_size_mb,
        ROUND(AVG(hit_count)::NUMERIC, 2) as avg_hit_count
      FROM package_cache;
    END;
    $$ LANGUAGE plpgsql;
    """

    # ============================================================================
    # MATERIALIZED VIEW - Hot packages cache
    # ============================================================================

    execute """
    CREATE MATERIALIZED VIEW hot_packages AS
    SELECT
      package_name,
      version,
      ecosystem,
      description,
      github_stars,
      download_count,
      tags
    FROM dependency_catalog
    WHERE
      github_stars > 1000
      OR download_count > 100000
    ORDER BY
      COALESCE(github_stars, 0) DESC,
      COALESCE(download_count, 0) DESC
    LIMIT 5000
    WITH DATA
    """

    # Unique index for CONCURRENT refresh
    execute """
    CREATE UNIQUE INDEX idx_hot_packages_unique
    ON hot_packages(package_name, ecosystem, version)
    """

    # GIN index for tag search
    execute """
    CREATE INDEX idx_hot_packages_tags
    ON hot_packages USING GIN(tags)
    """

    # Vector similarity index disabled - embedding column not selected in view
    # execute """
    # CREATE INDEX idx_hot_packages_embedding
    # ON hot_packages USING ivfflat (embedding vector_cosine_ops)
    # WITH (lists = 100)
    # """

    # ============================================================================
    # Enable extensions for monitoring
    # ============================================================================

    execute "CREATE EXTENSION IF NOT EXISTS pg_prewarm"
    execute "CREATE EXTENSION IF NOT EXISTS pg_buffercache"

    # ============================================================================
    # Schedule automatic refresh (if pg_cron is available)
    # ============================================================================

    # Uncomment if pg_cron is installed:
    # execute """
    # SELECT cron.schedule(
    #   'refresh-hot-packages',
    #   '0 * * * *',  -- Every hour
    #   $$REFRESH MATERIALIZED VIEW CONCURRENTLY hot_packages$$
    # )
    # """
    #
    # execute """
    # SELECT cron.schedule(
    #   'cleanup-expired-cache',
    #   '*/15 * * * *',  -- Every 15 minutes
    #   $$SELECT cleanup_expired_cache()$$
    # )
    # """
  end

  def down do
    # Drop materialized view
    execute "DROP MATERIALIZED VIEW IF EXISTS hot_packages CASCADE"

    # Drop functions
    execute "DROP FUNCTION IF EXISTS cache_stats() CASCADE"
    execute "DROP FUNCTION IF EXISTS cleanup_expired_cache() CASCADE"

    # Drop cache table
    execute "DROP TABLE IF EXISTS package_cache CASCADE"

    # Note: We don't drop extensions as other tables might use them
    # execute "DROP EXTENSION IF EXISTS pg_prewarm"
    # execute "DROP EXTENSION IF EXISTS pg_buffercache"
  end
end
