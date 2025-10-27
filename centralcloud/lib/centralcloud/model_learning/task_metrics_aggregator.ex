defmodule CentralCloud.ModelLearning.TaskMetricsAggregator do
  @moduledoc """
  Task Metrics Aggregator - Learn win rates from preference data.

  Periodically scans task_preferences table and calculates aggregated metrics:
  - Win rates per (task_type, model) pair
  - Quality scores
  - Response time stats
  - Confidence scores

  Runs every 60 seconds to keep metrics fresh for routing decisions.

  ## Data Flow

  ```
  1. TaskRouter.record_preference() → pgmq queue
  2. RoutingEventConsumer → TaskPreference table
  3. TaskMetricsAggregator (every 60s) → aggregate win rates
  4. CentralCloud.ModelLearning.Monitoring → dashboard queries
  5. TaskRouter queries aggregated metrics for routing
  ```

  ## Algorithm

  For each (task_type, model) pair in recent preferences (last 7 days):

  ```
  successes = COUNT(*) WHERE success = true
  total = COUNT(*)
  win_rate = successes / total
  confidence = 1 / (1 + e^(-0.01 * (total - 50)))
  avg_response_time = AVG(response_time_ms)
  avg_quality = AVG(response_quality)
  ```

  Only aggregates if total >= 1 (at least one sample).
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  import Ecto.Query

  @default_interval_ms 60_000  # Run every 60 seconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    interval_ms = Application.get_env(:central_cloud, :task_metrics_interval, @default_interval_ms)
    Logger.info("TaskMetricsAggregator: Starting with #{interval_ms}ms interval")

    # Schedule first aggregation
    schedule_next_aggregation(interval_ms)

    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:aggregate_metrics, %{interval_ms: interval} = state) do
    Logger.debug("Aggregating task metrics...")

    try do
      aggregate_task_metrics()
    rescue
      e ->
        Logger.error("Error aggregating task metrics: #{inspect(e)}")
    end

    schedule_next_aggregation(interval)
    {:noreply, state}
  end

  @doc """
  Manually trigger metrics aggregation.
  """
  @spec aggregate_now() :: :ok
  def aggregate_now do
    GenServer.cast(__MODULE__, :aggregate_metrics)
  end

  # === Private Implementation ===

  defp aggregate_task_metrics do
    # Query all (task_type, complexity_level, model_name) triplets from recent preferences
    query = from(p in "task_preferences",
      where: p.inserted_at > ago(7, "day"),
      select: {p.task_type, p.complexity_level, p.model_name},
      distinct: true
    )

    case Repo.all(query) do
      triplets when is_list(triplets) ->
        Enum.each(triplets, fn {task_type, complexity_level, model_name} ->
          calculate_and_store_metrics(task_type, complexity_level, model_name)
        end)

        Logger.info("Aggregated metrics for #{length(triplets)} task/complexity/model triplets")

      _ ->
        Logger.debug("No task preferences to aggregate")
    end
  end

  defp calculate_and_store_metrics(task_type, complexity_level, model_name) do
    # Calculate statistics for this (task, complexity, model) triplet
    stats_query = from(p in "task_preferences",
      where:
        p.task_type == ^task_type and p.complexity_level == ^complexity_level and
          p.model_name == ^model_name and
          p.inserted_at > ago(7, "day"),
      select: %{
        total: count(p.id),
        successes: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.success)),
        avg_quality: avg(p.response_quality),
        avg_response_time: avg(p.response_time_ms)
      }
    )

    case Repo.one(stats_query) do
      %{total: total} when total >= 1 ->
        metrics = %{
          task_type: task_type,
          complexity_level: complexity_level,
          model_name: model_name,
          total_samples: total,
          successes: stats_query |> Repo.one() |> Map.get(:successes, 0),
          avg_quality: stats_query |> Repo.one() |> Map.get(:avg_quality, 0.0),
          avg_response_time: stats_query |> Repo.one() |> Map.get(:avg_response_time, 0)
        }

        win_rate = calculate_win_rate(metrics)
        confidence = calculate_confidence(metrics)

        Logger.debug(
          "Task: #{task_type}, Complexity: #{complexity_level}, Model: #{model_name}, " <>
            "Win rate: #{Float.round(win_rate, 2)}, Samples: #{total}, " <>
            "Confidence: #{Float.round(confidence, 2)}"
        )

      _ ->
        Logger.debug("No valid metrics for #{task_type}/#{complexity_level}/#{model_name}")
    end
  end

  defp calculate_win_rate(%{total_samples: total, successes: successes})
       when is_number(total) and total > 0 do
    successes / total
  end

  defp calculate_win_rate(_), do: 0.5

  defp calculate_confidence(%{total_samples: total}) when is_number(total) do
    # Sigmoid: 1 / (1 + e^(-0.01 * (samples - 50)))
    exponent = -0.01 * (total - 50)
    1.0 / (1.0 + :math.exp(exponent))
  end

  defp calculate_confidence(_), do: 0.0

  defp schedule_next_aggregation(interval_ms) do
    Process.send_after(self(), :aggregate_metrics, interval_ms)
  end
end
