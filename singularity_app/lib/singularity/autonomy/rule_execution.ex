defmodule Singularity.Autonomy.RuleExecution do
  @moduledoc """
  Time-series record of rule executions for learning and analysis.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rule_executions" do
    belongs_to :rule, Singularity.Autonomy.Rule
    field :correlation_id, :binary_id

    field :confidence, :float
    field :decision, :string
    field :reasoning, :string
    field :execution_time_ms, :integer

    field :context, :map

    field :outcome, :string
    field :outcome_recorded_at, :utc_datetime_usec

    field :executed_at, :utc_datetime_usec
  end

  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [
      :rule_id,
      :correlation_id,
      :confidence,
      :decision,
      :reasoning,
      :execution_time_ms,
      :context,
      :executed_at
    ])
    |> validate_required([
      :rule_id,
      :correlation_id,
      :confidence,
      :decision,
      :execution_time_ms,
      :context,
      :executed_at
    ])
    |> validate_inclusion(:decision, ["autonomous", "collaborative", "escalated"])
    |> foreign_key_constraint(:rule_id)
  end

  def record_outcome(execution, outcome) do
    execution
    |> cast(%{outcome: outcome, outcome_recorded_at: DateTime.utc_now()}, [:outcome, :outcome_recorded_at])
    |> validate_inclusion(:outcome, ["success", "failure", "unknown"])
  end
end
