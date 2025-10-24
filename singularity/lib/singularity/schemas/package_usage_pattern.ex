defmodule Singularity.Schemas.PackageUsagePattern do
  @moduledoc """
  Schema for dependency_catalog_patterns table - best practices, anti-patterns, and usage patterns from package documentation

  Pattern types:
  - best_practice: Recommended ways to use the package
  - anti_pattern: Common mistakes to avoid
  - usage_pattern: Common usage scenarios
  - migration_guide: How to upgrade between versions

  ## Naming Convention
  - Module: singular (`PackageUsagePattern` - represents ONE pattern)
  - Table: plural (`dependency_catalog_patterns` - collection of patterns)
  - This is the Elixir/Ecto standard pattern

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.PackageUsagePattern",
    "purpose": "Best practices, anti-patterns, and usage patterns for packages",
    "role": "schema",
    "layer": "domain_services",
    "table": "dependency_catalog_patterns",
    "features": ["best_practices", "anti_patterns", "usage_patterns", "migration_guides"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - package_name: Package this pattern applies to
    - pattern_type: best_practice, anti_pattern, usage_pattern, migration_guide
    - name: Pattern name or identifier
    - description: Detailed pattern description
    - code_example: Sample code showing pattern
    - when_to_use: Guidance on applicability
  ```

  ### Anti-Patterns
  - ❌ DO NOT duplicate user code patterns - only official package patterns
  - ❌ DO NOT mix patterns from different packages
  - ✅ DO use for learning package best practices
  - ✅ DO rely on anti_patterns for mistake prevention

  ### Search Keywords
  package_patterns, best_practices, anti_patterns, usage_patterns, migrations,
  package_usage, learning, api_usage, code_patterns, official_guidance
  ```
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "dependency_catalog_patterns" do
    field :pattern_type, :string
    field :title, :string
    field :description, :string
    field :code_example, :string
    field :tags, {:array, :string}
    field :pattern_embedding, Pgvector.Ecto.Vector

    belongs_to :package, Singularity.Schemas.DependencyCatalog,
      foreign_key: :dependency_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :dependency_id,
      :pattern_type,
      :title,
      :description,
      :code_example,
      :tags,
      :pattern_embedding
    ])
    |> validate_required([:dependency_id, :title])
    |> validate_inclusion(:pattern_type, [
      "best_practice",
      "anti_pattern",
      "usage_pattern",
      "migration_guide"
    ])
    |> foreign_key_constraint(:dependency_id)
  end
end
