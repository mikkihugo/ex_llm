defmodule Singularity.Repo.Migrations.AddRagCache do
  use Ecto.Migration

  def up do
    # Enable pg_ivm for incremental materialized views
    execute "CREATE EXTENSION IF NOT EXISTS pg_ivm"

    # Create incremental materialized view for RAG cache
    execute """
    CREATE INCREMENTAL MATERIALIZED VIEW rag_query_cache AS
    SELECT
      e.embedding <=> e.embedding as zero_dist,  -- Trick to force column
      cf.language,
      cf.repo_name,
      COUNT(*) as match_count,
      AVG(LENGTH(cf.content)) as avg_content_size,
      array_agg(DISTINCT cf.id ORDER BY cf.updated_at DESC) as file_ids
    FROM embeddings e
    JOIN code_files cf ON cf.file_path = e.path
    WHERE cf.updated_at > CURRENT_DATE - INTERVAL '7 days'
    GROUP BY e.embedding, cf.language, cf.repo_name
    """

    # Create indexes for fast lookups
    execute "CREATE INDEX rag_cache_language_idx ON rag_query_cache (language)"
    execute "CREATE INDEX rag_cache_repo_idx ON rag_query_cache (repo_name)"

    # Create semantic cache table for LLM responses
    execute """
    CREATE TABLE llm_semantic_cache (
      id BIGSERIAL PRIMARY KEY,
      query_embedding vector(768) NOT NULL,
      query_text TEXT NOT NULL,
      response TEXT NOT NULL,
      model TEXT NOT NULL,
      cost_usd DECIMAL(10, 6),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      access_count INTEGER DEFAULT 1
    )
    """

    # HNSW index for semantic similarity
    execute """
    CREATE INDEX llm_cache_embedding_idx ON llm_semantic_cache
    USING hnsw (query_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """

    # Function to check cache before LLM call
    execute """
    CREATE OR REPLACE FUNCTION check_llm_cache(
      query_embedding vector(768),
      similarity_threshold FLOAT DEFAULT 0.95
    )
    RETURNS TABLE (
      cached_response TEXT,
      similarity FLOAT,
      model TEXT,
      saved_cost_usd DECIMAL
    )
    LANGUAGE plpgsql
    AS $$
    BEGIN
      -- Update access stats for cache hits
      UPDATE llm_semantic_cache
      SET
        accessed_at = CURRENT_TIMESTAMP,
        access_count = access_count + 1
      WHERE id IN (
        SELECT id
        FROM llm_semantic_cache
        WHERE 1 - (query_embedding <=> $1) >= similarity_threshold
        ORDER BY query_embedding <=> $1
        LIMIT 1
      );

      -- Return cached result if found
      RETURN QUERY
      SELECT
        response as cached_response,
        1 - (query_embedding <=> $1) as similarity,
        model,
        cost_usd as saved_cost_usd
      FROM llm_semantic_cache
      WHERE 1 - (query_embedding <=> $1) >= similarity_threshold
      ORDER BY query_embedding <=> $1
      LIMIT 1;
    END;
    $$
    """

    # Cache eviction for old/unused entries
    execute """
    CREATE OR REPLACE FUNCTION cleanup_llm_cache()
    RETURNS void
    LANGUAGE plpgsql
    AS $$
    BEGIN
      -- Delete old, rarely accessed cache entries
      DELETE FROM llm_semantic_cache
      WHERE accessed_at < CURRENT_DATE - INTERVAL '30 days'
        AND access_count < 3;

      -- Keep only top 100k most used entries
      DELETE FROM llm_semantic_cache
      WHERE id NOT IN (
        SELECT id FROM llm_semantic_cache
        ORDER BY access_count DESC, accessed_at DESC
        LIMIT 100000
      );
    END;
    $$
    """

    # Performance tracking table
    execute """
    CREATE TABLE rag_performance_stats (
      id BIGSERIAL PRIMARY KEY,
      query_type TEXT NOT NULL,
      execution_time_ms INTEGER NOT NULL,
      rows_returned INTEGER,
      cache_hit BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    )
    """

    # Create hypertable if TimescaleDB is available
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        PERFORM create_hypertable('rag_performance_stats', 'created_at',
          chunk_time_interval => interval '1 day',
          if_not_exists => TRUE);
      END IF;
    END $$
    """

    # Add compression policy for old stats
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        PERFORM add_compression_policy('rag_performance_stats', interval '7 days',
          if_not_exists => TRUE);
      END IF;
    END $$
    """
  end

  def down do
    execute "DROP MATERIALIZED VIEW IF EXISTS rag_query_cache CASCADE"
    execute "DROP TABLE IF EXISTS llm_semantic_cache CASCADE"
    execute "DROP TABLE IF EXISTS rag_performance_stats CASCADE"
    execute "DROP FUNCTION IF EXISTS check_llm_cache CASCADE"
    execute "DROP FUNCTION IF EXISTS cleanup_llm_cache CASCADE"
    execute "DROP EXTENSION IF EXISTS pg_ivm"
  end
end