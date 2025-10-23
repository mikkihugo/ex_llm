defmodule Singularity.Agents.AgentSpawner do
  @moduledoc """
  AgentSpawner - Spawns agents from Lua configurations.

  Converts Lua agent configs (from HTDAGLuaExecutor) into running Agent processes.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.AgentSpawner",
    "purpose": "Spawn agents from Lua strategy configurations",
    "layer": "Agents & Execution",
    "dependencies": ["Singularity.Agent"],
    "used_by": ["HTDAGExecutor"]
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph LR
    HTDAGExecutor[HTDAG Executor]
    Lua[Lua Script]
    Spawner[Agent Spawner]
    Agent[Agent Process]

    HTDAGExecutor -->|agent config| Spawner
    Lua -->|defines config| HTDAGExecutor
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

  @doc """
  Spawn an agent from Lua configuration.

  Actually starts a new Agent GenServer process via DynamicSupervisor.
  Returns the spawned agent's PID (not the spawner's PID).

  ## Parameters

  - `agent_config` - Map with keys:
    - `"role"` - Agent role (string)
    - `"behavior_id"` - Optional behavior ID (string)
    - `"config"` - Agent configuration (map)

  ## Returns

  - `{:ok, agent}` - Spawned agent metadata with correct PID
  - `{:error, reason}` - Spawn failed

  ## Examples

      iex> config = %{"role" => "architect", "config" => %{}}
      iex> AgentSpawner.spawn(config)
      {:ok, %{id: "agent-xyz", pid: #PID<0.250.0>, role: "architect"}}
  """
  def spawn(agent_config) do
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
             Singularity.Agent,
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
