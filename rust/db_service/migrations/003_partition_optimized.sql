-- Optimized Partitioning for Single Server with Nx/Bumblebee embeddings
-- Works with in-process Elixir embeddings (no pg_vectorize needed!)

-- ============================================
-- SIMPLIFIED PARTITIONING (Single Server)
-- ============================================

-- Keep it simple: partition by repo for parallel queries
-- But don't over-partition (causes overhead on single server)

-- Check current table size first
DO $$
DECLARE
    table_size BIGINT;
    partition_count INT;
BEGIN
    -- Get table size
    SELECT pg_total_relation_size('code_files')::BIGINT INTO table_size;

    -- Calculate optimal partitions based on size
    -- Rule: ~1GB per partition for optimal performance
    partition_count := GREATEST(4, LEAST(32, (table_size / (1024^3))::INT));

    RAISE NOTICE 'Table size: % GB, creating % partitions',
        (table_size / (1024^3))::INT, partition_count;
END $$;

-- Create simpler hash partitioning (4-8 partitions is plenty for single server)
ALTER TABLE IF EXISTS code_files RENAME TO code_files_old_backup;

CREATE TABLE code_files (
    id BIGSERIAL,
    file_path TEXT NOT NULL,
    content TEXT,
    language TEXT,
    metadata JSONB DEFAULT '{}',
    repo_name TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    hash TEXT GENERATED ALWAYS AS (encode(sha256(content::bytea), 'hex')) STORED,
    size_bytes INTEGER GENERATED ALWAYS AS (octet_length(content)) STORED,
    PRIMARY KEY (id, repo_name)
) PARTITION BY HASH (repo_name);

-- Create just 8 partitions (good for 8-16 CPU cores)
CREATE TABLE code_files_p0 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 0);
CREATE TABLE code_files_p1 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 1);
CREATE TABLE code_files_p2 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 2);
CREATE TABLE code_files_p3 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 3);
CREATE TABLE code_files_p4 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 4);
CREATE TABLE code_files_p5 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 5);
CREATE TABLE code_files_p6 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 6);
CREATE TABLE code_files_p7 PARTITION OF code_files FOR VALUES WITH (modulus 8, remainder 7);

-- ============================================
-- EMBEDDINGS TABLE (384 dims for MiniLM)
-- ============================================

ALTER TABLE IF EXISTS embeddings RENAME TO embeddings_old_backup;

CREATE TABLE embeddings (
    id BIGSERIAL,
    path TEXT NOT NULL,
    embedding vector(256),  -- CodeT5+ outputs 256 dimensions (faster!)
    model TEXT DEFAULT 'Salesforce/codet5p-110m-embedding',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    repo_name TEXT NOT NULL,
    -- Add embedding hash for dedup
    embedding_hash TEXT GENERATED ALWAYS AS (
        encode(sha256(embedding::text::bytea), 'hex')
    ) STORED,
    PRIMARY KEY (id, repo_name)
) PARTITION BY HASH (repo_name);

-- Same partition scheme
CREATE TABLE embeddings_p0 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 0);
CREATE TABLE embeddings_p1 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 1);
CREATE TABLE embeddings_p2 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 2);
CREATE TABLE embeddings_p3 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 3);
CREATE TABLE embeddings_p4 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 4);
CREATE TABLE embeddings_p5 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 5);
CREATE TABLE embeddings_p6 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 6);
CREATE TABLE embeddings_p7 PARTITION OF embeddings FOR VALUES WITH (modulus 8, remainder 7);

-- ============================================
-- HNSW INDEXES (Critical for speed!)
-- ============================================

-- Create HNSW on each partition
CREATE INDEX embeddings_p0_hnsw ON embeddings_p0 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p1_hnsw ON embeddings_p1 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p2_hnsw ON embeddings_p2 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p3_hnsw ON embeddings_p3 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p4_hnsw ON embeddings_p4 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p5_hnsw ON embeddings_p5 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p6_hnsw ON embeddings_p6 USING hnsw (embedding vector_cosine_ops);
CREATE INDEX embeddings_p7_hnsw ON embeddings_p7 USING hnsw (embedding vector_cosine_ops);

