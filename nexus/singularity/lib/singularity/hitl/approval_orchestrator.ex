defmodule Singularity.HITL.ApprovalOrchestrator do
  @moduledoc """
  Queue-backed HITL approval service for Singularity.

  Approval and question requests are enqueued in pgmq for Observer to pick up.
  Responses are read from a dedicated response queue per request.
  """

  require Logger

  alias Ecto.UUID

  @approval_timeout_ms 30_000
  @poll_interval_ms 500
  @request_queue "observer_hitl_requests"

  @doc """
  Request approval for a code change.

  Returns:
    * `{:ok, :approved}`
    * `{:ok, :rejected}`
    * `{:ok, :cancelled}`
    * `{:error, :timeout}`
  """
  def request_approval(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    diff = Keyword.fetch!(opts, :diff)
    description = Keyword.get(opts, :description, "Approval requested")
    agent_id = Keyword.get(opts, :agent_id, "system")
    task_type = Keyword.get(opts, :task_type)

    request_id = UUID.generate()
    response_queue = response_queue_name(request_id)

    payload = %{
      "request_id" => request_id,
      "type" => "approval",
      "response_queue" => response_queue,
      "agent_id" => agent_id,
      "task_type" => task_type,
      "payload" => %{
        "file_path" => file_path,
        "diff" => diff,
        "description" => description
      }
    }

    dispatch_and_wait(payload, response_queue)
  end

  @doc """
  Ask a human a free-form question.

  Returns:
    * `{:ok, response_text}`
    * `{:error, :timeout}`
  """
  def request_question(opts) do
    question = Keyword.fetch!(opts, :question)
    agent_id = Keyword.get(opts, :agent_id, "system")
    context = Keyword.get(opts, :context, %{})

    request_id = UUID.generate()
    response_queue = response_queue_name(request_id)

    payload = %{
      "request_id" => request_id,
      "type" => "question",
      "response_queue" => response_queue,
      "agent_id" => agent_id,
      "payload" => %{
        "question" => question,
        "context" => context
      }
    }

    dispatch_and_wait(payload, response_queue)
  end

  defp dispatch_and_wait(payload, response_queue) do
    with :ok <- ensure_queue(@request_queue),
         :ok <- ensure_queue(response_queue),
         result <- Singularity.Infrastructure.PgFlow.Queue.send_with_notify(@request_queue, payload) do
      case result do
        {:ok, _} ->
          await_response(response_queue, @approval_timeout_ms)

        {:error, reason} ->
          Logger.error("HITL request failed", reason: inspect(reason))
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("HITL request failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp await_response(queue, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_response(queue, deadline)
  end

  defp do_await_response(queue, deadline) do
    case MessageQueue.receive_message(queue) do
      {:ok, {msg_id, body}} ->
        MessageQueue.acknowledge(queue, msg_id)
        decode_response(body)

      :empty ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(@poll_interval_ms)
          do_await_response(queue, deadline)
        end

      {:error, reason} ->
        Logger.error("Error reading from queue #{queue}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp decode_response(%{"decision" => decision}) do
    case decision do
      "approved" -> {:ok, :approved}
      "rejected" -> {:ok, :rejected}
      "cancelled" -> {:ok, :cancelled}
      _ -> {:error, :invalid_response}
    end
  end

  defp decode_response(%{"response" => response}) when is_binary(response) do
    {:ok, response}
  end

  defp decode_response(other) do
    Logger.warning("Unknown HITL response", payload: inspect(other))
    {:error, :invalid_response}
  end

  defp ensure_queue(queue) do
    case MessageQueue.create_queue(queue) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp response_queue_name(request_id), do: "observer_hitl_response_" <> request_id
end
