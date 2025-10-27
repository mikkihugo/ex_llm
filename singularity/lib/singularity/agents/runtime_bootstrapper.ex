defmodule Singularity.Agents.RuntimeBootstrapper do
  @moduledoc false
  use GenServer

  require Logger

  alias Singularity.AgentSupervisor
  alias DynamicSupervisor

  @retry_interval 5_000

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, _opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      agent_id: Keyword.get(_opts, :agent_id, "task_graph-runtime"),
      agent_opts: Keyword.get(_opts, :agent_opts, [])
    }

    {:ok, state, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, %{agent_id: agent_id, agent_opts: agent_opts} = state) do
    case ensure_agent(agent_id, agent_opts) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Retrying runtime self-improving agent start",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        Process.send_after(self(), :retry_bootstrap, @retry_interval)
        {:noreply, Map.put(state, :last_error, reason)}
    end
  end

  @impl true
  def handle_info(:retry_bootstrap, %{agent_id: agent_id, agent_opts: agent_opts} = state) do
    case ensure_agent(agent_id, agent_opts) do
      :ok ->
        {:noreply, Map.delete(state, :last_error)}

      {:error, reason} ->
        Logger.warning("Runtime self-improving agent still unavailable",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        Process.send_after(self(), :retry_bootstrap, @retry_interval)
        {:noreply, Map.put(state, :last_error, reason)}
    end
  end

  defp ensure_agent(agent_id, agent_opts) do
    spec_opts = Keyword.put(agent_opts, :id, agent_id)
    child_spec = Singularity.SelfImprovingAgent.child_spec(spec_opts)

    case DynamicSupervisor.start_child(AgentSupervisor, child_spec) do
      {:ok, _pid} ->
        Logger.info("Started runtime self-improving agent", agent_id: agent_id)
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("Runtime self-improving agent already running", agent_id: agent_id)
        :ok

      {:error, reason} ->
        Logger.error("Failed to start runtime self-improving agent",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
