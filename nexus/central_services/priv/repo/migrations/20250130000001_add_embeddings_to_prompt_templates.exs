defmodule CentralCloud.Repo.Migrations.AddEmbeddingsToPromptTemplates do
  use Ecto.Migration

  def up do
    # Add embedding column for semantic search
    alter table(:prompt_templates) do
      add :embedding, :vector, size: 2560  # Matches CentralCloud's 2560-dim embeddings (Qodo + Jina v3)
    end

    # Create vector index for fast similarity search
    execute """
    DO $$
    DECLARE
      max_dims CONSTANT INTEGER := 2000;
      embedding_dims CONSTANT INTEGER := 2560;
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
        RAISE NOTICE 'vector extension not available - skipping embedding index';
        RETURN;
      END IF;

      IF embedding_dims > max_dims THEN
        RAISE NOTICE 'Skipping ivfflat index: embedding dimension % exceeds ivfflat limit %', embedding_dims, max_dims;
        RETURN;
      END IF;

      EXECUTE '
        CREATE INDEX IF NOT EXISTS prompt_templates_embedding_idx
        ON prompt_templates
        USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100)
      ';
    END $$;
    """
  end

  def down do
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = 'prompt_templates_embedding_idx'
      ) THEN
        EXECUTE 'DROP INDEX IF EXISTS prompt_templates_embedding_idx';
      END IF;
    END $$;
    """
    
    alter table(:prompt_templates) do
      remove :embedding
    end
  end
end
