defmodule Singularity.Control.Listener do
  @moduledoc """
  Subscribes to the cluster control `:pg` group and routes improvement messages
  to local agents. This keeps the system fully autonomous by relying on BEAM
  messaging instead of external HTTP transports.
  """
  use GenServer

  require Logger

  alias Singularity.Agents.Agent

  @group :singularity_control

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    ensure_pg()
    :ok = :pg.join(@group, self())
    Logger.debug("Joined control group", node: node(), group: @group)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:improve, agent_id, payload}, state) do
    case Agent.improve(agent_id, payload) do
      :ok -> :ok
      {:error, :not_found} -> :ok
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp ensure_pg do
    case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, {:already_registered_name, _name}} -> :ok
      {:error, reason} -> raise "failed to start :pg: #{inspect(reason)}"
    end
  end
end
