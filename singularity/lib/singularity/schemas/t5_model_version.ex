defmodule Singularity.Schemas.T5ModelVersion do
  @moduledoc """
  T5 Model Version Schema

  Tracks different versions of fine-tuned T5 models.
  Manages model deployment, performance metrics, and rollback capabilities.
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
