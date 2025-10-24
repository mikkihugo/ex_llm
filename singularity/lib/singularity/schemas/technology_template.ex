defmodule Singularity.Schemas.TechnologyTemplate do
  @moduledoc """
  Technology Templates - Configuration templates for frameworks and tools.

  Stores technology-specific templates for code generation, configuration, and best practices.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.TechnologyTemplate",
    "purpose": "Technology-specific templates for generation and configuration",
    "role": "schema",
    "layer": "domain_services",
    "table": "technology_templates",
    "features": ["technology_templates", "code_generation", "best_practices"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - identifier: Template identifier (e.g., react-18-tsx)
    - category: Category (web_framework, async_runtime, database, etc.)
    - version: Template version
    - template: JSONB with template content
    - metadata: Additional metadata (author, deprecated, etc.)
    - checksum: Content verification hash
  ```

  ### Anti-Patterns
  - ❌ DO NOT store code here - use Knowledge Artifacts instead
  - ❌ DO NOT duplicate across categories
  - ✅ DO use for technology-specific generation
  - ✅ DO rely on checksum for change detection

  ### Search Keywords
  templates, technology_templates, code_generation, configuration, best_practices,
  framework_templates, technology_specific, template_management
  ```
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "technology_templates" do
    field :identifier, :string
    field :category, :string
    field :version, :string
    field :source, :string
    field :template, :map
    field :metadata, :map, default: %{}
    field :checksum, :string

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(identifier category template)a

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:identifier, :category, :version, :source, :template, :metadata, :checksum])
    |> validate_required(@required)
    |> unique_constraint(:identifier)
    |> validate_template_is_object()
  end

  defp validate_template_is_object(changeset) do
    case get_field(changeset, :template) do
      %{} -> changeset
      _ -> add_error(changeset, :template, "must be a JSON object")
    end
  end
end
