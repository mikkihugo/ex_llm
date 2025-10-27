defmodule Singularity.Database.MessageQueue do
  @moduledoc """
  In-database message queue using PostgreSQL pgmq extension.

  Provides durable message queueing for:
  - **Singularity ↔ CentralCloud messaging** when pgmq is unavailable
  - **Cross-instance agent communication** in multi-instance setups
  - **Event persistence** for audit trails
  - **Reliable task distribution** between autonomous agents

  ## When to Use pgmq vs pgmq

  | Use Case | pgmq | pgmq |
  |----------|------|------|
  | Persistence | ✅ Durable | ❌ Memory-only |
  | Reliability | ✅ Guaranteed | ⚠️ Best-effort |
  | Speed | ⚠️ Slower | ✅ Fast |
  | Scale | ~1000s msgs/sec | 1M+ msgs/sec |
  | Distributed | ✅ Multi-instance | ✅ Native |
  | Transactions | ✅ ACID | ❌ None |

  **Use pgmq for**: Critical messages, audit logs, cross-instance sync
  **Use pgmq for**: Real-time, high-throughput, performance-critical

  ## Usage Examples

  ```elixir
  # Send a message to a queue
  iex> Singularity.Database.MessageQueue.send("agent-tasks", %{
  ...>   agent_id: "agent-123",
  ...>   task: "analyze_code"
  ...> })
  {:ok, message_id}

  # Receive a message (automatic deletion after 30 seconds)
  iex> Singularity.Database.MessageQueue.receive_message("agent-tasks")
  {:ok, {message_id, %{agent_id: "agent-123", ...}}}

  # Purge a queue (cleanup)
  iex> Singularity.Database.MessageQueue.purge("agent-tasks")
  {:ok, purged_count}
  ```

  ## Cross-System Use Cases

  1. **Agent Session Sync**: Persist agent state between Singularity instances
  2. **CentralCloud Requests**: Queue learning requests from Singularity to CentralCloud
  3. **Fallback Communication**: When pgmq is down, use pgmq as fallback
  4. **Audit Trail**: All inter-system messages persisted for compliance
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Create or get a queue by name.

  Idempotent - safe to call multiple times.
  """
  def create_queue(queue_name) when is_binary(queue_name) do
    case Repo.query("SELECT Singularity.Jobs.PgmqClient.create($1)", [queue_name]) do
      {:ok, _} ->
        Logger.info("Queue created: #{queue_name}")
        {:ok, queue_name}

      error ->
        Logger.error("Failed to create queue #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Send a message to a queue.

  Message can be any JSON-serializable Elixir term.
  Returns message ID for tracking.
  """
  def send(queue_name, message) when is_binary(queue_name) do
    json_msg = Jason.encode!(message)

    case Repo.query("SELECT Singularity.Jobs.PgmqClient.send($1, $2)", [queue_name, json_msg]) do
      {:ok, %{rows: [[msg_id]]}} ->
        {:ok, msg_id}

      error ->
        Logger.error("Failed to send message to #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Receive a message from a queue.

  Message is automatically marked as "read" for 30 seconds.
  Returns {message_id, decoded_message} if available, :empty if queue is empty.
  """
  def receive_message(queue_name) when is_binary(queue_name) do
    case Repo.query(
           "SELECT msg_id, body FROM Singularity.Jobs.PgmqClient.read($1, vt := 30, limit := 1)",
           [queue_name]
         ) do
      {:ok, %{rows: [[msg_id, body_json]]}} ->
        case Jason.decode(body_json) do
          {:ok, message} -> {:ok, {msg_id, message}}
          {:error, error} -> {:error, "JSON decode failed: #{inspect(error)}"}
        end

      {:ok, %{rows: []}} ->
        :empty

      error ->
        Logger.error("Failed to receive from #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Acknowledge a message (permanent deletion from queue).

  Call after successfully processing a message.
  """
  def acknowledge(queue_name, message_id) when is_binary(queue_name) and is_integer(message_id) do
    case Repo.query("SELECT Singularity.Jobs.PgmqClient.delete($1, $2)", [queue_name, message_id]) do
      {:ok, %{rows: [[1]]}} ->
        {:ok, :deleted}

      {:ok, %{rows: [[0]]}} ->
        {:error, "Message not found"}

      error ->
        Logger.error("Failed to acknowledge message: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Purge all messages from a queue.

  Useful for cleanup, testing, or emergency resets.
  """
  def purge(queue_name) when is_binary(queue_name) do
    case Repo.query("SELECT Singularity.Jobs.PgmqClient.purge_queue($1)", [queue_name]) do
      {:ok, %{rows: [[count]]}} ->
        {:ok, count}

      error ->
        Logger.error("Failed to purge queue #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Get queue statistics.

  Returns counts of messages in different states.
  """
  def stats(queue_name) when is_binary(queue_name) do
    case Repo.query(
           "SELECT queue_name, messages, messages_in_flight FROM Singularity.Jobs.PgmqClient.queue_stats() WHERE queue_name = $1",
           [queue_name]
         ) do
      {:ok, %{rows: [[_name, total, in_flight]]}} ->
        {:ok, %{total: total, in_flight: in_flight, available: total - in_flight}}

      {:ok, %{rows: []}} ->
        {:error, "Queue not found"}

      error ->
        Logger.error("Failed to get queue stats: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Process messages from a queue with a handler function.

  Automatically acknowledges successfully processed messages.
  Returns count of processed messages.
  """
  def process_batch(queue_name, handler_fn, limit \\ 10)
      when is_binary(queue_name) and is_function(handler_fn) and is_integer(limit) do
    Enum.reduce(1..limit, 0, fn _, count ->
      case receive_message(queue_name) do
        {:ok, {msg_id, message}} ->
          case handler_fn.(message) do
            :ok ->
              acknowledge(queue_name, msg_id)
              count + 1

            error ->
              Logger.warning("Handler failed for message #{msg_id}: #{inspect(error)}")
              count
          end

        :empty ->
          count

        error ->
          Logger.error("Receive error: #{inspect(error)}")
          count
      end
    end)
  end

  @doc """
  Drop a queue permanently.

  All messages in the queue are deleted.
  Use with caution!
  """
  def drop_queue(queue_name) when is_binary(queue_name) do
    case Repo.query("SELECT Singularity.Jobs.PgmqClient.drop_queue($1)", [queue_name]) do
      {:ok, _} ->
        Logger.warning("Queue dropped: #{queue_name}")
        {:ok, :dropped}

      error ->
        Logger.error("Failed to drop queue #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end
end
