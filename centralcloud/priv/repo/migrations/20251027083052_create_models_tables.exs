defmodule CentralCloud.Repo.Migrations.CreateModelsTables do
  use Ecto.Migration

  def change do
    # Model Providers table
    create table(:model_providers) do
      add :provider_id, :string, null: false
      add :name, :string, null: false
      add :npm_package, :string
      add :api_base_url, :string
      add :env_vars, {:array, :string}
      add :documentation_url, :string
      add :logo_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:model_providers, [:provider_id])

    # Model Cache table
    create table(:model_cache) do
      add :model_id, :string, null: false
      add :provider_id, :string, null: false
      add :name, :string, null: false
      add :description, :text
      
      # Pricing information (from models.dev or custom)
      add :pricing, :map
      
      # Model capabilities
      add :capabilities, :map
      
      # Technical specifications
      add :specifications, :map
      
      # Source tracking
      add :source, :string, null: false
      
      # Status
      add :status, :string, default: "active"
      
      # Metadata
      add :metadata, :map
      
      # Timestamps
      add :cached_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :last_verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:model_cache, [:model_id])
    create index(:model_cache, [:provider_id])
    create index(:model_cache, [:source])
    create index(:model_cache, [:status])
    create index(:model_cache, [:pricing], using: :gin)
    create index(:model_cache, [:capabilities], using: :gin)

    # Add foreign key constraint
    alter table(:model_cache) do
      modify :provider_id, references(:model_providers, column: :provider_id, type: :string)
    end

    # Add check constraints
    create constraint(:model_cache, :source_check, 
      check: "source IN ('models_dev', 'yaml_static', 'custom')")
    
    create constraint(:model_cache, :status_check, 
      check: "status IN ('active', 'deprecated', 'unavailable')")
  end
end
