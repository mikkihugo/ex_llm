defmodule Singularity.Repo.Migrations.CreateWorkPlanTables do
  use Ecto.Migration

  def change do
    # Strategic Themes - 3-5 year vision areas
    create_if_not_exists table(:strategic_themes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false
      add :target_bloc, :float, default: 0.0
      add :priority, :integer, default: 0
      add :status, :string, default: "active"
      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS strategic_themes_priority_index
      ON strategic_themes (priority)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS strategic_themes_status_index
      ON strategic_themes (status)
    """, "")

    # Epics - 6-12 month initiatives (Business or Enabler)
    create_if_not_exists table(:epics, primary_key: false) do
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

    execute("""
      CREATE INDEX IF NOT EXISTS epics_theme_id_index
      ON epics (theme_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS epics_type_index
      ON epics (type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS epics_status_index
      ON epics (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS epics_wsjf_score_index
      ON epics (wsjf_score)
    """, "")

    # Capabilities - 3-6 month cross-team features
    create_if_not_exists table(:capabilities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :epic_id, references(:epics, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text, null: false
      add :status, :string, default: "backlog" # backlog | analyzing | implementing | validating | done

      add :wsjf_score, :float, default: 0.0
      add :approved_by, :string

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS capabilities_epic_id_index
      ON capabilities (epic_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS capabilities_status_index
      ON capabilities (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS capabilities_wsjf_score_index
      ON capabilities (wsjf_score)
    """, "")

    # Capability Dependencies - Track dependencies between capabilities
    create_if_not_exists table(:capability_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :capability_id, references(:capabilities, type: :binary_id, on_delete: :delete_all), null: false
      add :depends_on_capability_id, references(:capabilities, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS capability_dependencies_capability_id_index
      ON capability_dependencies (capability_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS capability_dependencies_depends_on_capability_id_index
      ON capability_dependencies (depends_on_capability_id)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS capability_dependencies_capability_id_depends_on_capability_id_key
      ON capability_dependencies (capability_id, depends_on_capability_id)
    """, "")

    # Features - 1-3 month team deliverables
    create_if_not_exists table(:features, primary_key: false) do
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

    execute("""
      CREATE INDEX IF NOT EXISTS features_capability_id_index
      ON features (capability_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS features_status_index
      ON features (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS features_htdag_id_index
      ON features (htdag_id)
    """, "")
  end
end
