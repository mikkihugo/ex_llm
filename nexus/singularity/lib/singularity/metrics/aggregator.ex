defmodule Singularity.Metrics.Aggregator do
  @moduledoc """
  Metrics Aggregator - Aggregates and provides access to agent performance metrics.

  Provides unified access to agent metrics across the system, aggregating data
  from various sources and providing time-series analysis capabilities.

  ## Features

  - Agent performance metrics aggregation
  - Time-series data access
  - Metric filtering and grouping
  - Statistical analysis (averages, percentiles)

  ## Usage

  ```elixir
  # Get metrics for specific agent
  {:ok, metrics} = Aggregator.get_metrics_for(agent_id, :last_week)

  # Get all agent metrics
  {:ok, all_metrics} = Aggregator.get_all_agent_metrics()
  ```
  """

  require Logger
  alias Singularity.Database.MetricsAggregation
  alias Singularity.Repo

  @doc """
  Handle telemetry events and record them as metrics.

  This function is used as a telemetry handler to automatically capture
  and record telemetry events to the metrics database.
  """
  @spec handle_telemetry_event([atom()], map(), map(), any()) :: :ok
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    try do
      # Convert telemetry event to metric format and record it
      record_telemetry_metric(event_name, measurements, metadata)
      :ok
    rescue
      e ->
        Logger.error("Failed to handle telemetry event #{inspect(event_name)}: #{inspect(e)}")
        :ok
    end
  end

  @doc """
  Get metrics for a specific agent over a time period.

  ## Parameters
  - `agent_id` - The agent identifier
  - `period` - Time period (:last_week, :last_month, etc.)

  ## Returns
  - `{:ok, metrics}` - Agent metrics for the period
  - `{:error, reason}` - Failed to retrieve metrics
  """
  def get_metrics_for(agent_id, period) when is_binary(agent_id) or is_integer(agent_id) do
    try do
      # Convert period to seconds
      seconds = period_to_seconds(period)

      # Get metrics from database
      case MetricsAggregation.get_metrics(:agent_performance, last: seconds, agent_id: agent_id) do
        {:ok, metrics} ->
          {:ok, format_agent_metrics(metrics)}
        {:error, reason} ->
          Logger.warning("Failed to get metrics for agent #{agent_id}", reason: reason)
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error getting metrics for agent #{agent_id}", error: inspect(e))
        {:error, :metrics_retrieval_failed}
    end
  end

  @doc """
  Get metrics for all agents.

  ## Returns
  - `{:ok, metrics_map}` - Map of agent_id => metrics
  - `{:error, reason}` - Failed to retrieve metrics
  """
  def get_all_agent_metrics do
    try do
      # Get all agent metrics from the last week
      case MetricsAggregation.get_all_metrics(:agent_performance, last: 7 * 24 * 3600) do
        {:ok, metrics} ->
          {:ok, group_metrics_by_agent(metrics)}
        {:error, reason} ->
          Logger.warning("Failed to get all agent metrics", reason: reason)
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error getting all agent metrics", error: inspect(e))
        {:error, :metrics_retrieval_failed}
    end
  end

  @doc """
  Record a metric event for an agent.

  ## Parameters
  - `agent_id` - The agent identifier
  - `metric_type` - Type of metric (:cpu, :memory, :tasks_completed, etc.)
  - `value` - Metric value
  - `metadata` - Additional metadata

  ## Returns
  - `:ok` - Metric recorded successfully
  - `{:error, reason}` - Failed to record metric
  """
  def record_agent_metric(agent_id, metric_type, value, metadata \\ %{}) do
    try do
      metadata_with_agent = Map.put(metadata, :agent_id, agent_id)

      case MetricsAggregation.record_metric(metric_type, value, metadata_with_agent) do
        :ok ->
          :ok
        {:error, reason} ->
          Logger.warning("Failed to record metric for agent #{agent_id}",
            metric_type: metric_type,
            reason: reason
          )
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error recording metric for agent #{agent_id}",
          metric_type: metric_type,
          error: inspect(e)
        )
        {:error, :metric_recording_failed}
    end
  end

  @doc """
  Get aggregated statistics for agents.

  ## Parameters
  - `period` - Time period to aggregate over

  ## Returns
  - `{:ok, stats}` - Aggregated statistics
  - `{:error, reason}` - Failed to get statistics
  """
  def get_agent_statistics(period \\ :last_week) do
    try do
      seconds = period_to_seconds(period)

      case MetricsAggregation.get_aggregated_metrics(:agent_performance, last: seconds) do
        {:ok, aggregated} ->
          {:ok, %{
            total_agents: length(aggregated),
            average_performance: calculate_average(aggregated, :performance_score),
            top_performers: get_top_performers(aggregated, 5),
            performance_distribution: calculate_distribution(aggregated, :performance_score)
          }}
        {:error, reason} ->
          Logger.warning("Failed to get agent statistics", reason: reason)
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error getting agent statistics", error: inspect(e))
        {:error, :statistics_calculation_failed}
    end
  end

  # Private Functions

  defp period_to_seconds(period) do
    case period do
      :last_hour -> 3600
      :last_day -> 24 * 3600
      :last_week -> 7 * 24 * 3600
      :last_month -> 30 * 24 * 3600
      seconds when is_integer(seconds) -> seconds
      _ -> 7 * 24 * 3600  # Default to last week
    end
  end

  defp format_agent_metrics(metrics) do
    # Format raw metrics into structured agent metrics
    %{
      agent_id: metrics[:agent_id],
      period: metrics[:period] || :unknown,
      metrics: %{
        cpu_usage: metrics[:cpu_usage] || [],
        memory_usage: metrics[:memory_usage] || [],
        tasks_completed: metrics[:tasks_completed] || 0,
        error_rate: metrics[:error_rate] || 0.0,
        average_response_time: metrics[:average_response_time] || 0.0
      },
      summary: %{
        total_tasks: metrics[:total_tasks] || 0,
        success_rate: metrics[:success_rate] || 0.0,
        average_performance: metrics[:average_performance] || 0.0
      }
    }
  end

  defp group_metrics_by_agent(metrics) do
    # Group metrics by agent_id
    Enum.group_by(metrics, fn metric -> metric[:agent_id] end)
    |> Enum.map(fn {agent_id, agent_metrics} ->
      {agent_id, format_agent_metrics(%{
        agent_id: agent_id,
        metrics: agent_metrics,
        summary: calculate_agent_summary(agent_metrics)
      })}
    end)
    |> Map.new()
  end

  defp calculate_agent_summary(metrics) do
    # Calculate summary statistics for an agent
    %{
      total_tasks: Enum.reduce(metrics, 0, fn m, acc -> acc + (m[:tasks_completed] || 0) end),
      success_rate: calculate_average(metrics, :success_rate),
      average_performance: calculate_average(metrics, :performance_score)
    }
  end

  defp calculate_average(metrics, key) do
    values = Enum.map(metrics, fn m -> m[key] || 0 end) |> Enum.filter(&(&1 > 0))
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end

  defp get_top_performers(metrics, count) do
    metrics
    |> Enum.sort_by(fn m -> m[:performance_score] || 0 end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn m -> %{agent_id: m[:agent_id], score: m[:performance_score] || 0} end)
  end

  defp calculate_distribution(metrics, key) do
    values = Enum.map(metrics, fn m -> m[key] || 0 end) |> Enum.sort()

    if Enum.empty?(values) do
      %{min: 0, max: 0, median: 0, p95: 0}
    else
      %{
        min: Enum.min(values),
        max: Enum.max(values),
        median: Enum.at(values, div(length(values), 2)),
        p95: Enum.at(values, round(length(values) * 0.95))
      }
    end
  end

  # Private function to record telemetry events as metrics
  defp record_telemetry_metric(event_name, measurements, metadata) do
    # Convert telemetry event structure to metric format
    {measurement, metric_type} = extract_measurement_and_type(event_name, measurements)

    # Enrich metadata with environment and node information
    enriched_metadata = Map.merge(metadata, %{
      environment: Application.get_env(:singularity, :environment, "development"),
      node: Node.self() |> to_string(),
      telemetry_event: Enum.join(event_name, ".")
    })

    # Record the metric using the existing MetricsAggregation system
    MetricsAggregation.record_metric(metric_type, measurement, enriched_metadata)
  end

  defp extract_measurement_and_type(event_name, measurements) do
    case event_name do
      [:singularity, :llm, :request, :stop] ->
        cost = measurements[:cost_usd] || 0.0
        duration = measurements[:duration] || 0
        {cost + duration, :llm_request}

      [:singularity, :agent, :task, :stop] ->
        {measurements[:duration] || 0, :agent_task}

      [:singularity, :tool, :execution, :stop] ->
        {measurements[:duration_ms] || 0, :tool_execution}

      [:singularity, :search, :completed] ->
        {measurements[:result_count] || 0, :search_completed}

      _ ->
        {measurements[:value] || measurements[:count] || 1, :generic_metric}
    end
  end
end