-- ============================================
-- BLOOM FILTER TABLE (For ultra-fast dedup)
-- ============================================

CREATE TABLE IF NOT EXISTS bloom_filters (
    id SERIAL PRIMARY KEY,
    filter_name TEXT UNIQUE NOT NULL,
    filter_data BYTEA NOT NULL,
    item_count BIGINT DEFAULT 0,
    false_positive_rate FLOAT DEFAULT 0.01,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Store bloom filter for code hashes
INSERT INTO bloom_filters (filter_name, filter_data, item_count)
VALUES ('code_hashes', '\x00', 0)
ON CONFLICT (filter_name) DO NOTHING;

-- ============================================
-- OPTIMIZED SEARCH FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION search_similar_code_fast(
    query_embedding vector(256),
    target_language TEXT DEFAULT NULL,
    target_repos TEXT[] DEFAULT NULL,
    limit_results INT DEFAULT 10
)
RETURNS TABLE (
    file_path TEXT,
    content TEXT,
    language TEXT,
    repo_name TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
PARALLEL SAFE
AS $$
BEGIN
    -- Enable parallel execution
    SET LOCAL max_parallel_workers_per_gather = 4;
    SET LOCAL work_mem = '256MB';

    RETURN QUERY
    WITH fast_search AS (
        SELECT
            cf.file_path,
            cf.content,
            cf.language,
            cf.repo_name,
            1 - (e.embedding <=> query_embedding) AS similarity
        FROM embeddings e
        JOIN code_files cf
            ON cf.file_path = e.path
            AND cf.repo_name = e.repo_name
        WHERE
            (target_language IS NULL OR cf.language = target_language)
            AND (target_repos IS NULL OR cf.repo_name = ANY(target_repos))
        ORDER BY e.embedding <=> query_embedding
        LIMIT limit_results
    )
    SELECT * FROM fast_search;
END;
$$;

-- ============================================
-- SINGLE SERVER OPTIMIZATIONS
-- ============================================

-- Settings for single powerful server (adjust for your hardware)
ALTER SYSTEM SET shared_buffers = '8GB';           -- 25% of 32GB RAM
ALTER SYSTEM SET effective_cache_size = '24GB';    -- 75% of RAM
ALTER SYSTEM SET maintenance_work_mem = '1GB';
ALTER SYSTEM SET work_mem = '128MB';

-- Parallel settings (for 8-16 cores)
ALTER SYSTEM SET max_worker_processes = 8;
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
ALTER SYSTEM SET max_parallel_workers = 8;

-- pgvector optimizations
ALTER SYSTEM SET hnsw.ef_search = 100;  -- Higher accuracy
ALTER SYSTEM SET ivfflat.probes = 10;   -- If using IVFFlat

-- Apply
SELECT pg_reload_conf();

-- ============================================
-- MIGRATE DATA (if exists)
-- ============================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'code_files_old_backup') THEN
        INSERT INTO code_files (file_path, content, language, metadata, repo_name, updated_at)
        SELECT file_path, content, language, metadata, repo_name, updated_at
        FROM code_files_old_backup;

        RAISE NOTICE 'Migrated % rows', (SELECT COUNT(*) FROM code_files_old_backup);
    END IF;
END $$;

-- ============================================
-- MONITORING VIEW
-- ============================================

CREATE OR REPLACE VIEW rag_performance AS
SELECT
    'code_files' as table_name,
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('code_files')) as total_size,
    COUNT(DISTINCT repo_name) as unique_repos,
    COUNT(DISTINCT language) as unique_languages
FROM code_files
UNION ALL
SELECT
    'embeddings' as table_name,
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('embeddings')) as total_size,
    COUNT(DISTINCT repo_name) as unique_repos,
    COUNT(DISTINCT model) as unique_models
FROM embeddings;

-- Check it worked
SELECT * FROM rag_performance;