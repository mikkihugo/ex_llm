defmodule Singularity.Schemas.DependencyCatalog do
  @moduledoc """
  Dependency Catalog - Searchable catalog of reusable libraries

  Stores metadata from npm, cargo, hex, pypi with semantic search.

  **What it stores:**
  - Express, React (npm)
  - Tokio, Serde (cargo)
  - Phoenix, Ecto (hex)
  - Django, Flask (pypi)

  Your personal catalog of libraries you can depend on!
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "dependency_catalog" do
    field :package_name, :string
    field :version, :string
    field :ecosystem, :string

    # Documentation
    field :description, :string
    field :documentation, :string
    field :homepage_url, :string
    field :repository_url, :string
    field :license, :string

    # Metadata
    field :tags, {:array, :string}
    field :categories, {:array, :string}
    field :keywords, {:array, :string}

    # Vector embeddings for semantic search
    field :semantic_embedding, Pgvector.Ecto.Vector
    field :description_embedding, Pgvector.Ecto.Vector

    # Quality signals
    field :download_count, :integer
    field :github_stars, :integer
    field :last_release_date, :utc_datetime

    # Prompt intelligence
    field :prompt_templates, :map, default: %{}
    field :prompt_snippets, :map, default: %{}
    field :version_guidance, :map, default: %{}
    field :prompt_usage_stats, :map, default: %{}

    # Source tracking
    field :source_url, :string
    field :collected_at, :utc_datetime
    field :last_updated_at, :utc_datetime

    has_many :examples, Singularity.Schemas.PackageCodeExample, foreign_key: :dependency_id
    has_many :patterns, Singularity.Schemas.PackageUsagePattern, foreign_key: :dependency_id
    has_many :dependencies, Singularity.Schemas.PackageDependency, foreign_key: :dependency_id
    has_many :prompt_usages, Singularity.Schemas.PackagePromptUsage, foreign_key: :dependency_id

    timestamps(type: :utc_datetime)
  end

  def changeset(package, attrs) do
    package
    |> cast(attrs, [
      :package_name,
      :version,
      :ecosystem,
      :description,
      :documentation,
      :homepage_url,
      :repository_url,
      :license,
      :tags,
      :categories,
      :keywords,
      :semantic_embedding,
      :description_embedding,
      :download_count,
      :github_stars,
      :last_release_date,
      :source_url,
      :collected_at,
      :last_updated_at,
      :prompt_templates,
      :prompt_snippets,
      :version_guidance,
      :prompt_usage_stats
    ])
    |> validate_required([:package_name, :version, :ecosystem])
    |> unique_constraint([:package_name, :version, :ecosystem],
      name: :dependency_catalog_unique_identifier
    )
  end
end
