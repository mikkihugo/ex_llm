defmodule CentralCloud.ModelLearning.RoutingEventConsumer do
  @moduledoc """
  Consumes routing decisions from Singularity instances via pgmq.

  ## Architecture

  ```
  Singularity Instances
      ↓ (publish routing decisions)
  PostgreSQL pgmq: model_routing_decisions queue
      ↓
  RoutingEventConsumer (GenServer, polls every 5s)
      ↓
  1. Record routing event in database
  2. Update aggregated metrics (usage_count, success_rate, etc.)
  3. Track response times
      ↓
  Database: routing_records, model_routing_metrics tables
      ↓
  ComplexityScoreLearner (separate process)
      ├─ Analyzes high-usage models
      ├─ Calculates optimal complexity scores
      └─ Publishes updates back to instances via model_score_updates queue
  ```

  ## Behavior

  - Polls `model_routing_decisions` queue every 5 seconds
  - Processes routing events asynchronously
  - Persists all decisions for audit trail
  - Updates real-time metrics for learning
  - Continues gracefully if database unavailable
  - Monitors queue for anomalies

  ## Events Consumed

  ```json
  {
    "timestamp": "2025-10-27T06:55:00Z",
    "instance_id": "singularity-1",
    "routing_decision": {
      "complexity": "complex",
      "selected_model": "gpt-4o",
      "selected_provider": "github_models",
      "complexity_score": 4.8,
      "outcome": "routed",
      "response_time_ms": 1240
    }
  }
  ```
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.ModelLearning.{
    RoutingRecord,
    ModelMetrics,
    ModelPerformanceAnalyzer
  }

  @queue_name "model_routing_decisions"
  @poll_interval_ms 5000  # Check every 5 seconds
  @max_consecutive_errors 5  # Stop if too many errors

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("RoutingEventConsumer starting...")

    # Ensure queue exists in database
    ensure_queue_exists()

    # Schedule first poll
    schedule_poll()

    state = %{
      processed_count: 0,
      error_count: 0,
      last_error: nil,
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_info(:poll, state) do
    case process_batch() do
      {:ok, count} ->
        # Successfully processed batch
        if count > 0 do
          Logger.debug("Processed #{count} routing events")
        end

        schedule_poll()
        {:noreply, %{state | processed_count: state.processed_count + count, error_count: 0}}

      {:error, reason} ->
        # Log error but continue
        Logger.warning("Error processing routing events: #{inspect(reason)}")
        error_count = state.error_count + 1

        if error_count > @max_consecutive_errors do
          Logger.error("Too many consecutive errors, stopping consumer")
          {:stop, :max_errors, state}
        else
          schedule_poll()
          {:noreply, %{state | error_count: error_count, last_error: reason}}
        end
    end
  end

  # Helper: Process one batch of events from queue
  defp process_batch do
    case receive_message() do
      {:ok, {msg_id, event}} ->
        # Process the event
        process_routing_event(event)

        # Delete from queue
        case delete_message(msg_id) do
          :ok ->
            # Continue to next message
            {:ok, 1 + (elem(process_batch(), 1) || 0)}

          {:error, _} ->
            Logger.warning("Failed to delete message #{msg_id}, may reprocess")
            {:ok, 1}
        end

      :empty ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error in process_batch: #{inspect(e)}")
      {:error, e}
  end

  # Process a single routing event
  defp process_routing_event(event) do
    with {:ok, record} <- create_routing_record(event),
         :ok <- update_model_metrics(event),
         :ok <- analyze_anomalies(event) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Failed to process routing event: #{inspect(reason)}")
        :error
    end
  end

  # Create audit record of routing decision
  defp create_routing_record(%{
    "timestamp" => timestamp,
    "instance_id" => instance_id,
    "routing_decision" => decision
  }) do
    record = %{
      timestamp: parse_timestamp(timestamp),
      instance_id: instance_id,
      complexity: decision["complexity"],
      model: decision["selected_model"],
      provider: decision["selected_provider"],
      score: decision["complexity_score"],
      outcome: decision["outcome"],
      response_time_ms: decision["response_time_ms"],
      capabilities_required: decision["capabilities_required"] || [],
      preference: decision["prefer"]
    }

    case Repo.insert(%RoutingRecord{} |> RoutingRecord.changeset(record)) do
      {:ok, _record} -> {:ok, record}
      {:error, reason} -> {:error, reason}
    end
  end

  # Update real-time metrics for this model/complexity combo
  defp update_model_metrics(%{"routing_decision" => decision}) do
    model = decision["selected_model"]
    complexity = decision["complexity"]
    outcome = decision["outcome"]
    response_time = decision["response_time_ms"]

    try do
      # Update or create metrics record
      case ModelMetrics.update_or_create(model, complexity) do
        {:ok, _metrics} ->
          # Update counters based on outcome
          if outcome == "success" do
            ModelMetrics.increment_success(model, complexity)
          end

          # Record response time if available
          if response_time do
            ModelMetrics.record_response_time(model, complexity, response_time)
          end

          :ok

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error updating metrics: #{inspect(e)}")
        :error
    end
  end

  # Check for anomalies (unusual patterns)
  defp analyze_anomalies(%{"routing_decision" => decision}) do
    try do
      ModelPerformanceAnalyzer.analyze(decision)
    rescue
      _ -> :ok  # Don't fail if analysis fails
    end
  end

  # === pgmq Queue Operations ===

  defp ensure_queue_exists do
    try do
      Repo.query("SELECT pgmq.create($1)", [@queue_name])
      Logger.info("Ensured queue exists: #{@queue_name}")
    rescue
      _ -> :ok  # Queue likely already exists
    end
  end

  defp receive_message do
    case Repo.query(
      "SELECT msg_id, body FROM pgmq.read($1, vt := 30, limit := 1)",
      [@queue_name]
    ) do
      {:ok, %{rows: [[msg_id, body_json]]}} ->
        # Decode JSON body
        case Jason.decode(body_json) do
          {:ok, body} -> {:ok, {msg_id, body}}
          {:error, reason} -> {:error, {:decode_failed, reason}}
        end

      {:ok, %{rows: []}} ->
        :empty

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error receiving message: #{inspect(e)}")
      {:error, e}
  end

  defp delete_message(msg_id) do
    case Repo.query("SELECT pgmq.delete($1, $2)", [@queue_name, msg_id]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error deleting message: #{inspect(e)}")
      {:error, e}
  end

  # === Scheduling ===

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end

  # === Utilities ===

  defp parse_timestamp(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
