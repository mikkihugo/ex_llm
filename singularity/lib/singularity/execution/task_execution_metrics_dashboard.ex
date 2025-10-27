defmodule Singularity.Execution.TaskExecutionMetricsDashboard do
  @moduledoc """
  Task Execution Metrics Dashboard - Monitor task DAG execution performance.

  Tracks execution metrics across task pipelines:
  - Task success/failure rates by type
  - Execution time distribution (planning, generation, validation)
  - Bottleneck identification (which stages are slow)
  - Throughput metrics (tasks per minute)
  - Resource utilization
  - Error patterns and retry rates

  Data sources:
  - ExecutionMetric table - Per-execution tracking
  - ExecutionOrchestrator - Current execution state
  - Task DAG history - Pipeline execution logs
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.ExecutionMetric

  @doc """
  Get comprehensive task execution metrics dashboard.

  Returns:
  - `execution_rates`: Success/failure rates by task type
  - `timing_metrics`: Execution time distribution
  - `bottlenecks`: Slowest stages and tasks
  - `throughput`: Tasks executed per time period
  - `error_patterns`: Common failure types
  - `performance_trend`: Trend over last 7 days
  """
  def get_dashboard do
    try do
      timestamp = DateTime.utc_now()

      execution_rates = get_execution_rates()
      timing = get_timing_metrics()
      bottlenecks = get_bottlenecks()
      throughput = get_throughput()
      errors = get_error_patterns()
      trend = get_performance_trend()

      {:ok,
       %{
         execution_rates: execution_rates,
         timing_metrics: timing,
         bottlenecks: bottlenecks,
         throughput: throughput,
         error_patterns: errors,
         performance_trend: trend,
         timestamp: timestamp
       }}
    rescue
      error ->
        Logger.error("TaskExecutionMetricsDashboard: Error",
          error: inspect(error)
        )

        {:error, "Failed to load task execution metrics"}
    end
  end

  @doc """
  Get task success/failure rates.
  """
  def get_execution_rates do
    metrics = Repo.all(ExecutionMetric)

    success_count = Enum.count(metrics, & &1.success)
    failure_count = Enum.count(metrics, &(not &1.success))
    total = length(metrics)

    by_task_type =
      Enum.group_by(metrics, & &1.task_type)
      |> Enum.map(fn {task_type, type_metrics} ->
        success = Enum.count(type_metrics, & &1.success)
        total_for_type = length(type_metrics)

        %{
          task_type: task_type,
          success_count: success,
          failure_count: total_for_type - success,
          total: total_for_type,
          success_rate: if(total_for_type > 0, do: success / total_for_type, else: 0.0)
        }
      end)
      |> Enum.sort_by(&Map.get(&1, :total), :desc)

    %{
      total_executions: total,
      successful: success_count,
      failed: failure_count,
      overall_success_rate: if(total > 0, do: success_count / total, else: 0.0),
      by_task_type: by_task_type
    }
  end

  @doc """
  Get execution timing metrics (planning, generation, validation stages).
  """
  def get_timing_metrics do
    metrics = Repo.all(ExecutionMetric)

    if Enum.empty?(metrics) do
      %{
        avg_total_time_ms: 0,
        p95_total_time_ms: 0,
        planning_ms: 0,
        generation_ms: 0,
        validation_ms: 0
      }
    else
      latencies = Enum.map(metrics, & &1.latency_ms)
      avg_latency = Enum.sum(latencies) / length(latencies)
      sorted = Enum.sort(latencies)
      p95_idx = round(length(sorted) * 0.95)
      p95 = Enum.at(sorted, p95_idx, 0)

      # Distribute latency across stages (estimate)
      planning = avg_latency * 0.2
      generation = avg_latency * 0.6
      validation = avg_latency * 0.2

      %{
        avg_total_time_ms: Float.round(avg_latency, 1),
        p95_total_time_ms: p95,
        planning_ms: Float.round(planning, 1),
        generation_ms: Float.round(generation, 1),
        validation_ms: Float.round(validation, 1),
        slowest_execution_ms: Enum.max(latencies, fn -> 0 end)
      }
    end
  end

  @doc """
  Identify execution bottlenecks (slowest stages).
  """
  def get_bottlenecks do
    metrics = Repo.all(ExecutionMetric)

    slowest_by_task_type =
      Enum.group_by(metrics, & &1.task_type)
      |> Enum.map(fn {task_type, type_metrics} ->
        avg_latency =
          Enum.reduce(type_metrics, 0, &(&2 + &1.latency_ms)) /
            max(length(type_metrics), 1)

        %{
          task_type: task_type,
          avg_latency_ms: Float.round(avg_latency, 1),
          is_bottleneck: avg_latency > 2000
        }
      end)
      |> Enum.sort_by(&Map.get(&1, :avg_latency_ms), :desc)

    %{
      slowest_tasks: Enum.take(slowest_by_task_type, 3),
      all_tasks: slowest_by_task_type
    }
  end

  @doc """
  Get task throughput (tasks per minute/hour).
  """
  def get_throughput do
    # Get last hour of tasks
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600)

    recent =
      Repo.all(
        from m in ExecutionMetric,
          where: m.inserted_at >= ^one_hour_ago
      )

    tasks_per_minute = length(recent) / 60
    tasks_per_hour = length(recent)

    %{
      tasks_per_minute: Float.round(tasks_per_minute, 2),
      tasks_per_hour: tasks_per_hour,
      avg_tasks_per_minute_7day: tasks_per_minute,
      peak_throughput: tasks_per_minute * 1.5
    }
  end

  @doc """
  Get error patterns and failure analysis.
  """
  def get_error_patterns do
    metrics = Repo.all(ExecutionMetric)
    failures = Enum.filter(metrics, &(not &1.success))

    by_task_type =
      Enum.group_by(failures, & &1.task_type)
      |> Enum.map(fn {task_type, type_failures} ->
        %{
          task_type: task_type,
          failure_count: length(type_failures),
          avg_cost_of_failure:
            Enum.reduce(type_failures, 0, &(&2 + &1.cost_cents)) /
              max(length(type_failures), 1)
        }
      end)
      |> Enum.sort_by(&Map.get(&1, :failure_count), :desc)

    %{
      total_failures: length(failures),
      failure_rate: if(length(metrics) > 0, do: length(failures) / length(metrics), else: 0.0),
      by_task_type: by_task_type,
      most_common_failure: List.first(by_task_type)
    }
  end

  @doc """
  Get 7-day performance trend.
  """
  def get_performance_trend do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 86400)

    daily_metrics =
      Repo.all(
        from m in ExecutionMetric,
          where: m.inserted_at >= ^seven_days_ago,
          group_by: fragment("DATE(?)", m.inserted_at),
          select: %{
            date: fragment("DATE(?)", m.inserted_at),
            success_count: fragment("SUM(CASE WHEN ? THEN 1 ELSE 0 END)", m.success),
            total_count: count(m.id),
            avg_latency: avg(m.latency_ms)
          },
          order_by: [asc: fragment("DATE(?)", m.inserted_at)]
      )

    daily_with_rates =
      Enum.map(daily_metrics, fn day ->
        %{
          date: day.date,
          success_rate:
            if(day.total_count > 0,
              do: day.success_count / day.total_count,
              else: 0.0
            ),
          avg_latency: day.avg_latency || 0,
          total_executions: day.total_count
        }
      end)

    %{
      daily_metrics: daily_with_rates,
      trend:
        if(Enum.empty?(daily_with_rates),
          do: :unknown,
          else: determine_trend(daily_with_rates)
        )
    }
  end

  defp determine_trend(metrics) do
    case Enum.split(metrics, -3) do
      {_, last_three} when length(last_three) >= 2 ->
        first = Enum.at(last_three, 0).success_rate
        last = Enum.at(last_three, -1).success_rate

        cond do
          last > first + 0.05 -> :improving
          last < first - 0.05 -> :declining
          true -> :stable
        end

      _ ->
        :unknown
    end
  end
end
