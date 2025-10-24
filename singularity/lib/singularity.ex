defmodule Singularity do
  @moduledoc """
  Public API for interacting with self-improving agents.
  """

  alias Singularity.Agents.Agent
  alias Singularity.AgentSupervisor

  # Backwards compatibility alias
  alias Singularity.Agents.Agent, as: SingularityAgent

  @doc """
  Start a new agent process with the provided context map.
  """
  @spec start_agent(map()) :: DynamicSupervisor.on_start_child()
  def start_agent(opts) when is_map(opts) do
    DynamicSupervisor.start_child(AgentSupervisor, {Agent, opts})
  end

  @doc """
  Broadcast a message to all agents.
  """
  @spec broadcast(term()) :: :ok
  def broadcast(message) do
    Enum.each(AgentSupervisor.children(), fn pid -> send(pid, message) end)
  end

  @doc """
  Submit an improvement payload for a specific agent instance.
  """
  @spec improve_agent(String.t(), map()) :: :ok | {:error, :not_found}
  def improve_agent(agent_id, payload) when is_map(payload) do
    Agent.improve(agent_id, payload)
  end

  @doc """
  Merge metrics into an agent's observation state.
  """
  @spec update_agent_metrics(String.t(), map()) :: :ok | {:error, :not_found}
  def update_agent_metrics(agent_id, metrics) when is_map(metrics) do
    Agent.update_metrics(agent_id, metrics)
  end

  @doc """
  Record whether the latest evaluation succeeded or failed.
  """
  @spec record_outcome(String.t(), :success | :failure) :: :ok | {:error, :not_found}
  def record_outcome(agent_id, outcome) do
    Agent.record_outcome(agent_id, outcome)
  end

  @doc """
  Force an agent to attempt self-improvement on the next cycle with an
  annotated reason.
  """
  @spec force_improvement(String.t(), String.t()) :: :ok | {:error, :not_found}
  def force_improvement(agent_id, reason \\ "manual") do
    Agent.force_improvement(agent_id, reason)
  end
end
