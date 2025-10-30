defmodule Singularity.Infrastructure.QuantumFlow.Queue do
  @moduledoc """
  Helper functions for persisting QuantumFlow workflow records and publishing
  messages via the quantum_flow package.
  """

  require Logger

  import Ecto.Query

  alias Pgmq
  alias Pgmq.Message
  alias QuantumFlow.{Messaging, Notifications}
  alias Singularity.Infrastructure.QuantumFlow.Workflow
  alias Singularity.Repo

  @doc """
  Persist a workflow record for observability.
  """
  def create_workflow(attrs) when is_map(attrs) do
    %Workflow{}
    |> Workflow.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Look up a workflow record by its external identifier.
  """
  def get_workflow(workflow_id) when is_binary(workflow_id) do
    Repo.get_by(Workflow, workflow_id: workflow_id)
  end

  @doc """
  Update workflow status.
  """
  def update_workflow_status(%Workflow{} = workflow, status) when is_binary(status) do
    workflow
    |> Workflow.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Publish a message to a QuantumFlow/pgmq queue with NOTIFY.
  """
  @spec send_with_notify(String.t(), map(), Ecto.Repo.t()) :: {:ok, term()} | {:error, term()}
  def send_with_notify(queue_name, message, repo \\ Repo, opts \\ [])
      when is_binary(queue_name) do
    opts = Keyword.put_new(opts, :expect_reply, false)
    Messaging.publish(repo, queue_name, message, opts)
  end

  @doc """
  Send a lightweight NOTIFY-only message.
  """
  def notify_only(channel, payload, repo \\ Repo)
      when is_binary(channel) and is_binary(payload) do
    Notifications.notify_only(channel, payload, repo)
  end

  @doc """
  Subscribe to NOTIFY events for a queue.
  """
  def listen(queue_name, repo \\ Repo) when is_binary(queue_name) do
    Notifications.listen(queue_name, repo)
  end

  @doc """
  Stop listening to NOTIFY events.
  """
  def unlisten(pid, repo \\ Repo) when is_pid(pid) do
    Notifications.unlisten(pid, repo)
  end

  @doc """
  Read messages directly from a pgmq queue and decode their JSON payloads.
  """
  def read_from_queue(queue_name, opts \\ []) when is_binary(queue_name) do
    repo = Keyword.get(opts, :repo, Repo)
    limit = Keyword.get(opts, :limit, 10)
    vt = Keyword.get(opts, :vt, 30)

    try do
      messages = Pgmq.read_messages(repo, queue_name, vt, limit)
      {:ok, Enum.map(messages, &normalize_message/1)}
    rescue
      error in [Postgrex.Error] ->
        {:error, format_postgrex_error(error)}

      error ->
        {:error, inspect(error)}
    end
  end

  @doc """
  Drop workflow records older than the configured retention window.
  """
  def prune_workflows(retention_minutes \\ 60) do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_minutes * 60, :second)

    {count, _} =
      from(w in Workflow, where: w.inserted_at < ^cutoff)
      |> Repo.delete_all()

    if count > 0 do
      Logger.debug("Pruned stale QuantumFlow workflow records", count: count)
    end

    count
  end

  @doc """
  Delete a message from the given queue by message identifier.
  """
  def delete_message(queue_name, msg_id, repo \\ Repo) when is_binary(queue_name) do
    normalized_id = normalize_msg_id(msg_id)

    try do
      :ok = Pgmq.delete_messages(repo, queue_name, [normalized_id])
      :ok
    rescue
      error in [Postgrex.Error] -> {:error, format_postgrex_error(error)}
      error -> {:error, inspect(error)}
    end
  end

  @doc """
  Archive a message to a dedicated dead-letter queue.
  """
  def move_to_dead_letter(queue_name, message, reason, repo \\ Repo) do
    dlq = "#{queue_name}_dlq"

    payload =
      message
      |> Map.get(:payload, %{})
      |> Map.put("dlq_reason", inspect(reason))
      |> Map.put("original_queue", queue_name)
      |> Map.put("msg_id", inspect(message[:msg_id] || message["msg_id"]))

    case send_with_notify(dlq, payload, repo) do
      {:ok, _} -> {:ok, dlq}
      {:error, err} -> {:error, err}
    end
  end

  defp normalize_message(%Message{id: msg_id, body: payload} = message) do
    %{
      msg_id: msg_id,
      payload: decode_payload(payload),
      raw: message
    }
  end

  defp normalize_message(other) do
    %{
      msg_id: nil,
      payload: decode_payload(other),
      raw: other
    }
  end

  defp decode_payload(nil), do: %{}
  defp decode_payload(%{} = payload), do: payload

  defp decode_payload(binary) when is_binary(binary) do
    case Jason.decode(binary) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"raw" => binary}
    end
  end

  defp decode_payload(other), do: %{"raw" => other}

  defp normalize_msg_id(id) when is_integer(id), do: id

  defp normalize_msg_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, _} -> value
      :error -> raise ArgumentError, "Unable to parse msg_id #{inspect(id)}"
    end
  end

  defp normalize_msg_id(id) when is_float(id), do: trunc(id)
  defp normalize_msg_id(id), do: id

  defp format_postgrex_error(%Postgrex.Error{postgres: postgres}) do
    %{code: postgres[:code], message: postgres[:message], detail: postgres[:detail]}
  end

  defp format_postgrex_error(error), do: error
end
