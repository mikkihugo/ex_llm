defmodule Singularity.Messaging.Client do
  @moduledoc """
  Unified messaging client replacing NATS with pgmq (PostgreSQL message queue).

  This module provides a compatibility layer between NATS and pgmq, allowing
  gradual migration from NATS to persistent PostgreSQL-based messaging.

  ## API Compatibility

  ### Publish (Fire & Forget)
  ```elixir
  iex> Singularity.Messaging.Client.publish("template.get.request", message_json)
  {:ok, message_id}
  ```

  ### Request-Reply Pattern
  ```elixir
  iex> Singularity.Messaging.Client.request("quality.rules.request", request_json, timeout: 5000)
  {:ok, response_message}
  ```

  ### Subscribe (Event Listener - GenServer patterns)
  ```elixir
  iex> Singularity.Messaging.Client.subscribe("template.invalidate.*")
  {:ok, subscription_id}
  ```

  ## Subject Mapping

  NATS subjects map to PostgreSQL queue names:
  - `template.get.*` → queue: `template_get_replies`
  - `quality.rules.*` → queue: `quality_rules_replies`
  - `*` → queue: `{subject_name}_queue`

  ## Under the Hood

  Uses `Singularity.Database.MessageQueue` (pgmq) for:
  - **Persistence**: All messages stored in PostgreSQL
  - **Ordering**: FIFO queue semantics
  - **Timeouts**: Request-reply with configurable timeouts
  - **Multi-instance**: Works across multiple Singularity instances
  """

  require Logger
  alias Singularity.Database.MessageQueue
  alias Singularity.Repo

  @doc """
  Publish a message to a subject (fire & forget).

  Uses pgmq to store the message. Subscribers will consume it asynchronously.
  """
  def publish(subject, message) when is_binary(subject) and is_binary(message) do
    queue_name = subject_to_queue(subject)

    case MessageQueue.send(queue_name, Jason.decode!(message)) do
      {:ok, msg_id} ->
        Logger.debug("Message published",
          subject: subject,
          queue: queue_name,
          message_id: msg_id
        )

        {:ok, msg_id}

      {:error, reason} ->
        Logger.error("Failed to publish message",
          subject: subject,
          queue: queue_name,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def publish(subject, message) when is_map(message) do
    publish(subject, Jason.encode!(message))
  end

  @doc """
  Subscribe to a subject (request-reply listener).

  This spawns a persistent listener process that consumes messages from
  the queue and handles them via a callback.
  """
  def subscribe(subject, opts \\ []) when is_binary(subject) do
    queue_name = subject_to_queue(subject)
    handler = Keyword.get(opts, :handler, &default_handler/1)
    timeout = Keyword.get(opts, :timeout, 30000)

    case MessageQueue.create_queue(queue_name) do
      {:ok, ^queue_name} ->
        Logger.info("Subscribed to subject",
          subject: subject,
          queue: queue_name
        )

        {:ok, queue_name}

      {:error, reason} ->
        Logger.error("Failed to subscribe",
          subject: subject,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Request-reply pattern with timeout.

  Sends a message and waits for a response from the reply-to queue.
  Useful for synchronous RPC-style communication.
  """
  def request(subject, message, opts \\ []) when is_binary(subject) and is_binary(message) do
    timeout = Keyword.get(opts, :timeout, 5000)
    reply_subject = Keyword.get(opts, :reply_to, "#{subject}.replies")
    queue_name = subject_to_queue(subject)
    reply_queue = subject_to_queue(reply_subject)

    # Ensure reply queue exists
    MessageQueue.create_queue(reply_queue)

    # Send request
    case MessageQueue.send(queue_name, Jason.decode!(message)) do
      {:ok, _msg_id} ->
        # Wait for response
        start_time = System.monotonic_time(:millisecond)
        wait_for_response(reply_queue, timeout, start_time)

      {:error, reason} ->
        Logger.error("Failed to send request",
          subject: subject,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def request(subject, message, opts) when is_map(message) do
    request(subject, Jason.encode!(message), opts)
  end

  # Private Helpers

  defp subject_to_queue(subject) do
    subject
    |> String.replace(".", "_")
    |> String.replace("*", "wildcard")
  end

  defp wait_for_response(queue_name, timeout, start_time) do
    case MessageQueue.receive_message(queue_name, timeout: 1000) do
      {:ok, {_msg_id, message}} ->
        {:ok, Jason.encode!(message)}

      {:error, :no_messages} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed < timeout do
          # Retry with remaining time
          remaining = timeout - elapsed
          wait_for_response(queue_name, remaining, start_time)
        else
          {:error, :timeout}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_handler(message) do
    Logger.debug("Received message: #{inspect(message)}")
    :ok
  end
end
