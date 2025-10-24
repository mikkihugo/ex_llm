defmodule Singularity.Schemas.T5TrainingSession do
  @moduledoc """
  T5 Training Session Schema

  Tracks T5 fine-tuning sessions in the database.
  Stores training configuration, data sources, and results.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.T5TrainingSession",
    "purpose": "Training session metadata for T5 fine-tuning runs",
    "role": "schema",
    "layer": "ml_training",
    "table": "t5_training_sessions",
    "features": ["session_tracking", "training_configuration", "experiment_management"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - name: Session identifier
    - description: Training session purpose
    - config: JSONB with hyperparameters (batch_size, lr, epochs, etc.)
    - data_source: Where training data came from
    - status: active, completed, failed, paused
    - started_at: Training start time
    - completed_at: Training completion time
  ```

  ### Anti-Patterns
  - ❌ DO NOT duplicate session configs - normalize to single version
  - ❌ DO NOT use for training examples - use T5TrainingExample
  - ✅ DO use for tracking training runs and experiments
  - ✅ DO rely on status field for run management

  ### Search Keywords
  training_sessions, training_runs, t5_training, machine_learning, experiments,
  fine_tuning, session_tracking, training_configuration
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "t5_training_sessions" do
    field :name, :string
    field :description, :string
    field :language, :string
    field :base_model, :string, default: "Salesforce/codet5p-770m"

    field :status, Ecto.Enum,
      values: [:pending, :preparing, :training, :completed, :failed],
      default: :pending

    field :config, :map, default: %{}
    field :training_data_query, :string
    field :training_examples_count, :integer, default: 0
    field :validation_examples_count, :integer, default: 0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :model_path, :string
    field :performance_metrics, :map, default: %{}
    field :is_deployed, :boolean, default: false
    field :is_active, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(training_session, attrs) do
    training_session
    |> cast(attrs, [
      :name,
      :description,
      :language,
      :base_model,
      :status,
      :config,
      :training_data_query,
      :training_examples_count,
      :validation_examples_count,
      :started_at,
      :completed_at,
      :error_message,
      :model_path,
      :performance_metrics,
      :is_deployed,
      :is_active
    ])
    |> validate_required([:name, :language, :base_model])
    |> validate_inclusion(:status, [:pending, :preparing, :training, :completed, :failed])
    |> validate_inclusion(:language, ["elixir", "rust", "typescript", "python", "go", "java"])
  end
end
