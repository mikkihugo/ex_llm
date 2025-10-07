defmodule Singularity.Schemas.PackageUsagePattern do
  @moduledoc """
  Schema for package_usage_patterns table - best practices, anti-patterns, and usage patterns from package documentation

  Pattern types:
  - best_practice: Recommended ways to use the package
  - anti_pattern: Common mistakes to avoid
  - usage_pattern: Common usage scenarios
  - migration_guide: How to upgrade between versions
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
