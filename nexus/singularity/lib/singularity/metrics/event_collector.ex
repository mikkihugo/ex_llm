defmodule Singularity.Metrics.EventCollector do
  @moduledoc """
  Event Collector - Handles telemetry events and records metrics to the database.

  This module bridges Telemetry events to the unified Metrics system by:
  - Processing telemetry events from various sources
  - Recording structured metrics to the database
  - Providing convenience functions for common metric types
  - Enriching events with environment and node information

  ## Usage

  ```elixir
  # Direct recording
  EventCollector.record_measurement("llm.cost", 0.025, "usd", %{model: "claude"})

  # Convenience functions
  EventCollector.record_cost_spent(:api_call, 0.025, %{service: "openai"})
  EventCollector.record_latency_ms(:search_query, 245, %{query_type: "semantic"})
  ```

  ## Telemetry Integration

  The module automatically handles telemetry events attached in Telemetry module:
  - [:singularity, :llm, :request, :stop]
  - [:singularity, :agent, :task, :stop]
  - [:singularity, :tool, :execution, :stop]
  - [:singularity, :search, :completed]
  """

  require Logger
  alias Singularity.Metrics.Event
  alias Singularity.Repo

  @doc """
  Handle telemetry events and record them as metrics.

  This function is used as a telemetry handler to automatically capture
  and record telemetry events to the metrics database.
  """
  @spec handle_telemetry_event([atom()], map(), map(), any()) :: :ok
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    try do
      # Convert telemetry event to metric event
      metric_data = telemetry_to_metric(event_name, measurements, metadata)

      # Record the metric asynchronously to avoid blocking telemetry
      Task.start(fn ->
        record_metric_event(metric_data)
      end)

      :ok
    rescue
      e ->
        Logger.error("Failed to handle telemetry event #{inspect(event_name)}: #{inspect(e)}")
        :ok
    end
  end

  @doc """
  Record a raw measurement event.

  ## Parameters
  - `event_name` - Name of the event (e.g., "llm.cost", "search.latency")
  - `value` - Numeric measurement value
  - `unit` - Unit of measurement ("ms", "usd", "count", etc.)
  - `tags` - Additional contextual data
  """
  @spec record_measurement(String.t(), number(), String.t(), map()) :: :ok
  def record_measurement(event_name, value, unit, tags \\ %{}) do
    Task.start(fn ->
      metric_data = %{
        event_name: event_name,
        measurement: value,
        unit: unit,
        tags: enrich_tags(tags),
        recorded_at: DateTime.utc_now()
      }

      record_metric_event(metric_data)
    end)

    :ok
  end

  @doc """
  Record cost spent (convenience function for cost tracking).

  ## Parameters
  - `operation` - Operation that incurred cost
  - `cost_usd` - Cost in USD
  - `tags` - Additional contextual data
  """
  @spec record_cost_spent(atom(), float(), map()) :: :ok
  def record_cost_spent(operation, cost_usd, tags \\ %{}) do
    record_measurement("#{operation}.cost", cost_usd, "usd", tags)
  end

  @doc """
  Record latency in milliseconds (convenience function for performance tracking).

  ## Parameters
  - `operation` - Operation being measured
  - `latency_ms` - Latency in milliseconds
  - `tags` - Additional contextual data
  """
  @spec record_latency_ms(atom(), number(), map()) :: :ok
  def record_latency_ms(operation, latency_ms, tags \\ %{}) do
    record_measurement("#{operation}.latency", latency_ms, "ms", tags)
  end

  @doc """
  Record agent success/failure.

  ## Parameters
  - `agent_id` - Agent identifier
  - `success` - Boolean success status
  - `latency_ms` - Optional latency in milliseconds
  """
  @spec record_agent_success(String.t(), boolean(), number() | nil) :: :ok
  def record_agent_success(agent_id, success, latency_ms \\ nil) do
    event_name = if success, do: "agent.success", else: "agent.failure"
    measurement = if success, do: 1, else: 0

    tags = %{agent_id: agent_id}
    tags = if latency_ms, do: Map.put(tags, :latency_ms, latency_ms), else: tags

    record_measurement(event_name, measurement, "count", tags)
  end

  @doc """
  Record search completion metrics.

  ## Parameters
  - `query` - Search query string
  - `result_count` - Number of results returned
  - `latency_ms` - Search latency in milliseconds
  """
  @spec record_search_completed(String.t(), number(), number()) :: :ok
  def record_search_completed(query, result_count, latency_ms) do
    tags = %{query: query, latency_ms: latency_ms}
    record_measurement("search.completed", result_count, "count", tags)
  end

  # Private Functions

  defp telemetry_to_metric(event_name, measurements, metadata) do
    # Convert telemetry event structure to metric format
    {measurement, unit} = extract_measurement_and_unit(event_name, measurements)

    %{
      event_name: Enum.join(event_name, "."),
      measurement: measurement,
      unit: unit,
      tags: enrich_tags(Map.drop(metadata, [:__struct__])),
      recorded_at: DateTime.utc_now()
    }
  end

  defp extract_measurement_and_unit(event_name, measurements) do
    case event_name do
      [:singularity, :llm, :request, :stop] ->
        {measurements[:cost_usd] || measurements[:duration] || 1, "usd"}

      [:singularity, :agent, :task, :stop] ->
        {measurements[:duration] || 1, "ms"}

      [:singularity, :tool, :execution, :stop] ->
        {measurements[:duration_ms] || 1, "ms"}

      [:singularity, :search, :completed] ->
        {measurements[:result_count] || 0, "count"}

      _ ->
        {measurements[:value] || measurements[:count] || 1, "count"}
    end
  end

  defp enrich_tags(tags) do
    Map.merge(tags, %{
      environment: Application.get_env(:singularity, :environment, "development"),
      node: Node.self() |> to_string()
    })
  end

  defp record_metric_event(metric_data) do
    try do
      %Event{}
      |> Event.changeset(metric_data)
      |> Repo.insert()
    rescue
      e ->
        Logger.error("Failed to record metric event: #{inspect(e)}",
          event_name: metric_data.event_name,
          measurement: metric_data.measurement
        )
    end
  end
end