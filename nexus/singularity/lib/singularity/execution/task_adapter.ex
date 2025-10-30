defmodule Singularity.Execution.TaskAdapter do
  @moduledoc """
  Task Adapter Behavior - Contract for all task execution strategies.

  Defines the unified interface for task adapters (Oban jobs, pgmq messages, GenServer tasks, etc.)
  enabling config-driven orchestration of task execution patterns.

  Consolidates 4 distinct execution systems (Oban, pgmq, Task Graph, GenServer agents)
  into a unified execution adapter system with consistent configuration and queuing.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.TaskAdapter",
    "purpose": "Behavior contract for config-driven task execution orchestration",
    "type": "behavior/protocol",
    "layer": "execution",
    "status": "production"
  }
  ```

  ## Configuration Example

  ```elixir
  # singularity/config/config.exs
  config :singularity, :task_adapters,
    oban_adapter: %{
      module: Singularity.Adapters.ObanAdapter,
      enabled: true,
      priority: 10,
      description: "Background job execution via Oban"
    },
    # pgmq_adapter removed - using QuantumFlow workflows instead
    genserver_adapter: %{
      module: Singularity.Adapters.GenServerAdapter,
      enabled: true,
      priority: 20,
      description: "Synchronous task execution via GenServer agents"
    }
  ```

  ## How Task Adapters Work

  1. **Orchestrator chooses adapter** based on task type and execution requirements
  2. **Adapter queues or executes task** using its underlying mechanism
  3. **Task is executed** (async or sync, in process or distributed)
  4. **Results are reported** back to caller

  ## Usage

  ```elixir
  TaskAdapterOrchestrator.execute(task, type: :async)
  # => {:ok, task_id} or {:error, reason}
  ```
  """

  require Logger

  @doc """
  Returns the atom identifier for this adapter.

  Examples: `:oban_adapter`, `:pgmq_adapter`, `:genserver_adapter`
  """
  @callback adapter_type() :: atom()

  @doc """
  Returns human-readable description of what this adapter does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of execution capabilities this adapter provides.

  Examples: `["async", "background_jobs"]` or `["sync", "in_process"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Execute a task using this adapter.

  Returns one of:
  - `{:ok, task_id}` - Task queued/executed successfully
  - `{:error, reason}` - Execution failed

  Task should be a map with:
  - `:type` - Task type (atom)
  - `:args` - Task arguments (any)
  - `:opts` - Task options (keyword list)
  """
  @callback execute(task :: map(), opts :: Keyword.t()) ::
              {:ok, String.t()} | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled adapters from config, sorted by priority (ascending).

  Returns: `[{adapter_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_adapters do
    :singularity
    |> Application.get_env(:task_adapters, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific adapter type is enabled.
  """
  def enabled?(adapter_type) when is_atom(adapter_type) do
    adapters = load_enabled_adapters()
    Enum.any?(adapters, fn {type, _priority, _config} -> type == adapter_type end)
  end

  @doc """
  Get the module implementing a specific adapter type.
  """
  def get_adapter_module(adapter_type) when is_atom(adapter_type) do
    case Application.get_env(:singularity, :task_adapters, %{})[adapter_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :adapter_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific adapter type (lower numbers try first).

  Defaults to 100 if not specified, ensuring priority-ordered execution.
  """
  def get_priority(adapter_type) when is_atom(adapter_type) do
    case Application.get_env(:singularity, :task_adapters, %{})[adapter_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific adapter type.
  """
  def get_description(adapter_type) when is_atom(adapter_type) do
    case get_adapter_module(adapter_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown adapter"
        end

      {:error, _} ->
        "Unknown adapter"
    end
  end
end
