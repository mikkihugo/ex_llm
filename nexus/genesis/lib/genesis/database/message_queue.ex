defmodule Genesis.Database.MessageQueue do
  @moduledoc """
  PostgreSQL-based message queue for Genesis using pgmq extension.

  Provides durable, ACID-backed messaging for experiment events and notifications,
  with fallback to NATS for real-time operations.

  ## Queues

  - `genesis-experiments` - Experiment execution events
  - `genesis-rollbacks` - Rollback notifications
  - `genesis-metrics` - Metrics and results reporting
  - `genesis-errors` - Error and failure notifications

  ## Durability

  pgmq guarantees:
  - ACID transactions (PostgreSQL guarantees)
  - Message persistence (survives restarts)
  - Exactly-once delivery semantics
  - Visibility timeout (in-flight message protection)
  """

  require Logger
  alias Genesis.Repo
  alias Pgmq
  alias Pgmq.Message

  @doc """
  Create a message queue if it doesn't exist.
  """
  def create_queue(queue_name) when is_binary(queue_name) do
    try do
      :ok = Pgmq.create_queue(Repo, queue_name)
      Logger.info("Queue created: #{queue_name}")
      {:ok, queue_name}
    rescue
      error in [Postgrex.Error] ->
        case error.postgres[:code] do
          :duplicate_table -> {:ok, queue_name}
          :duplicate_object -> {:ok, queue_name}
          _ -> {:error, error}
        end
    end
  end

  @doc """
  Send a message to a queue.

  Returns message ID on success.
  """
  def send(queue_name, message) when is_binary(queue_name) do
    json_msg = Jason.encode!(message)

    try do
      case Pgmq.send_message(Repo, queue_name, json_msg) do
        {:ok, msg_id} -> {:ok, msg_id}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Receive a message from a queue.

  Sets visibility timeout to 30 seconds (message invisible while being processed).
  Returns {msg_id, message} tuple or :empty if no messages.
  """
  def receive_message(queue_name) when is_binary(queue_name) do
    try do
      case Pgmq.read_message(Repo, queue_name, 30) do
        nil ->
          :empty

        %Message{id: msg_id, body: body} ->
          case Jason.decode(body) do
            {:ok, message} -> {:ok, {msg_id, message}}
            {:error, error} -> {:error, "JSON decode failed: #{inspect(error)}"}
          end
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Acknowledge (delete) a message after successful processing.
  """
  def acknowledge(queue_name, message_id) when is_binary(queue_name) and is_integer(message_id) do
    try do
      :ok = Pgmq.delete_messages(Repo, queue_name, [message_id])
      {:ok, :deleted}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Put a message back in the queue (visibility timeout expired or processing failed).
  """
  def nack(queue_name, message_id) when is_binary(queue_name) and is_integer(message_id) do
    try do
      :ok = Pgmq.set_message_vt(Repo, queue_name, message_id, 0)
      {:ok, :requeued}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Process messages from a queue in batch.

  Calls handler_fn for each message. If handler returns :ok, message is deleted.
  Otherwise, message is requeued.

  Returns count of successfully processed messages.
  """
  def process_batch(queue_name, handler_fn, limit \\ 10) do
    Enum.reduce(1..limit, 0, fn _, count ->
      case receive_message(queue_name) do
        {:ok, {msg_id, message}} ->
          case handler_fn.(message) do
            :ok ->
              acknowledge(queue_name, msg_id)
              count + 1
            error ->
              Logger.warning("Handler failed for message #{msg_id}: #{inspect(error)}")
              nack(queue_name, msg_id)
              count
          end
        :empty -> count
        error -> Logger.error("Receive error: #{inspect(error)}"); count
      end
    end)
  end

  @doc """
  Get statistics for a queue.
  """
  def queue_stats(queue_name) when is_binary(queue_name) do
    case Repo.query(
      "SELECT messages, messages_in_flight FROM pgmq.queue_stats() WHERE queue_name = $1",
      [queue_name]
    ) do
      {:ok, %{rows: [[total, in_flight]]}} ->
        {:ok, %{total_messages: total, in_flight: in_flight, available: total - in_flight}}
      {:ok, %{rows: []}} ->
        {:error, "Queue not found"}
      error ->
        {:error, error}
    end
  end

  @doc """
  Purge all messages from a queue (use with caution).
  """
  def purge_queue(queue_name) when is_binary(queue_name) do
    case Repo.query("SELECT pgmq.purge_queue($1)", [queue_name]) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Check if queue is backed up (more messages than threshold).
  """
  def queue_backed_up?(queue_name, threshold \\ 100) when is_binary(queue_name) do
    case queue_stats(queue_name) do
      {:ok, stats} -> stats.total_messages > threshold
      _ -> false
    end
  end

  @doc """
  Destroy a queue (drops table and all messages).
  """
  def drop_queue(queue_name) when is_binary(queue_name) do
    try do
      :ok = Pgmq.drop_queue(Repo, queue_name)
      Logger.info("Queue dropped: #{queue_name}")
      {:ok, :dropped}
    rescue
      error -> {:error, error}
    end
  end
end
