defmodule Singularity.Repo.Migrations.CreateGitAndCacheTables do
  use Ecto.Migration

  def change do
    # Git Coordination Tables
    create_if_not_exists table(:git_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_type, :string, null: false
      add :branch_name, :string, null: false
      add :base_branch, :string
      add :status, :string, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS git_sessions_session_type_index
      ON git_sessions (session_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS git_sessions_status_index
      ON git_sessions (status)
    """, "")

    create_if_not_exists table(:git_commits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:git_sessions, type: :binary_id, on_delete: :delete_all)
      add :commit_hash, :string, null: false
      add :message, :text, null: false
      add :author, :string
      add :files_changed, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS git_commits_session_id_index
      ON git_commits (session_id)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS git_commits_commit_hash_key
      ON git_commits (commit_hash)
    """, "")

    # RAG Cache Tables
    create_if_not_exists table(:rag_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_type, :string, null: false
      add :source_id, :string, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 768
      add :metadata, :map, default: %{}
      add :token_count, :integer
      add :last_accessed, :utc_datetime
      add :access_count, :integer, default: 0
      timestamps()
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS rag_documents_source_type_source_id_key
      ON rag_documents (source_type, source_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rag_documents_last_accessed_index
      ON rag_documents (last_accessed)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rag_documents_access_count_index
      ON rag_documents (access_count)
    """, "")

    create_if_not_exists table(:rag_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_text, :text, null: false
      add :query_embedding, :vector, size: 768
      add :result_ids, {:array, :binary_id}, default: []
      add :response, :text
      add :model_used, :string
      add :tokens_used, :integer
      add :latency_ms, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS rag_queries_inserted_at_index
      ON rag_queries (inserted_at)
    """, "")

    create_if_not_exists table(:rag_feedback, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_id, references(:rag_queries, type: :binary_id, on_delete: :delete_all)
      add :document_id, references(:rag_documents, type: :binary_id, on_delete: :delete_all)
      add :relevance_score, :float
      add :user_rating, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS rag_feedback_query_id_index
      ON rag_feedback (query_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rag_feedback_document_id_index
      ON rag_feedback (document_id)
    """, "")

    # Semantic Cache
    create_if_not_exists table(:prompt_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :cache_key, :string, null: false
      add :query, :text, null: false
      add :query_embedding, :vector, size: 768
      add :response, :text, null: false
      add :model, :string
      add :template_id, :string
      add :tokens_used, :integer
      add :cost_cents, :integer
      add :hit_count, :integer, default: 0
      add :last_accessed, :utc_datetime
      add :ttl_seconds, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS prompt_cache_cache_key_key
      ON prompt_cache (cache_key)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS prompt_cache_last_accessed_index
      ON prompt_cache (last_accessed)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS prompt_cache_hit_count_index
      ON prompt_cache (hit_count)
    """, "")

    # Performance Cache Configuration
    execute """
    CREATE OR REPLACE FUNCTION refresh_cache_stats()
    RETURNS void AS $$
    BEGIN
      -- Refresh cache statistics for optimization
      ANALYZE rag_documents;
      ANALYZE prompt_cache;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create hypertable for time-series data if TimescaleDB is available
    # Note: Hypertables require partitioning column in primary key
    # Skipping for now - can be added later with composite keys if needed
    execute """
    DO $$
    BEGIN
      -- TimescaleDB hypertables disabled (requires composite primary key)
      -- Can enable with: ALTER TABLE rag_queries DROP CONSTRAINT rag_queries_pkey;
      -- Then: SELECT create_hypertable('rag_queries', 'inserted_at');
      NULL;
    END $$;
    """
  end
end