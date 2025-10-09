defmodule CentralCloud.Schemas.Package do
  @moduledoc """
  Package schema for Central Cloud global package registry.

  Stores packages from npm, cargo, hex, pypi with:
  - Framework detection results from LLM
  - Semantic embeddings for search
  - Usage analytics and learning data
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "packages" do
    field :name, :string
    field :ecosystem, :string
    field :version, :string
    field :description, :string
    field :homepage, :string
    field :repository, :string
    field :license, :string
    field :keywords, {:array, :string}, default: []
    field :dependencies, {:array, :string}, default: []
    field :tags, {:array, :string}, default: []
    field :source, :string
    field :last_updated, :utc_datetime

    # Framework detection (stores full LLM output from framework_discovery.json)
    field :detected_framework, :map, default: %{}

    # Vector embeddings
    field :semantic_embedding, Pgvector.Ecto.Vector
    field :code_embedding, Pgvector.Ecto.Vector

    # Usage stats (hstore)
    field :usage_stats, :map, default: %{}
    field :learning_data, :map, default: %{}

    # Security
    field :security_score, :float
    field :license_info, :map, default: %{}

    # Graph relationships (ltree)
    field :dependency_path, :string
    field :category_path, :string

    timestamps(type: :utc_datetime)

    # Associations
    has_many :code_snippets, CentralCloud.Schemas.CodeSnippet
    has_many :security_advisories, CentralCloud.Schemas.SecurityAdvisory
    has_many :analysis_results, CentralCloud.Schemas.AnalysisResult
    has_many :package_examples, CentralCloud.Schemas.PackageExample
    has_many :prompt_templates, CentralCloud.Schemas.PromptTemplate
  end

  @doc """
  Changeset for creating/updating packages
  """
  def changeset(package, attrs) do
    package
    |> cast(attrs, [
      :name,
      :ecosystem,
      :version,
      :description,
      :homepage,
      :repository,
      :license,
      :keywords,
      :dependencies,
      :tags,
      :source,
      :last_updated,
      :detected_framework,
      :semantic_embedding,
      :code_embedding,
      :usage_stats,
      :learning_data,
      :security_score,
      :license_info,
      :dependency_path,
      :category_path
    ])
    |> validate_required([:name, :ecosystem, :version])
    |> unique_constraint([:name, :ecosystem, :version])
    |> validate_inclusion(:ecosystem, ["npm", "cargo", "hex", "pypi", "maven", "nuget"])
  end

  @doc """
  Changeset for updating framework detection results from LLM
  """
  def framework_detection_changeset(package, llm_output) do
    package
    |> change(detected_framework: llm_output)
    |> change(last_updated: DateTime.utc_now())
  end
end
