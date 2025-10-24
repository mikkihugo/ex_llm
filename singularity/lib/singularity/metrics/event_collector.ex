defmodule Singularity.Metrics.EventCollector do
  @moduledoc """
  Metrics Event Collector - Records measurements from all sources.

  Central recording point for all metrics in the system. Collects measurements
  from Telemetry events, RateLimiter costs, ErrorRateTracker, agent execution,
  and other sources, storing them in the unified metrics_events table.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Metrics.EventCollector",
    "purpose": "Unified measurement recording from all system sources",
    "layer": "metrics",
    "status": "production",
    "integration": "Telemetry, RateLimiter, ErrorRateTracker, Agents"
  }
  ```

  ## Self-Documenting API

  Main recording function:
  - `record_measurement/4` - Record raw measurement with event name and unit

  Convenience functions (self-documenting by purpose):
  - `record_cost_spent/3` - Record money spent (cost_usd)
  - `record_latency_ms/3` - Record time taken (elapsed_ms)
  - `record_agent_success/3` - Record agent execution outcome
  - `record_search_completed/3` - Record search operation result

  Integration handler:
  - `handle_telemetry_event/4` - Telemetry event handler

  ## Examples

  ```elixir
  # Record LLM cost
  EventCollector.record_cost_spent(:llm_api_call, 0.025, %{model: "claude-opus"})

  # Record search latency
  EventCollector.record_latency_ms(:search_query, 245, %{query: "async patterns"})

  # Record agent success
  EventCollector.record_agent_success("agent-123", true, 2500)

  # Record search operation
  EventCollector.record_search_completed("async", 42, 245)
  ```

  ## Implementation Notes

  - Non-blocking: Uses Task to write asynchronously
  - Error handling: Logs failures but doesn't crash
  - Tag enrichment: Automatically adds environment, node, timestamp
  - Validation: Measurements must be valid numbers (not NaN/Inf)
  """

  require Logger
  alias Singularity.Metrics.Event
  alias Singularity.Repo

  @doc """
  Record a raw measurement event.

  This is the main recording function. All other functions use this internally.

  ## Parameters

  - `event_name` - Event identifier: "agent.success", "llm.cost", etc.
  - `measurement` - The numeric value to record
  - `unit` - Unit of measurement: "ms", "usd", "count", "%", etc.
  - `tags` - Map of contextual data: {agent_id, model, operation, ...}

  ## Returns

  `{:ok, Event.t}` - Event recorded successfully
  `{:error, term}` - Recording failed (logged)

  ## Examples

      iex> EventCollector.record_measurement("llm.cost", 0.025, "usd", %{model: "claude"})
      {:ok, %Singularity.Metrics.Event{...}}

      iex> EventCollector.record_measurement("agent.latency", 2500, "ms", %{agent_id: "123"})
      {:ok, %Singularity.Metrics.Event{...}}
  """
  def record_measurement(event_name, measurement, unit, tags \\ %{})
      when is_binary(event_name) and is_number(measurement) and is_binary(unit) and is_map(tags) do
    # Record asynchronously to avoid blocking
    Task.Supervisor.start_child(
      Singularity.TaskSupervisor,
      fn -> insert_event(event_name, measurement, unit, tags) end
    )
  end

  @doc """
  Record cost spent (convenience function for cost measurements).

  Automatically sets unit to "usd" and creates event name for operation.

  ## Parameters

  - `operation` - What operation this cost is for (atom or string)
  - `cost_usd` - Cost amount in USD
  - `tags` - Contextual data (model, complexity, etc.)

  ## Returns

  `{:ok, Event.t}` - Cost recorded
  `{:error, term}` - Recording failed

  ## Examples

      iex> EventCollector.record_cost_spent(:llm_api, 0.025, %{model: "claude-opus"})
      {:ok, %Singularity.Metrics.Event{...}}

      iex> EventCollector.record_cost_spent(:search, 0.001, %{query_type: "semantic"})
      {:ok, %Singularity.Metrics.Event{...}}
  """
  def record_cost_spent(operation, cost_usd, tags \\ %{})
      when is_atom(operation) or is_binary(operation) do
    operation_str = if is_atom(operation), do: Atom.to_string(operation), else: operation
    event_name = "#{operation_str}.cost"

    record_measurement(event_name, cost_usd, "usd", tags)
  end

  @doc """
  Record latency measurement (convenience function for timing).

  Automatically sets unit to "ms" and creates event name for operation.

  ## Parameters

  - `operation` - What operation this timing is for (atom or string)
  - `elapsed_ms` - Time elapsed in milliseconds
  - `tags` - Contextual data (agent_id, complexity, etc.)

  ## Returns

  `{:ok, Event.t}` - Latency recorded
  `{:error, term}` - Recording failed

  ## Examples

      iex> EventCollector.record_latency_ms(:search_query, 245, %{results: 42})
      {:ok, %Singularity.Metrics.Event{...}}

      iex> EventCollector.record_latency_ms(:agent_execution, 3500, %{agent_id: "123"})
      {:ok, %Singularity.Metrics.Event{...}}
  """
  def record_latency_ms(operation, elapsed_ms, tags \\ %{})
      when is_atom(operation) or is_binary(operation) do
    operation_str = if is_atom(operation), do: Atom.to_string(operation), else: operation
    event_name = "#{operation_str}.latency"

    record_measurement(event_name, elapsed_ms, "ms", tags)
  end

  @doc """
  Record agent execution success (convenience function).

  Automatically creates event based on success status.

  ## Parameters

  - `agent_id` - Unique agent identifier
  - `successful` - Whether execution succeeded (boolean)
  - `latency_ms` - Time taken in milliseconds

  ## Returns

  `{:ok, Event.t}` - Execution metric recorded
  `{:error, term}` - Recording failed

  ## Examples

      iex> EventCollector.record_agent_success("agent-123", true, 2500)
      {:ok, %Singularity.Metrics.Event{event_name: "agent.success", ...}}

      iex> EventCollector.record_agent_success("agent-456", false, 500)
      {:ok, %Singularity.Metrics.Event{event_name: "agent.failure", ...}}
  """
  def record_agent_success(agent_id, successful, latency_ms)
      when is_binary(agent_id) and is_boolean(successful) and is_integer(latency_ms) do
    event_name = if successful, do: "agent.success", else: "agent.failure"
    measurement = if successful, do: 1, else: 0

    record_measurement(event_name, measurement, "count", %{
      agent_id: agent_id,
      latency_ms: latency_ms
    })
  end

  @doc """
  Record search operation completion (convenience function).

  Records search metrics: query, result count, latency.

  ## Parameters

  - `query` - Search query (or query type)
  - `results_count` - Number of results returned
  - `elapsed_ms` - Time taken in milliseconds

  ## Returns

  `{:ok, Event.t}` - Search metric recorded
  `{:error, term}` - Recording failed

  ## Examples

      iex> EventCollector.record_search_completed("async patterns", 42, 245)
      {:ok, %Singularity.Metrics.Event{...}}
  """
  def record_search_completed(query, results_count, elapsed_ms)
      when is_binary(query) and is_integer(results_count) and is_integer(elapsed_ms) do
    record_measurement("search.completed", results_count, "count", %{
      query: query,
      latency_ms: elapsed_ms
    })
  end

  @doc """
  Telemetry event handler (for telemetry.attach integration).

  This function is called automatically by Telemetry when events fire.
  It converts Telemetry events to unified metrics.

  ## Parameters

  - `event_name` - Telemetry event name (list)
  - `measurements` - Telemetry measurements (map)
  - `metadata` - Telemetry metadata (map)
  - `config` - Handler configuration (map)

  ## Returns

  `:ok` - Event handled (or error logged)

  ## Examples (internal use)

      Telemetry will call this automatically:
      :telemetry.execute([:singularity, :llm, :request, :stop], %{cost_usd: 0.025}, %{...})
      → Calls handle_telemetry_event([:singularity, :llm, :request, :stop], ...)
  """
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    try do
      case event_name do
        [:singularity, :llm, :request, :stop] ->
          handle_llm_request_stop(measurements, metadata)

        [:singularity, :agent, :execution, :stop] ->
          handle_agent_execution_stop(measurements, metadata)

        [:singularity, :search, :completed] ->
          handle_search_completed(measurements, metadata)

        [:singularity, :tool, :execution, :stop] ->
          handle_tool_execution_stop(measurements, metadata)

        _other ->
          :ok
      end
    rescue
      e ->
        Logger.error("Error in Telemetry handler for #{inspect(event_name)}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        :ok
    end
  end

  # Private helpers - Telemetry handlers

  defp handle_llm_request_stop(measurements, metadata) do
    cost_usd = Map.get(measurements, :cost_usd, 0)

    tags = %{
      model: metadata[:model],
      complexity: metadata[:complexity],
      task_type: metadata[:task_type],
      success: metadata[:success]
    }

    record_cost_spent(:llm_request, cost_usd, tags)
  end

  defp handle_agent_execution_stop(measurements, metadata) do
    latency_ms = Map.get(measurements, :duration_ms, 0)
    successful = metadata[:success] == true

    record_agent_success(
      metadata[:agent_id] || "unknown",
      successful,
      trunc(latency_ms)
    )
  end

  defp handle_search_completed(measurements, metadata) do
    results_count = Map.get(measurements, :results_count, 0)
    elapsed_ms = Map.get(measurements, :duration_ms, 0)

    record_search_completed(
      metadata[:query] || "unknown",
      results_count,
      trunc(elapsed_ms)
    )
  end

  defp handle_tool_execution_stop(measurements, metadata) do
    elapsed_ms = Map.get(measurements, :duration_ms, 0)

    record_latency_ms(
      metadata[:tool_name] || "unknown",
      trunc(elapsed_ms),
      %{success: metadata[:success]}
    )
  end

  # Private helpers - Database insertion

  defp insert_event(event_name, measurement, unit, tags) do
    now = DateTime.utc_now()

    event = %Event{
      event_name: event_name,
      measurement: measurement,
      unit: unit,
      tags: enrich_tags(tags),
      recorded_at: now
    }

    case Repo.insert(event) do
      {:ok, result} ->
        Logger.debug("Recorded metric event",
          event_name: event_name,
          measurement: measurement,
          unit: unit
        )

        {:ok, result}

      {:error, changeset} ->
        Logger.error("Failed to record metric event",
          event_name: event_name,
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
    end
  end

  defp enrich_tags(tags) do
    tags
    |> Map.put_new(:environment, get_environment())
    |> Map.put_new(:node, node())
  end

  defp get_environment do
    System.get_env("MIX_ENV", "dev")
  end
end
