defmodule Singularity.Repo.Migrations.RenameCacheTables do
  use Ecto.Migration

  @moduledoc """
  Phase 6: Standardize cache table naming (noun-first pattern)

  BEFORE: cache_code_embeddings (prefix pattern)
  AFTER: code_embedding_cache (noun-first, more readable)

  Also consolidate duplicate cache tables.
  """

  def up do
    # Flip cache prefix to suffix (noun-first pattern)
    execute "ALTER TABLE cache_code_embeddings RENAME TO code_embedding_cache"
    execute "ALTER TABLE cache_llm_responses RENAME TO llm_response_cache"
    execute "ALTER TABLE cache_memory RENAME TO agent_memory_cache"
    execute "ALTER TABLE cache_semantic_similarity RENAME TO semantic_similarity_cache"

    # Note: Check if prompt_cache and vector_similarity_cache are duplicates
    # If so, drop them in a separate migration after data migration

    # Update indexes
    execute """
    ALTER INDEX IF EXISTS cache_code_embeddings_pkey
    RENAME TO code_embedding_cache_pkey
    """
    execute """
    ALTER INDEX IF EXISTS cache_llm_responses_pkey
    RENAME TO llm_response_cache_pkey
    """
    execute """
    ALTER INDEX IF EXISTS cache_memory_pkey
    RENAME TO agent_memory_cache_pkey
    """
    execute """
    ALTER INDEX IF EXISTS cache_semantic_similarity_pkey
    RENAME TO semantic_similarity_cache_pkey
    """
  end

  def down do
    # Reverse index renames
    execute """
    ALTER INDEX IF EXISTS semantic_similarity_cache_pkey
    RENAME TO cache_semantic_similarity_pkey
    """
    execute """
    ALTER INDEX IF EXISTS agent_memory_cache_pkey
    RENAME TO cache_memory_pkey
    """
    execute """
    ALTER INDEX IF EXISTS llm_response_cache_pkey
    RENAME TO cache_llm_responses_pkey
    """
    execute """
    ALTER INDEX IF EXISTS code_embedding_cache_pkey
    RENAME TO cache_code_embeddings_pkey
    """

    # Reverse table renames
    execute "ALTER TABLE semantic_similarity_cache RENAME TO cache_semantic_similarity"
    execute "ALTER TABLE agent_memory_cache RENAME TO cache_memory"
    execute "ALTER TABLE llm_response_cache RENAME TO cache_llm_responses"
    execute "ALTER TABLE code_embedding_cache RENAME TO cache_code_embeddings"
  end
end
