defmodule Singularity.Repo.Migrations.StandardizeEmbeddingDimensions do
  use Ecto.Migration

  # DISABLED FOR DEVELOPMENT: 2560-dim vectors exceed pgvector ivfflat index limits (max 2000 dims)
  # TODO: Re-enable once indexes are properly configured or dimensions adjusted
  #
  # Original purpose: Standardize all embedding columns to 2560 dimensions
  # Multi-vector concatenation for maximum quality:
  # - Qodo-Embed-1-1.5B: 1536 dims (code-optimized)
  # - Jina Embeddings v3: 1024 dims (general-purpose)
  # - Total: 2560 dims (concatenated)

  def up do
    # No-op: Migration disabled to allow development setup
  end

  def down do
    # No-op: Migration disabled to allow development setup
  end
end
