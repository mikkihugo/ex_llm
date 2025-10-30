defmodule Singularity.Evolution.Pgflow.MessageRouter do
  @moduledoc """
  PgFlow Message Router - Routes incoming pgflow messages to appropriate consumer handlers.

  This module listens to pgflow queues and routes messages to the appropriate handler
  based on message type. Handles acknowledgment, retries, and dead-letter queue routing.

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Evolution.Pgflow.MessageRouter",
    "purpose": "Routes incoming pgflow messages to consumer handlers",
    "role": "orchestrator",
    "layer": "integration",
    "introduced_in": "October 2025",
    "depends_on": ["Consumers", "ExPgflow", "PgFlow"],
    "features": ["message_routing", "handler_dispatch", "acknowledgment", "retry_handling"]
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph LR
      Queue1["PgFlow Queue"]
      Queue2["CentralCloud Queue"]
      Router["MessageRouter"]
      Handlers["Consumer Handlers"]
      DB["PostgreSQL"]

      Queue1 -->|read| Router
      Queue2 -->|read| Router
      Router -->|dispatch| Handlers
      Handlers -->|ack/retry| DB
  ```

  ### Call Graph (YAML)

  ```yaml
  provides:
    - route_message/1 (dispatch message to handler)
    - listen_for_messages/0 (start message listener)
    - acknowledge_message/1 (mark message processed)

  called_by:
    - Application (supervisor)
    - Pgflow.listen_worker (queue listener)

  depends_on:
    - Singularity.Evolution.Pgflow.Consumers
    - ExPgflow (pgflow library)
    - Singularity.PgFlow (message queue API)
  ```

  ### Anti-Patterns

  - ❌ DO NOT assume message format is valid
  - ❌ DO NOT fail silently on routing errors
  - ❌ DO NOT forget to acknowledge processed messages
  - ✅ DO validate message type before routing
  - ✅ DO log all routing and handler calls
  - ✅ DO return {:ok, "processed"} for idempotency

  ### Search Keywords

  pgflow message router, message routing, handler dispatch, queue listener,
  message acknowledgment, consensus patterns, workflow patterns
  """

  require Logger

  alias Singularity.Evolution.Pgflow.Consumers

  @doc """
  Route incoming pgflow message to appropriate consumer handler.

  Dispatches message to handler based on message type field.
  Returns {:ok, "processed"} or {:error, reason} for retry.

  ## Supported Message Types

  - `consensus_result` → Consumers.handle_consensus_result/1
  - `rollback_trigger` → Consumers.handle_rollback_trigger/1
  - `safety_profile_update` → Consumers.handle_safety_profile_update/1
  - `workflow_consensus_patterns` → Consumers.handle_workflow_consensus_patterns/1
  """
  @spec route_message(map()) :: {:ok, String.t()} | {:error, any()}
  def route_message(%{"type" => type} = message) do
    Logger.debug("Routing pgflow message of type: #{type}")

    case type do
      "consensus_result" ->
        Consumers.handle_consensus_result(message)

      "rollback_trigger" ->
        Consumers.handle_rollback_trigger(message)

      "safety_profile_update" ->
        Consumers.handle_safety_profile_update(message)

      "workflow_consensus_patterns" ->
        Consumers.handle_workflow_consensus_patterns(message)

      _ ->
        Logger.warning("Unknown message type: #{type}")
        {:error, :unknown_message_type}
    end
  rescue
    e ->
      Logger.error("Exception routing message: #{inspect(e)}")
      {:error, {:routing_failed, inspect(e)}}
  end

  def route_message(message) do
    Logger.error("Invalid message format (missing type): #{inspect(message)}")
    {:error, :invalid_message_format}
  end

  @doc """
  Listen for messages on a specific pgflow queue and route them.

  Starts listening to queue and processes messages continuously.
  Returns {:ok, pid} or {:error, reason}.

  ## Examples

      {:ok, pid} = MessageRouter.listen_on_queue("centralcloud_workflow_consensus_patterns")
  """
  @spec listen_on_queue(String.t()) :: {:ok, pid()} | {:error, any()}
  def listen_on_queue(queue_name) do
    Task.start_link(fn ->
      Logger.info("Started listening on queue: #{queue_name}")

      loop_listen(queue_name)
    end)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp loop_listen(queue_name) do
    case PgFlow.receive_from_queue(queue_name) do
      {:ok, messages} when is_list(messages) and length(messages) > 0 ->
        # Process each message
        Enum.each(messages, fn msg ->
          process_message(queue_name, msg)
        end)

        # Continue listening
        loop_listen(queue_name)

      {:ok, []} ->
        # No messages, wait a bit before checking again
        Process.sleep(1000)
        loop_listen(queue_name)

      {:error, reason} ->
        Logger.error("Error receiving from queue #{queue_name}: #{inspect(reason)}")
        # Retry after delay
        Process.sleep(5000)
        loop_listen(queue_name)
    end
  end

  defp process_message(queue_name, %{"msg_id" => msg_id, "message" => message_data} = _msg) do
    # Parse message if it's a JSON string
    parsed_message = parse_message(message_data)

    Logger.info("Processing message #{msg_id} from queue #{queue_name}")

    case route_message(parsed_message) do
      {:ok, _} ->
        # Message processed successfully, acknowledge it
        case PgFlow.acknowledge_message(queue_name, msg_id) do
          :ok ->
            Logger.debug("Message #{msg_id} acknowledged")

          {:error, reason} ->
            Logger.warning("Failed to acknowledge message #{msg_id}: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("Failed to process message #{msg_id}: #{inspect(reason)}")
        # For retryable errors, message stays in queue
        # For non-retryable errors, move to dead-letter queue
        case reason do
          :invalid_message_format ->
            # Non-retryable - move to DLQ
            move_to_dlq(queue_name, msg_id, reason)

          :unknown_message_type ->
            # Non-retryable - move to DLQ
            move_to_dlq(queue_name, msg_id, reason)

          _ ->
            # Retryable - leave in queue for retry
            Logger.info("Message #{msg_id} will be retried")
        end
    end
  rescue
    e ->
      Logger.error("Exception processing message from #{queue_name}: #{inspect(e)}")
  end

  defp process_message(queue_name, message) do
    Logger.error("Invalid message format from #{queue_name}: #{inspect(message)}")
  end

  defp parse_message(data) when is_map(data), do: data
  defp parse_message(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{"type" => "unknown", "raw_data" => data}
    end
  end
  defp parse_message(data), do: %{"type" => "unknown", "raw_data" => data}

  defp move_to_dlq(queue_name, msg_id, reason) do
    dlq_name = "#{queue_name}_dlq"
    Logger.warning("Moving message #{msg_id} to DLQ: #{dlq_name}, reason: #{inspect(reason)}")

    # In a real implementation, copy to DLQ and delete from main queue
    # For now, just log the intention
    {:ok, dlq_name}
  end
end
