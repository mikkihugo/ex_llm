defmodule CentralCloud.Schemas.Package do
  @moduledoc """
  Central package schema for package metadata from registries.
  Managed by centralcloud service.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Pgvector.Ecto.Vector

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "central_packages" do
    field :name, :string
    field :ecosystem, :string  # npm, cargo, hex, pypi
    field :version, :string
    field :description, :string
    field :homepage, :string
    field :repository, :string
    field :license, :string
    field :keywords, {:array, :string}, default: []
    field :dependencies, {:array, :string}, default: []
    field :tags, {:array, :string}, default: []
    field :source, :string  # registry, github, etc.
    field :last_updated, :utc_datetime
    
    # Tech profile detection
    field :detected_framework, :map, default: %{}
    
    # Vector embeddings for semantic search
    field :semantic_embedding, Vector
    field :code_embedding, Vector
    
    # Usage and learning data
    field :usage_stats, :map, default: %{}
    field :learning_data, :map, default: %{}
    
    # Security and licensing
    field :security_score, :float
    field :license_info, :map, default: %{}
    
    # Relationships (commented out until schemas are created)
    # has_many :code_snippets, CentralCloud.Schemas.CodeSnippet
    # has_many :security_advisories, CentralCloud.Schemas.SecurityAdvisory
    # has_many :analysis_results, CentralCloud.Schemas.AnalysisResult
    # has_many :package_examples, CentralCloud.Schemas.PackageExample
    # has_many :prompt_templates, CentralCloud.Schemas.PromptTemplate
    
    timestamps()
  end

  def changeset(package, attrs) do
    package
    |> cast(attrs, [:name, :ecosystem, :version, :description, :homepage, 
                    :repository, :license, :keywords, :dependencies, :tags, 
                    :source, :last_updated, :detected_framework, :semantic_embedding, 
                    :code_embedding, :usage_stats, :learning_data, :security_score, 
                    :license_info])
    |> validate_required([:name, :ecosystem, :version])
    |> unique_constraint([:name, :ecosystem, :version])
  end
end
