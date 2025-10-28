defmodule Singularity.Repo.Migrations.AddMissingVectorIndexes do
  use Ecto.Migration

  @moduledoc """
  Adds ivfflat vector indexes for tables with embedding columns.

  These indexes enable fast cosine similarity search on vector embeddings.
  All vector columns use 2560 dimensions (Qodo 1536 + Jina v3 1024 concatenated).
  ivfflat index supports high dimensions (no 2000-dim limit like HNSW).

  Tables with vector columns that need indexes:
  - rules.embedding (2560-dim) - Rule semantic search
  - code_embeddings.embedding (2560-dim) - Code chunk search
  - code_locations.embedding (2560-dim) - Symbol location search
  - rag_documents.embedding (2560-dim) - RAG document search
  - rag_queries.query_embedding (2560-dim) - Query similarity
  - prompt_cache.query_embedding (2560-dim) - Cache lookup by similarity
  """

  def up do
    # Vector indexes DISABLED - Both HNSW and ivfflat support max 2000 dimensions
    # Our vectors are 2560-dim (Qodo 1536 + Jina 1024), exceeding index limits
    # Vector search relies on sequential scan (acceptable for system size)
    # Migration kept for schema/tool compatibility (no-op in production)

    nil  # No-op: vector indexes cannot be created with 2560-dim vectors
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
