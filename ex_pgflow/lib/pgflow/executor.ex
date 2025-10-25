defmodule Pgflow.Executor do
  @moduledoc """
  Database-driven DAG workflow executor matching pgflow's architecture.

  ## Overview

  Pgflow.Executor now implements database-driven execution with full DAG support:
  1. Parses workflow step definitions (supports both sequential and depends_on syntax)
  2. Initializes workflow run in database (creates runs, step_states, step_tasks, dependencies)
  3. Executes tasks in parallel as dependencies are satisfied
  4. Uses PostgreSQL functions for coordination (start_ready_steps, complete_task)
  5. Returns final result when all steps complete

  ## Execution Modes

  ### Sequential (Legacy, Backwards Compatible)

      def __workflow_steps__ do
        [
          {:step1, &__MODULE__.step1/1},
          {:step2, &__MODULE__.step2/1}
        ]
      end

  Automatically converted to: step2 depends on step1

  ### DAG (Parallel Dependencies)

      def __workflow_steps__ do
        [
          {:fetch, &__MODULE__.fetch/1, depends_on: []},
          {:analyze, &__MODULE__.analyze/1, depends_on: [:fetch]},
          {:summarize, &__MODULE__.summarize/1, depends_on: [:fetch]},
          {:save, &__MODULE__.save/1, depends_on: [:analyze, :summarize]}
        ]
      end

  Steps `analyze` and `summarize` run in parallel!

  ## Execution Flow (Database-Driven)

      execute(WorkflowModule, input, repo)
        ├─ Parse workflow definition
        │   ├─ Validate dependencies
        │   ├─ Check for cycles
        │   └─ Find root steps
        │
        ├─ Initialize run in database
        │   ├─ Create workflow_runs record
        │   ├─ Create step_states (with remaining_deps counters)
        │   ├─ Create step_dependencies
        │   ├─ Create step_tasks for root steps
        │   └─ Call start_ready_steps() to mark roots as 'started'
        │
        ├─ Execute task loop
        │   ├─ Poll for queued tasks
        │   ├─ Claim task (FOR UPDATE SKIP LOCKED)
        │   ├─ Execute step function
        │   ├─ Call complete_task() → cascades to dependents
        │   └─ Repeat until all tasks complete
        │
        └─ Return final output

  ## Multi-Instance Coordination

  Multiple workers can execute the same run_id concurrently:
  - PostgreSQL row-level locking prevents race conditions
  - Workers independently poll and claim tasks
  - complete_task() function atomically updates state
  - No inter-worker communication needed

  ## Error Handling

  - Task failure: Automatic retry (configurable max_attempts)
  - Step failure: Marks run as failed, no dependent steps execute
  - Timeout: Run-level timeout (default 5 minutes)
  - Validation: Cycle detection, dependency validation

  ## Usage

      # Sequential execution (legacy syntax)
      {:ok, result} = Pgflow.Executor.execute(MyWorkflow, input, MyApp.Repo)

      # DAG execution (parallel steps)
      {:ok, result} = Pgflow.Executor.execute(
        MyWorkflow,
        input,
        MyApp.Repo,
        timeout: 600_000  # 10 minutes
      )

      # Error handling
      case Pgflow.Executor.execute(MyWorkflow, input, repo) do
        {:ok, result} -> IO.inspect(result)
        {:error, reason} -> Logger.error("Workflow failed: #{inspect(reason)}")
      end
  """

  require Logger

  alias Pgflow.DAG.{WorkflowDefinition, RunInitializer, TaskExecutor}

  @doc """
  Execute a workflow with database-driven DAG coordination.

  ## Parameters

    - `workflow_module` - Module implementing `__workflow_steps__/0`
    - `input` - Initial input map passed to workflow
    - `repo` - Ecto repo for database operations (e.g., MyApp.Repo)
    - `opts` - Execution options (optional)

  ## Options

    - `:timeout` - Maximum execution time in milliseconds (default: 300_000 = 5 minutes)
    - `:poll_interval` - Time between task polls in milliseconds (default: 100)
    - `:worker_id` - Worker identifier for task claiming (default: inspect(self()))

  ## Returns

    - `{:ok, result}` - Workflow completed successfully
    - `{:error, reason}` - Workflow failed (validation, execution, or timeout)
  """
  @spec execute(module(), map(), module(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(workflow_module, input, repo, opts \\ []) do
    Logger.info("Pgflow.Executor: Starting workflow",
      workflow: workflow_module,
      input_keys: Map.keys(input)
    )

    with {:ok, definition} <- WorkflowDefinition.parse(workflow_module),
         {:ok, run_id} <- RunInitializer.initialize(definition, input, repo),
         result <- TaskExecutor.execute_run(run_id, definition, repo, opts) do
      case result do
        {:ok, output} ->
          Logger.info("Pgflow.Executor: Workflow completed",
            workflow: workflow_module,
            run_id: run_id
          )

          {:ok, output}

        {:error, reason} ->
          Logger.error("Pgflow.Executor: Workflow failed",
            workflow: workflow_module,
            run_id: run_id,
            reason: inspect(reason)
          )

          {:error, reason}

        {:timeout, partial_output} ->
          Logger.warn("Pgflow.Executor: Workflow timed out",
            workflow: workflow_module,
            run_id: run_id
          )

          {:error, {:timeout, partial_output}}
      end
    else
      {:error, reason} ->
        Logger.error("Pgflow.Executor: Workflow initialization failed",
          workflow: workflow_module,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Get the status of a workflow run.

  ## Returns

    - `{:ok, :completed, output}` - Run completed successfully
    - `{:ok, :failed, error}` - Run failed
    - `{:ok, :in_progress, progress}` - Run still executing
    - `{:error, :not_found}` - Run ID not found
  """
  @spec get_run_status(Ecto.UUID.t(), module()) ::
          {:ok, :completed | :failed | :in_progress, term()} | {:error, :not_found}
  def get_run_status(run_id, repo) do
    import Ecto.Query

    case repo.get(Pgflow.WorkflowRun, run_id) do
      nil ->
        {:error, :not_found}

      run ->
        case run.status do
          "completed" ->
            {:ok, :completed, run.output}

          "failed" ->
            {:ok, :failed, run.error_message}

          "started" ->
            # Calculate progress
            progress = calculate_progress(run_id, repo)
            {:ok, :in_progress, progress}
        end
    end
  end

  # Calculate workflow progress
  defp calculate_progress(run_id, repo) do
    import Ecto.Query

    total_steps =
      from(s in Pgflow.StepState,
        where: s.run_id == ^run_id,
        select: count()
      )
      |> repo.one()

    completed_steps =
      from(s in Pgflow.StepState,
        where: s.run_id == ^run_id,
        where: s.status == "completed",
        select: count()
      )
      |> repo.one()

    %{
      total_steps: total_steps,
      completed_steps: completed_steps,
      percentage: if(total_steps > 0, do: completed_steps / total_steps * 100, else: 0)
    }
  end
end
