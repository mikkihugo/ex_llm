defmodule CentralCloud.Consumers.InfrastructureRegistryConsumer do
  @moduledoc """
  Infrastructure Registry Consumer - Handles pgmq requests for infrastructure definitions

  Listens to `infrastructure_registry_requests` queue from Singularity instances.
  Uses InfrastructureSystemLearningOrchestrator to discover infrastructure systems
  and sends responses back via pgmq.

  ## Integration

  Receives requests from Singularity via `infrastructure_registry_requests` queue.
  Sends responses to Singularity via `infrastructure_registry_responses` queue.

  Both queues are stored in PostgreSQL pgmq shared_queue database.

  ## How It Works

  1. Receives infrastructure registry request (query_type: "infrastructure_registry")
  2. Uses InfrastructureSystemLearningOrchestrator to learn systems from request
  3. Orchestrator tries enabled learners in priority order (manual registry first, then LLM if needed)
  4. Sends learned systems back via pgmq response queue
  """

  require Logger
  alias CentralCloud.InfrastructureSystemLearningOrchestrator
  alias CentralCloud.SharedQueueRepo

  @doc """
  Handle an infrastructure registry request from Singularity.

  Expected request format:
  ```json
  {
    "query_type": "infrastructure_registry",
    "include": ["message_brokers", "databases", ...],
    "min_confidence": 0.7
  }
  ```
  """
  def handle_message(request) when is_map(request) do
    Logger.info("[InfrastructureRegistry] Processing request",
      query_type: request["query_type"],
      include_count: length(request["include"] || [])
    )

    case request["query_type"] do
      "infrastructure_registry" ->
        handle_registry_request(request)

      other ->
        Logger.warning("[InfrastructureRegistry] Unknown query type: #{other}")
        :ok
    end
  end

  def handle_message(message) do
    Logger.warning("[InfrastructureRegistry] Invalid message format: #{inspect(message)}")
    :ok
  end

  # Private

  defp handle_registry_request(request) do
    try do
      # Use orchestrator to learn infrastructure systems
      case InfrastructureSystemLearningOrchestrator.learn(request) do
        {:ok, systems, learner_type} ->
          Logger.info("[InfrastructureRegistry] Successfully learned systems",
            learner: learner_type,
            categories_count: map_size(systems)
          )
          send_response(systems)

        {:error, :no_systems_found} ->
          Logger.warn("[InfrastructureRegistry] No infrastructure systems found for request",
            query_type: request["query_type"]
          )
          send_error_response("No infrastructure systems found matching criteria")

        {:error, reason} ->
          Logger.error("[InfrastructureRegistry] Failed to learn infrastructure systems",
            error: inspect(reason)
          )
          send_error_response(reason)
      end
    rescue
      e ->
        Logger.error("[InfrastructureRegistry] Exception handling request: #{inspect(e)}")
        send_error_response(e)
    end

    :ok
  end

  defp send_response(response) do
    case send_to_pgmq("infrastructure_registry_responses", response) do
      {:ok, msg_id} ->
        Logger.info("[InfrastructureRegistry] Sent response", message_id: msg_id)
        :ok

      {:error, reason} ->
        Logger.error("[InfrastructureRegistry] Failed to send response: #{inspect(reason)}")
        :ok
    end
  end

  defp send_error_response(error) do
    response = %{
      "error" => "Failed to fetch infrastructure registry",
      "reason" => inspect(error)
    }

    send_to_pgmq("infrastructure_registry_responses", response)
  end

  # Send message to pgmq queue using SharedQueueRepo
  defp send_to_pgmq(queue_name, message) do
    try do
      result =
        SharedQueueRepo.query!(
          "SELECT pgmq.send($1, $2)",
          [queue_name, Jason.encode!(message)]
        )

      case result.rows do
        [[message_id]] -> {:ok, message_id}
        _ -> {:error, "Failed to send message to pgmq queue: #{queue_name}"}
      end
    rescue
      error ->
        Logger.error("pgmq send error",
          queue: queue_name,
          error: inspect(error)
        )

        {:error, error}
    end
  end
end
