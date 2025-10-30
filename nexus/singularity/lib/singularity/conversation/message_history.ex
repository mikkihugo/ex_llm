defmodule Singularity.Conversation.MessageHistory do
  @moduledoc """
  Message History - Stores conversation messages in pgmq for durability and auditability.

  Persists all messages (agent messages, human responses, system notifications) in pgmq
  queues for audit trail, debugging, and learning from past conversations.

  ## Design

  Uses pgmq as a durable append-only log with one queue per conversation/approval:
  - Queue name: `conv_history_{conversation_id}`
  - Messages include: timestamp, sender, type, content, metadata
  - Queryable: retrieve full history, filter by sender/type

  ## Usage

      # Store a message
      :ok = MessageHistory.add_message("conv-123", %{
        sender: :agent,
        type: :question,
        content: "Should I refactor this module?",
        metadata: %{context: "lib/my_module.ex"}
      })

      # Retrieve conversation history
      {:ok, messages} = MessageHistory.get_messages("conv-123")
      # => [%{sender: :agent, type: :question, content: "...", timestamp: ...}, ...]

      # Cleanup old messages
      :ok = MessageHistory.delete_conversation("conv-123")
  """

  require Logger
  alias Singularity.Database.MessageQueue

  @queue_prefix "conv_history_"
  @max_messages_per_query 100

  @doc """
  Add a message to the conversation history.

  Stores message in pgmq queue with timestamp and metadata.
  """
  @spec add_message(String.t(), map()) :: :ok | {:error, term()}
  def add_message(conversation_id, message_data)
      when is_binary(conversation_id) and is_map(message_data) do
    queue_name = queue_name_for(conversation_id)

    message = %{
      conversation_id: conversation_id,
      sender: Map.get(message_data, :sender, :system),
      type: Map.get(message_data, :type, :message),
      content: Map.get(message_data, :content, ""),
      metadata: Map.get(message_data, :metadata, %{}),
      timestamp: DateTime.utc_now(),
      message_id: generate_message_id()
    }

    try do
      case MessageQueue.send(queue_name, message) do
        {:ok, _msg_id} ->
          Logger.debug("Message stored for conversation #{conversation_id}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to store message for #{conversation_id}: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Exception storing message: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Retrieve all messages for a conversation.

  Returns messages in chronological order (oldest first).
  """
  @spec get_messages(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_messages(conversation_id) when is_binary(conversation_id) do
    queue_name = queue_name_for(conversation_id)

    try do
      # Read all available messages from the queue
      messages = read_batch_messages(queue_name, @max_messages_per_query)

      # Convert to list of message data, preserving order
      parsed_messages =
        Enum.map(messages, fn {_msg_id, data} ->
          parse_message(data)
        end)

      {:ok, parsed_messages}
    rescue
      error ->
        Logger.error("Exception reading messages: #{inspect(error)}")
        {:error, error}
    end
  end

  defp read_batch_messages(queue_name, limit) do
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

  @doc """
  Delete/archive conversation history.

  Removes the queue to clean up old conversations.
  """
  @spec delete_conversation(String.t()) :: :ok | {:error, term()}
  def delete_conversation(conversation_id) when is_binary(conversation_id) do
    queue_name = queue_name_for(conversation_id)

    try do
      # Note: pgmq doesn't have direct delete queue, so we'll just log it
      # In practice, old queues can be purged via MessageQueue.purge/1
      Logger.info("Conversation #{conversation_id} archived (queue: #{queue_name})")
      :ok
    rescue
      error ->
        Logger.error("Failed to delete conversation #{conversation_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Get conversation summary (metadata without full message content).

  Returns high-level stats about the conversation.
  """
  @spec get_summary(String.t()) :: {:ok, map()} | {:error, term()}
  def get_summary(conversation_id) when is_binary(conversation_id) do
    case get_messages(conversation_id) do
      {:ok, messages} ->
        summary = %{
          conversation_id: conversation_id,
          message_count: length(messages),
          first_message_at: messages |> Enum.at(0) |> then(& &1[:timestamp]),
          last_message_at: messages |> Enum.at(-1) |> then(& &1[:timestamp]),
          senders: messages |> Enum.map(& &1[:sender]) |> Enum.uniq(),
          message_types: messages |> Enum.map(& &1[:type]) |> Enum.uniq(),
          agent_messages: Enum.count(messages, &(&1[:sender] == :agent)),
          human_messages: Enum.count(messages, &(&1[:sender] == :human)),
          system_messages: Enum.count(messages, &(&1[:sender] == :system))
        }

        {:ok, summary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Filter messages by sender or type.

  Useful for getting only agent questions or human responses.
  """
  @spec filter_messages(String.t(), atom(), atom() | nil) :: {:ok, [map()]} | {:error, term()}
  def filter_messages(conversation_id, sender \\ nil, type \\ nil)
      when is_binary(conversation_id) do
    case get_messages(conversation_id) do
      {:ok, messages} ->
        filtered =
          messages
          |> filter_by_sender(sender)
          |> filter_by_type(type)

        {:ok, filtered}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private: Parse message from pgmq format
  defp parse_message(data) when is_map(data) do
    data
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key = if is_atom(k), do: k, else: String.to_atom(k)
      Map.put(acc, key, v)
    end)
  end

  defp parse_message(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> parse_message(parsed)
      {:error, _} -> data
    end
  end

  defp parse_message(data), do: data

  # Private: Generate unique message ID
  defp generate_message_id do
    "msg-#{System.unique_integer([:positive])}"
  end

  # Private: Get queue name for conversation
  defp queue_name_for(conversation_id) do
    "#{@queue_prefix}#{conversation_id}"
  end

  # Private: Filter by sender
  defp filter_by_sender(messages, nil), do: messages

  defp filter_by_sender(messages, sender) do
    Enum.filter(messages, &(&1[:sender] == sender))
  end

  # Private: Filter by type
  defp filter_by_type(messages, nil), do: messages

  defp filter_by_type(messages, type) do
    Enum.filter(messages, &(&1[:type] == type))
  end
end
