defmodule Singularity.HotReload.DocumentationHotReloader do
  @moduledoc """
  Documentation Hot Reloader - Enables live documentation updates without system restart.

  ## How System Improvement Works with Hot Reload

  ### 1. **Continuous Learning Loop**
  ```
  Agent observes → Generates improvement → Hot reloads → Observes results → Learns
  ```

  ### 2. **Multi-Agent Coordination**
  - **SelfImprovingAgent**: Generates code improvements
  - **DocumentationPipeline**: Generates documentation improvements  
  - **QualityEnforcer**: Generates quality fixes
  - **All agents**: Can hot reload their own improvements

  ### 3. **Live System Evolution**
  - Agents can modify their own behavior
  - Documentation updates apply immediately
  - Quality improvements deploy instantly
  - No downtime for system improvements

  ## Hot Reload Pipeline

  1. **Agent generates improvement** (code, docs, quality fixes)
  2. **Validation** (syntax, tests, quality gates)
  3. **Staging** (isolated testing environment)
  4. **Hot reload** (live deployment without restart)
  5. **Monitoring** (observe results, learn from feedback)
  6. **Rollback** (if improvement fails)

  ## Integration Points

  - **Documentation System**: Live doc updates
  - **Quality System**: Live quality improvements
  - **Agent System**: Self-modifying agents
  - **Code Generation**: Live code improvements
  """

  use GenServer
  require Logger
  alias Singularity.HotReload.{ModuleReloader, SafeCodeChangeDispatcher}
  alias Singularity.Agents.{DocumentationPipeline, CodeQualityAgent}

  @type improvement_type :: :documentation | :quality | :code | :agent_behavior
  @type hot_reload_payload :: %{
          type: improvement_type(),
          content: String.t(),
          target_file: String.t(),
          agent_id: String.t(),
          metadata: map()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Hot reload a documentation improvement.
  """
  @spec hot_reload_documentation(String.t(), String.t(), String.t(), map()) ::
          :ok | {:error, term()}
  def hot_reload_documentation(file_path, improved_content, agent_id, metadata \\ %{}) do
    payload = %{
      type: :documentation,
      content: improved_content,
      target_file: file_path,
      agent_id: agent_id,
      metadata:
        Map.merge(metadata, %{
          improvement_type: "documentation_upgrade",
          timestamp: DateTime.utc_now(),
          quality_version: "2.3.0"
        })
    }

    GenServer.call(__MODULE__, {:hot_reload, payload})
  end

  @doc """
  Hot reload a quality improvement.
  """
  @spec hot_reload_quality(String.t(), String.t(), String.t(), map()) ::
          :ok | {:error, term()}
  def hot_reload_quality(file_path, improved_content, agent_id, metadata \\ %{}) do
    payload = %{
      type: :quality,
      content: improved_content,
      target_file: file_path,
      agent_id: agent_id,
      metadata:
        Map.merge(metadata, %{
          improvement_type: "quality_fix",
          timestamp: DateTime.utc_now(),
          quality_version: "2.3.0"
        })
    }

    GenServer.call(__MODULE__, {:hot_reload, payload})
  end

  @doc """
  Hot reload agent behavior improvement.
  """
  @spec hot_reload_agent_behavior(String.t(), String.t(), String.t(), map()) ::
          :ok | {:error, term()}
  def hot_reload_agent_behavior(agent_module, improved_code, agent_id, metadata \\ %{}) do
    payload = %{
      type: :agent_behavior,
      content: improved_code,
      target_file: agent_module,
      agent_id: agent_id,
      metadata:
        Map.merge(metadata, %{
          improvement_type: "agent_evolution",
          timestamp: DateTime.utc_now(),
          self_improvement: true
        })
    }

    GenServer.call(__MODULE__, {:hot_reload, payload})
  end

  @doc """
  Enable automatic hot reload for documentation system.
  """
  @spec enable_auto_hot_reload() :: :ok
  def enable_auto_hot_reload do
    GenServer.call(__MODULE__, :enable_auto_hot_reload)
  end

  @doc """
  Get hot reload statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    state = %{
      auto_hot_reload: false,
      stats: %{
        total_reloads: 0,
        successful_reloads: 0,
        failed_reloads: 0,
        documentation_reloads: 0,
        quality_reloads: 0,
        agent_behavior_reloads: 0,
        last_reload: nil
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:hot_reload, payload}, _from, state) do
    case process_hot_reload(payload) do
      :ok ->
        new_stats = update_stats(state.stats, payload.type, :success)
        new_state = %{state | stats: new_stats}
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_stats = update_stats(state.stats, payload.type, :failure)
        new_state = %{state | stats: new_stats}
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:enable_auto_hot_reload, _from, state) do
    new_state = %{state | auto_hot_reload: true}
    Logger.info("Auto hot reload enabled for documentation system")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  ## Private Functions

  defp process_hot_reload(payload) do
    Logger.info("Hot reloading #{payload.type} improvement",
      file: payload.target_file,
      agent: payload.agent_id
    )

    case payload.type do
      :documentation -> hot_reload_documentation_file(payload)
      :quality -> hot_reload_quality_file(payload)
      :agent_behavior -> hot_reload_agent_file(payload)
      :code -> hot_reload_code_file(payload)
    end
  end

  defp hot_reload_documentation_file(payload) do
    # Write improved documentation to file
    case File.write(payload.target_file, payload.content) do
      :ok ->
        # Trigger documentation validation
        case validate_documentation_content(payload.content) do
          :ok ->
            Logger.info("Documentation hot reload successful", file: payload.target_file)
            :ok

          {:error, reason} ->
            Logger.error("Documentation validation failed after hot reload",
              file: payload.target_file,
              reason: reason
            )

            {:error, :validation_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to write documentation file",
          file: payload.target_file,
          reason: reason
        )

        {:error, :write_failed}
    end
  end

  # Validate documentation content has required elements
  defp validate_documentation_content(content) when is_binary(content) do
    # Check if content has at least @moduledoc or documentation markers
    cond do
      String.contains?(content, "@moduledoc") -> :ok
      String.contains?(content, "///") -> :ok
      String.contains?(content, "//!") -> :ok
      true -> {:error, :missing_documentation}
    end
  end

  defp hot_reload_quality_file(payload) do
    # Write improved quality code to file
    case File.write(payload.target_file, payload.content) do
      :ok ->
        # Trigger quality validation
        case CodeQualityAgent.validate_file(payload.target_file) do
          {:ok, _validation} ->
            Logger.info("Quality hot reload successful", file: payload.target_file)
            :ok

          {:error, reason} ->
            Logger.error("Quality validation failed after hot reload",
              file: payload.target_file,
              reason: reason
            )

            {:error, :validation_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to write quality file", file: payload.target_file, reason: reason)
        {:error, :write_failed}
    end
  end

  defp hot_reload_agent_file(payload) do
    # Use the existing hot reload system for agent behavior changes
    hot_reload_payload = %{
      code: payload.content,
      metadata: payload.metadata
    }

    case ModuleReloader.enqueue(payload.agent_id, hot_reload_payload) do
      :ok ->
        Logger.info("Agent behavior hot reload queued", agent: payload.agent_id)
        :ok

      {:error, reason} ->
        Logger.error("Failed to queue agent behavior hot reload",
          agent: payload.agent_id,
          reason: reason
        )

        {:error, :queue_failed}
    end
  end

  defp hot_reload_code_file(payload) do
    # Use the improvement gateway for general code improvements
    case SafeCodeChangeDispatcher.dispatch(payload.content,
           agent_id: payload.agent_id,
           metadata: payload.metadata
         ) do
      :ok ->
        Logger.info("Code hot reload dispatched", file: payload.target_file)
        :ok

      {:error, reason} ->
        Logger.error("Failed to dispatch code hot reload",
          file: payload.target_file,
          reason: reason
        )

        {:error, :dispatch_failed}
    end
  end

  defp update_stats(stats, type, result) do
    key = if result == :success, do: :successful_reloads, else: :failed_reloads

    stats
    |> Map.update!(:total_reloads, &(&1 + 1))
    |> Map.update!(key, &(&1 + 1))
    |> Map.update!(type_reloads_key(type), &(&1 + 1))
    |> Map.put(:last_reload, DateTime.utc_now())
  end

  defp type_reloads_key(:documentation), do: :documentation_reloads
  defp type_reloads_key(:quality), do: :quality_reloads
  defp type_reloads_key(:agent_behavior), do: :agent_behavior_reloads
  defp type_reloads_key(_), do: :total_reloads
end
