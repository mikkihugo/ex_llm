defmodule Singularity.Agents.AgentSpawner do
  @moduledoc """
  AgentSpawner - Spawns agents from Lua configurations.

  Converts Lua agent configs (from LuaStrategyExecutor) into running Agent processes.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.AgentSpawner",
    "purpose": "Spawn agents from Lua strategy configurations",
    "layer": "Agents & Execution",
    "dependencies": ["Singularity.Agents.Agent"],
    "used_by": ["TaskGraphExecutor"]
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph LR
    TaskGraphExecutor[TaskGraph Executor]
    Lua[Lua Script]
    Spawner[Agent Spawner]
    Agent[Agent Process]

    TaskGraphExecutor -->|agent config| Spawner
    Lua -->|defines config| TaskGraphExecutor
    Spawner -->|spawn| Agent
  ```

  ## Usage

      # Spawn agent from Lua config
      agent_config = %{
        "role" => "code_developer",
        "behavior_id" => "code-gen-v1",
        "config" => %{
          "tools" => ["read_file", "write_file"],
          "confidence_threshold" => 0.85
        }
      }

      {:ok, agent} = AgentSpawner.spawn(agent_config)
      # => %{id: "agent-abc123", pid: #PID<0.123.0>, role: "code_developer"}
  """

  require Logger

  alias Singularity.Agents.AgentConfigurationSchemaGenerator

  @doc """
  Spawn an agent from Lua configuration.

  Actually starts a new Agent GenServer process via DynamicSupervisor.
  Validates agent configuration against JSON Schema before spawning.

  ## Parameters

  - `agent_config` - Map with keys:
    - `"role"` - Agent role (string, required)
    - `"behavior_id"` - Optional behavior ID (string)
    - `"config"` - Agent configuration (map, optional)

  ## Returns

  - `{:ok, agent}` - Spawned agent metadata with correct PID
  - `{:error, {:invalid_config, errors}}` - Config validation failed
  - `{:error, {:spawn_failed, reason}}` - Agent spawn failed

  ## Validation

  Agent config is validated against JSON Schema before spawning. Invalid configs
  are rejected with detailed error messages.

  ## Examples

      iex> config = %{"role" => "architect", "config" => %{}}
      iex> AgentSpawner.spawn(config)
      {:ok, %{id: "agent-xyz", pid: #PID<0.250.0>, role: "architect"}}

      iex> invalid = %{"behavior_id" => "test"}  # Missing required "role"
      iex> AgentSpawner.spawn(invalid)
      {:error, {:invalid_config, ["Missing required field: role"]}}
  """
  def spawn(agent_config) do
    # Validate config against schema
    case AgentConfigurationSchemaGenerator.validate_agent_config(agent_config) do
      :ok ->
        spawn_validated_agent(agent_config)

      {:error, :invalid_config, errors} ->
        Logger.warning("Agent config validation failed",
          config: agent_config,
          errors: errors
        )

        {:error, {:invalid_config, errors}}
    end
  end

  defp spawn_validated_agent(agent_config) do
    role = agent_config["role"] || agent_config[:role] || "code_developer"
    behavior_id = agent_config["behavior_id"] || agent_config[:behavior_id]
    config = agent_config["config"] || agent_config[:config] || %{}

    # Generate unique agent ID
    agent_id = generate_agent_id()

    Logger.debug("Spawning agent",
      agent_id: agent_id,
      role: role,
      behavior_id: behavior_id
    )

    # Start new Agent GenServer via DynamicSupervisor
    case DynamicSupervisor.start_child(
           Singularity.AgentSupervisor,
           {
             Singularity.Agents.Agent,
             [
               id: agent_id,
               role: role,
               behavior_id: behavior_id,
               config: config
             ]
           }
         ) do
      {:ok, agent_pid} ->
        Logger.info("Agent spawned successfully",
          agent_id: agent_id,
          pid: inspect(agent_pid),
          role: role
        )

        {:ok,
         %{
           id: agent_id,
           pid: agent_pid,
           role: role,
           behavior_id: behavior_id,
           config: config,
           spawned_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.error("Failed to spawn agent",
          agent_id: agent_id,
          role: role,
          reason: inspect(reason)
        )

        {:error, {:spawn_failed, reason}}
    end
  end

  @doc """
  Generate unique agent ID.
  """
  def generate_agent_id do
    "agent-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end
