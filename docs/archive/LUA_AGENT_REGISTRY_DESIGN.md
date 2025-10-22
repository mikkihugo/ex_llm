# Lua Agent Registry - Design Addendum

## Overview

**Agent Registry** tracks all active agents, their assigned behaviors, and runtime performance - enabling centralized management and hot-reload behavior assignment.

---

## Database Schema

### Table: `agent_registry`

```sql
CREATE TABLE agent_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Agent Identity
  agent_id TEXT NOT NULL UNIQUE,  -- matches Singularity.Agent id
  agent_role TEXT NOT NULL,  -- code_developer, architecture_analyst, etc.
  agent_name TEXT,  -- Human-readable name

  -- Assigned Behavior
  behavior_id UUID REFERENCES agent_behaviors(id),
  behavior_assigned_at TIMESTAMP,

  -- Runtime Stats
  status TEXT DEFAULT 'active',  -- active, paused, stopped
  cycles_completed INTEGER DEFAULT 0,
  tasks_completed INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,
  avg_response_time_ms FLOAT DEFAULT 0.0,

  -- Performance Tracking
  last_task_at TIMESTAMP,
  last_success_at TIMESTAMP,
  last_failure_at TIMESTAMP,
  consecutive_failures INTEGER DEFAULT 0,

  -- Metadata
  created_by TEXT,
  notes TEXT,

  -- Timestamps
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX agent_registry_agent_id_index ON agent_registry(agent_id);
CREATE INDEX agent_registry_role_index ON agent_registry(agent_role);
CREATE INDEX agent_registry_behavior_id_index ON agent_registry(behavior_id);
CREATE INDEX agent_registry_status_index ON agent_registry(status);
```

### Table: `agent_behavior_assignments`

Track behavior changes over time:

```sql
CREATE TABLE agent_behavior_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Assignment
  agent_id TEXT NOT NULL REFERENCES agent_registry(agent_id),
  behavior_id UUID NOT NULL REFERENCES agent_behaviors(id),

  -- Assignment metadata
  assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
  assigned_by TEXT,  -- "system" or user_id
  reason TEXT,  -- "manual", "performance", "a_b_test"

  -- Outcome (when unassigned)
  unassigned_at TIMESTAMP,
  tasks_completed INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,
  outcome_notes TEXT
);

CREATE INDEX agent_behavior_assignments_agent_id_index ON agent_behavior_assignments(agent_id);
CREATE INDEX agent_behavior_assignments_behavior_id_index ON agent_behavior_assignments(behavior_id);
CREATE INDEX agent_behavior_assignments_assigned_at_index ON agent_behavior_assignments(assigned_at);
```

---

## Module Structure

### 1. AgentRegistry Schema (`agent_registry.ex`)

```elixir
defmodule Singularity.Agents.AgentRegistry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_registry" do
    field :agent_id, :string
    field :agent_role, :string
    field :agent_name, :string

    # Assigned behavior
    belongs_to :behavior, Singularity.Agents.AgentBehavior
    field :behavior_assigned_at, :utc_datetime

    # Runtime stats
    field :status, :string, default: "active"
    field :cycles_completed, :integer, default: 0
    field :tasks_completed, :integer, default: 0
    field :success_rate, :float, default: 1.0
    field :avg_response_time_ms, :float, default: 0.0

    # Performance tracking
    field :last_task_at, :utc_datetime
    field :last_success_at, :utc_datetime
    field :last_failure_at, :utc_datetime
    field :consecutive_failures, :integer, default: 0

    # Metadata
    field :created_by, :string
    field :notes, :string

    timestamps(type: :utc_datetime)

    has_many :behavior_assignments, Singularity.Agents.AgentBehaviorAssignment
  end

  def changeset(registry, attrs) do
    registry
    |> cast(attrs, [
      :agent_id, :agent_role, :agent_name,
      :behavior_id, :behavior_assigned_at,
      :status, :cycles_completed, :tasks_completed,
      :success_rate, :avg_response_time_ms,
      :created_by, :notes
    ])
    |> validate_required([:agent_id, :agent_role])
    |> validate_inclusion(:status, ["active", "paused", "stopped"])
    |> unique_constraint(:agent_id)
  end

  def update_stats_changeset(registry, attrs) do
    registry
    |> cast(attrs, [
      :cycles_completed, :tasks_completed,
      :success_rate, :avg_response_time_ms,
      :last_task_at, :last_success_at, :last_failure_at,
      :consecutive_failures
    ])
  end

  def assign_behavior_changeset(registry, behavior_id, assigned_by, reason) do
    registry
    |> change(%{
      behavior_id: behavior_id,
      behavior_assigned_at: DateTime.utc_now()
    })
  end
end
```

### 2. AgentRegistryService (`agent_registry_service.ex`)

