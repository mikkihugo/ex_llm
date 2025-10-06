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

    # technology_knowledge → detected_technology_knowledge
    # (Auto-detected from codebase scanning)
    execute "ALTER TABLE technology_knowledge RENAME TO detected_technology_knowledge"

    # tool_knowledge was already renamed to package_registry_knowledge in Phase 1
    # (See migration 20251007003000)

    # Update indexes
    execute """
    ALTER INDEX IF EXISTS knowledge_artifacts_pkey
    RENAME TO curated_knowledge_artifacts_pkey
    """
    execute """
    ALTER INDEX IF EXISTS knowledge_artifacts_unique_idx
    RENAME TO curated_knowledge_artifacts_unique_idx
    """
    execute """
    ALTER INDEX IF EXISTS technology_knowledge_pkey
    RENAME TO detected_technology_knowledge_pkey
    """
  end

  def down do
    execute """
    ALTER INDEX IF EXISTS detected_technology_knowledge_pkey
    RENAME TO technology_knowledge_pkey
    """
    execute """
    ALTER INDEX IF EXISTS curated_knowledge_artifacts_unique_idx
    RENAME TO knowledge_artifacts_unique_idx
    """
    execute """
    ALTER INDEX IF EXISTS curated_knowledge_artifacts_pkey
    RENAME TO knowledge_artifacts_pkey
    """

    execute "ALTER TABLE detected_technology_knowledge RENAME TO technology_knowledge"
    execute "ALTER TABLE curated_knowledge_artifacts RENAME TO knowledge_artifacts"
  end
end
