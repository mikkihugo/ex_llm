defmodule Singularity.Repo.Migrations.RenameTemplateTables do
  use Ecto.Migration

  @moduledoc """
  Phase 3: Rename template tables for clarity

  BEFORE: "templates" - What kind? Code? Email? Configuration?
  AFTER: "code_generation_templates" - Clear purpose!
  """

  def up do
    # templates → code_generation_templates
    execute "ALTER TABLE templates RENAME TO code_generation_templates"

    # technology_templates → technology_stack_templates (more specific)
    execute "ALTER TABLE technology_templates RENAME TO technology_stack_templates"

    # Update indexes
    execute """
    ALTER INDEX IF EXISTS templates_pkey
    RENAME TO code_generation_templates_pkey
    """
    execute """
    ALTER INDEX IF EXISTS technology_templates_pkey
    RENAME TO technology_stack_templates_pkey
    """

    # Note: store_templates likely duplicate - merge separately
  end

  def down do
    execute """
    ALTER INDEX IF EXISTS technology_stack_templates_pkey
    RENAME TO technology_templates_pkey
    """
    execute """
    ALTER INDEX IF EXISTS code_generation_templates_pkey
    RENAME TO templates_pkey
    """

    execute "ALTER TABLE technology_stack_templates RENAME TO technology_templates"
    execute "ALTER TABLE code_generation_templates RENAME TO templates"
  end
end
