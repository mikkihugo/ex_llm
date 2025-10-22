defmodule Singularity.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    # Rules and Decision Engine
    create table(:rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :string
      add :condition, :map, default: %{}
      add :action, :map, default: %{}
      add :metadata, :map, default: %{}
      add :priority, :integer, default: 0
      add :active, :boolean, default: true
      add :version, :integer, default: 1
      add :parent_id, references(:rules, type: :binary_id, on_delete: :nilify_all)
      add :embedding, :vector, size: 768
      timestamps()
    end

    create index(:rules, [:name])
    create index(:rules, [:category])
    create index(:rules, [:active])
    create index(:rules, [:priority])
    create index(:rules, [:parent_id])
    create index(:rules, [:condition], using: :gin)
    create index(:rules, [:metadata], using: :gin)

    # LLM Calls Tracking
    create table(:llm_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :model, :string, null: false
      add :prompt, :text
      add :response, :text
      add :tokens_used, :integer
      add :cost_cents, :integer
      add :latency_ms, :integer
      add :metadata, :map, default: %{}
      add :error, :text
      add :success, :boolean, default: true
      timestamps()
    end

    create index(:llm_calls, [:provider, :model])
    create index(:llm_calls, [:success])
    create index(:llm_calls, [:inserted_at])
    create index(:llm_calls, [:metadata], using: :gin)

    # Quality Metrics
    create table(:quality_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_type, :string, null: false
      add :entity_id, :string, null: false
      add :metric_type, :string, null: false
      add :value, :float, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:quality_metrics, [:entity_type, :entity_id])
    create index(:quality_metrics, [:metric_type])
    create index(:quality_metrics, [:inserted_at])
  end
end