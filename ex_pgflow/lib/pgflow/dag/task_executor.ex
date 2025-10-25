defmodule Pgflow.DAG.TaskExecutor do
  @moduledoc """
  Executes workflow step tasks from the database.

  Implements the pgflow execution model:
  1. Poll for queued tasks
  2. Claim a task (mark as 'started')
  3. Execute the step function
  4. Call complete_task() PostgreSQL function
  5. Repeat until all tasks complete or fail

  ## Execution Loop

      TaskExecutor.execute_run(run_id, definition, repo)
        ↓
      Poll for queued tasks
        ↓
      Claim task (update status='started', set claimed_by)
        ↓
      Execute step function
        ↓
      Call complete_task(run_id, step_slug, task_index, output)
        ↓
      PostgreSQL cascades completion
        ↓
      Poll for next queued tasks (newly awakened steps)
        ↓
      Repeat until no more queued tasks

  ## Parallelism

  Multiple workers can run execute_run() concurrently for the same run_id.
  PostgreSQL handles coordination via row-level locking on task claims.

  ## Error Handling

  - Task failure: Mark as 'failed', retry if attempts_count < max_attempts
  - Task timeout: Mark as 'failed' with timeout error
  - Max attempts: Mark step as 'failed', propagate to run
  """

  require Logger
  import Ecto.Query

  alias Pgflow.DAG.WorkflowDefinition
  alias Pgflow.{WorkflowRun, StepState, StepTask}

  @doc """
  Execute all tasks for a workflow run until completion or failure.

  Returns:
  - `{:ok, output}` - Run completed successfully
  - `{:error, reason}` - Run failed
  - `{:timeout, partial_output}` - Run timed out (not all steps completed)
  """
  @spec execute_run(Ecto.UUID.t(), WorkflowDefinition.t(), module(), keyword()) ::
          {:ok, map()} | {:error, term()} | {:timeout, map()}
  def execute_run(run_id, definition, repo, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300_000)
    # 5 minutes default
    poll_interval = Keyword.get(opts, :poll_interval, 100)
    # 100ms between polls
    worker_id = Keyword.get(opts, :worker_id, inspect(self()))

    start_time = System.monotonic_time(:millisecond)

    Logger.info("TaskExecutor: Starting execution loop", run_id: run_id, worker_id: worker_id)

    execute_loop(run_id, definition, repo, worker_id, start_time, timeout, poll_interval)
  end

  # Main execution loop: poll → claim → execute → repeat
  defp execute_loop(run_id, definition, repo, worker_id, start_time, timeout, poll_interval) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    cond do
      elapsed > timeout ->
        Logger.warn("TaskExecutor: Timeout exceeded", run_id: run_id, elapsed_ms: elapsed)
        check_run_status(run_id, repo)

      true ->
        case poll_and_execute_next_task(run_id, definition, repo, worker_id) do
          {:ok, :task_executed} ->
            # Task completed, poll for next task immediately
            execute_loop(run_id, definition, repo, worker_id, start_time, timeout, poll_interval)

          {:ok, :no_tasks_available} ->
            # No tasks available right now
            case check_run_status(run_id, repo) do
              {:ok, :completed} = result ->
                result

              {:error, _} = error ->
                error

              {:ok, :in_progress} ->
                # Run is still in progress, sleep and poll again
                :timer.sleep(poll_interval)

                execute_loop(
                  run_id,
                  definition,
                  repo,
                  worker_id,
                  start_time,
                  timeout,
                  poll_interval
                )
            end

          {:error, reason} ->
            Logger.error("TaskExecutor: Task execution failed", run_id: run_id, reason: inspect(reason))
            {:error, reason}
        end
    end
  end

  # Poll for a queued task, claim it, and execute it
  defp poll_and_execute_next_task(run_id, definition, repo, worker_id) do
    # Find queued tasks for started steps
    query =
      from t in StepTask,
        where: t.run_id == ^run_id,
        where: t.status == "queued",
        where:
          t.step_slug in subquery(
            from s in StepState,
              where: s.run_id == ^run_id,
              where: s.status == "started",
              select: s.step_slug
          ),
        order_by: [asc: t.step_slug, asc: t.task_index],
        limit: 1,
        lock: "FOR UPDATE SKIP LOCKED"

    case repo.one(query) do
      nil ->
        {:ok, :no_tasks_available}

      task ->
        execute_task(task, definition, repo, worker_id)
    end
  end

  # Execute a single task
  defp execute_task(task, definition, repo, worker_id) do
    step_slug_atom = String.to_existing_atom(task.step_slug)
    step_fn = WorkflowDefinition.get_step_function(definition, step_slug_atom)

    if step_fn == nil do
      Logger.error("TaskExecutor: Step function not found",
        step_slug: task.step_slug,
        run_id: task.run_id
      )

      return {:error, {:step_not_found, task.step_slug}}
    end

    # Claim the task
    claimed_task =
      task
      |> StepTask.claim(worker_id)
      |> repo.update!()

    Logger.debug("TaskExecutor: Executing task",
      run_id: task.run_id,
      step_slug: task.step_slug,
      task_index: task.task_index,
      worker_id: worker_id
    )

    # Build input for step function
    # TODO: Merge outputs from dependencies
    input = build_step_input(task, definition, repo)

    # Execute step function with timeout
    result =
      try do
        task_with_timeout = Task.async(fn -> step_fn.(input) end)

        case Task.yield(task_with_timeout, 30_000) do
          {:ok, {:ok, output}} ->
            {:ok, output}

          {:ok, {:error, reason}} ->
            {:error, reason}

          nil ->
            Task.shutdown(task_with_timeout, :brutal_kill)
            {:error, :timeout}
        end
      catch
        kind, error ->
          {:error, {:exception, {kind, error}}}
      end

    # Handle result
    case result do
      {:ok, output} ->
        complete_task_success(claimed_task, output, repo)

      {:error, reason} ->
        complete_task_failure(claimed_task, reason, repo)
    end
  end

  # Build input for step function (merge workflow input + dependency outputs)
  defp build_step_input(task, _definition, repo) do
    # Get the workflow run input
    run = repo.get!(WorkflowRun, task.run_id)

    # TODO: Merge outputs from dependencies
    # For now, just use task input (which contains workflow input for root steps)
    Map.merge(run.input, task.input || %{})
  end

  # Complete task successfully
  defp complete_task_success(task, output, repo) do
    # Call PostgreSQL complete_task function
    result =
      repo.query(
        "SELECT complete_task($1::uuid, $2::text, $3::integer, $4::jsonb)",
        [task.run_id, task.step_slug, task.task_index, Jason.encode!(output)]
      )

    case result do
      {:ok, _} ->
        Logger.debug("TaskExecutor: Task completed successfully",
          run_id: task.run_id,
          step_slug: task.step_slug,
          task_index: task.task_index
        )

        {:ok, :task_executed}

      {:error, reason} ->
        Logger.error("TaskExecutor: Failed to complete task",
          run_id: task.run_id,
          step_slug: task.step_slug,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Complete task with failure
  defp complete_task_failure(task, reason, repo) do
    error_message = inspect(reason)

    if StepTask.can_retry?(task) do
      # Requeue for retry
      Logger.warn("TaskExecutor: Task failed, requeuing",
        run_id: task.run_id,
        step_slug: task.step_slug,
        attempts: task.attempts_count,
        max_attempts: task.max_attempts
      )

      task
      |> StepTask.requeue()
      |> repo.update()

      {:ok, :task_executed}
    else
      # Max attempts exceeded, mark as failed
      Logger.error("TaskExecutor: Task failed permanently",
        run_id: task.run_id,
        step_slug: task.step_slug,
        attempts: task.attempts_count,
        reason: error_message
      )

      task
      |> StepTask.mark_failed(error_message)
      |> repo.update()

      # Mark step and run as failed
      mark_step_failed(task.run_id, task.step_slug, error_message, repo)
      mark_run_failed(task.run_id, error_message, repo)

      {:error, {:task_failed_permanently, reason}}
    end
  end

  # Mark step as failed
  defp mark_step_failed(run_id, step_slug, error_message, repo) do
    from(s in StepState,
      where: s.run_id == ^run_id,
      where: s.step_slug == ^step_slug
    )
    |> repo.update_all(
      set: [
        status: "failed",
        error_message: error_message,
        failed_at: DateTime.utc_now()
      ]
    )
  end

  # Mark run as failed
  defp mark_run_failed(run_id, error_message, repo) do
    from(r in WorkflowRun,
      where: r.id == ^run_id
    )
    |> repo.update_all(
      set: [
        status: "failed",
        error_message: error_message,
        failed_at: DateTime.utc_now()
      ]
    )
  end

  # Check run status to determine if execution is complete
  defp check_run_status(run_id, repo) do
    run = repo.get!(WorkflowRun, run_id)

    case run.status do
      "completed" ->
        Logger.info("TaskExecutor: Run completed", run_id: run_id)
        {:ok, run.output || %{}}

      "failed" ->
        Logger.error("TaskExecutor: Run failed", run_id: run_id, error: run.error_message)
        {:error, {:run_failed, run.error_message}}

      "started" ->
        # Still in progress
        {:ok, :in_progress}
    end
  end
end
