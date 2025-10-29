defmodule CentralCloud.Repo.Migrations.AddEmbeddingsToPromptTemplates do
  use Ecto.Migration

  def up do
    # Add embedding column for semantic search
    alter table(:prompt_templates) do
      add :embedding, :vector, size: 2560  # Matches CentralCloud's 2560-dim embeddings (Qodo + Jina v3)
    end

    # Create vector index for fast similarity search
    create index(:prompt_templates, :embedding, using: "ivfflat", with: "lists = 100")
  end

  def down do
    drop index(:prompt_templates, :embedding)
    
    alter table(:prompt_templates) do
      remove :embedding
    end
  end
end
