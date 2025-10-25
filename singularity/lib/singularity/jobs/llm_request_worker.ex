defmodule Singularity.Jobs.LlmRequestWorker do
  @moduledoc """
  LLM Request Worker - Execute LLM requests via Elixir workflow

  Replaces: NATS llm.request topic + TypeScript pgflow

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
    - opts: Optional parameters (model, provider, etc.)

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
      "provider" => Keyword.get(opts, :provider, "auto")
    }

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
end
