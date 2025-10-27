defmodule Singularity.Schemas.ValidationMetric do
  @moduledoc """
  Ecto schema for tracking validation check effectiveness.

  Records every validation check result with metadata for computing:
  - Check effectiveness (precision, recall, accuracy)
  - Validation time metrics
  - Cost and token tracking

  Used in Phase 3 (Multi-Layer Validation) and Phase 5 (Learning) of
  the self-evolving pipeline to dynamically adjust validation weights.

  ## Table Structure

  - `id` - Primary key (UUID)
  - `run_id` - ID of the execution run
  - `check_id` - Validation check identifier
  - `check_type` - Type of check (e.g., "template", "quality", "metadata")
  - `result` - Check result ("pass", "fail", "warning")
  - `confidence_score` - Confidence in the check (0.0 - 1.0)
  - `runtime_ms` - Time taken to run check
  - `context` - JSONB metadata (failure details, metrics, etc.)
  - `inserted_at` - Timestamp
  - `updated_at` - Timestamp
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestampsopts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: binary() | nil,
          run_id: binary(),
          check_id: String.t(),
          check_type: String.t(),
          result: String.t(),
          confidence_score: float(),
          runtime_ms: integer(),
          context: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "validation_metrics" do
    field :run_id, :binary_id
    field :check_id, :string
    field :check_type, :string
    field :result, :string
    field :confidence_score, :float, default: 0.5
    field :runtime_ms, :integer, default: 0
    field :context, :map, default: %{}

    timestamps()
  end

  @doc """
  Create a changeset for recording a validation metric.

  ## Parameters
  - `attrs` - Map with:
    - `:run_id` - Execution run ID (required)
    - `:check_id` - Check identifier (required)
    - `:check_type` - Type of check (required)
    - `:result` - "pass" | "fail" | "warning" (required)
    - `:confidence_score` - 0.0 to 1.0 (optional, default: 0.5)
    - `:runtime_ms` - Check duration (optional)
    - `:context` - Additional metadata (optional)
  """
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [
      :run_id,
      :check_id,
      :check_type,
      :result,
      :confidence_score,
      :runtime_ms,
      :context
    ])
    |> validate_required([:run_id, :check_id, :check_type, :result])
    |> validate_inclusion(:result, ["pass", "fail", "warning"])
    |> validate_number(:confidence_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:runtime_ms, greater_than_or_equal_to: 0)
  end

  @doc """
  Get a validation metric by ID.
  """
  @spec get(binary()) :: __MODULE__.t() | nil
  def get(id) do
    Singularity.Repo.get(__MODULE__, id)
  end

  @doc """
  List all metrics for a run.
  """
  @spec list_by_run(binary()) :: [__MODULE__.t()]
  def list_by_run(run_id) do
    Singularity.Repo.all(
      from vm in __MODULE__,
        where: vm.run_id == ^run_id,
        order_by: [asc: vm.inserted_at]
    )
  end

  @doc """
  List metrics for a specific check across all runs.
  """
  @spec list_by_check(String.t()) :: [__MODULE__.t()]
  def list_by_check(check_id) do
    Singularity.Repo.all(
      from vm in __MODULE__,
        where: vm.check_id == ^check_id,
        order_by: [desc: vm.inserted_at]
    )
  end

  @doc """
  Get metrics for a time range.
  """
  @spec list_by_time_range(DateTime.t(), DateTime.t()) :: [__MODULE__.t()]
  def list_by_time_range(from_dt, to_dt) do
    Singularity.Repo.all(
      from vm in __MODULE__,
        where: vm.inserted_at >= ^from_dt and vm.inserted_at <= ^to_dt,
        order_by: [desc: vm.inserted_at]
    )
  end
end
