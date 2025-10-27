defmodule Singularity.Jobs.LlmResultPoller do
  @moduledoc """
  LLM Result Poller - Polls pgmq for Responses API results routed through Nexus.

  Architecture:
  - Nexus publishes LLM results to the `ai_results` pgmq queue
  - This worker polls `ai_results` periodically
  - Processes results and acknowledges messages
  - Persists results so agents can retrieve outcomes or await them synchronously

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
  alias Singularity.Schemas.Execution.JobResult
  alias Singularity.Repo

  import Ecto.Query

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
      case JobResult.record_success(
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

  # ==========================================================================
  # Synchronous helper
  # ==========================================================================

  @doc """
  Await the Responses API result for the given `request_id`.

  This helper polls the `job_results` table (populated by the poller) until a
  matching result is available or the timeout elapses.

  ## Options

    * `:timeout` - Maximum wait time in milliseconds (default: 30_000)
    * `:poll_interval` - Delay between checks in milliseconds (default: 500)

  ## Examples

      iex> Singularity.Jobs.LlmResultPoller.await_responses_result(request_id)
      {:ok, %{"response" => "..."}}
  """
  @spec await_responses_result(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def await_responses_result(request_id, _opts \\ []) when is_binary(request_id) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    poll_interval = Keyword.get(opts, :poll_interval, 500)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_await(request_id, poll_interval, deadline)
  end

  defp do_await(request_id, poll_interval, deadline) do
    case fetch_job_result(request_id) do
      :pending ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(poll_interval)
          do_await(request_id, poll_interval, deadline)
        end

      {:success, output} ->
        {:ok, output}

      {:failure, %JobResult{} = result} ->
        {:error, {:failed, result.error, result.output}}

      {:timeout, %JobResult{} = result} ->
        {:error, {:timeout, result}}

      {:unknown, %JobResult{} = result} ->
        {:error, {:unknown_status, result.status, result}}
    end
  end

  defp fetch_job_result(request_id) do
    query =
      from jr in JobResult,
        where: jr.workflow == "Singularity.Workflows.LlmRequest",
        where:
          fragment("(?->>'request_id') = ?", jr.input, ^request_id) or
            fragment("(?->>'request_id') = ?", jr.output, ^request_id),
        order_by: [desc: jr.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> :pending
      %JobResult{status: "success", output: output} -> {:success, output}
      %JobResult{status: "failed"} = result -> {:failure, result}
      %JobResult{status: "timeout"} = result -> {:timeout, result}
      %JobResult{} = result -> {:unknown, result}
    end
  end
end
