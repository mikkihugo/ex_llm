defmodule Singularity.Execution.Autonomy.RuleExecution do
  @moduledoc """
  Time-series record of rule executions for learning and analysis.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Execution.Autonomy.RuleExecution",
    "purpose": "Time-series tracking of rule executions with outcomes for learning",
    "role": "schema",
    "layer": "domain_services",
    "table": "rule_executions",
    "relationships": {
      "belongs_to": "Rule - the rule that was executed"
    }
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - rule_id: Foreign key to executed rule
    - correlation_id: Links related executions across system
    - confidence: Execution confidence score (0.0-1.0)
    - decision: Decision type (autonomous, collaborative, escalated)
    - reasoning: Explanation of why rule triggered
    - execution_time_ms: Rule evaluation duration
    - context: JSONB with execution context
    - outcome: Result (success, failure, unknown) - recorded later
    - outcome_recorded_at: When outcome was known
    - executed_at: When rule was executed

  relationships:
    belongs_to: [Rule]
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT record executions without correlation_id - breaks traceability
  - ❌ DO NOT skip outcome recording - needed for rule learning
  - ✅ DO use RuleExecution for all rule evaluations
  - ✅ DO record outcomes asynchronously via record_outcome/2

  ### Search Keywords
  rule execution, execution history, time series, rule learning,
  outcome tracking, confidence scoring, autonomous decisions, rule analytics
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rule_executions" do
    belongs_to :rule, Singularity.Execution.Autonomy.Rule
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
    |> cast(%{outcome: outcome, outcome_recorded_at: DateTime.utc_now()}, [
      :outcome,
      :outcome_recorded_at
    ])
    |> validate_inclusion(:outcome, ["success", "failure", "unknown"])
  end
end
