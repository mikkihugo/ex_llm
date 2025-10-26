defmodule Singularity.HITL.ApprovalService do
  @moduledoc """
  Service for managing Human-in-the-Loop (HITL) approval workflow via NATS.

  Implements request-reply pattern with external HITL web UI.

  ## Approval Flow
  - Agent requests approval via NATS (approval.request topic)
  - External service displays in web UI
  - Human approves/rejects in UI
  - Response sent back via NATS reply

  ## Timeout
  - 30 second timeout if no human response
  - Agent can proceed with fallback decision

  ## Usage

      # Request approval (NATS request-reply, 30s timeout)
      case ApprovalService.request_approval(
        file_path: "lib/my_module.ex",
        diff: diff_text,
        description: "Add feature X"
      ) do
        {:ok, :approved} -> write_file(...)
        {:ok, :rejected} -> skip_change()
        {:error, :timeout} -> fallback_behavior()
      end
  """

  require Logger

  alias Singularity.Messaging.Client

  @approval_timeout_ms 30_000  # 30 second timeout

  @doc """
  Request approval for a code change via NATS.

  Sends approval request to external HITL service via NATS request-reply.
  Waits up to 30 seconds for human response.

  Returns:
  - {:ok, :approved} - Human approved
  - {:ok, :rejected} - Human rejected
  - {:error, :timeout} - No response within 30s
  """
  def request_approval(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    diff = Keyword.fetch!(opts, :diff)
    description = Keyword.get(opts, :description, "Approval requested")
    agent_id = Keyword.get(opts, :agent_id, "system")

    approval_request = %{
      id: UUID.uuid4(),
      file_path: file_path,
      diff: diff,
      description: description,
      agent_id: agent_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("Requesting approval via NATS: #{approval_request.id} (#{file_path})")

    try do
      # NATS request-reply to external HITL service
      response = Client.request(
        "approval.request",
        Jason.encode!(approval_request),
        timeout: @approval_timeout_ms
      )

      case response do
        {:ok, body} ->
          decoded = Jason.decode!(body)
          case decoded do
            %{"approved" => true} ->
              Logger.info("Approval granted: #{approval_request.id}")
              {:ok, :approved}
            %{"approved" => false} ->
              Logger.info("Approval rejected: #{approval_request.id}")
              {:ok, :rejected}
            _ ->
              Logger.warning("Invalid approval response")
              {:error, :invalid_response}
          end

        {:error, :timeout} ->
          Logger.warning("Approval request timeout: #{approval_request.id}")
          {:error, :timeout}

        {:error, reason} ->
          Logger.error("Approval request failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e in RuntimeError ->
        Logger.error("Error requesting approval: #{inspect(e)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Request a question/clarification from human via NATS.

  Similar to approval but returns text response instead of yes/no.

  Returns:
  - {:ok, response_text} - Human provided response
  - {:error, :timeout} - No response within 30s
  """
  def request_question(opts) do
    question = Keyword.fetch!(opts, :question)
    agent_id = Keyword.get(opts, :agent_id, "system")
    context = Keyword.get(opts, :context, %{})

    question_request = %{
      id: UUID.uuid4(),
      question: question,
      context: context,
      agent_id: agent_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("Requesting question response via NATS: #{question_request.id}")

    try do
      response = Client.request(
        "question.ask",
        Jason.encode!(question_request),
        timeout: @approval_timeout_ms
      )

      case response do
        {:ok, body} ->
          decoded = Jason.decode!(body)
          case decoded do
            %{"response" => response_text} when is_binary(response_text) ->
              Logger.info("Question answered: #{question_request.id}")
              {:ok, response_text}
            _ ->
              Logger.warning("Invalid question response")
              {:error, :invalid_response}
          end

        {:error, :timeout} ->
          Logger.warning("Question request timeout: #{question_request.id}")
          {:error, :timeout}

        {:error, reason} ->
          Logger.error("Question request failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e in RuntimeError ->
        Logger.error("Error requesting question: #{inspect(e)}")
        {:error, :request_failed}
    end
  end
end
