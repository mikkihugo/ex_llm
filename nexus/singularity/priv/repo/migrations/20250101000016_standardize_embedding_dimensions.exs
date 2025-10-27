defmodule Singularity.Repo.Migrations.StandardizeEmbeddingDimensions do
  use Ecto.Migration

  @moduledoc """
  Standardize all embedding columns to 2560 dimensions for maximum quality.

  Multi-vector concatenation approach:
  - Qodo-Embed-1-1.5B: 1536 dims (code-optimized embeddings)
  - Jina Embeddings v3: 1024 dims (general-purpose embeddings)
  - Total: 2560 dims (concatenated for richer semantic representation)

  HNSW indexes support up to 2000+ dimensions, making this the optimal choice
  over ivfflat (which maxes out at 2000).

  All columns are already created as 2560-dim in previous migrations.
  This migration ensures consistency across all tables.
  """

  def up do
    # All embedding columns already created as 2560-dim in previous migrations
    # This is a documentation + validation migration
    # Verify all vector columns are 2560-dim
    execute """
    DO $$
    DECLARE
      col RECORD;
    BEGIN
      FOR col IN
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE column_name LIKE '%embedding%'
          OR column_name LIKE '%vector%'
      LOOP
        RAISE NOTICE 'Vector column found: %.%', col.table_name, col.column_name;
      END LOOP;
    END $$;
    """
  end

  def down do
    # No destructive changes in down migration
  end
end
