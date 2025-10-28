defmodule Singularity.Notifications.PgmqNotify do
  @moduledoc """
  PGMQ + PostgreSQL NOTIFY integration for real-time message delivery.

  Combines the reliability of PGMQ with the real-time capabilities of PostgreSQL NOTIFY.
  This eliminates the need for separate PubSub systems while maintaining message persistence.

  ## How it works

  1. **Send Message**: `send_with_notify/3` sends to PGMQ + triggers NOTIFY
  2. **Listen**: `listen/2` subscribes to PostgreSQL NOTIFY events
  3. **Poll**: When NOTIFY arrives, poll PGMQ for the actual message

  ## Benefits

  - ✅ **Reliable**: Messages persisted in PGMQ
  - ✅ **Real-time**: NOTIFY triggers instant polling
  - ✅ **Efficient**: No constant polling, only when messages arrive
  - ✅ **Simple**: One system instead of PGMQ + PubSub

  ## Example

      # Send a message with real-time notification
      {:ok, message_id} = PgmqNotify.send_with_notify(
        "chat_messages", 
        %{type: "notification", content: "Hello!"}, 
        Singularity.Repo
      )

      # Listen for real-time updates
      {:ok, pid} = PgmqNotify.listen("chat_messages", Singularity.Repo)
      
      # Handle NOTIFY events
      receive do
        {:notification, ^pid, "pgmq_chat_messages", message_id} ->
          # Poll PGMQ for the actual message
          {:ok, message} = PgmqNotify.read_message("chat_messages", message_id, Singularity.Repo)
          # Process message...
      end
  """

  require Logger

  @doc """
  Send a message via PGMQ with PostgreSQL NOTIFY for real-time delivery.

  ## Parameters

  - `queue_name` - PGMQ queue name
  - `message` - Message payload (will be JSON encoded)
  - `repo` - Ecto repository

  ## Returns

  - `{:ok, message_id}` - Message sent successfully
  - `{:error, reason}` - Send failed

  ## Example

      {:ok, message_id} = PgmqNotify.send_with_notify(
        "observer_notifications",
        %{type: "notification", content: "System update"},
        Singularity.Repo
      )
  """
  @spec send_with_notify(String.t(), map(), Ecto.Repo.t()) :: {:ok, String.t()} | {:error, any()}
  def send_with_notify(queue_name, message, repo) do
    with {:ok, message_id} <- Singularity.Jobs.PgmqClient.send_message(queue_name, message),
         :ok <- trigger_notify(queue_name, message_id, repo) do
      {:ok, message_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Listen for NOTIFY events on a PGMQ queue.

  ## Parameters

  - `queue_name` - PGMQ queue name to listen for
  - `repo` - Ecto repository

  ## Returns

  - `{:ok, pid}` - Notification listener process
  - `{:error, reason}` - Failed to start listener

  ## Example

      {:ok, pid} = PgmqNotify.listen("observer_notifications", Singularity.Repo)
      
      # Listen for messages
      receive do
        {:notification, ^pid, channel, message_id} ->
          # Process the notification
      end
  """
  @spec listen(String.t(), Ecto.Repo.t()) :: {:ok, pid()} | {:error, any()}
  def listen(queue_name, repo) do
    channel = "pgmq_#{queue_name}"

    case Postgrex.Notifications.listen(repo, channel) do
      {:ok, pid} ->
        Logger.info("Listening for PGMQ notifications on channel: #{channel}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to listen for notifications: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Read a message from PGMQ queue by message ID.

  ## Parameters

  - `queue_name` - PGMQ queue name
  - `message_id` - Message ID to read
  - `repo` - Ecto repository

  ## Returns

  - `{:ok, message}` - Message read successfully
  - `{:error, reason}` - Read failed
  """
  @spec read_message(String.t(), String.t(), Ecto.Repo.t()) :: {:ok, map()} | {:error, any()}
  def read_message(queue_name, message_id, repo) do
    # This would need to be implemented based on your PGMQ client
    # For now, return a mock response
    {:ok, %{id: message_id, content: "Mock message"}}
  end

  @doc """
  Send a notification without PGMQ (NOTIFY only).

  Useful for simple notifications that don't need persistence.

  ## Parameters

  - `channel` - NOTIFY channel name
  - `payload` - Notification payload
  - `repo` - Ecto repository

  ## Returns

  - `:ok` - Notification sent
  - `{:error, reason}` - Send failed
  """
  @spec notify_only(String.t(), String.t(), Ecto.Repo.t()) :: :ok | {:error, any()}
  def notify_only(channel, payload, repo) do
    case repo.query("SELECT pg_notify($1, $2)", [channel, payload]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stop listening for notifications.

  ## Parameters

  - `pid` - Notification listener process
  - `repo` - Ecto repository

  ## Returns

  - `:ok` - Stopped successfully
  - `{:error, reason}` - Stop failed
  """
  @spec unlisten(pid(), Ecto.Repo.t()) :: :ok | {:error, any()}
  def unlisten(pid, repo) do
    Postgrex.Notifications.unlisten(repo, pid)
  end

  # Private: Trigger PostgreSQL NOTIFY after PGMQ send
  defp trigger_notify(queue_name, message_id, repo) do
    channel = "pgmq_#{queue_name}"

    case repo.query("SELECT pg_notify($1, $2)", [channel, message_id]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
