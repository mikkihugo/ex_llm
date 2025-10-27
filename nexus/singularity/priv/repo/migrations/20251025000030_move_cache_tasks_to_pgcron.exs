defmodule Singularity.Repo.Migrations.MoveCacheTasksToPgcron do
  use Ecto.Migration

  def up do
    # Enable pg_cron if not already enabled
    execute("CREATE EXTENSION IF NOT EXISTS pg_cron")

    # ===========================================================================
    # Cache Cleanup Stored Procedure
    # ===========================================================================
    # Pure SQL: Delete expired cache entries
    # Was: CacheCleanupWorker (every 15 min)
    # Now: pg_cron scheduled procedure (every 15 min)
    execute("""
    CREATE OR REPLACE PROCEDURE cleanup_expired_cache_task()
    LANGUAGE SQL
    AS $$
      DELETE FROM package_cache
      WHERE expires_at <= NOW();
    $$;
    """)

    # ===========================================================================
    # Refresh Hot Packages Materialized View
    # ===========================================================================
    # Pure SQL: Refresh materialized view concurrently
    # Was: CacheRefreshWorker (every hour)
    # Now: pg_cron scheduled procedure (every hour)
    execute("""
    CREATE OR REPLACE PROCEDURE refresh_hot_packages_task()
    LANGUAGE SQL
    AS $$
      REFRESH MATERIALIZED VIEW CONCURRENTLY hot_packages;
    $$;
    """)

    # ===========================================================================
    # Prewarm Cache with Hot Packages
    # ===========================================================================
    # Pure SQL: Insert hot packages into cache
    # Was: CachePrewarmWorker (every 6 hours)
    # Now: pg_cron scheduled procedure (every 6 hours)
    execute("""
    CREATE OR REPLACE PROCEDURE prewarm_hot_packages_task()
    LANGUAGE SQL
    AS $$
      INSERT INTO package_cache (cache_key, package_data, expires_at)
      SELECT
        ecosystem || ':' || package_name || ':' || version as cache_key,
        to_jsonb(hot_packages.*) as package_data,
        NOW() + INTERVAL '24 hours' as expires_at
      FROM hot_packages
      ON CONFLICT (cache_key) DO NOTHING;
    $$;
    """)

    # ===========================================================================
    # Schedule Cache Tasks with pg_cron
    # ===========================================================================

    # Every 15 minutes: Clean up expired cache entries
    execute("""
    SELECT cron.schedule('cache-cleanup-expired', '*/15 * * * *', 'CALL cleanup_expired_cache_task();');
    """)

    # Every hour: Refresh hot packages materialized view
    execute("""
    SELECT cron.schedule('cache-refresh-hot-packages', '0 * * * *', 'CALL refresh_hot_packages_task();');
    """)

    # Every 6 hours: Prewarm cache with hot packages
    execute("""
    SELECT cron.schedule('cache-prewarm-hot-packages', '0 */6 * * *', 'CALL prewarm_hot_packages_task();');
    """)
  end

  def down do
    # Remove pg_cron jobs
    execute("""
    SELECT cron.unschedule('cache-cleanup-expired');
    """)

    execute("""
    SELECT cron.unschedule('cache-refresh-hot-packages');
    """)

    execute("""
    SELECT cron.unschedule('cache-prewarm-hot-packages');
    """)

    # Drop procedures
    execute("DROP PROCEDURE IF EXISTS cleanup_expired_cache_task();")
    execute("DROP PROCEDURE IF EXISTS refresh_hot_packages_task();")
    execute("DROP PROCEDURE IF EXISTS prewarm_hot_packages_task();")
  end
end
