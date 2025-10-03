defmodule SeedAgent do
  @moduledoc """
  Public API for interacting with self-improving agents.
  """

  alias SeedAgent.AgentSupervisor

  @doc """
  Start a new agent process with the provided context map.
  """
  @spec start_agent(map()) :: DynamicSupervisor.on_start_child()
  def start_agent(opts) when is_map(opts) do
    DynamicSupervisor.start_child(AgentSupervisor, {SeedAgent.Agent, opts})
  end

  @doc """
  Broadcast a message to all agents.
  """
  @spec broadcast(term()) :: :ok
  def broadcast(message) do
    Enum.each(AgentSupervisor.children(), fn pid -> send(pid, message) end)
  end
end
