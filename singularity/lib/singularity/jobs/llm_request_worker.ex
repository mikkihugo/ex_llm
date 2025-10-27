defmodule Singularity.Jobs.LlmRequestWorker do
  @moduledoc """
  LLM Request Worker - Execute LLM requests via Elixir workflow

  Replaces: pgmq llm.request topic + TypeScript pgflow

  Architecture:
  - Oban job enqueues with request details
  - WorkflowExecutor executes LlmRequest workflow
  - Workflow steps: receive → select model → call provider → publish result
  - All in Elixir (no network overhead, direct function calls)

  Benefits vs TypeScript pgflow:
  - ✅ No network latency (direct execution)
  - ✅ Native Elixir (type-safe, pattern matching)
  - ✅ Direct access to Singularity code
  - ✅ Automatic retry with exponential backoff via Oban
  - ✅ Single language ecosystem
  """

  use Pgflow.Worker, queue: :default, max_attempts: 3

  require Logger
  alias Singularity.Workflows.LlmRequest

  @doc """
  Enqueue an LLM request to be executed by the workflow.

  Args:
    - task_type: Type of task (architect, coder, classifier, etc.)
    - messages: List of message objects for LLM
    - _opts: Optional parameters (model, provider, etc.)

  Returns: {:ok, request_id} or {:error, reason}
  """
  @spec enqueue_llm_request(String.t(), list(map()), keyword()) :: {:ok, String.t()} | {:error, term()}
  def enqueue_llm_request(task_type, messages, opts \\ []) do
    request_id = Ecto.UUID.generate()

    args = %{
      "request_id" => request_id,
      "task_type" => task_type,
      "messages" => messages,
      "model" => Keyword.get(opts, :model, "auto"),
      "provider" => Keyword.get(opts, :provider, "auto"),
      "api_version" => Keyword.get(opts, :api_version, "responses"),
      "complexity" => Keyword.get(opts, :complexity, "medium"),
      "max_tokens" => Keyword.get(opts, :max_tokens),
      "temperature" => Keyword.get(opts, :temperature),
      "agent_id" => Keyword.get(opts, :agent_id),
      "previous_response_id" => Keyword.get(opts, :previous_response_id),
      "mcp_servers" => Keyword.get(opts, :mcp_servers),
      "store" => Keyword.get(opts, :store),
      "tools" => Keyword.get(opts, :tools)
    }
    # Remove nil values to keep message compact
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    case %{}
         |> new(args)
         |> Oban.insert() do
      {:ok, job} ->
        Logger.info("LLM request enqueued",
          request_id: request_id,
          task_type: task_type,
          job_id: job.id
        )

        {:ok, request_id}

      {:error, reason} ->
        Logger.error("Failed to enqueue LLM request",
          request_id: request_id,
          task_type: task_type,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, id: job_id}) do
    request_id = args["request_id"]
    start_time = System.monotonic_time(:millisecond)

    Logger.info("Executing LLM workflow",
      request_id: request_id,
      task_type: args["task_type"]
    )

    # Execute the LLM workflow directly via ExPgflow (no network overhead!)
    case Pgflow.Executor.execute(LlmRequest, args, timeout: 30000) do
      {:ok, result} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        Logger.info("LLM workflow completed",
          request_id: request_id,
          cost_cents: result["cost_cents"],
          duration_ms: duration_ms
        )

        # Record result in database for tracking and CentralCloud learning
        Singularity.Schemas.Execution.JobResult.record_success(
          workflow: "Singularity.Workflows.LlmRequest",
          instance_id: Pgflow.Instance.Registry.instance_id(),
          job_id: job_id,
          input: args,
          output: result,
          tokens_used: result["tokens_used"] || 0,
          cost_cents: result["cost_cents"] || 0,
          duration_ms: duration_ms
        )

        :ok

      {:error, reason} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        Logger.error("LLM workflow failed",
          request_id: request_id,
          reason: inspect(reason),
          duration_ms: duration_ms
        )

        # Record failure for tracking
        Singularity.Schemas.Execution.JobResult.record_failure(
          workflow: "Singularity.Workflows.LlmRequest",
          instance_id: Pgflow.Instance.Registry.instance_id(),
          job_id: job_id,
          input: args,
          error: inspect(reason),
          duration_ms: duration_ms
        )

        # Oban will retry automatically (max_attempts: 3)
        {:error, reason}
    end
  end

  @doc """
  Wait synchronously for an LLM request result.

  Polls the JobResult table until a result with the given request_id is found,
  or times out after the specified duration.

  ## Parameters
    - `request_id` - UUID of the LLM request returned by enqueue_llm_request/3
    - `timeout_ms` - Maximum time to wait in milliseconds (default: 30000 = 30 seconds)

  ## Returns
    - `{:ok, result}` - LLM result from Responses API
    - `{:error, :timeout}` - No result available after timeout
    - `{:error, :not_found}` - No result and no workflow job found
    - `{:error, :failed}` - Workflow execution failed

  ## Examples

      # Wait up to 30 seconds for a result
      case LlmRequestWorker.await_responses_result(request_id) do
        {:ok, result} -> handle_result(result)
        {:error, :timeout} -> handle_timeout()
        {:error, reason} -> handle_error(reason)
      end

      # Wait only 5 seconds
      LlmRequestWorker.await_responses_result(request_id, timeout_ms: 5000)
  """
  @spec await_responses_result(String.t(), keyword()) ::
    {:ok, map()} | {:error, :timeout | :not_found | :failed | term()}
  def await_responses_result(opts \\ [])(request_id, _opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 30000)
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, 100)

    start_time = System.monotonic_time(:millisecond)
    poll_until_found(request_id, timeout_ms, poll_interval_ms, start_time)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp poll_until_found(request_id, timeout_ms, poll_interval_ms, start_time) do
    import Ecto.Query

    alias Singularity.Schemas.Execution.JobResult
    alias Singularity.Repo

    # Check if result exists
    result = Repo.one(
      from jr in JobResult,
      where: fragment("? ->> 'request_id' = ?", jr.input, ^request_id),
      select: jr
    )

    case result do
      # Result found - return it
      %{status: "success", output: output} ->
        {:ok, output}

      # Workflow failed
      %{status: "failed", error: error} ->
        {:error, {:failed, error}}

      # No result yet - check timeout
      nil ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed >= timeout_ms do
          {:error, :timeout}
        else
          # Sleep and retry
          Process.sleep(poll_interval_ms)
          poll_until_found(request_id, timeout_ms, poll_interval_ms, start_time)
        end
    end
  end
end
