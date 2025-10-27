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

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.DependencyCatalog",
    "purpose": "Stores external package metadata with dual embeddings and prompt intelligence",
    "role": "schema",
    "layer": "domain_services",
    "table": "dependency_catalogs",
    "relationships": {
      "has_many": "PackageCodeExample - code examples for this package",
      "has_many": "PackageUsagePattern - usage patterns learned",
      "has_many": "PackageDependency - dependency relationships",
      "has_many": "PackagePromptUsage - prompt usage tracking"
    }
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - package_name: Package name (tokio, express, phoenix)
    - version: Package version
    - ecosystem: Package ecosystem (cargo, npm, hex, pypi)
    - description: Package description
    - documentation: Documentation text
    - tags: Array of tags for categorization
    - semantic_embedding: Vector for semantic search
    - description_embedding: Vector for description search
    - download_count: Popularity metric
    - github_stars: Quality signal
    - prompt_templates: JSONB with LLM prompt templates
    - prompt_snippets: JSONB with common code snippets
    - version_guidance: JSONB with version-specific guidance

  indexes:
    - unique: [package_name, version, ecosystem]
    - ivfflat: semantic_embedding, description_embedding

  relationships:
    belongs_to: []
    has_many: [PackageCodeExample, PackageUsagePattern, PackageDependency, PackagePromptUsage]
  ```

  ### Anti-Patterns
  - ❌ DO NOT confuse DependencyCatalog (external packages) with CodeFile (your code)
  - ❌ DO NOT use DependencyCatalog for semantic code search - use CodeChunk instead
  - ✅ DO use DependencyCatalog for "what packages should I use?" queries
  - ✅ DO use semantic_embedding for similarity search across packages

  ### Search Keywords
  dependency catalog, package metadata, npm, cargo, hex, pypi, semantic search,
  package intelligence, prompt templates, version guidance, library search
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "dependency_catalogs" do
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
