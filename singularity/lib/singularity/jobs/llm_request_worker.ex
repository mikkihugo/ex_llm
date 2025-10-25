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

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    priority: 5

  require Logger
  alias Singularity.Workflow.Executor
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
  def perform(%Oban.Job{args: args}) do
    request_id = args["request_id"]

    Logger.info("Executing LLM workflow",
      request_id: request_id,
      task_type: args["task_type"]
    )

    # Execute the LLM workflow directly (no network overhead!)
    case Executor.execute(LlmRequest, args, max_attempts: 1, timeout: 30000) do
      {:ok, result} ->
        Logger.info("LLM workflow completed",
          request_id: request_id,
          cost_cents: result["cost_cents"]
        )

        # TODO: Store result in database for agents to consume
        # Or: Publish to event log for interested parties

        :ok

      {:error, reason} ->
        Logger.error("LLM workflow failed",
          request_id: request_id,
          reason: inspect(reason)
        )

        # Oban will retry automatically (max_attempts: 3)
        {:error, reason}
    end
  end
end
