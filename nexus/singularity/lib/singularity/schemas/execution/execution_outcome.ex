defmodule Singularity.Schemas.Execution.ExecutionOutcome do
  @moduledoc """
  ExecutionOutcome Schema - Persistent record of agent execution outcomes.

  Stores results from task execution for learning system analysis:
  - Success/failure status
  - Latency and token usage
  - Quality scores
  - Error details

  Used by WorkflowLearner to learn optimal agent selection patterns.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.Execution.ExecutionOutcome",
    "purpose": "Persist agent execution outcomes for learning system",
    "layer": "data",
    "pattern": "Ecto schema",
    "table": "execution_outcomes",
    "responsibilities": [
      "Store execution results",
      "Track performance metrics",
      "Enable learning analysis",
      "Provide historical data"
    ]
  }
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "execution_outcomes" do
    field :agent, :string
    field :task_id, :string
    field :task_domain, :string
    field :success, :boolean
    field :latency_ms, :integer
    field :tokens_used, :integer
    field :quality_score, :float
    field :feedback, :string
    field :error, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(execution_outcome, attrs) do
    execution_outcome
    |> cast(attrs, [
      :agent,
      :task_id,
      :task_domain,
      :success,
      :latency_ms,
      :tokens_used,
      :quality_score,
      :feedback,
      :error,
      :metadata
    ])
    |> validate_required([:agent, :task_id, :task_domain, :success])
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
    |> validate_number(:tokens_used, greater_than_or_equal_to: 0)
    |> validate_number(:quality_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  @doc """
  Create a changeset from an outcome map (from WorkflowLearner.record_outcome).
  """
  def from_outcome(outcome) when is_map(outcome) do
    changeset(%__MODULE__{}, outcome)
  end
end
