defmodule CentralCloud.ModelLearning.ModelMetrics do
  @moduledoc """
  Real-time aggregated metrics for model performance tracking.

  Maintains running statistics on how well each model performs at each
  complexity level for complexity score learning.

  ## Attributes

  - `model_name` - Model identifier (e.g., "gpt-4o")
  - `complexity_level` - Task complexity: "simple", "medium", "complex"
  - `usage_count` - How many times this model was routed for this complexity
  - `success_count` - How many times succeeded
  - `response_times` - Array of all response times observed
  - `avg_response_time` - Running average response time in milliseconds
  - `response_time_count` - Number of response time samples recorded

  ## Unique Constraint

  One row per (model_name, complexity_level) pair.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias CentralCloud.Repo

  @primary_key {:id, :bigserial, autogenerate: true}
  schema "model_routing_metrics" do
    field :model_name, :string
    field :complexity_level, :string
    field :usage_count, :integer, default: 0
    field :success_count, :integer, default: 0
    field :response_times, {:array, :integer}, default: []
    field :avg_response_time, :float
    field :response_time_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(metrics, attrs) do
    metrics
    |> cast(attrs, [
      :model_name,
      :complexity_level,
      :usage_count,
      :success_count,
      :response_times,
      :avg_response_time,
      :response_time_count
    ])
    |> validate_required([:model_name, :complexity_level])
    |> validate_inclusion(:complexity_level, ["simple", "medium", "complex"])
    |> unique_constraint(:model_complexity, name: :model_routing_metrics_model_complexity_idx)
  end

  # === Query Operations ===

  @doc """
  Get or create metrics record for a model/complexity combo.
  """
  def update_or_create(model_name, complexity_level) do
    metrics = %{
      model_name: model_name,
      complexity_level: complexity_level
    }

    case Repo.insert_or_update(
      Ecto.Changeset.change(%__MODULE__{}, metrics),
      on_conflict: :nothing
    ) do
      {:ok, record} ->
        {:ok, record}

      {:error, _} ->
        # Already exists, just fetch it
        Repo.get_by(__MODULE__, model_name: model_name, complexity_level: complexity_level)
        |> case do
          nil -> {:error, :not_found}
          record -> {:ok, record}
        end
    end
  end

  @doc """
  Increment usage counter for a model/complexity.
  """
  def increment_usage(model_name, complexity_level) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET usage_count = usage_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model_name, complexity_level])
  end

  @doc """
  Increment success counter for a model/complexity.
  """
  def increment_success(model_name, complexity_level) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET success_count = success_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model_name, complexity_level])
  end

  @doc """
  Record a response time sample and update running average.
  """
  def record_response_time(model_name, complexity_level, time_ms) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET response_times = array_append(response_times, $3),
          avg_response_time = (
            COALESCE(avg_response_time, 0) * response_time_count + $3
          ) / (response_time_count + 1),
          response_time_count = response_time_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model_name, complexity_level, time_ms])
  end

  @doc """
  Get success rate (0.0-1.0) for a model/complexity.
  """
  def get_success_rate(model_name, complexity_level) do
    case Repo.query("""
      SELECT
        CASE
          WHEN usage_count = 0 THEN 0
          ELSE success_count::float / usage_count
        END as success_rate
      FROM model_routing_metrics
      WHERE model_name = $1 AND complexity_level = $2
    """, [model_name, complexity_level]) do
      {:ok, %{rows: [[rate]]}} -> {:ok, rate}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get all metrics for a specific complexity level, ordered by usage.
  """
  def get_by_complexity(complexity_level) do
    Repo.all(
      from m in __MODULE__,
      where: m.complexity_level == ^complexity_level,
      order_by: [desc: m.usage_count]
    )
  end

  @doc """
  Get all models with usage_count >= min_samples.
  Useful for finding models with enough data for learning.
  """
  def get_high_usage_models(min_samples) do
    Repo.all(
      from m in __MODULE__,
      where: m.usage_count >= ^min_samples,
      order_by: [desc: m.usage_count]
    )
  end

  @doc """
  Get metrics for a specific model across all complexity levels.
  """
  def get_by_model(model_name) do
    Repo.all(
      from m in __MODULE__,
      where: m.model_name == ^model_name,
      order_by: m.complexity_level
    )
  end
end
