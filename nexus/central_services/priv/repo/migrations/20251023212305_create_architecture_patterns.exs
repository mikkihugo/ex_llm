defmodule CentralCloud.Repo.Migrations.CreateArchitecturePatterns do
  use Ecto.Migration

  def change do
    # Enable pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"

    # Pattern definitions table
    create table(:architecture_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pattern_id, :string, null: false
      add :name, :string, null: false
      add :category, :string, null: false
      add :version, :string, null: false

      add :description, :text
      add :metadata, :jsonb  # Full pattern JSON
      add :indicators, :jsonb
      add :benefits, {:array, :string}
      add :concerns, {:array, :string}

      add :detection_template, :string  # Lua template filename
      add :embedding, :vector, size: 768  # For semantic search

      timestamps()
    end

    create unique_index(:architecture_patterns, [:pattern_id, :version])
    create index(:architecture_patterns, [:category])
    create index(:architecture_patterns, :embedding, using: "ivfflat")

    # Pattern validation results table
    create table(:pattern_validations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :pattern_id, references(:architecture_patterns, type: :binary_id), null: false

      add :analyst_result, :jsonb
      add :validator_result, :jsonb
      add :critic_result, :jsonb
      add :researcher_result, :jsonb
      add :consensus_result, :jsonb

      add :consensus_score, :integer
      add :confidence, :float
      add :approved, :boolean

      timestamps()
    end

    create index(:pattern_validations, [:codebase_id])
    create index(:pattern_validations, [:pattern_id])
    create index(:pattern_validations, [:consensus_score])
    create index(:pattern_validations, [:approved])

    # Lua prompt templates table (renamed to avoid conflict with existing prompt_templates)
    create table(:lua_prompt_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_path, :string, null: false
      add :template_name, :string, null: false
      add :category, :string, null: false
      add :version, :string, null: false

      add :lua_content, :text, null: false
      add :description, :text
      add :model_recommendation, :string
      add :input_variables, :jsonb
      add :embedding, :vector, size: 768

      timestamps()
    end

    create unique_index(:lua_prompt_templates, [:template_path])
    create index(:lua_prompt_templates, [:category])
    create index(:lua_prompt_templates, [:template_name])
    create index(:lua_prompt_templates, :embedding, using: "ivfflat")
  end
end
