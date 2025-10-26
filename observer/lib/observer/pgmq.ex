defmodule Observer.Pgmq do
  @moduledoc """
  Minimal pgmq helper for Observer.

  Wraps the SQL functions provided by the pgmq extension
  so we can publish and consume messages using `Observer.Repo`.
  """

  require Logger
  alias Observer.Repo

  @spec send_message(String.t(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def send_message(queue, message) do
    ensure_queue(queue)

    try do
      result =
        Repo.query!(
          "SELECT pgmq.send($1, $2)",
          [queue, Jason.encode!(message)]
        )

      case result.rows do
        [[msg_id]] -> {:ok, msg_id}
        _ -> {:error, :send_failed}
      end
    rescue
      error ->
        Logger.error("pgmq send error", queue: queue, error: inspect(error))
        {:error, error}
    end
  end

  @spec read_messages(String.t(), non_neg_integer()) :: [{non_neg_integer(), map()}]
  def read_messages(queue, limit \\ 1) do
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

  @spec ack_message(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def ack_message(queue, msg_id) do
    try do
      Repo.query!("SELECT pgmq.delete($1, $2)", [queue, msg_id])
      :ok
    rescue
      error ->
        Logger.error("pgmq ack error", queue: queue, message_id: msg_id, error: inspect(error))
        {:error, error}
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

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> map
      _ -> %{"raw" => body}
    end
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(other), do: other
end
