defmodule Genesis.Schemas.SandboxHistory do
  @moduledoc """
  SandboxHistory Schema

  Tracks sandbox lifecycle events for cleanup, archival, and debugging.

  ## Fields

  - `experiment_id` - Reference to the experiment
  - `sandbox_path` - Location of the sandbox
  - `action` - What happened: created, preserved, cleaned_up
  - `reason` - Why the action was taken
  - `sandbox_size_mb` - Disk space used
  - `duration_seconds` - How long sandbox existed
  - `final_metrics` - Metrics at time of action
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "sandbox_history" do
    field :sandbox_path, :string
    field :action, :string  # created, preserved, cleaned_up
    field :reason, :string
    field :sandbox_size_mb, :float
    field :duration_seconds, :integer
    field :final_metrics, :map, default: %{}

    # Timestamps
    field :created_at, :utc_datetime_usec

    # Association
    belongs_to :experiment, Genesis.Schemas.ExperimentRecord, foreign_key: :experiment_id, type: :string
  end

  @doc """
  Create a new sandbox history record.
  """
  def changeset(record, attrs \\ %{}) do
    record
    |> cast(attrs, [
      :experiment_id,
      :sandbox_path,
      :action,
      :reason,
      :sandbox_size_mb,
      :duration_seconds,
      :final_metrics
    ])
    |> validate_required([:experiment_id, :sandbox_path, :action])
    |> validate_inclusion(:action, ["created", "preserved", "cleaned_up"])
  end
end
