defmodule Singularity.Schemas.ExecutionMetric do
  @moduledoc """
  Ecto schema for tracking execution-level metrics.

  Records metrics from LLM executions:
  - Cost in cents
  - Tokens used (prompt + completion)
  - Execution latency
  - Model used
  - Success/failure status

  Used in Phase 5 (Learning) to:
  - Track cost trends and optimization opportunities
  - Measure token efficiency by model and task
  - Monitor latency for performance tuning
  - Correlate metrics with validation effectiveness

  ## Table Structure

  - `id` - Primary key (UUID)
  - `run_id` - ID of the execution run
  - `task_type` - Type of task (architect, coder, classifier, etc.)
  - `model` - LLM model used
  - `provider` - Provider (anthropic, openai, gemini, etc.)
  - `cost_cents` - Cost in cents
  - `tokens_used` - Total tokens
  - `prompt_tokens` - Prompt tokens
  - `completion_tokens` - Completion tokens
  - `latency_ms` - Execution time in milliseconds
  - `success` - Whether execution succeeded
  - `inserted_at` - Timestamp
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
          task_type: String.t(),
          model: String.t(),
          provider: String.t(),
          cost_cents: integer(),
          tokens_used: integer(),
          prompt_tokens: integer(),
          completion_tokens: integer(),
          latency_ms: integer(),
          success: boolean(),
          inserted_at: DateTime.t() | nil
        }

  schema "execution_metrics" do
    field :run_id, :binary_id
    field :task_type, :string
    field :model, :string
    field :provider, :string
    field :cost_cents, :integer, default: 0
    field :tokens_used, :integer, default: 0
    field :prompt_tokens, :integer, default: 0
    field :completion_tokens, :integer, default: 0
    field :latency_ms, :integer, default: 0
    field :success, :boolean, default: true

    timestamps(updated_at: false)
  end

  @doc """
  Create a changeset for recording an execution metric.

  ## Parameters
  - `attrs` - Map with:
    - `:run_id` - Execution run ID (required)
    - `:task_type` - Task type (required)
    - `:model` - LLM model (required)
    - `:provider` - Provider name (required)
    - `:cost_cents` - Cost (optional)
    - `:tokens_used` - Total tokens (optional)
    - `:prompt_tokens` - Prompt tokens (optional)
    - `:completion_tokens` - Completion tokens (optional)
    - `:latency_ms` - Latency (optional)
    - `:success` - Success flag (optional)
  """
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [
      :run_id,
      :task_type,
      :model,
      :provider,
      :cost_cents,
      :tokens_used,
      :prompt_tokens,
      :completion_tokens,
      :latency_ms,
      :success
    ])
    |> validate_required([:run_id, :task_type, :model, :provider])
    |> validate_number(:cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:tokens_used, greater_than_or_equal_to: 0)
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
  end

  @doc """
  Get metrics by run.
  """
  @spec list_by_run(binary()) :: [__MODULE__.t()]
  def list_by_run(run_id) do
    Singularity.Repo.all(
      from em in __MODULE__,
        where: em.run_id == ^run_id,
        order_by: [asc: em.inserted_at]
    )
  end

  @doc """
  Get metrics grouped by model.
  """
  @spec list_by_model(String.t()) :: [__MODULE__.t()]
  def list_by_model(model) do
    Singularity.Repo.all(
      from em in __MODULE__,
        where: em.model == ^model,
        order_by: [desc: em.inserted_at]
    )
  end

  @doc """
  Calculate aggregate metrics for a time range.
  """
  @spec aggregate_metrics(DateTime.t(), DateTime.t(), String.t() | nil) :: [map()]
  def aggregate_metrics(from_dt, to_dt, group_by \\ nil) do
    # Simplified query that just gets the base data
    # Full aggregation with grouping would require more complex query construction
    query =
      from em in __MODULE__,
        where: em.inserted_at >= ^from_dt and em.inserted_at <= ^to_dt,
        select: em

    query =
      case group_by do
        "model" ->
          query |> group_by([em], em.model) |> select([em], em)

        "task_type" ->
          query |> group_by([em], em.task_type) |> select([em], em)

        "provider" ->
          query |> group_by([em], em.provider) |> select([em], em)

        _ ->
          query
      end

    Singularity.Repo.all(query)
  end
end
