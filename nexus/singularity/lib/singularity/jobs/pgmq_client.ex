defmodule Singularity.Jobs.PgmqClient do
  @moduledoc """
  **DEPRECATED** - PostgreSQL Message Queue (pgmq) Client

  ⚠️ **This module is deprecated and will be removed in a future version.**

  Use `Singularity.PgFlow.send_with_notify/3` for sending messages (pgmq + NOTIFY).
  Use `Singularity.Database.MessageQueue` for reading/acknowledging messages.

  ## Migration Guide

  ### Send Messages
  ```elixir
  # OLD (deprecated):
  PgmqClient.send_message("my_queue", message)

  # NEW:
  PgFlow.send_with_notify("my_queue", message)
  ```

  ### Read Messages
  ```elixir
  # OLD (deprecated):
  PgmqClient.read_messages("my_queue", 10)

  # NEW:
  MessageQueue.receive_message("my_queue")  # Reads one at a time
  ```

  ### Acknowledge Messages
  ```elixir
  # OLD (deprecated):
  PgmqClient.ack_message("my_queue", msg_id)

  # NEW:
  MessageQueue.acknowledge("my_queue", msg_id)
  ```

  ### Ensure Queue
  ```elixir
  # OLD (deprecated):
  PgmqClient.ensure_queue("my_queue")

  # NEW:
  MessageQueue.create_queue("my_queue")
  ```

  All functions delegate to the new implementation for backwards compatibility,
  but new code should use `PgFlow` and `Database.MessageQueue` directly.
  """

  require Logger

  alias Singularity.Database.MessageQueue
  alias Singularity.PgFlow
  alias Singularity.Repo

  @deprecated "Use PgFlow.send_with_notify/3 instead"
  def send_message(queue_name, message) do
    Logger.warning(
      "[DEPRECATED] PgmqClient.send_message/2 is deprecated. Use PgFlow.send_with_notify/3 instead."
    )

    case PgFlow.send_with_notify(queue_name, message) do
      {:ok, :sent} ->
        {:ok, 0}

      {:ok, msg_id} when is_integer(msg_id) ->
        {:ok, msg_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @deprecated "Use Database.MessageQueue.receive_message/1 instead"
  def read_messages(queue_name, limit \\ 1) do
    Logger.warning(
      "[DEPRECATED] PgmqClient.read_messages/2 is deprecated. Use Database.MessageQueue.receive_message/1 instead."
    )

    Enum.reduce(1..limit, [], fn _, acc ->
      case MessageQueue.receive_message(queue_name) do
        {:ok, {msg_id, message}} ->
          [{msg_id, message} | acc]

        :empty ->
          acc

        {:error, _reason} ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  @deprecated "Use Database.MessageQueue.acknowledge/2 instead"
  def ack_message(queue_name, message_id) do
    Logger.warning(
      "[DEPRECATED] PgmqClient.ack_message/2 is deprecated. Use Database.MessageQueue.acknowledge/2 instead."
    )

    case MessageQueue.acknowledge(queue_name, message_id) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @deprecated "Use Database.MessageQueue.create_queue/1 instead"
  def ensure_queue(queue_name) do
    Logger.warning(
      "[DEPRECATED] PgmqClient.ensure_queue/1 is deprecated. Use Database.MessageQueue.create_queue/1 instead."
    )

    case MessageQueue.create_queue(queue_name) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @deprecated "Use Database.MessageQueue.create_queue/1 directly for each queue"
  def ensure_all_queues do
    Logger.warning(
      "[DEPRECATED] PgmqClient.ensure_all_queues/0 is deprecated. Use Database.MessageQueue.create_queue/1 directly."
    )

    queues = [
      "ai_requests",
      "ai_results",
      "embedding_requests",
      "embedding_results",
      "agent_messages",
      "agent_responses",
      "centralcloud_updates",
      "centralcloud_failures",
      "search_analytics",
      "observer_hitl_requests",
      "infrastructure_registry_requests",
      "infrastructure_registry_responses"
    ]

    Enum.each(queues, fn queue ->
      MessageQueue.create_queue(queue)
    end)

    :ok
  end

  @deprecated "Use Database.MessageQueue.receive_message/1 and acknowledge/2 instead"
  def read_message(queue_name, message_id) do
    Logger.warning(
      "[DEPRECATED] PgmqClient.read_message/2 is deprecated. Use Database.MessageQueue.receive_message/1 instead."
    )

    # This function doesn't exist in MessageQueue - read_message only reads by ID
    # If you need to read a specific message by ID, you'll need to poll or use a different approach
    {:error, :not_implemented}
  end
end
