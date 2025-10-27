defmodule Singularity.Repo.Migrations.AddMissingVectorIndexes do
  use Ecto.Migration

  @moduledoc """
  Adds HNSW vector indexes for tables with embedding columns.

  These indexes enable fast cosine similarity search on vector embeddings.
  All vector columns use 2560 dimensions (Qodo 1536 + Jina v3 1024 concatenated).
  HNSW index supports higher dimensions better than ivfflat (which maxes out at 2000).

  Tables with vector columns that need indexes:
  - rules.embedding (2560-dim) - Rule semantic search
  - code_embeddings.embedding (2560-dim) - Code chunk search
  - code_locations.embedding (2560-dim) - Symbol location search
  - rag_documents.embedding (2560-dim) - RAG document search
  - rag_queries.query_embedding (2560-dim) - Query similarity
  - prompt_cache.query_embedding (2560-dim) - Cache lookup by similarity
  """

  def up do
    # Vector indexes using HNSW (better for higher dimensions than ivfflat)
    # pgvector now available in Nix environment

    # rules.embedding - For semantic rule matching
    # Created in: 20240101000002_create_core_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rules_embedding_vector ON rules
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """

    # code_embeddings.embedding - For code chunk semantic search
    # Created in: 20240101000004_create_code_analysis_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_code_embeddings_embedding_vector ON code_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """

    # code_locations.embedding - For symbol location semantic search
    # Created in: 20240101000004_create_code_analysis_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_code_locations_embedding_vector ON code_locations
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """

    # rag_documents.embedding - For RAG document retrieval
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rag_documents_embedding_vector ON rag_documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """

    # rag_queries.query_embedding - For finding similar past queries
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_rag_queries_query_embedding_vector ON rag_queries
    USING hnsw (query_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """

    # prompt_cache.query_embedding - For semantic cache lookup
    # Created in: 20240101000005_create_git_and_cache_tables.exs
    execute """
    CREATE INDEX IF NOT EXISTS idx_prompt_cache_query_embedding_vector ON prompt_cache
    USING hnsw (query_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """
  end

  def down do
    # Drop vector indexes in reverse order
    drop_if_exists index(:prompt_cache, [:query_embedding],
      name: :idx_prompt_cache_query_embedding_vector
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
