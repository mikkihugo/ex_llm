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
        SASL.infrastructure_failure(
          :telemetry_error,
          "Failed to handle telemetry event",
          event_name: event_name,
          error: e
        )

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
      normalized_id = normalize_agent_id(agent_id)
      # Convert period to seconds
      seconds = period_to_seconds(period)

      # Get metrics from database
      case MetricsAggregation.get_metrics(:agent_performance, last: seconds, agent_id: agent_id) do
        {:ok, metrics} ->
          {:ok, summarize_agent_metrics(normalized_id, period, metrics)}

        {:error, reason} ->
          Logger.warning("Failed to get metrics for agent #{agent_id}", reason: reason)
          {:error, reason}
      end
    rescue
      e ->
        SASL.database_failure(
          :metrics_retrieval_error,
          "Failed to retrieve metrics for agent",
          agent_id: agent_id,
          error: e
        )

        {:error, :metrics_retrieval_failed}
    end
  end

  @doc """
  Get metrics for all agents.

  ## Returns
  - `{:ok, metrics_map}` - Map of agent_id => metrics
  - `{:error, reason}` - Failed to retrieve metrics
  """
  def get_all_agent_metrics(period \\ :last_week) do
    try do
      seconds = period_to_seconds(period)

      case MetricsAggregation.get_metrics(:agent_performance, last: seconds) do
        {:ok, metrics} ->
          agent_metrics =
            metrics
            |> Enum.group_by(fn metric ->
              metric
              |> agent_id_from_metric()
              |> normalize_agent_id()
            end)
            |> Enum.reject(fn {agent_id, _} -> is_nil(agent_id) or agent_id == "" end)
            |> Enum.map(fn {agent_id, agent_samples} ->
              {agent_id, summarize_agent_metrics(agent_id, period, agent_samples)}
            end)
            |> Map.new()

          {:ok, agent_metrics}

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
      case get_all_agent_metrics(period) do
        {:ok, metrics_by_agent} ->
          summaries = Map.values(metrics_by_agent)
          summary_values = Enum.map(summaries, fn %{summary: %{average_value: avg}} -> avg end)

          {:ok,
           %{
             total_agents: length(summaries),
             average_performance: average(summary_values),
             top_performers: top_performers(summaries, 5),
             performance_distribution: calculate_distribution(summary_values)
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
      # Default to last week
      _ -> 7 * 24 * 3600
    end
  end

  defp summarize_agent_metrics(agent_id, period, metrics) do
    resolved_agent_id =
      case normalize_agent_id(agent_id) do
        nil ->
          metrics
          |> Enum.find_value(nil, fn metric ->
            metric
            |> agent_id_from_metric()
            |> normalize_agent_id()
          end)

        normalized ->
          normalized
      end

    values =
      metrics
      |> Enum.map(&metric_value/1)
      |> Enum.reject(&is_nil/1)

    latest_sample = List.first(metrics)

    %{
      agent_id: resolved_agent_id,
      period: period,
      samples: metrics,
      summary: %{
        sample_count: length(values),
        average_value: average(values),
        min_value: min_value(values),
        max_value: max_value(values),
        latest_value: metric_value(latest_sample),
        latest_timestamp: latest_sample && latest_sample.timestamp
      }
    }
  end

  defp agent_id_from_metric(%{labels: labels}) when is_map(labels) do
    Map.get(labels, "agent_id") || Map.get(labels, :agent_id)
  end

  defp agent_id_from_metric(_), do: nil

  defp normalize_agent_id(nil), do: nil

  defp normalize_agent_id(agent_id) when is_binary(agent_id) do
    agent_id
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_agent_id(agent_id) when is_integer(agent_id), do: Integer.to_string(agent_id)
  defp normalize_agent_id(agent_id), do: to_string(agent_id)

  defp metric_value(nil), do: nil

  defp metric_value(%{value: %Decimal{} = decimal}) do
    Decimal.to_float(decimal)
  end

  defp metric_value(%{value: value}) when is_number(value), do: value * 1.0

  defp metric_value(%{value: value}) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> nil
    end
  end

  defp metric_value(%{value: value}) when is_map(value) do
    value
    |> Map.get("value")
    |> case do
      nil -> nil
      inner -> metric_value(%{value: inner})
    end
  end

  defp metric_value(_), do: nil

  defp min_value([]), do: 0.0
  defp min_value(values), do: Enum.min(values)

  defp max_value([]), do: 0.0
  defp max_value(values), do: Enum.max(values)

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp calculate_distribution([]) do
    %{min: 0.0, max: 0.0, median: 0.0, p95: 0.0}
  end

  defp calculate_distribution(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    median =
      if rem(count, 2) == 1 do
        Enum.at(sorted, div(count, 2))
      else
        upper = Enum.at(sorted, div(count, 2))
        lower = Enum.at(sorted, div(count, 2) - 1)
        average([upper, lower])
      end

    p95_index =
      case count do
        1 ->
          0

        n ->
          n
          |> Kernel.*(0.95)
          |> Float.ceil()
          |> trunc()
          |> Kernel.-(1)
          |> max(0)
          |> min(n - 1)
      end

    %{
      min: hd(sorted),
      max: List.last(sorted),
      median: median,
      p95: Enum.at(sorted, p95_index)
    }
  end

  defp top_performers(agent_metrics, count) do
    agent_metrics
    |> Enum.sort_by(fn %{summary: %{average_value: value}} -> value || 0.0 end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn %{agent_id: agent_id, summary: %{average_value: value}} ->
      %{agent_id: agent_id, score: value || 0.0}
    end)
  end

  # Private function to record telemetry events as metrics
  defp record_telemetry_metric(event_name, measurements, metadata) do
    # Convert telemetry event structure to metric format
    {measurement, metric_type} = extract_measurement_and_type(event_name, measurements)

    # Enrich metadata with environment and node information
    enriched_metadata =
      Map.merge(metadata, %{
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
