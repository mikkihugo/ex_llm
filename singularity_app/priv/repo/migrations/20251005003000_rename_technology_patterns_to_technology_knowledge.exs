defmodule Singularity.Repo.Migrations.RenameTechnologyPatternsToTechnologyKnowledge do
  use Ecto.Migration

  def up do
    # Rename table to reflect it's a knowledge base, not pattern definitions
    # Stores what we KNOW about technologies (frameworks, languages, cloud, etc.)
    execute "ALTER TABLE technology_patterns RENAME TO technology_knowledge"

    # Rename columns for clarity
    execute "ALTER TABLE technology_knowledge RENAME COLUMN technology_name TO name"
    execute "ALTER TABLE technology_knowledge RENAME COLUMN technology_type TO category"

    # Update indexes
    execute "ALTER INDEX technology_patterns_pkey RENAME TO technology_knowledge_pkey"
    execute "ALTER INDEX technology_patterns_name_idx RENAME TO technology_knowledge_name_idx"
    execute "ALTER INDEX technology_patterns_type_idx RENAME TO technology_knowledge_category_idx"
    execute "ALTER INDEX technology_patterns_embedding_idx RENAME TO technology_knowledge_embedding_idx"

    # Update unique constraint
    execute """
    ALTER TABLE technology_knowledge
    DROP CONSTRAINT technology_patterns_technology_name_technology_type_key
    """

    execute """
    ALTER TABLE technology_knowledge
    ADD CONSTRAINT technology_knowledge_name_category_key
    UNIQUE (name, category)
    """
  end

  def down do
    # Reverse the rename
    execute "ALTER TABLE technology_knowledge RENAME TO technology_patterns"
    execute "ALTER TABLE technology_patterns RENAME COLUMN name TO technology_name"
    execute "ALTER TABLE technology_patterns RENAME COLUMN category TO technology_type"

    execute "ALTER INDEX technology_knowledge_pkey RENAME TO technology_patterns_pkey"
    execute "ALTER INDEX technology_knowledge_name_idx RENAME TO technology_patterns_name_idx"
    execute "ALTER INDEX technology_knowledge_category_idx RENAME TO technology_patterns_type_idx"
    execute "ALTER INDEX technology_knowledge_embedding_idx RENAME TO technology_patterns_embedding_idx"

    execute """
    ALTER TABLE technology_patterns
    DROP CONSTRAINT technology_knowledge_name_category_key
    """

    execute """
    ALTER TABLE technology_patterns
    ADD CONSTRAINT technology_patterns_technology_name_technology_type_key
    UNIQUE (technology_name, technology_type)
    """
  end
end
