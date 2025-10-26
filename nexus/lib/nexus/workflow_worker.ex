defmodule Nexus.WorkflowWorker do
  @moduledoc """
  Workflow Worker - Executes ex_pgflow workflows for LLM request processing.

  Replaces the manual pgmq polling approach with ex_pgflow's DAG-based execution.

  ## Benefits over Manual Queue Polling

  - **Automatic Retry** - ex_pgflow handles retries with exponential backoff
  - **State Management** - Workflow state persisted in PostgreSQL
  - **Fault Isolation** - Failed steps retry independently
  - **Observability** - Every step, task, and attempt logged in DB
  - **Parallel Execution** - Multiple workers process requests concurrently
  - **Dependency Tracking** - Steps wait for dependencies automatically

  ## Architecture

  ```
  Singularity/Client
      ↓ Enqueue LLM request
  PostgreSQL pgmq:llm_requests
      ↓
  WorkflowWorker (this module)
      ↓ Start ex_pgflow workflow
  ex_pgflow Executor
      ↓ Execute DAG steps
  Nexus.Workflows.LLMRequestWorkflow
      ↓ Process request
  PostgreSQL pgmq:llm_results
  ```

  ## Usage

      # Start worker
      {:ok, pid} = Nexus.WorkflowWorker.start_link([
        database_url: "postgresql://...",
        poll_interval_ms: 1000,
        batch_size: 10
      ])

  """

  use GenServer
  require Logger

  alias Nexus.Workflows.LLMRequestWorkflow
  alias Pgflow.Executor

  @queue_name "llm_requests"
  @poll_interval_ms 1000
  @batch_size 10

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    batch_size = Keyword.get(opts, :batch_size, @batch_size)

    Logger.info("Starting Nexus Workflow Worker",
      queue: @queue_name,
      poll_interval: poll_interval,
      batch_size: batch_size,
      workflow: LLMRequestWorkflow
    )

    state = %{
      poll_interval: poll_interval,
      batch_size: batch_size
    }

    # Start polling immediately
    schedule_poll(0)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case poll_and_execute(state) do
      {:ok, count} when count > 0 ->
        Logger.debug("Started #{count} LLM request workflows")

      {:ok, 0} ->
        # No messages, keep polling
        :ok

      {:error, reason} ->
        Logger.error("Failed to poll queue", reason: inspect(reason))
    end

    # Schedule next poll
    schedule_poll(state.poll_interval)

    {:noreply, state}
  end

  # Private functions

  defp schedule_poll(delay_ms) do
    Process.send_after(self(), :poll, delay_ms)
  end

  defp poll_and_execute(state) do
    # Read messages from pgmq
    case read_messages(state.batch_size) do
      {:ok, messages} when length(messages) > 0 ->
        # Execute workflow for each message
        results =
          Enum.map(messages, fn msg ->
            execute_workflow(msg)
          end)

        successful = Enum.count(results, &match?({:ok, _}, &1))
        {:ok, successful}

      {:ok, []} ->
        {:ok, 0}

      {:error, _reason} = error ->
        error
    end
  end

  defp read_messages(limit) do
    # TODO: Use pgmq Elixir client
    # For now, simulate empty queue
    {:ok, []}
  end

  defp execute_workflow(%{msg_id: msg_id, msg: request}) do
    Logger.info("Executing LLM workflow",
      msg_id: msg_id,
      request_id: Map.get(request, "request_id"),
      workflow: LLMRequestWorkflow
    )

    # Execute workflow via ex_pgflow
    # This starts the DAG execution in background
    case Executor.execute(LLMRequestWorkflow, request, Nexus.Repo) do
      {:ok, result} ->
        Logger.info("LLM workflow completed",
          msg_id: msg_id,
          request_id: Map.get(request, "request_id"),
          metrics: Map.get(result, :track_metrics)
        )

        # Archive message from pgmq
        archive_message(msg_id)

        {:ok, result}

      {:error, reason} = error ->
        Logger.error("LLM workflow failed",
          msg_id: msg_id,
          request_id: Map.get(request, "request_id"),
          error: inspect(reason)
        )

        # Message will retry via pgmq visibility timeout
        error
    end
  end

  defp archive_message(_msg_id) do
    # TODO: Use pgmq Elixir client to archive
    :ok
  end
end
