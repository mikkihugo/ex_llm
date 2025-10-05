defmodule Singularity.Repo.Migrations.RenameFrameworkPatternsToTechnologyPatterns do
  use Ecto.Migration

  def up do
    # Rename table to reflect it stores ALL technology patterns, not just frameworks
    # Used by: detectors, prompt builders, LLM context, embeddings, etc.
    execute "ALTER TABLE framework_patterns RENAME TO technology_patterns"

    # Rename column for clarity
    execute "ALTER TABLE technology_patterns RENAME COLUMN framework_name TO technology_name"
    execute "ALTER TABLE technology_patterns RENAME COLUMN framework_type TO technology_type"

    # Update indexes
    execute "ALTER INDEX framework_patterns_pkey RENAME TO technology_patterns_pkey"
    execute "ALTER INDEX framework_patterns_name_idx RENAME TO technology_patterns_name_idx"
    execute "ALTER INDEX framework_patterns_type_idx RENAME TO technology_patterns_type_idx"
    execute "ALTER INDEX framework_patterns_embedding_idx RENAME TO technology_patterns_embedding_idx"

    # Update unique constraint name
    execute """
    ALTER TABLE technology_patterns
    DROP CONSTRAINT framework_patterns_framework_name_framework_type_key
    """

    execute """
    ALTER TABLE technology_patterns
    ADD CONSTRAINT technology_patterns_technology_name_technology_type_key
    UNIQUE (technology_name, technology_type)
    """
  end

  def down do
    # Reverse the rename
    execute "ALTER TABLE technology_patterns RENAME TO framework_patterns"
    execute "ALTER TABLE framework_patterns RENAME COLUMN technology_name TO framework_name"
    execute "ALTER TABLE framework_patterns RENAME COLUMN technology_type TO framework_type"

    execute "ALTER INDEX technology_patterns_pkey RENAME TO framework_patterns_pkey"
    execute "ALTER INDEX technology_patterns_name_idx RENAME TO framework_patterns_name_idx"
    execute "ALTER INDEX technology_patterns_type_idx RENAME TO framework_patterns_type_idx"
    execute "ALTER INDEX technology_patterns_embedding_idx RENAME TO framework_patterns_embedding_idx"

    execute """
    ALTER TABLE framework_patterns
    DROP CONSTRAINT technology_patterns_technology_name_technology_type_key
    """

    execute """
    ALTER TABLE framework_patterns
    ADD CONSTRAINT framework_patterns_framework_name_framework_type_key
    UNIQUE (framework_name, framework_type)
    """
  end
end
