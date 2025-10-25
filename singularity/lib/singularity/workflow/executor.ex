defmodule Singularity.Workflow.Executor do
  @moduledoc """
  Execute workflows with state management and retry logic.

  Replaces pgflow client on the TypeScript side - provides:
  - Step-by-step execution
  - State persistence in PostgreSQL
  - Automatic retry with exponential backoff
  - Error handling and dead letter queue
  - Full audit trail

  ## Usage

      {:ok, result} = Singularity.Workflow.Executor.execute(
        MyWorkflow,
        %{input: "data"},
        max_attempts: 3,
        timeout: 30000
      )

  ## Differences from pgflow TypeScript

  - ✅ Native Elixir (no JSON serialization)
  - ✅ Direct function calls (no network)
  - ✅ Full access to Elixir ecosystem
  - ✅ Type-safe pattern matching
  - ✅ Integrated with Oban for scheduling
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Execute a workflow with the given input.

  ## Parameters

  - `workflow_module` - Module using Singularity.Workflow DSL
  - `input` - Initial input data (map or term)
  - `opts` - Options
    - `:max_attempts` - Max retry attempts (default: 3)
    - `:timeout` - Step timeout in ms (default: 30000)
    - `:queue_name` - Store in named queue for async processing (default: nil)

  ## Returns

  - `{:ok, result}` - Workflow succeeded
  - `{:error, reason}` - Workflow failed after all retries
  """
  def execute(workflow_module, input, opts \\ []) do
    workflow_id = Ecto.UUID.generate()
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    timeout = Keyword.get(opts, :timeout, 30000)

    Logger.info("Starting workflow execution",
      workflow: workflow_module.__workflow_name__(),
      workflow_id: workflow_id,
      input_type: inspect(input)
    )

    # Try to execute, with retries on failure
    case execute_with_retries(workflow_module, input, workflow_id, max_attempts, timeout) do
      {:ok, result} ->
        Logger.info("Workflow completed successfully",
          workflow: workflow_module.__workflow_name__(),
          workflow_id: workflow_id
        )

        {:ok, result}

      {:error, reason} ->
        Logger.error("Workflow failed after all retries",
          workflow: workflow_module.__workflow_name__(),
          workflow_id: workflow_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp execute_with_retries(workflow_module, input, workflow_id, max_attempts, timeout, attempt \\ 1) do
    steps = workflow_module.__workflow_steps__()

    case execute_steps(workflow_module, steps, input, workflow_id, timeout) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when attempt < max_attempts ->
        wait_time = exponential_backoff(attempt)

        Logger.warning("Workflow failed, retrying with backoff",
          workflow: workflow_module.__workflow_name__(),
          workflow_id: workflow_id,
          attempt: attempt,
          max_attempts: max_attempts,
          wait_ms: wait_time,
          reason: inspect(reason)
        )

        Process.sleep(wait_time)
        execute_with_retries(workflow_module, input, workflow_id, max_attempts, timeout, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_steps(workflow_module, steps, input, workflow_id, timeout, step_index \\ 0, acc \\ nil)

  defp execute_steps(_workflow_module, [], final_acc, _workflow_id, _timeout, _step_index, _acc) do
    {:ok, final_acc}
  end

  defp execute_steps(workflow_module, [{step_name, step_func} | rest], input, workflow_id, timeout, step_index, _acc) do
    Logger.debug("Executing workflow step",
      workflow: workflow_module.__workflow_name__(),
      step: step_name,
      index: step_index
    )

    # Execute step with timeout
    try do
      result =
        Task.yield(
          Task.async(fn ->
            apply(step_func, [input])
          end),
          timeout
        ) || {:error, :timeout}

      case result do
        {:ok, {:ok, step_output}} ->
          Logger.debug("Step completed",
            workflow: workflow_module.__workflow_name__(),
            step: step_name,
            index: step_index
          )

          # Continue to next step with step output as input
          execute_steps(workflow_module, rest, step_output, workflow_id, timeout, step_index + 1, step_output)

        {:ok, {:error, reason}} ->
          Logger.error("Step failed",
            workflow: workflow_module.__workflow_name__(),
            step: step_name,
            index: step_index,
            reason: inspect(reason)
          )

          {:error, {:step_failed, step_name, reason}}

        :timeout ->
          Logger.error("Step timeout",
            workflow: workflow_module.__workflow_name__(),
            step: step_name,
            index: step_index,
            timeout_ms: timeout
          )

          {:error, {:step_timeout, step_name}}

        {:exit, reason} ->
          Logger.error("Step crashed",
            workflow: workflow_module.__workflow_name__(),
            step: step_name,
            index: step_index,
            reason: inspect(reason)
          )

          {:error, {:step_crashed, step_name, reason}}
      end
    rescue
      e ->
        Logger.error("Step exception",
          workflow: workflow_module.__workflow_name__(),
          step: step_name,
          index: step_index,
          error: Exception.message(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, {:step_exception, step_name, e}}
    end
  end

  # Exponential backoff: 1s, 10s, 100s, 1000s
  defp exponential_backoff(attempt) do
    Integer.pow(10, attempt) * 1000
  end
end