```elixir
defmodule Singularity.Agents.AgentRegistryService do
  @moduledoc """
  Service for managing agent registry - tracking active agents and their behaviors.
  """

  alias Singularity.Repo
  alias Singularity.Agents.{AgentRegistry, AgentBehavior, AgentBehaviorAssignment}
  import Ecto.Query
  require Logger

  ## Registration

  @doc "Register a new agent in the registry"
  def register_agent(agent_id, role, opts \\ []) do
    attrs = %{
      agent_id: agent_id,
      agent_role: role,
      agent_name: Keyword.get(opts, :name),
      created_by: Keyword.get(opts, :created_by, "system")
    }

    %AgentRegistry{}
    |> AgentRegistry.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Unregister an agent (mark as stopped)"
  def unregister_agent(agent_id) do
    case get_by_agent_id(agent_id) do
      {:ok, registry} ->
        registry
        |> AgentRegistry.changeset(%{status: "stopped"})
        |> Repo.update()

      error -> error
    end
  end

  ## Behavior Assignment

  @doc "Assign behavior to agent"
  def assign_behavior(agent_id, behavior_id, assigned_by \\ "system", reason \\ "manual") do
    Repo.transaction(fn ->
      with {:ok, registry} <- get_by_agent_id(agent_id),
           {:ok, behavior} <- get_behavior(behavior_id) do

        # Update registry
        updated = registry
        |> AgentRegistry.assign_behavior_changeset(behavior_id, assigned_by, reason)
        |> Repo.update!()

        # Record assignment history
        %AgentBehaviorAssignment{}
        |> AgentBehaviorAssignment.changeset(%{
          agent_id: agent_id,
          behavior_id: behavior_id,
          assigned_by: assigned_by,
          reason: reason
        })
        |> Repo.insert!()

        Logger.info("Assigned behavior to agent",
          agent_id: agent_id,
          behavior: behavior.name,
          reason: reason
        )

        {:ok, updated}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc "Get current behavior for agent"
  def get_agent_behavior(agent_id) do
    case get_by_agent_id(agent_id) do
      {:ok, %{behavior_id: nil}} ->
        {:error, :no_behavior_assigned}

      {:ok, registry} ->
        behavior = Repo.get(AgentBehavior, registry.behavior_id)
        {:ok, behavior}

      error -> error
    end
  end

  ## Stats Tracking

  @doc "Update agent runtime statistics"
  def update_stats(agent_id, stats) do
    case get_by_agent_id(agent_id) do
      {:ok, registry} ->
        registry
        |> AgentRegistry.update_stats_changeset(stats)
        |> Repo.update()

      error -> error
    end
  end

  @doc "Record task completion"
  def record_task(agent_id, success?) do
    case get_by_agent_id(agent_id) do
      {:ok, registry} ->
        now = DateTime.utc_now()

        stats = %{
          tasks_completed: registry.tasks_completed + 1,
          last_task_at: now
        }

        stats = if success? do
          Map.merge(stats, %{
            last_success_at: now,
            consecutive_failures: 0,
            success_rate: calculate_new_success_rate(registry, true)
          })
        else
          Map.merge(stats, %{
            last_failure_at: now,
            consecutive_failures: registry.consecutive_failures + 1,
            success_rate: calculate_new_success_rate(registry, false)
          })
        end

        update_stats(agent_id, stats)

      error -> error
    end
  end

  ## Queries

  @doc "Get all active agents"
  def list_active_agents do
    from(r in AgentRegistry,
      where: r.status == "active",
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Get agents by role"
  def list_agents_by_role(role) do
    from(r in AgentRegistry,
      where: r.agent_role == ^role,
      where: r.status == "active"
    )
    |> Repo.all()
  end

  @doc "Get agents with low performance (candidates for behavior change)"
  def list_underperforming_agents(threshold \\ 0.7) do
    from(r in AgentRegistry,
      where: r.status == "active",
      where: r.tasks_completed > 10,
      where: r.success_rate < ^threshold,
      order_by: [asc: r.success_rate]
    )
    |> Repo.all()
  end

  @doc "Get agent registry by agent_id"
  def get_by_agent_id(agent_id) do
    case Repo.get_by(AgentRegistry, agent_id: agent_id) do
      nil -> {:error, :not_found}
      registry -> {:ok, registry}
    end
  end

  ## Hot-Reload Behavior Assignment

  @doc """
  Hot-reload: Assign new behavior to agent without restart.

  This triggers behavior cache reload for the agent.
  """
  def hot_reload_behavior(agent_id, behavior_id, reason \\ "hot_reload") do
    with {:ok, _} <- assign_behavior(agent_id, behavior_id, "system", reason) do
      # Clear behavior cache for this agent
      Cachex.del(:behavior_cache, "agent:#{agent_id}")

      # Notify agent (if listening)
      :telemetry.execute([:singularity, :agent, :behavior_changed], %{count: 1}, %{
        agent_id: agent_id,
        behavior_id: behavior_id
      })

      {:ok, :reloaded}
    end
  end

  ## Private

  defp get_behavior(behavior_id) do
    case Repo.get(AgentBehavior, behavior_id) do
      nil -> {:error, :behavior_not_found}
      behavior -> {:ok, behavior}
    end
  end

  defp calculate_new_success_rate(registry, success?) do
    total = registry.tasks_completed + 1
    successes = if success?, do: registry.success_rate * registry.tasks_completed + 1,
                            else: registry.success_rate * registry.tasks_completed
    successes / total
  end
end
```

