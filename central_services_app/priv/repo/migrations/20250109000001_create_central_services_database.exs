defmodule CentralServices.Repo.Migrations.CreateCentralServicesDatabase do
  use Ecto.Migration

  @moduledoc """
  Creates central services database schema for package data, code snippets, 
  security advisories, and analysis results.
  
  This is separate from the main Singularity app database and serves
  the central package servers and services.
  """

  def up do
    # Enable required extensions
    execute "CREATE EXTENSION IF NOT EXISTS vector;"
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb;"
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

    # ============================================================================
    # PACKAGE METADATA (from package_registry_server)
    # ============================================================================
    
    create table(:packages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :ecosystem, :string, null: false  # npm, cargo, hex, pypi
      add :version, :string, null: false
      add :description, :text
      add :homepage, :string
      add :repository, :string
      add :license, :string
      add :keywords, {:array, :string}, default: []
      add :dependencies, {:array, :string}, default: []
      add :tags, {:array, :string}, default: []
      add :source, :string  # registry, github, etc.
      add :last_updated, :utc_datetime
      add :created_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
      
      # Tech profile detection
      add :detected_framework, :map, default: %{}
      
      # Vector embeddings for semantic search
      add :semantic_embedding, :vector, size: 384
      add :code_embedding, :vector, size: 384
      
      # Usage and learning data
      add :usage_stats, :map, default: %{}
      add :learning_data, :map, default: %{}
      
      # Security and licensing
      add :security_score, :float
      add :license_info, :map, default: %{}
    end

    # ============================================================================
    # CODE SNIPPETS (from package_analysis_server)
    # ============================================================================
    
    create table(:code_snippets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :title, :string, null: false
      add :code, :text, null: false
      add :language, :string, null: false
      add :description, :text
      add :file_path, :string
      add :line_number, :integer
      add :function_name, :string
      add :class_name, :string
      add :visibility, :string  # public, private, protected
      add :is_exported, :boolean, default: false
      
      # Vector embeddings for semantic search
      add :semantic_embedding, :vector, size: 384
      add :code_embedding, :vector, size: 384
      
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # SECURITY ADVISORIES (from package_security_server)
    # ============================================================================
    
    create table(:security_advisories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :vulnerability_id, :string, null: false
      add :severity, :string, null: false  # low, medium, high, critical
      add :description, :text
      add :affected_versions, {:array, :string}, default: []
      add :patched_versions, {:array, :string}, default: []
      add :source, :string, null: false  # github, npm, rustsec
      add :published_at, :utc_datetime
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # ANALYSIS RESULTS (from package_analysis_server)
    # ============================================================================
    
    create table(:analysis_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :analysis_type, :string, null: false  # code_quality, performance, architecture
      add :score, :float
      add :metrics, :map, default: %{}  # JSON blob of analysis metrics
      add :recommendations, {:array, :string}, default: []
      add :complexity_score, :integer
      add :maintainability_score, :integer
      add :test_coverage, :float
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # PACKAGE EXAMPLES (from package_analysis_server)
    # ============================================================================
    
    create table(:package_examples, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :title, :string, null: false
      add :description, :text
      add :code, :text, null: false
      add :language, :string, null: false
      add :source, :string  # readme, docs, examples/
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # PROMPT TEMPLATES (from package_analysis_server)
    # ============================================================================
    
    create table(:prompt_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :template_name, :string, null: false
      add :template_content, :text, null: false
      add :template_type, :string, null: false  # usage, migration, quickstart
      add :language, :string, null: false
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # INDEXES FOR PERFORMANCE
    # ============================================================================
    
    # Package indexes
    create unique_index(:packages, [:name, :ecosystem, :version])
    create index(:packages, [:ecosystem])
    create index(:packages, [:last_updated])
    create index(:packages, [:tags], using: :gin)
    create index(:packages, [:keywords], using: :gin)
    
    # Vector similarity indexes
    create index(:packages, [:semantic_embedding], using: :ivfflat, 
                 with: "vector_cosine_ops", options: "lists = 100")
    create index(:packages, [:code_embedding], using: :ivfflat, 
                 with: "vector_cosine_ops", options: "lists = 100")
    
    # Code snippet indexes
    create index(:code_snippets, [:package_id])
    create index(:code_snippets, [:language])
    create index(:code_snippets, [:is_exported])
    create index(:code_snippets, [:semantic_embedding], using: :ivfflat, 
                 with: "vector_cosine_ops", options: "lists = 100")
    create index(:code_snippets, [:code_embedding], using: :ivfflat, 
                 with: "vector_cosine_ops", options: "lists = 100")
    
    # Full-text search indexes
    create index(:code_snippets, [:code], using: :gin, 
                 with: "to_tsvector('english', code)")
    create index(:packages, [:description], using: :gin, 
                 with: "to_tsvector('english', description)")
    
    # Security advisory indexes
    create index(:security_advisories, [:package_id])
    create index(:security_advisories, [:severity])
    create index(:security_advisories, [:source])
    create index(:security_advisories, [:published_at])
    
    # Analysis result indexes
    create index(:analysis_results, [:package_id])
    create index(:analysis_results, [:analysis_type])
    create index(:analysis_results, [:score])
    
    # Example and template indexes
    create index(:package_examples, [:package_id])
    create index(:prompt_templates, [:package_id])
    create index(:prompt_templates, [:template_type])
    create index(:prompt_templates, [:language])
  end

  def down do
    drop table(:prompt_templates)
    drop table(:package_examples)
    drop table(:analysis_results)
    drop table(:security_advisories)
    drop table(:code_snippets)
    drop table(:packages)
  end
end
