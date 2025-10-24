defmodule Centralcloud.NATS.PatternValidatorSubscriber do
  @moduledoc """
  NATS subscriber for pattern validation requests from Singularity instances.

  Subject: patterns.validate.request
  Response Subject: patterns.validate.response.<request_id>

  ## Message Format

  Request:
  ```json
  {
    "codebase_id": "mikkihugo/singularity",
    "code_samples": [
      {"path": "lib/service.ex", "content": "...", "language": "elixir"}
    ],
    "pattern_type": "architecture",  // optional, default "architecture"
    "request_id": "uuid"              // optional, for correlation
  }
  ```

  Response:
  ```json
  {
    "status": "success" | "error",
    "consensus": {...},               // if success
    "error": "...",                   // if error
    "timestamp": "2025-10-23T..."
  }
  ```
  """

  use GenServer
  require Logger
  alias Centralcloud.LLMTeamOrchestrator

  @subject "patterns.validate.request"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    case subscribe_to_nats() do
      {:ok, subscription} ->
        Logger.info("Subscribed to NATS subject: #{@subject}")
        {:ok, %{subscription: subscription, requests_processed: 0}}

      {:error, reason} ->
        Logger.error("Failed to subscribe to NATS: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:nats_msg, subject, reply_to, payload}, state) do
    Logger.debug("Received pattern validation request on #{subject}")

    # Process request asynchronously to avoid blocking subscriber
    Task.start(fn -> process_request(payload, reply_to) end)

    new_state = %{state | requests_processed: state.requests_processed + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp subscribe_to_nats do
    case Application.get_env(:centralcloud, :nats_client) do
      nil ->
        Logger.warn("NATS client not configured - pattern validation will not work")
        {:error, :nats_not_configured}

      nats_client ->
        # TODO: Use actual NATS client module
        # For now, return success placeholder
        Logger.info("TODO: Subscribe to NATS subject #{@subject}")
        {:ok, :placeholder_subscription}
    end
  end

  defp process_request(payload, reply_to) do
    start_time = System.monotonic_time(:millisecond)

    case Jason.decode(payload) do
      {:ok, %{"codebase_id" => codebase_id, "code_samples" => code_samples} = request} ->
        pattern_type = Map.get(request, "pattern_type", "architecture")
        request_id = Map.get(request, "request_id", generate_request_id())

        Logger.info("Processing pattern validation: #{request_id} for #{codebase_id}")

        # Run LLM Team validation
        case LLMTeamOrchestrator.validate_pattern(codebase_id, code_samples,
               pattern_type: pattern_type
             ) do
          {:ok, consensus} ->
            duration = System.monotonic_time(:millisecond) - start_time

            response = Jason.encode!(%{
              status: "success",
              request_id: request_id,
              consensus: consensus,
              duration_ms: duration,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            })

            publish_response(reply_to, response)

            Logger.info(
              "Pattern validation completed: #{request_id} (#{duration}ms, score: #{get_in(consensus, ["consensus_score"])})"
            )

          {:error, reason} ->
            duration = System.monotonic_time(:millisecond) - start_time

            error_response = Jason.encode!(%{
              status: "error",
              request_id: request_id,
              error: inspect(reason),
              duration_ms: duration,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            })

            publish_response(reply_to, error_response)

            Logger.error("Pattern validation failed: #{request_id} - #{inspect(reason)}")
        end

      {:error, json_error} ->
        Logger.error("Invalid JSON payload: #{inspect(json_error)}")

        error_response = Jason.encode!(%{
          status: "error",
          error: "invalid_json",
          details: inspect(json_error),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        publish_response(reply_to, error_response)

      {:ok, invalid_request} ->
        Logger.error("Missing required fields in request: #{inspect(invalid_request)}")

        error_response = Jason.encode!(%{
          status: "error",
          error: "missing_required_fields",
          required: ["codebase_id", "code_samples"],
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        publish_response(reply_to, error_response)
    end
  end

  defp publish_response(reply_to, response_payload) do
    # TODO: Use actual NATS client to publish
    Logger.debug("TODO: Publish response to #{reply_to}")
    Logger.debug("Response preview: #{String.slice(response_payload, 0, 200)}...")
    :ok
  end

  defp generate_request_id do
    Ecto.UUID.generate()
  end
end
