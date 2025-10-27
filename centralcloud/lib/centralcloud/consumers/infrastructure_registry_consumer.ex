defmodule CentralCloud.Consumers.InfrastructureRegistryConsumer do
  @moduledoc """
  Infrastructure Registry Consumer - Handles pgmq requests for infrastructure definitions

  Listens to `infrastructure_registry_requests` queue from Singularity instances.
  Queries InfrastructureRegistry service and sends responses back via pgmq.

  ## Integration

  Receives requests from Singularity via `infrastructure_registry_requests` queue.
  Sends responses to Singularity via `infrastructure_registry_responses` queue.

  Both queues are stored in PostgreSQL pgmq shared_queue database.
  """

  require Logger
  alias CentralCloud.Infrastructure.Registry
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
    min_confidence = request["min_confidence"] || 0.7
    include = request["include"] || []

    try do
      # Get formatted registry from CentralCloud
      case Registry.get_formatted_registry(min_confidence: min_confidence) do
        {:ok, full_registry} ->
          # Filter by categories if specified
          response =
            if Enum.empty?(include) do
              full_registry
            else
              include_set = MapSet.new(include)

              full_registry
              |> Enum.filter(fn {category, _systems} ->
                MapSet.member?(include_set, category)
              end)
              |> Enum.into(%{})
            end

          # Send response back via pgmq
          send_response(response)

        {:error, reason} ->
          Logger.error("[InfrastructureRegistry] Failed to get registry: #{inspect(reason)}")
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
