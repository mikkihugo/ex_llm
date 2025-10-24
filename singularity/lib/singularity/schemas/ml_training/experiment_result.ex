defmodule Singularity.Learning.ExperimentResult do
  @moduledoc """
  ExperimentResult - Records and learns from Genesis experiment outcomes.

  Integration Point: Genesis publishes experiment results to NATS.
  Singularity records these results and learns from outcomes to improve future experiments.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Learning.ExperimentResult",
    "purpose": "Record and learn from Genesis experiment results",
    "role": "schema",
    "layer": "ml_training",
    "table": "experiment_results",
    "integration": "Genesis ↔ Singularity via NATS",
    "features": ["learning_from_outcomes", "success_rate_tracking", "insights_generation"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT use this for non-Genesis experiments - this is Genesis-specific
  - ❌ DO NOT skip recording outcomes - needed for learning loop
  - ✅ DO use this for all Genesis experiment results via NATS
  - ✅ DO query insights for improving future experiments

  ### Search Keywords
  Genesis experiments, experiment results, learning loop, success rate,
  experiment insights, recommendation engine, ML training, isolated testing

  ## Data Flow

  ```
  Genesis (Isolated)
      ↓ NATS: agent.events.experiment.completed.{experiment_id}
  {
    "experiment_id": "exp-abc123",
    "status": "success",
    "metrics": {...},
    "recommendation": "merge_with_adaptations"
  }
      ↓
  Singularity.Learning.ExperimentResultConsumer
      ↓
  ExperimentResult.record/2
      ↓
  Ecto Schema (database storage)
      ↓
  ExperimentResult.get_insights/1 (query for learning)
  ```

  ## Result Schema

  Stores:
  - `experiment_id` - UUID from Genesis
  - `status` - success, timeout, failed
  - `metrics` - success_rate, regression, runtime, etc.
  - `recommendation` - merge, merge_with_adaptations, rollback
  - `changes_description` - what was being tested
  - `risk_level` - low, medium, high
  - `recorded_at` - when result was received
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  alias Singularity.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "experiment_results" do
    field :experiment_id, :string
    field :status, :string  # success, timeout, failed
    field :metrics, :map    # success_rate, regression, runtime_ms, etc.
    field :recommendation, :string  # merge, merge_with_adaptations, rollback
    field :changes_description, :string
    field :risk_level, :string  # low, medium, high
    field :recorded_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :experiment_id,
      :status,
      :metrics,
      :recommendation,
      :changes_description,
      :risk_level,
      :recorded_at
    ])
    |> validate_required([
      :experiment_id,
      :status,
      :metrics,
      :recommendation,
      :recorded_at
    ])
    |> validate_inclusion(:status, ["success", "timeout", "failed"])
    |> validate_inclusion(:recommendation, ["merge", "merge_with_adaptations", "rollback"])
    |> validate_inclusion(:risk_level, ["low", "medium", "high"])
    |> unique_constraint(:experiment_id)
  end

  @doc """
  Record a Genesis experiment result.

  Called when Genesis publishes results to NATS.
  Stores result for learning and provides recommendation to caller.
  """
  def record(experiment_id, genesis_result) when is_binary(experiment_id) and is_map(genesis_result) do
    try do
      now = DateTime.utc_now()

      result = %__MODULE__{
        experiment_id: experiment_id,
        status: genesis_result["status"] || "unknown",
        metrics: genesis_result["metrics"] || %{},
        recommendation: genesis_result["recommendation"] || "rollback",
        risk_level: genesis_result["risk_level"],
        recorded_at: genesis_result["timestamp"] || now
      }

      case Repo.insert(result) do
        {:ok, result} ->
          Logger.info("Recorded Genesis experiment result",
            experiment_id: experiment_id,
            status: result.status,
            recommendation: result.recommendation
          )

          {:ok, result}

        {:error, changeset} ->
          Logger.error("Failed to record experiment result",
            experiment_id: experiment_id,
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
      end
    rescue
      e ->
        Logger.error("Exception recording experiment result",
          experiment_id: experiment_id,
          error: inspect(e)
        )

        {:error, :record_failed}
    end
  end

  @doc """
  Get all results for an experiment type.
  """
  def get_by_type(experiment_type, limit \\ 50) when is_binary(experiment_type) do
    query =
      from(r in __MODULE__,
        where: ilike(r.changes_description, ^"%#{experiment_type}%"),
        order_by: [desc: r.recorded_at],
        limit: ^limit
      )

    Repo.all(query)
  end

  @doc """
  Get success statistics for experiment type.
  """
  def get_success_rate(experiment_type) when is_binary(experiment_type) do
    results = get_by_type(experiment_type)

    if Enum.empty?(results) do
      nil
    else
      successful = Enum.count(results, fn r -> r.status == "success" end)
      total = length(results)
      %{successful: successful, total: total, rate: successful / total}
    end
  end

  @doc """
  Get insights for improving future experiments.

  Returns statistics about what works well.
  """
  def get_insights(experiment_type) when is_binary(experiment_type) do
    results = get_by_type(experiment_type, 100)

    if Enum.empty?(results) do
      {:error, :no_results}
    else
      successful_merges = Enum.filter(results, fn r ->
        r.status == "success" and r.recommendation in ["merge", "merge_with_adaptations"]
      end)

      rollbacks = Enum.filter(results, fn r -> r.recommendation == "rollback" end)

      success_rate = length(successful_merges) / length(results)

      # Calculate average metrics for successful experiments
      avg_metrics = calculate_avg_metrics(successful_merges)

      # Common failure patterns
      failure_patterns = extract_failure_patterns(rollbacks)

      {:ok,
       %{
         success_rate: success_rate,
         total_experiments: length(results),
         successful_merges: length(successful_merges),
         rollbacks: length(rollbacks),
         avg_metrics: avg_metrics,
         failure_patterns: failure_patterns,
         recommendation: recommend_next_experiment(success_rate, failure_patterns)
       }}
    end
  end

  # Private helpers

  defp calculate_avg_metrics(results) when is_list(results) do
    case results do
      [] ->
        %{}

      results ->
        metrics_list = Enum.map(results, & &1.metrics)

        # Average success_rate, llm_reduction, regression
        avg_success_rate = average_field(metrics_list, "success_rate")
        avg_llm_reduction = average_field(metrics_list, "llm_reduction")
        avg_regression = average_field(metrics_list, "regression")

        %{
          avg_success_rate: avg_success_rate,
          avg_llm_reduction: avg_llm_reduction,
          avg_regression: avg_regression
        }
    end
  end

  defp average_field(metrics_list, field) do
    values = Enum.map(metrics_list, &Map.get(&1, field, 0))
    Enum.sum(values) / length(values)
  end

  defp extract_failure_patterns(rollbacks) when is_list(rollbacks) do
    rollbacks
    |> Enum.map(& &1.metrics)
    |> Enum.group_by(fn m -> classify_failure(m) end)
    |> Enum.map(fn {reason, metrics} -> {reason, length(metrics)} end)
    |> Enum.into(%{})
  end

  defp classify_failure(metrics) do
    regression = metrics["regression"] || 0
    success_rate = metrics["success_rate"] || 0

    cond do
      regression > 0.05 -> :high_regression
      success_rate < 0.7 -> :low_success_rate
      true -> :other
    end
  end

  defp recommend_next_experiment(success_rate, failure_patterns) do
    cond do
      success_rate > 0.9 -> :increase_risk_level
      success_rate > 0.7 -> :continue_current_approach
      Map.get(failure_patterns, :high_regression, 0) > 3 -> :reduce_scope
      true -> :refactor_approach
    end
  end
end
