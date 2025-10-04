defmodule Singularity.Autonomy.Correlation do
  @moduledoc """
  Correlation tracking via OTP process dictionary.

  **NO EVENT-DRIVEN** - uses native Erlang process dictionary.

  Every workflow gets a UUID that flows through:
  - Process dictionary (automatic in same process)
  - GenServer calls (pass as argument)
  - Task spawning (copied to child processes)
  - Logger metadata (automatic tagging)

  ## Usage

      # Start workflow
      Correlation.start("epic_creation")

      # Correlation auto-flows through same process
      RuleEngine.execute(rule, context)  # Gets correlation from process dict

      # Pass to other GenServers
      GenServer.call(Coordinator, {:add_epic, epic, Correlation.current()})

      # Spawn task with correlation
      Correlation.spawn_task(fn ->
        # Child process inherits correlation
        do_work()
      end)

      # Correlation appears in all logs
      Logger.info("Epic validated")  # Automatically tagged with correlation_id
  """

  require Logger

  @correlation_key :correlation_id
  @workflow_key :workflow_type

  ## Client API

  @doc """
  Start a new correlated workflow.

  Sets correlation_id in process dictionary and Logger metadata.
  """
  def start(workflow_type) do
    correlation_id = Ecto.UUID.generate()
    set(correlation_id, workflow_type)
    correlation_id
  end

  @doc """
  Set correlation in current process.

  Used when receiving correlation from another process.
  """
  def set(correlation_id, workflow_type \\ nil) do
    Process.put(@correlation_key, correlation_id)

    if workflow_type do
      Process.put(@workflow_key, workflow_type)
    end

    # Also set in Logger metadata for automatic tagging
    Logger.metadata(correlation_id: correlation_id, workflow: workflow_type)

    correlation_id
  end

  @doc "Get current correlation ID from process dictionary"
  def current do
    Process.get(@correlation_key)
  end

  @doc "Get current workflow type"
  def workflow_type do
    Process.get(@workflow_key)
  end

  @doc """
  Spawn a Task with correlation inherited.

  The spawned task will have the same correlation_id as parent.
  """
  def spawn_task(fun) when is_function(fun, 0) do
    correlation_id = current()
    workflow = workflow_type()

    Task.start(fn ->
      # Set correlation in child process
      if correlation_id, do: set(correlation_id, workflow)
      fun.()
    end)
  end

  @doc """
  Spawn a supervised Task with correlation inherited.
  """
  def spawn_supervised_task(supervisor, fun) when is_function(fun, 0) do
    correlation_id = current()
    workflow = workflow_type()

    Task.Supervisor.start_child(supervisor, fn ->
      if correlation_id, do: set(correlation_id, workflow)
      fun.()
    end)
  end

  @doc """
  Execute a function in a new correlation context.

  Useful for background jobs that start their own workflows.
  """
  def with_new_correlation(workflow_type, fun) when is_function(fun, 0) do
    old_correlation = current()
    old_workflow = workflow_type()

    try do
      start(workflow_type)
      fun.()
    after
      # Restore old correlation
      if old_correlation do
        set(old_correlation, old_workflow)
      else
        clear()
      end
    end
  end

  @doc """
  Execute a function with a specific correlation.

  Useful when handling messages from other processes.
  """
  def with_correlation(correlation_id, workflow_type \\ nil, fun) when is_function(fun, 0) do
    old_correlation = current()
    old_workflow = workflow_type()

    try do
      set(correlation_id, workflow_type)
      fun.()
    after
      # Restore old correlation
      if old_correlation do
        set(old_correlation, old_workflow)
      else
        clear()
      end
    end
  end

  @doc "Clear correlation from current process"
  def clear do
    Process.delete(@correlation_key)
    Process.delete(@workflow_key)
    Logger.metadata(correlation_id: nil, workflow: nil)
  end

  @doc """
  Get correlation context as map.

  Useful for passing to other systems or logging.
  """
  def context do
    %{
      correlation_id: current(),
      workflow_type: workflow_type(),
      process_pid: self()
    }
  end
end
