defmodule Observer.Pgmq do
  @moduledoc """
  QuantumFlow-based messaging helper for Observer.

  Uses QuantumFlow.Notifications for reliable message delivery with real-time notifications.
  """

  require Logger
  alias Observer.Repo

  @spec send_message(String.t(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def send_message(queue, message) do
    QuantumFlow.Notifications.send_with_notify(queue, message, Repo, expect_reply: false)
  end

  @spec read_messages(String.t(), non_neg_integer()) :: [{non_neg_integer(), map()}]
  def read_messages(queue, limit \\ 1) do
    # For reading, we still need to use raw PGMQ since QuantumFlow is primarily for sending
    # TODO: Consider using QuantumFlow.Workflow for complete workflow orchestration
    ensure_queue(queue)

    try do
      result =
        Repo.query!(
          "SELECT msg_id, msg_body FROM pgmq.read($1, limit => $2)",
          [queue, limit]
        )

      Enum.map(result.rows, fn [msg_id, body] ->
        {msg_id, decode_body(body)}
      end)
    rescue
      error ->
        Logger.error("pgmq read error", queue: queue, error: inspect(error))
        []
    end
  end

  @spec peek_message(String.t(), term()) :: {:ok, {non_neg_integer(), map()}} | {:error, term()}
  def peek_message(queue, msg_id) do
    with {:ok, msg_id} <- normalize_msg_id(msg_id),
         :ok <- ensure_queue(queue) do
      case Repo.query("SELECT msg_id, msg_body FROM pgmq.peek($1, $2)", [queue, msg_id]) do
        {:ok, %{rows: [[fetched_id, body] | _]}} ->
          {:ok, {fetched_id, decode_body(body)}}

        {:ok, %{rows: []}} ->
          {:error, :not_found}

        {:error, error} ->
          Logger.error("pgmq peek error", queue: queue, message_id: msg_id, error: inspect(error))
          {:error, error}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec ack_message(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def ack_message(queue, msg_id) do
    with {:ok, msg_id} <- normalize_msg_id(msg_id) do
      try do
        Repo.query!("SELECT pgmq.delete($1, $2)", [queue, msg_id])
        :ok
      rescue
        error ->
          Logger.error("pgmq ack error", queue: queue, message_id: msg_id, error: inspect(error))
          {:error, error}
      end
    end
  end

  @spec ensure_queue(String.t()) :: :ok | {:error, term()}
  def ensure_queue(queue) do
    try do
      Repo.query!("SELECT pgmq.create($1)", [queue])
      :ok
    rescue
      error ->
        message = inspect(error)

        if String.contains?(message, "already exists") do
          :ok
        else
          Logger.error("pgmq create error", queue: queue, error: message)
          {:error, error}
        end
    end
  end

  @spec send_reply(String.t(), map()) :: :ok | {:error, term()}
  def send_reply(reply_queue, message) do
    QuantumFlow.Notifications.send_with_notify(reply_queue, message, Repo, expect_reply: false)
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> map
      _ -> %{"raw" => body}
    end
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(other), do: other

  defp normalize_msg_id(msg_id) when is_integer(msg_id) and msg_id >= 0, do: {:ok, msg_id}

  defp normalize_msg_id(msg_id) when is_binary(msg_id) do
    case Integer.parse(String.trim(msg_id)) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> {:error, :invalid_message_id}
    end
  end

  defp normalize_msg_id(_msg_id), do: {:error, :invalid_message_id}
end
