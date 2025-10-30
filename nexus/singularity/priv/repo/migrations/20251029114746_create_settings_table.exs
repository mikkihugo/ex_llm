defmodule Singularity.Repo.Migrations.CreateSettingsTable do
  use Ecto.Migration

  def change do
    create table(:settings, primary_key: false) do
      add :key, :string, primary_key: true, comment: "Self-documenting setting key"
      add :value, :jsonb, null: false, comment: "Setting value (string, number, boolean, or complex object)"
      add :description, :text, comment: "Human-readable description of the setting"
      add :category, :string, comment: "Grouping category (pipelines, workflows, features, etc.)"
      add :updated_by, :string, default: "system", comment: "Who last updated this setting"

      timestamps(updated_at: :updated_at, inserted_at: false)
    end

    create index(:settings, [:category], comment: "Index for filtering settings by category")
    create index(:settings, [:updated_at], comment: "Index for finding recently updated settings")

    # Insert default settings for Broadway pipelines
    execute """
    INSERT INTO settings (key, value, description, category, updated_by, updated_at) VALUES
    ('pipelines.code_quality.enabled', '{"type": "boolean", "value": false}', 'Enable QuantumFlow mode for code quality training pipeline', 'pipelines', 'migration', NOW()),
    ('pipelines.complexity_training.enabled', '{"type": "boolean", "value": false}', 'Enable QuantumFlow mode for complexity analysis training pipeline', 'pipelines', 'migration', NOW()),
    ('pipelines.architecture_learning.enabled', '{"type": "boolean", "value": false}', 'Enable QuantumFlow mode for architecture learning pipeline', 'pipelines', 'migration', NOW()),
    ('pipelines.embedding_training.enabled', '{"type": "boolean", "value": false}', 'Enable QuantumFlow mode for embedding training pipeline', 'pipelines', 'migration', NOW()),
    ('workflows.code_quality.timeout_ms', '{"type": "number", "value": 300000}', 'Timeout in milliseconds for code quality training workflow', 'workflows', 'migration', NOW()),
    ('workflows.complexity_training.timeout_ms', '{"type": "number", "value": 600000}', 'Timeout in milliseconds for complexity training workflow', 'workflows', 'migration', NOW()),
    ('workflows.architecture_learning.timeout_ms', '{"type": "number", "value": 900000}', 'Timeout in milliseconds for architecture learning workflow', 'workflows', 'migration', NOW()),
    ('workflows.embedding_training.timeout_ms', '{"type": "number", "value": 300000}', 'Timeout in milliseconds for embedding training workflow', 'workflows', 'migration', NOW());
    """
  end
end