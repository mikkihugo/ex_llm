defmodule Singularity.Metrics.Aggregator do
  @moduledoc """
  Agent Metrics Aggregator - Aggregates telemetry into actionable metrics.

  This module aggregates telemetry events from agent executions into per-agent
  performance metrics stored in the `agent_metrics` table. These aggregated metrics
  power the feedback analyzer, which drives autonomous agent evolution.

  ## Architecture

  ```
  Agent Execution
      ↓
  Telemetry Events (live in-memory counters)
      ↓
  Metrics.Aggregator.aggregate_agent_metrics/1
      ↓
  agent_metrics table (time-series with TSRANGE)
      ↓
  Feedback.Analyzer (identifies improvements needed)
  ```

  ## Time Windows

  - `:last_hour` - Last 60 minutes (default, for hourly aggregations)
  - `:last_day` - Last 24 hours (for daily trends)
  - `:last_week` - Last 7 days (for weekly patterns)

  ## Metrics Calculated

  For each agent in the time window:
  - `success_rate` - % of tasks completed successfully (0.0 - 1.0)
  - `avg_cost_cents` - Average cost per task in cents
  - `avg_latency_ms` - Average execution time in milliseconds
  - `patterns_used` - JSON map of patterns used and their frequency

  ## Usage

      # Aggregate metrics for last hour
      {:ok, metrics} = Aggregator.aggregate_agent_metrics(:last_hour)

      # Get metrics for specific agent
      {:ok, metrics} = Aggregator.get_metrics_for("agent-id", :last_week)

      # List all agents with current metrics
      agents = Aggregator.get_all_agent_metrics()
  """

  require Logger
  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.AgentMetric

  @doc """
  Aggregate agent metrics for a given time window.

  Queries telemetry data from agent execution logs and computes performance
  metrics. Stores results in agent_metrics table for historical tracking.

  ## Parameters

  - `time_window` - One of `:last_hour`, `:last_day`, `:last_week` (default: `:last_hour`)

  ## Returns

  `{:ok, metrics_map}` with agent_id -> metric_data, or `{:error, reason}`

  ## Example

      iex> Aggregator.aggregate_agent_metrics(:last_hour)
      {:ok, %{
        "elixir-specialist" => %{
          success_rate: 0.95,
          avg_cost_cents: 3.5,
          avg_latency_ms: 1200,
          patterns_used: %{"supervision" => 5, "nats" => 3}
        }
      }}
  """
  @spec aggregate_agent_metrics(atom()) :: {:ok, map()} | {:error, term()}
  def aggregate_agent_metrics(time_window \\ :last_hour) do
    try do
      time_range = calculate_time_range(time_window)

      # Query usage events and agent execution data
      # Note: This is a placeholder - actual implementation depends on
      # how agent execution events are stored in your telemetry system
      metrics = calculate_metrics_for_window(time_range)

      # Store aggregated metrics in database
      case store_metrics(metrics, time_window) do
        {:ok, count} ->
          Logger.info("✅ Aggregated metrics for #{count} agents in #{time_window} window")
          {:ok, metrics}

        {:error, reason} ->
          Logger.error("❌ Failed to store metrics", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Metrics aggregation exception", error: inspect(e), stacktrace: __STACKTRACE__)
        {:error, e}
    end
  end

  @doc """
  Get metrics for a specific agent over a time window.

  Returns the most recent aggregated metrics for the given agent.

  ## Example

      iex> Aggregator.get_metrics_for("elixir-specialist", :last_week)
      {:ok, [
        %{success_rate: 0.95, avg_cost_cents: 3.5, avg_latency_ms: 1200},
        %{success_rate: 0.92, avg_cost_cents: 3.8, avg_latency_ms: 1350}
      ]}
  """
  @spec get_metrics_for(String.t(), atom()) :: {:ok, list(map())} | {:error, term()}
  def get_metrics_for(agent_id, time_window) do
    try do
      time_range = calculate_time_range(time_window)

      metrics =
        Repo.all(
          from m in AgentMetric,
            where: m.agent_id == ^agent_id and m.time_window >= ^time_range,
            order_by: [desc: m.inserted_at],
            limit: 10
        )

      {:ok, metrics}
    rescue
      e in Exception ->
        Logger.error("Error querying metrics for agent", agent_id: agent_id, error: inspect(e))
        {:error, e}
    end
  end

  @doc """
  Get current metrics for all agents.

  Returns the most recent metric snapshot for each active agent.

  ## Example

      iex> Aggregator.get_all_agent_metrics()
      %{
        "elixir-specialist" => %{success_rate: 0.95, avg_cost_cents: 3.5},
        "rust-nif-specialist" => %{success_rate: 0.88, avg_cost_cents: 5.2}
      }
  """
  @spec get_all_agent_metrics() :: map()
  def get_all_agent_metrics do
    try do
      # Get the most recent metric for each agent
      query =
        from m in AgentMetric,
          distinct: m.agent_id,
          order_by: [m.agent_id, desc: m.inserted_at],
          select: m

      metrics = Repo.all(query)

      metrics
      |> Enum.map(fn m -> {m.agent_id, metric_to_map(m)} end)
      |> Map.new()
    rescue
      e in Exception ->
        Logger.error("Error querying all metrics", error: inspect(e))
        %{}
    end
  end

  # Private functions

  @spec calculate_time_range(atom()) :: DateTime.t()
  defp calculate_time_range(time_window) do
    now = DateTime.utc_now()

    case time_window do
      :last_hour -> DateTime.add(now, -1, :hour)
      :last_day -> DateTime.add(now, -1, :day)
      :last_week -> DateTime.add(now, -7, :day)
      _ -> DateTime.add(now, -1, :hour)
    end
  end

  @spec calculate_metrics_for_window(DateTime.t()) :: map()
  defp calculate_metrics_for_window(time_range) do
    # TODO: Query agent execution logs filtered by time_range
    # For now, return empty metrics as placeholder
    # In production, this would query:
    # - agent_execution_logs table
    # - Calculate success_rate, avg_cost_cents, avg_latency_ms
    # - Group by agent_id
    %{}
  end

  @spec store_metrics(map(), atom()) :: {:ok, integer()} | {:error, term()}
  defp store_metrics(metrics, time_window) do
    timestamp = DateTime.utc_now()
    time_lower = calculate_time_range(time_window)
    time_upper = DateTime.utc_now()

    try do
      count =
        metrics
        |> Enum.reduce(0, fn {agent_id, metric_data}, acc ->
          case create_agent_metric(agent_id, metric_data, time_lower, time_upper) do
            {:ok, _} -> acc + 1
            {:error, _} -> acc
          end
        end)

      {:ok, count}
    rescue
      e in Exception ->
        {:error, e}
    end
  end

  @spec create_agent_metric(String.t(), map(), DateTime.t(), DateTime.t()) ::
          {:ok, AgentMetric.t()} | {:error, term()}
  defp create_agent_metric(agent_id, metric_data, time_lower, time_upper) do
    attrs = %{
      agent_id: agent_id,
      time_window: {time_lower, time_upper},
      success_rate: Map.get(metric_data, :success_rate, 0.0),
      avg_cost_cents: Map.get(metric_data, :avg_cost_cents, 0.0),
      avg_latency_ms: Map.get(metric_data, :avg_latency_ms, 0.0),
      patterns_used: Map.get(metric_data, :patterns_used, %{})
    }

    Repo.insert(%AgentMetric{} |> Ecto.Changeset.change(attrs))
  end

  @spec metric_to_map(AgentMetric.t()) :: map()
  defp metric_to_map(metric) do
    %{
      agent_id: metric.agent_id,
      success_rate: metric.success_rate,
      avg_cost_cents: metric.avg_cost_cents,
      avg_latency_ms: metric.avg_latency_ms,
      patterns_used: metric.patterns_used,
      inserted_at: metric.inserted_at
    }
  end
end
