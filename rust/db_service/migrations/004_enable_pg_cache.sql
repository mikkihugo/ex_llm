-- Enable ALL PostgreSQL caching and performance extensions
-- Run this to supercharge your PostgreSQL with in-memory caching!

-- ============================================
-- 1. ENABLE CACHING EXTENSIONS
-- ============================================

-- pg_stat_statements - Track query performance
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- pg_buffercache - Monitor shared buffer cache
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

-- pg_prewarm - Preload tables into cache
CREATE EXTENSION IF NOT EXISTS pg_prewarm;

-- pgfincore - Manage OS page cache
-- CREATE EXTENSION IF NOT EXISTS pgfincore;  -- May need separate install

-- ============================================
-- 2. CONFIGURE SHARED MEMORY CACHE
-- ============================================

-- Increase shared buffers (in-memory cache)
ALTER SYSTEM SET shared_buffers = '4GB';          -- 25% of RAM for cache
ALTER SYSTEM SET effective_cache_size = '12GB';   -- 75% of RAM

-- Query result caching
ALTER SYSTEM SET work_mem = '256MB';              -- Per operation memory
ALTER SYSTEM SET maintenance_work_mem = '1GB';    -- For index builds

-- ============================================
-- 3. ENABLE QUERY RESULT CACHING
-- ============================================

-- Statement-level caching
ALTER SYSTEM SET statement_timeout = 0;
ALTER SYSTEM SET lock_timeout = 0;
ALTER SYSTEM SET idle_in_transaction_session_timeout = 0;
ALTER SYSTEM SET temp_buffers = '32MB';

-- Prepared statement caching
ALTER SYSTEM SET max_prepared_transactions = 100;

-- ============================================
-- 4. CONNECTION POOLING & CACHING
-- ============================================

-- pgBouncer configuration (external but important)
-- Connection pooling reduces overhead
ALTER SYSTEM SET max_connections = 200;

-- ============================================
-- 5. PREWARM CRITICAL TABLES
-- ============================================

-- Reload config
SELECT pg_reload_conf();

-- Prewarm tables into cache
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_prewarm') THEN
        -- Prewarm code_files table
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'code_files') THEN
            PERFORM pg_prewarm('code_files');
        END IF;

        -- Prewarm embeddings table
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'embeddings') THEN
            PERFORM pg_prewarm('embeddings');
        END IF;

        -- Prewarm indexes
        PERFORM pg_prewarm(c.oid)
        FROM pg_class c
        JOIN pg_index i ON i.indexrelid = c.oid
        WHERE c.relname LIKE '%hnsw%' OR c.relname LIKE '%embedding%';
    END IF;
END $$;

-- ============================================
-- 6. CREATE RESULT CACHE TABLE
-- ============================================

-- Manual query result cache
CREATE TABLE IF NOT EXISTS query_cache (
    query_hash TEXT PRIMARY KEY,
    query_text TEXT NOT NULL,
    result JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    access_count INTEGER DEFAULT 1,
    execution_time_ms INTEGER
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_query_cache_accessed
ON query_cache(accessed_at DESC);

-- Function to use cache
CREATE OR REPLACE FUNCTION cached_query(
    query_text TEXT,
    cache_ttl INTERVAL DEFAULT '1 hour'
)
RETURNS JSONB AS $$
DECLARE
    query_hash TEXT;
    cached_result JSONB;
    start_time TIMESTAMP;
    exec_time INTEGER;
BEGIN
    -- Generate hash of query
    query_hash := encode(digest(query_text, 'md5'), 'hex');

    -- Check cache
    SELECT result INTO cached_result
    FROM query_cache
    WHERE query_cache.query_hash = cached_query.query_hash
      AND created_at > CURRENT_TIMESTAMP - cache_ttl;

    IF cached_result IS NOT NULL THEN
        -- Update access stats
        UPDATE query_cache
        SET accessed_at = CURRENT_TIMESTAMP,
            access_count = access_count + 1
        WHERE query_cache.query_hash = cached_query.query_hash;

        RETURN cached_result;
    END IF;

    -- Execute query and cache result
    start_time := clock_timestamp();
    EXECUTE query_text INTO cached_result;
    exec_time := EXTRACT(MILLISECOND FROM clock_timestamp() - start_time);

    -- Store in cache
    INSERT INTO query_cache (query_hash, query_text, result, execution_time_ms)
    VALUES (query_hash, query_text, cached_result, exec_time)
    ON CONFLICT (query_hash) DO UPDATE
    SET result = EXCLUDED.result,
        created_at = CURRENT_TIMESTAMP,
        execution_time_ms = EXCLUDED.execution_time_ms;

    RETURN cached_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. MONITOR CACHE PERFORMANCE
-- ============================================

-- View to monitor cache hit ratio
CREATE OR REPLACE VIEW cache_performance AS
SELECT
    'Shared Buffer Hit Ratio' as metric,
    ROUND(
        100.0 * SUM(blks_hit) /
        NULLIF(SUM(blks_hit + blks_read), 0),
        2
    ) as percentage
FROM pg_stat_database
UNION ALL
SELECT
    'Query Cache Hit Ratio' as metric,
    ROUND(
        100.0 * SUM(access_count - 1) /
        NULLIF(SUM(access_count), 0),
        2
    ) as percentage
FROM query_cache;

-- Function to show what's in cache
CREATE OR REPLACE FUNCTION show_cache_contents()
RETURNS TABLE (
    tablename TEXT,
    size_in_cache TEXT,
    percentage_cached NUMERIC
) AS $$
SELECT
    schemaname || '.' || tablename as tablename,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as size_in_cache,
    ROUND(100.0 * pg_relation_size(schemaname||'.'||tablename) /
          NULLIF(pg_database_size(current_database()), 0), 2) as percentage_cached
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
$$ LANGUAGE sql;

-- ============================================
-- 8. CLEANUP OLD CACHE ENTRIES
-- ============================================

-- Automatic cache cleanup
CREATE OR REPLACE FUNCTION cleanup_query_cache()
RETURNS void AS $$
BEGIN
    -- Delete old cache entries (>7 days)
    DELETE FROM query_cache
    WHERE accessed_at < CURRENT_TIMESTAMP - INTERVAL '7 days';

    -- Delete rarely used entries when cache is large
    DELETE FROM query_cache
    WHERE query_hash IN (
        SELECT query_hash
        FROM query_cache
        WHERE access_count < 3
        ORDER BY accessed_at ASC
        LIMIT 1000
    )
    AND (SELECT COUNT(*) FROM query_cache) > 10000;
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (requires pg_cron)
-- SELECT cron.schedule('cleanup-cache', '0 */6 * * *', 'SELECT cleanup_query_cache()');

-- ============================================
-- VERIFY SETUP
-- ============================================

-- Check enabled extensions
SELECT name, setting
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'max_connections'
);

-- Show cache stats
SELECT * FROM cache_performance;

-- Show what's cached
SELECT * FROM show_cache_contents();