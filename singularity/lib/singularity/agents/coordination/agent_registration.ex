defmodule Singularity.Agents.Coordination.AgentRegistration do
  @moduledoc """
  Agent Registration Helper - Simplifies agent capability registration.

  Provides a simple API for agents to register their capabilities with the
  CapabilityRegistry during startup.

  ## Usage

  In your agent's start_link callback:

      defmodule MyAgent do
        def start_link(opts) do
          # ... existing startup code ...

          # Register capabilities
          AgentRegistration.register_agent(:my_agent, %{
            role: :my_role,
            domains: [:domain1, :domain2],
            input_types: [:code, :design],
            output_types: [:code, :documentation],
            complexity_level: :medium,
            estimated_cost: 500,
            success_rate: 0.85
          })

          {:ok, pid}
        end
      end

  ## Common Patterns

  ```elixir
  # Self-Improving Agent
  AgentRegistration.register_agent(:self_improving_agent, %{
    role: :self_improve,
    domains: [:code_quality, :refactoring, :testing],
    input_types: [:code, :codebase, :metrics],
    output_types: [:code, :documentation],
    complexity_level: :complex,
    estimated_cost: 1000,
    success_rate: 0.88
  })

  # Quality Enforcer Agent
  AgentRegistration.register_agent(:quality_enforcer, %{
    role: :quality_enforcer,
    domains: [:code_quality, :documentation],
    input_types: [:code, :codebase],
    output_types: [:analysis, :documentation],
    complexity_level: :medium,
    estimated_cost: 300,
    success_rate: 0.92
  })

  # Cost-Optimized Agent
  AgentRegistration.register_agent(:cost_optimized_agent, %{
    role: :cost_optimize,
    domains: [:code_quality, :performance],
    input_types: [:code, :metrics],
    output_types: [:code, :decision],
    complexity_level: :medium,
    estimated_cost: 200,
    success_rate: 0.90
  })
  ```
  """

  require Logger
  alias Singularity.Agents.Coordination.CapabilityRegistry

  @doc """
  Register an agent's capabilities with the coordination system.

  This should be called during agent startup (typically in start_link callback).

  ## Parameters

  - `agent_name` - Atom identifier for the agent (e.g., `:quality_enforcer`)
  - `attrs` - Map of capability attributes:
    - `:role` - Agent role atom (required)
    - `:domains` - List of domain atoms (required)
    - `:input_types` - List of input type atoms (required)
    - `:output_types` - List of output type atoms (required)
    - `:complexity_level` - Atom: :simple, :medium, :complex (required)
    - `:estimated_cost` - Integer tokens estimate (required)
    - `:success_rate` - Float 0.0-1.0 (required)
    - `:availability` - Atom: :available, :busy, :overloaded, :offline (optional, defaults to :available)
    - `:preferred_model` - Atom: :simple, :medium, :complex (optional)
    - `:tags` - List of atoms describing agent traits (optional)
    - `:metadata` - Map of additional metadata (optional)

  ## Returns

  - `:ok` - Registration successful
  - `{:error, reason}` - Registration failed

  ## Examples

      # Register self-improving agent
      :ok = AgentRegistration.register_agent(:self_improving_agent, %{
        role: :self_improve,
        domains: [:code_quality, :refactoring],
        input_types: [:code, :codebase],
        output_types: [:code, :documentation],
        complexity_level: :complex,
        estimated_cost: 1000,
        success_rate: 0.88
      })

      # Register with optional attributes
      :ok = AgentRegistration.register_agent(:quality_enforcer, %{
        role: :quality_enforcer,
        domains: [:code_quality, :documentation],
        input_types: [:code],
        output_types: [:analysis],
        complexity_level: :medium,
        estimated_cost: 300,
        success_rate: 0.92,
        tags: [:async_safe, :idempotent],
        metadata: %{"github" => "quality-enforcer"}
      })
  """
  @spec register_agent(atom(), map()) :: :ok | {:error, term()}
  def register_agent(agent_name, attrs) when is_atom(agent_name) and is_map(attrs) do
    try do
      Logger.info("Registering agent capability",
        agent: agent_name,
        role: attrs[:role],
        domains: attrs[:domains]
      )

      case CapabilityRegistry.register(agent_name, attrs) do
        :ok ->
          Logger.info("Agent capability registered successfully",
            agent: agent_name
          )
          :ok

        {:error, reason} ->
          Logger.error("Failed to register agent capability",
            agent: agent_name,
            reason: inspect(reason)
          )
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception during agent capability registration",
          agent: agent_name,
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )
        {:error, :registration_failed}
    end
  end

  @doc """
  Update an agent's availability status (e.g., when busy/idle).

  Called when agent capacity changes.

  ## Examples

      # Agent starting work
      AgentRegistration.update_availability(:my_agent, :busy)

      # Agent finished work
      AgentRegistration.update_availability(:my_agent, :available)
  """
  @spec update_availability(atom(), atom()) :: :ok | {:error, term()}
  def update_availability(agent_name, availability) when is_atom(agent_name) and is_atom(availability) do
    CapabilityRegistry.update_availability(agent_name, availability)
  end

  @doc """
  Update agent success rate based on execution results.

  Called by ExecutionCoordinator after task completion to update success rate
  for learning and routing optimization.

  ## Examples

      # After successful task execution
      AgentRegistration.update_success_rate(:my_agent, 0.92)

      # Update after failure
      AgentRegistration.update_success_rate(:my_agent, 0.87)
  """
  @spec update_success_rate(atom(), float()) :: :ok | {:error, term()}
  def update_success_rate(agent_name, success_rate) when is_atom(agent_name) and is_float(success_rate) do
    CapabilityRegistry.update_success_rate(agent_name, success_rate)
  end
end