---

## Usage Examples

### Register Agent on Startup

```elixir
# In Singularity.Agent.init/1
def init(opts) do
  id = Keyword.fetch!(opts, :id)
  role = Keyword.get(opts, :role, :generalist)

  # Register in registry
  AgentRegistryService.register_agent(id, role, name: "Agent #{id}")

  # Rest of init...
  {:ok, state}
end
```

### Assign Behavior After Creation

```elixir
# Create agent
{:ok, agent_pid} = Singularity.Agent.start_link(id: "agent-001", role: :code_developer)

# Find suitable behavior
{:ok, behavior} = Repo.get_by(AgentBehavior,
  role_type: "code_developer",
  name: "friendly_code_reviewer"
)

# Assign behavior
AgentRegistryService.assign_behavior("agent-001", behavior.id)
```

### Hot-Reload Behavior

```elixir
# Agent is running with behavior A
# Create improved behavior B

{:ok, behavior_b} = %AgentBehavior{}
|> AgentBehavior.changeset(%{
  name: "code_developer_improved_v2",
  role_type: "code_developer",
  lua_script: improved_script,
  parent_behavior_id: behavior_a.id
})
|> Repo.insert()

# Hot-reload without restart!
AgentRegistryService.hot_reload_behavior("agent-001", behavior_b.id, "performance_improvement")

# Agent immediately uses new behavior
```

### Track Performance

```elixir
# After task completion
AgentRegistryService.record_task("agent-001", success? = true)

# Check stats
{:ok, registry} = AgentRegistryService.get_by_agent_id("agent-001")
IO.inspect(registry.success_rate)  # => 0.94
IO.inspect(registry.tasks_completed)  # => 127
```

### Find Underperforming Agents

```elixir
# Find agents with <70% success rate
underperforming = AgentRegistryService.list_underperforming_agents(0.7)

# Auto-assign better behavior
Enum.each(underperforming, fn registry ->
  # Find best-performing behavior for this role
  {:ok, best_behavior} = find_best_behavior_for_role(registry.agent_role)

  # Hot-reload
  AgentRegistryService.hot_reload_behavior(
    registry.agent_id,
    best_behavior.id,
    "automatic_improvement"
  )
end)
```

---

## Benefits

### 1. Centralized Agent Management
- View all active agents in one place
- Track performance across agents
- Identify patterns (which behaviors work best?)

### 2. Hot-Reload Behavior Changes
- Change agent behavior without restart
- A/B test behaviors on live agents
- Automatic performance-based behavior switching

### 3. Performance Monitoring
- Success rate per agent
- Response time tracking
- Consecutive failure detection

### 4. Behavior Evolution Tracking
- Which behaviors are assigned to which agents?
- Historical assignment data
- Parent-child behavior lineage

### 5. Automatic Optimization
- Detect underperforming agents
- Auto-assign better behaviors
- Performance-driven evolution

---

## Integration with Agent Module

Add hooks to existing `Singularity.Agent`:

```elixir
defmodule Singularity.Agent do
  # ... existing code ...

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    role = Keyword.get(opts, :role, :generalist)

    # Register in registry
    case AgentRegistryService.register_agent(id, role) do
      {:ok, _registry} -> :ok
      {:error, reason} ->
        Logger.warning("Failed to register agent", agent_id: id, reason: inspect(reason))
    end

    # ... rest of init ...
  end

  @impl true
  def handle_info(:tick, state) do
    # Update cycle count in registry
    AgentRegistryService.update_stats(state.id, %{
      cycles_completed: state.cycles + 1
    })

    # ... rest of tick handler ...
  end

  @impl true
  def handle_info({:reload_complete, version}, state) do
    # Record successful task
    AgentRegistryService.record_task(state.id, true)

    # ... rest of handler ...
  end

  @impl true
  def handle_info({:reload_failed, reason}, state) do
    # Record failed task
    AgentRegistryService.record_task(state.id, false)

    # ... rest of handler ...
  end
end
```

---

## Summary

**Agent Registry** provides:

✅ **Centralized tracking** of all active agents
✅ **Performance monitoring** with automatic metrics
✅ **Hot-reload behavior assignment** without restart
✅ **Historical tracking** of behavior changes
✅ **Automatic optimization** based on performance

Combined with **Lua Agent Behaviors**, this enables:

🔥 **Full agent lifecycle management**
🔥 **Performance-driven behavior evolution**
🔥 **A/B testing at scale**
🔥 **Zero-downtime personality changes**

**Ready to implement?** This adds ~2 hours to the original 6-hour estimate for a total of **8 hours** for the complete Agent Behavior + Registry system.
