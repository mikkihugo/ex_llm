defmodule Singularity.Repo.Migrations.CreateGitAndCacheTables do
  use Ecto.Migration

  def change do
    # Git Coordination Tables
    create table(:git_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_type, :string, null: false
      add :branch_name, :string, null: false
      add :base_branch, :string
      add :status, :string, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:git_sessions, [:session_type])
    create index(:git_sessions, [:status])

    create table(:git_commits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:git_sessions, type: :binary_id, on_delete: :delete_all)
      add :commit_hash, :string, null: false
      add :message, :text, null: false
      add :author, :string
      add :files_changed, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:git_commits, [:session_id])
    create unique_index(:git_commits, [:commit_hash])

    # RAG Cache Tables
    create table(:rag_documents, primary_key: false) do
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

    create unique_index(:rag_documents, [:source_type, :source_id])
    create index(:rag_documents, [:last_accessed])
    create index(:rag_documents, [:access_count])

    create table(:rag_queries, primary_key: false) do
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

    create index(:rag_queries, [:inserted_at])

    create table(:rag_feedback, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_id, references(:rag_queries, type: :binary_id, on_delete: :delete_all)
      add :document_id, references(:rag_documents, type: :binary_id, on_delete: :delete_all)
      add :relevance_score, :float
      add :user_rating, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:rag_feedback, [:query_id])
    create index(:rag_feedback, [:document_id])

    # Semantic Cache
    create table(:semantic_cache, primary_key: false) do
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

    create unique_index(:semantic_cache, [:cache_key])
    create index(:semantic_cache, [:last_accessed])
    create index(:semantic_cache, [:hit_count])

    # Performance Cache Configuration
    execute """
    CREATE OR REPLACE FUNCTION refresh_cache_stats()
    RETURNS void AS $$
    BEGIN
      -- Refresh cache statistics for optimization
      ANALYZE rag_documents;
      ANALYZE semantic_cache;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create hypertable for time-series data if TimescaleDB is available
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        PERFORM create_hypertable('rag_queries', 'inserted_at', if_not_exists => TRUE);
        PERFORM create_hypertable('llm_calls', 'inserted_at', if_not_exists => TRUE);
      END IF;
    END $$;
    """
  end
end