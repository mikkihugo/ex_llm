defmodule Singularity.Execution.TaskAdapterOrchestrator do
  @moduledoc """
  Task Adapter Orchestrator - Config-driven orchestration of task execution strategies.

  Automatically discovers and uses enabled adapters to execute tasks using the most
  appropriate execution method (Oban jobs, NATS messages, GenServer agents, etc.).

  Routes tasks to first-available-match adapter based on task requirements and adapter
  capabilities.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.TaskAdapterOrchestrator",
    "purpose": "Config-driven orchestration of task execution strategies",
    "layer": "execution",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Execute["execute(task, opts)"]
      LoadConfig["Load enabled adapters by priority"]
      Try1["Try Adapter 1 (priority 10)"]
      Try2["Try Adapter 2 (priority 15)"]
      Try3["Try Adapter 3 (priority 20)"]
      Success["Success: {:ok, task_id}"]
      Continue1["Not suitable → Try next"]
      Continue2["Not suitable → Try next"]
      Error["Error: {:error, reason}"]

      Execute --> LoadConfig
      LoadConfig --> Try1
      Try1 -->|{ok, id}| Success
      Try1 -->|no_match| Continue1
      Try1 -->|error| Error
      Continue1 --> Try2
      Try2 -->|{ok, id}| Success
      Try2 -->|no_match| Continue2
      Try2 -->|error| Error
      Continue2 --> Try3
      Try3 -->|{ok, id}| Success
      Try3 -->|error| Error
  ```

  ## Usage Examples

  ```elixir
  # Execute task with automatic adapter selection
  TaskAdapterOrchestrator.execute(%{
    type: :pattern_analysis,
    args: %{codebase_id: "my-project"},
    opts: [async: true]
  })
  # => {:ok, "oban:12345"}

  # Execute with specific adapter
  TaskAdapterOrchestrator.execute(task, adapters: [:oban_adapter])
  # => {:ok, task_id} or {:error, reason}

  # Get adapter information
  TaskAdapterOrchestrator.get_adapters_info()
  # => [%{name: :oban_adapter, enabled: true, priority: 10, ...}, ...]
  ```

  ## How Task Execution Works

  1. **Load enabled adapters from config** (sorted by priority, ascending)
  2. **Try each adapter in sequence** until success:
     - If success returned → Return immediately
     - If not suitable → Try next adapter
     - If error returned → Stop and propagate error
  3. **Return result** with task ID for tracking

  Similar to FrameworkLearningOrchestrator (first-success-stops) but for task execution.
  """

  require Logger
  alias Singularity.Execution.TaskAdapter

  @doc """
  Execute a task using the most appropriate adapter.

  Tries adapters in priority order until one successfully executes the task.

  ## Parameters

  - `task`: Map with `:type`, `:args`, `:opts`
  - `opts`: Optional keyword list:
    - `:adapters` - Specific adapters to try (default: all enabled)
    - `:execution_type` - Async or sync (default: async)

  ## Returns

  - `{:ok, task_id}` - Task queued/executed successfully
  - `{:error, :no_adapter_found}` - No adapter could execute task
  - `{:error, reason}` - Hard error from adapter
  """
  def execute(task, opts \\ []) when is_map(task) and is_list(opts) do
    try do
      adapters = load_adapters_for_attempt(opts)

      Logger.info("TaskAdapterOrchestrator: Executing task",
        task_type: task[:type],
        adapter_count: length(adapters)
      )

      case try_adapters(adapters, task, opts) do
        {:ok, task_id} ->
          Logger.info("Task queued successfully",
            task_type: task[:type],
            task_id: task_id
          )
          {:ok, task_id}

        {:error, :no_adapter_found} ->
          Logger.warning("No adapter could execute task",
            task_type: task[:type],
            tried_adapters: Enum.map(adapters, fn {type, _priority, _config} -> type end)
          )
          {:error, :no_adapter_found}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Task execution failed",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )
        {:error, :execution_failed}
    end
  end

  @doc """
  Get information about all configured adapters and their status.

  Returns list of adapter info maps with name, enabled status, priority, description.
  """
  def get_adapters_info do
    TaskAdapter.load_enabled_adapters()
    |> Enum.map(fn {type, priority, config} ->
      description = TaskAdapter.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific adapter type.
  """
  def get_capabilities(adapter_type) when is_atom(adapter_type) do
    case TaskAdapter.get_adapter_module(adapter_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp load_adapters_for_attempt(opts) do
    case Keyword.get(opts, :adapters) do
      nil ->
        # Use all enabled adapters
        TaskAdapter.load_enabled_adapters()

      specific_adapters when is_list(specific_adapters) ->
        # Filter to only requested adapters, maintaining priority order
        all_adapters = TaskAdapter.load_enabled_adapters()

        Enum.filter(all_adapters, fn {type, _priority, _config} ->
          type in specific_adapters
        end)
    end
  end

  defp try_adapters([], _task, _opts) do
    # All adapters tried, none matched
    {:error, :no_adapter_found}
  end

  defp try_adapters([{adapter_type, _priority, config} | rest], task, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{adapter_type} adapter", task_type: task[:type])

        # Execute adapter
        case module.execute(task, opts) do
          {:ok, task_id} ->
            Logger.info("Task execution succeeded with #{adapter_type}",
              task_type: task[:type],
              task_id: task_id
            )
            {:ok, task_id}

          {:error, :not_suitable} ->
            # This adapter can't handle this task, try next
            Logger.debug("#{adapter_type} adapter not suitable for task", task_type: task[:type])
            try_adapters(rest, task, opts)

          {:error, reason} ->
            # Hard error, stop trying
            Logger.error("#{adapter_type} adapter returned error",
              reason: inspect(reason),
              task_type: task[:type]
            )
            {:error, reason}
        end
      else
        Logger.warning("Adapter module not found for #{adapter_type}")
        try_adapters(rest, task, opts)
      end
    rescue
      e ->
        Logger.error("Adapter execution failed for #{adapter_type}",
          error: inspect(e),
          task_type: task[:type],
          stacktrace: inspect(__STACKTRACE__)
        )

        # Try next adapter on execution error
        try_adapters(rest, task, opts)
    end
  end
end
