defmodule Singularity.Jobs.LlmResultPoller do
  @moduledoc """
  LLM Result Poller - Poll pgmq for results from ai-server

  Architecture:
  - ai-server publishes LLM results to pgmq:ai_results
  - This job polls pgmq:ai_results periodically
  - Processes results and acknowledges messages
  - Stores results in database for agents to consume

  Polling Strategy:
  - Runs every 5 seconds via Oban cron job
  - Reads up to 10 messages per poll
  - Processes each result
  - Acknowledges message on success

  Results are stored in:
  - Database table for tracking
  - Event log for agent consumption
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    priority: 9

  require Logger
  alias Singularity.Jobs.PgmqClient

  @doc """
  Poll pgmq:ai_results for responses from ai-server.

  Called periodically by Oban scheduler.
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("Polling ai_results queue")

    # Read up to 10 messages from ai_results queue
    messages = PgmqClient.read_messages("ai_results", 10)

    Enum.each(messages, fn {message_id, body} ->
      process_result(body, message_id)
    end)

    if length(messages) > 0 do
      Logger.info("Processed LLM results from ai-server",
        count: length(messages)
      )
    end

    :ok
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp process_result(body, message_id) do
    try do
      # body is already a map or needs to be parsed
      result = if is_map(body), do: body, else: Jason.decode!(body)

      request_id = result["request_id"]

      Logger.debug("Processing LLM result",
        request_id: request_id,
        message_id: message_id
      )

      # Store result in database for agent consumption
      case store_result(result) do
        :ok ->
          # Acknowledge message
          PgmqClient.ack_message("ai_results", message_id)

          Logger.info("LLM result processed and stored",
            request_id: request_id
          )

        {:error, reason} ->
          Logger.error("Failed to store LLM result",
            request_id: request_id,
            reason: inspect(reason)
          )

          # Don't acknowledge - message will be retried
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error processing LLM result",
          error: inspect(error),
          message_id: message_id
        )

        {:error, error}
    end
  end

  defp store_result(result) do
    try do
      request_id = result["request_id"]

      Logger.info("Storing LLM result",
        request_id: request_id,
        model: result["model"],
        tokens: result["tokens_used"]
      )

      # Insert result into job_results table for persistent storage and agent consumption
      case Singularity.Schemas.Execution.JobResult.record_success(
        workflow: "Singularity.Workflows.LlmRequest",
        instance_id: Singularity.Application.instance_id(),
        input: %{
          request_id: request_id,
          agent_id: result["agent_id"],
          complexity: result["complexity"],
          task_type: result["task_type"]
        },
        output: %{
          request_id: request_id,
          response: result["response"],
          model: result["model"],
          usage: result["usage"],
          cost: result["cost"],
          latency_ms: result["latency_ms"]
        },
        tokens_used: get_in(result, ["usage", "total_tokens"]) || 0,
        cost_cents: Float.round((result["cost"] || 0.0) * 100) |> trunc(),
        duration_ms: result["latency_ms"]
      ) do
        {:ok, job_result} ->
          Logger.info("LLM result stored successfully",
            request_id: request_id,
            result_id: job_result.id
          )
          :ok

        {:error, reason} ->
          Logger.error("Failed to store LLM result",
            request_id: request_id,
            error: inspect(reason)
          )
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error storing LLM result",
          error: inspect(error),
          request_id: result["request_id"]
        )

        {:error, error}
    end
  end
end
