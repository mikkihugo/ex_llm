defmodule Singularity.Repo.Migrations.AddMissingVectorIndexes do
  use Ecto.Migration

  @moduledoc """
  Adds missing ivfflat vector indexes for existing tables with embedding columns.

  These indexes enable fast cosine similarity search on vector embeddings.
  All existing vector columns use 768 dimensions (Google text-embedding-004).

  Tables with vector columns that need indexes:
  - rules.embedding (768-dim) - Rule semantic search
  - code_embeddings.embedding (768-dim) - Code chunk search
  - code_locations.embedding (768-dim) - Symbol location search
  - rag_documents.embedding (768-dim) - RAG document search
  - rag_queries.query_embedding (768-dim) - Query similarity
  - semantic_cache.query_embedding (768-dim) - Cache lookup by similarity
  """

  def up do
    # rules.embedding - For semantic rule matching
    # Created in: 20240101000002_create_core_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rules_embedding_vector ON rules 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # code_embeddings.embedding - For code chunk semantic search
    # Created in: 20240101000004_create_code_analysis_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_code_embeddings_embedding_vector ON code_embeddings 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # code_locations.embedding - For symbol location semantic search
    # Created in: 20240101000004_create_code_analysis_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_code_locations_embedding_vector ON code_locations 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # rag_documents.embedding - For RAG document retrieval
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rag_documents_embedding_vector ON rag_documents 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # rag_queries.query_embedding - For finding similar past queries
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rag_queries_query_embedding_vector ON rag_queries 
    USING ivfflat (query_embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # semantic_cache.query_embedding - For semantic cache lookup
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_semantic_cache_query_embedding_vector ON semantic_cache 
    USING ivfflat (query_embedding vector_cosine_ops) 
    WITH (lists = 100)
    """
  end

  def down do
    # Drop vector indexes in reverse order
    drop_if_exists index(:semantic_cache, [:query_embedding],
      name: :idx_semantic_cache_query_embedding_vector
    )

    drop_if_exists index(:rag_queries, [:query_embedding],
      name: :idx_rag_queries_query_embedding_vector
    )

    drop_if_exists index(:rag_documents, [:embedding],
      name: :idx_rag_documents_embedding_vector
    )

    drop_if_exists index(:code_locations, [:embedding],
      name: :idx_code_locations_embedding_vector
    )

    drop_if_exists index(:code_embeddings, [:embedding],
      name: :idx_code_embeddings_embedding_vector
    )

    drop_if_exists index(:rules, [:embedding],
      name: :idx_rules_embedding_vector
    )
  end
end
