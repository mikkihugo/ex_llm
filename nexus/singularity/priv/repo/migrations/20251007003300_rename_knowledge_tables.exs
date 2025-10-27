defmodule Singularity.Repo.Migrations.RenameKnowledgeTables do
  use Ecto.Migration

  @moduledoc """
  Phase 4: Clarify knowledge table purposes

  BEFORE: Multiple vague "knowledge" tables
  AFTER: Clear distinction between curated vs detected knowledge
  """

  def up do
    # knowledge_artifacts → curated_knowledge_artifacts
    # (Git ↔ DB bidirectional learning - human-curated templates/patterns/prompts)
    execute "ALTER TABLE knowledge_artifacts RENAME TO curated_knowledge_artifacts"

    # technology_knowledge was dropped in migration 20250101000015 (consolidated schema)
    # No need to rename - table doesn't exist

    # Update indexes for knowledge_artifacts only
    execute """
    ALTER INDEX IF EXISTS knowledge_artifacts_pkey
    RENAME TO curated_knowledge_artifacts_pkey
    """
    execute """
    ALTER INDEX IF EXISTS knowledge_artifacts_unique_idx
    RENAME TO curated_knowledge_artifacts_unique_idx
    """
    execute """
    ALTER INDEX IF EXISTS knowledge_artifacts_type_lang_idx
    RENAME TO curated_knowledge_artifacts_type_lang_idx
    """
  end

  def down do
    execute """
    ALTER INDEX IF EXISTS curated_knowledge_artifacts_type_lang_idx
    RENAME TO knowledge_artifacts_type_lang_idx
    """
    execute """
    ALTER INDEX IF EXISTS curated_knowledge_artifacts_unique_idx
    RENAME TO knowledge_artifacts_unique_idx
    """
    execute """
    ALTER INDEX IF EXISTS curated_knowledge_artifacts_pkey
    RENAME TO knowledge_artifacts_pkey
    """

    execute "ALTER TABLE curated_knowledge_artifacts RENAME TO knowledge_artifacts"
  end
end
