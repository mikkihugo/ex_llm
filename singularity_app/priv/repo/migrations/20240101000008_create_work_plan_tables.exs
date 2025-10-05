defmodule Singularity.Repo.Migrations.CreateWorkPlanTables do
  use Ecto.Migration

  def change do
    # Strategic Themes - 3-5 year vision areas
    create table(:strategic_themes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false
      add :target_bloc, :float, default: 0.0
      add :priority, :integer, default: 0
      add :status, :string, default: "active"
      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    create index(:strategic_themes, [:priority])
    create index(:strategic_themes, [:status])

    # Epics - 6-12 month initiatives (Business or Enabler)
    create table(:epics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :theme_id, references(:strategic_themes, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text, null: false
      add :type, :string, null: false # business | enabler
      add :status, :string, default: "ideation" # ideation | analysis | implementation | done

      # WSJF scoring
      add :wsjf_score, :float, default: 0.0
      add :business_value, :integer, default: 5
      add :time_criticality, :integer, default: 5
      add :risk_reduction, :integer, default: 5
      add :job_size, :integer, default: 8

      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    create index(:epics, [:theme_id])
    create index(:epics, [:type])
    create index(:epics, [:status])
    create index(:epics, [:wsjf_score])

    # Capabilities - 3-6 month cross-team features
    create table(:capabilities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :epic_id, references(:epics, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text, null: false
      add :status, :string, default: "backlog" # backlog | analyzing | implementing | validating | done

      add :wsjf_score, :float, default: 0.0
      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    create index(:capabilities, [:epic_id])
    create index(:capabilities, [:status])
    create index(:capabilities, [:wsjf_score])

    # Capability Dependencies - Track dependencies between capabilities
    create table(:capability_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :capability_id, references(:capabilities, type: :binary_id, on_delete: :delete_all), null: false
      add :depends_on_capability_id, references(:capabilities, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:capability_dependencies, [:capability_id])
    create index(:capability_dependencies, [:depends_on_capability_id])
    create unique_index(:capability_dependencies, [:capability_id, :depends_on_capability_id], name: :capability_dependencies_unique)

    # Features - 1-3 month team deliverables
    create table(:features, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :capability_id, references(:capabilities, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text, null: false
      add :status, :string, default: "backlog" # backlog | in_progress | done

      add :htdag_id, :string # Link to HTDAG breakdown
      add :acceptance_criteria, {:array, :string}, default: []

      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    create index(:features, [:capability_id])
    create index(:features, [:status])
    create index(:features, [:htdag_id])
  end
end
