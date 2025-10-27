defmodule Singularity.Schemas.T5ModelVersion do
  @moduledoc """
  T5 Model Version Schema

  Tracks different versions of fine-tuned T5 models.
  Manages model deployment, performance metrics, and rollback capabilities.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.T5ModelVersion",
    "purpose": "Version management for fine-tuned T5 models",
    "role": "schema",
    "layer": "ml_training",
    "table": "t5_model_versions",
    "features": ["model_versioning", "deployment_tracking", "rollback_capability"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - training_session_id: Reference to training session
    - version: Version identifier (semantic versioning)
    - status: deployed, staging, archived
    - model_path: Where model file is stored
    - performance_score: Overall performance metric
    - deployment_date: When deployed to production
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for training data - use T5TrainingSession
  - ❌ DO NOT create versions without evaluation
  - ✅ DO use for model rollback capability
  - ✅ DO rely on status field for deployment tracking

  ### Search Keywords
  model_versions, model_versioning, deployment, t5_models, machine_learning,
  model_management, rollback, production_models
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "t5_model_versions" do
    field :training_session_id, :binary_id
    field :version, :string
    field :model_path, :string
    field :base_model, :string
    field :config, :map, default: %{}
    field :performance_metrics, :map, default: %{}
    field :is_deployed, :boolean, default: false
    field :is_active, :boolean, default: false
    field :deployed_at, :utc_datetime
    field :file_size_mb, :float
    field :training_time_seconds, :integer
    field :evaluation_results, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model_version, attrs) do
    model_version
    |> cast(attrs, [
      :training_session_id,
      :version,
      :model_path,
      :base_model,
      :config,
      :performance_metrics,
      :is_deployed,
      :is_active,
      :deployed_at,
      :file_size_mb,
      :training_time_seconds,
      :evaluation_results
    ])
    |> validate_required([:training_session_id, :version, :model_path, :base_model])
    |> validate_format(:version, ~r/^v\d+\.\d+\.\d+$/,
      message: "must be semantic version (e.g., v1.0.0)"
    )
  end
end
