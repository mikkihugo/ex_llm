defmodule Singularity.Schemas.PackageRegistryKnowledge do
  @moduledoc """
  Schema for package_registry_knowledge table - stores structured package metadata from npm/cargo/hex/pypi registries

  This is NOT RAG! This stores curated, versioned package metadata with quality signals,
  dependencies, and structured documentation for semantic search across package ecosystems.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "tools" do
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

    # Source tracking
    field :source_url, :string
    field :collected_at, :utc_datetime
    field :last_updated_at, :utc_datetime

    has_many :examples, Singularity.Schemas.PackageCodeExample
    has_many :patterns, Singularity.Schemas.PackageUsagePattern
    has_many :dependencies, Singularity.Schemas.PackageDependency

    timestamps(type: :utc_datetime)
  end

  def changeset(package, attrs) do
    package
    |> cast(attrs, [
      :package_name, :version, :ecosystem, :description, :documentation,
      :homepage_url, :repository_url, :license, :tags, :categories,
      :keywords, :semantic_embedding, :description_embedding,
      :download_count, :github_stars, :last_release_date,
      :source_url, :collected_at, :last_updated_at
    ])
    |> validate_required([:package_name, :version, :ecosystem])
    |> unique_constraint([:package_name, :version, :ecosystem],
      name: :tools_unique_identifier)
  end
end
