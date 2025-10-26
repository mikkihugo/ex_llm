defmodule Singularity.Jobs.PgmqClient do
  @moduledoc """
  PostgreSQL Message Queue (pgmq) Client

  Provides helper functions for publishing messages to pgmq queues.
  pgmq enables Singularity (Elixir/Oban) ↔ Nexus (Responses API workflows) communication.

  Architecture:
  - Singularity enqueues tasks to pgmq (via Oban/ex_pgflow workers)
  - Nexus polls pgmq, executes Responses workflows
  - Results published back to pgmq
  - Singularity polls results via separate Oban jobs
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Send a message to a pgmq queue.

  Returns {:ok, message_id} or {:error, reason}
  """
  @spec send_message(String.t(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def send_message(queue_name, message) do
    try do
      result =
        Repo.query!(
          "SELECT pgmq.send($1, $2)",
          [queue_name, Jason.encode!(message)]
        )

      case result.rows do
        [[message_id]] -> {:ok, message_id}
        _ -> {:error, "Failed to send message to pgmq queue: #{queue_name}"}
      end
    rescue
      error ->
        Logger.error("pgmq error",
          queue: queue_name,
          error: inspect(error),
          message: inspect(message)
        )

        {:error, error}
    end
  end

  @doc """
  Read messages from a pgmq queue.

  Returns list of {message_id, body} tuples or empty list if no messages.
  """
  @spec read_messages(String.t(), non_neg_integer()) :: [{non_neg_integer(), map()}]
  def read_messages(queue_name, limit \\ 1) do
    try do
      result =
        Repo.query!(
          "SELECT msg_id, msg_body FROM pgmq.read($1, limit => $2)",
          [queue_name, limit]
        )

      Enum.map(result.rows, fn [msg_id, body] ->
        {msg_id, body}
      end)
    rescue
      error ->
        Logger.error("pgmq read error",
          queue: queue_name,
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Acknowledge (delete) a message from a pgmq queue.

  Returns :ok or {:error, reason}
  """
  @spec ack_message(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def ack_message(queue_name, message_id) do
    try do
      Repo.query!(
        "SELECT pgmq.delete($1, $2)",
        [queue_name, message_id]
      )

      :ok
    rescue
      error ->
        Logger.error("pgmq ack error",
          queue: queue_name,
          message_id: message_id,
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Create a pgmq queue if it doesn't exist.

  Returns :ok or {:error, reason}
  """
  @spec ensure_queue(String.t()) :: :ok | {:error, term()}
  def ensure_queue(queue_name) do
    try do
      Repo.query!(
        "SELECT pgmq.create($1)",
        [queue_name]
      )

      Logger.info("pgmq queue created", queue: queue_name)
      :ok
    rescue
      error ->
        # Queue may already exist, which is fine
        if String.contains?(inspect(error), "already exists") do
          :ok
        else
          Logger.error("pgmq queue creation error",
            queue: queue_name,
            error: inspect(error)
          )

          {:error, error}
        end
    end
  end

  @doc """
  Ensure all required pgmq queues exist.
  """
  @spec ensure_all_queues() :: :ok
  def ensure_all_queues do
    queues = [
      "ai_requests",
      "ai_results",
      "embedding_requests",
      "embedding_results",
      "agent_messages",
      "agent_responses",
      "centralcloud_updates"
    ]

    Enum.each(queues, &ensure_queue/1)
    :ok
  end
end
