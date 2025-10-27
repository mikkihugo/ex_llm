defmodule Singularity.Agents.Coordination.CapabilityRegistry do
  @moduledoc """
  Capability Registry - Track what all agents can do.

  GenServer that maintains a registry of agent capabilities. Agents register
  their capabilities at startup, and the registry helps the Coordination Router
  understand which agents to use for each task.

  ## Agent Registration

  ```elixir
  CapabilityRegistry.register(:refactoring_agent, %{
    role: :refactoring,
    domains: [:code_quality, :testing],
    input_types: [:code, :codebase],
    output_types: [:code, :documentation],
    complexity_level: :medium,
    estimated_cost: 500,
    success_rate: 0.92
  })
  ```

  ## Queries

  ```elixir
  # Find agents for a specific domain
  CapabilityRegistry.agents_for_domain(:code_quality)

  # Find best agent for a task
  CapabilityRegistry.best_agent_for_task(%{
    domain: :code_quality,
    input_type: :code,
    output_type: :analysis,
    complexity: :medium
  })

  # Get all registered agents
  CapabilityRegistry.all_agents()
  ```
  """

  use GenServer
  require Logger
  alias Singularity.Agents.Coordination.AgentCapability

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[CapabilityRegistry] Starting Agent Capability Registry")
    {:ok, %{capabilities: %{}, index_by_domain: %{}, index_by_role: %{}}}
  end

  @doc """
  Register an agent's capabilities.

  Takes agent name and attribute map, creates AgentCapability struct,
  and indexes it for fast lookup by domain and role.
  """
  def register(agent_name, attrs) when is_atom(agent_name) and is_map(attrs) do
    GenServer.call(__MODULE__, {:register, agent_name, attrs})
  end

  @doc """
  Update agent's availability status.
  """
  def update_availability(agent_name, availability) when is_atom(agent_name) do
    GenServer.call(__MODULE__, {:update_availability, agent_name, availability})
  end

  @doc """
  Update agent's success rate (from feedback).
  """
  def update_success_rate(agent_name, success_rate) when is_atom(agent_name) do
    GenServer.call(__MODULE__, {:update_success_rate, agent_name, success_rate})
  end

  @doc """
  Get capability for specific agent.
  """
  def get_capability(agent_name) when is_atom(agent_name) do
    GenServer.call(__MODULE__, {:get, agent_name})
  end

  @doc """
  Get all agents that can handle a specific domain.
  """
  def agents_for_domain(domain) when is_atom(domain) do
    GenServer.call(__MODULE__, {:agents_for_domain, domain})
  end

  @doc """
  Get all agents with a specific role.
  """
  def agents_with_role(role) when is_atom(role) do
    GenServer.call(__MODULE__, {:agents_with_role, role})
  end

  @doc """
  Get all registered agents.
  """
  def all_agents do
    GenServer.call(__MODULE__, :all_agents)
  end

  @doc """
  Get best agent for a specific task.

  Returns {agent_name, fit_score} tuple. Selects agent with highest
  fit_score based on domain, input/output types, success rate, and availability.
  """
  def best_agent_for_task(task) when is_map(task) do
    GenServer.call(__MODULE__, {:best_agent_for_task, task})
  end

  @doc """
  Get top N agents for a task (ranked by fit).

  Returns list of {agent_name, fit_score} tuples sorted by fit descending.
  """
  def top_agents_for_task(task, count) when is_map(task) and is_integer(count) do
    GenServer.call(__MODULE__, {:top_agents_for_task, task, count})
  end

  @doc """
  Check if a task domain has available agents.
  """
  def domain_has_agents?(domain) when is_atom(domain) do
    case agents_for_domain(domain) do
      [] -> false
      _ -> true
    end
  end

  # Callbacks

  @impl true
  def handle_call({:register, agent_name, attrs}, _from, state) do
    cap = AgentCapability.new(agent_name, attrs)

    # Add to main registry
    capabilities = Map.put(state.capabilities, agent_name, cap)

    # Index by domain
    index_by_domain =
      Enum.reduce(cap.domains, state.index_by_domain, fn domain, idx ->
        agents = Map.get(idx, domain, [])
        Map.put(idx, domain, [agent_name | agents])
      end)

    # Index by role
    index_by_role = Map.put(state.index_by_role, cap.role, agent_name)

    new_state = %{
      state
      | capabilities: capabilities,
        index_by_domain: index_by_domain,
        index_by_role: index_by_role
    }

    Logger.info("[CapabilityRegistry] Registered agent: #{agent_name}",
      domains: cap.domains,
      role: cap.role
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_availability, agent_name, availability}, _from, state) do
    case Map.get(state.capabilities, agent_name) do
      nil ->
        {:reply, {:error, :agent_not_found}, state}

      cap ->
        updated_cap = %{cap | availability: availability}
        new_capabilities = Map.put(state.capabilities, agent_name, updated_cap)
        {:reply, :ok, %{state | capabilities: new_capabilities}}
    end
  end

  @impl true
  def handle_call({:update_success_rate, agent_name, rate}, _from, state) when is_float(rate) do
    case Map.get(state.capabilities, agent_name) do
      nil ->
        {:reply, {:error, :agent_not_found}, state}

      cap ->
        updated_cap = %{cap | success_rate: min(1.0, max(0.0, rate))}
        new_capabilities = Map.put(state.capabilities, agent_name, updated_cap)
        {:reply, :ok, %{state | capabilities: new_capabilities}}
    end
  end

  @impl true
  def handle_call({:get, agent_name}, _from, state) do
    case Map.get(state.capabilities, agent_name) do
      nil -> {:reply, {:error, :not_found}, state}
      cap -> {:reply, {:ok, cap}, state}
    end
  end

  @impl true
  def handle_call({:agents_for_domain, domain}, _from, state) do
    agents = Map.get(state.index_by_domain, domain, [])
    caps = Enum.map(agents, &Map.get(state.capabilities, &1))
    {:reply, caps, state}
  end

  @impl true
  def handle_call({:agents_with_role, role}, _from, state) do
    agents =
      state.capabilities
      |> Enum.filter(fn {_name, cap} -> cap.role == role end)
      |> Enum.map(fn {_name, cap} -> cap end)

    {:reply, agents, state}
  end

  @impl true
  def handle_call(:all_agents, _from, state) do
    agents = Map.values(state.capabilities)
    {:reply, agents, state}
  end

  @impl true
  def handle_call({:best_agent_for_task, task}, _from, state) do
    {best_agent, _fit} =
      state.capabilities
      |> Enum.map(fn {name, cap} -> {name, AgentCapability.fit_score(cap, task)} end)
      |> Enum.max_by(fn {_name, score} -> score end, fn -> {nil, 0.0} end)

    {:reply, best_agent, state}
  end

  @impl true
  def handle_call({:top_agents_for_task, task, count}, _from, state) do
    ranked =
      state.capabilities
      |> Enum.map(fn {name, cap} -> {name, AgentCapability.fit_score(cap, task)} end)
      |> Enum.sort_by(fn {_name, score} -> score end, :desc)
      |> Enum.take(count)

    {:reply, ranked, state}
  end
end
