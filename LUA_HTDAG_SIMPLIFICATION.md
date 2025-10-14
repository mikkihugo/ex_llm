## HTDAG Simplification with Lua

You're absolutely right! With Lua strategies, we can **remove tons of hand-written code** because:

### Automatic Task Ordering (Already Works!)

**HTDAGCore.select_next_task()** already handles ordering automatically:

```elixir
# In HTDAGCore (existing code)
def select_next_task(dag) do
  # Finds task where:
  # 1. Status is :pending
  # 2. ALL dependencies are :completed
  # 3. No blocks

  # Returns tasks in dependency order automatically!
end
```

**This means:**
- No manual ordering needed
- Dependencies tracked in DAG
- Lua just adds subtasks with dependencies
- HTDAGCore figures out execution order

### What Gets REMOVED from HTDAGExecutor

#### ❌ REMOVE: Hardcoded Model Selection (lines 285-297)

```elixir
# DELETE THIS:
defp select_model_for_task(task) do
  cond do
    task.estimated_complexity >= 8.0 -> "claude-sonnet-4.5"
    task.estimated_complexity >= 5.0 -> "gemini-2.5-pro"
    true -> "gemini-1.5-flash"
  end
end
```

**Why:** Lua agent spawning script decides model per task!

#### ❌ REMOVE: Hardcoded Prompt Building (lines 299-334)

```elixir
# DELETE THIS:
defp build_task_prompt(task) do
  """
  Complete the following task:
  Task: #{task.description}
  ...
  """
end

defp build_task_prompt_with_rag(task, opts) do
  # ... hardcoded RAG prompt
end
```

**Why:** Lua agent config defines prompts/tools per task!

#### ❌ REMOVE: Hardcoded Operation Params (lines 261-283)

```elixir
# DELETE THIS:
defp build_operation_params(task, opts) do
  %{
    model_id: select_model_for_task(task),  # Hardcoded!
    prompt_template: build_task_prompt(task),  # Hardcoded!
    temperature: 0.7,  # Hardcoded!
    # ...
  }
end
```

**Why:** Lua agent spawning returns complete config!

### Simplified HTDAGExecutor

**New flow:**

```elixir
defp execute_task(task, state, opts) do
  # 1. Get Lua strategy for this task
  {:ok, strategy} = HTDAGStrategyLoader.get_strategy_for_task(task.description)

  # 2. Spawn agents via Lua (gets model, tools, config)
  {:ok, agent_config} = HTDAGLuaExecutor.spawn_agents(strategy, task, state)

  # 3. Execute with agent config (Lua-defined everything!)
  execute_with_agents(agent_config.agents, task, state, opts)
end

defp execute_with_agents([agent_config | _rest], task, state, opts) do
  # Agent config from Lua contains:
  # - role
  # - model (from behavior or role)
  # - tools
  # - confidence_threshold
  # - prompt_template (optional)

  # Spawn actual agent
  agent = spawn_agent_from_config(agent_config)

  # Agent executes task
  Agent.execute_task(agent, task)
end
```

### Complete Removal List

From `htdag_executor.ex`, DELETE:

1. **Lines 261-283:** `build_operation_params/2`
2. **Lines 285-297:** `select_model_for_task/1`
3. **Lines 299-312:** `build_task_prompt/1`
4. **Lines 314-334:** `build_task_prompt_with_rag/2`
5. **Lines 336-360:** `find_similar_code_examples/1`, `format_rag_examples/1`

**Total:** ~100 lines of hardcoded logic REMOVED!

### What HTDAGExecutor Becomes

**Minimal orchestrator:**

```elixir
defmodule Singularity.Execution.Planning.HTDAGExecutor do
  @moduledoc """
  Minimal HTDAG executor - orchestrates Lua-defined execution strategies.

  All task decomposition, agent spawning, and orchestration logic is in Lua scripts.
  This module just:
  1. Selects next task (via HTDAGCore - respects dependencies)
  2. Loads Lua strategy
  3. Executes Lua strategy
  4. Updates DAG status
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Planning.{HTDAGCore, HTDAGStrategyLoader, HTDAGLuaExecutor}
  alias Singularity.Agents.AgentSpawner  # New module for spawning agents

  ## execute_dag_loop stays the same (it's generic!)

  defp execute_dag_loop(state, opts) do
    case HTDAGCore.select_next_task(state.dag) do
      nil -> {:ok, state}  # Done!

      task ->
        case execute_task_with_lua(task, state, opts) do
          {:ok, result} ->
            dag = HTDAGCore.mark_completed(state.dag, task.id)
            results = Map.put(state.results, task.id, result)
            execute_dag_loop(%{state | dag: dag, results: results}, opts)

          {:error, reason} ->
            dag = HTDAGCore.mark_failed(state.dag, task.id, reason)
            {:error, {:task_failed, task.id, reason}}
        end
    end
  end

  ## NEW: Lua-powered task execution

  defp execute_task_with_lua(task, state, opts) do
    Logger.info("Executing task via Lua strategy", task_id: task.id)

    # 1. Get Lua strategy for this task
    case HTDAGStrategyLoader.get_strategy_for_task(task.description) do
      {:ok, strategy} ->
        # 2. If task is complex, decompose it first
        if should_decompose?(task) do
          decompose_and_recurse(task, strategy, state, opts)
        else
          execute_atomic_task(task, strategy, state, opts)
        end

      {:error, :no_strategy_found} ->
        # Fallback to default execution
        execute_with_default_strategy(task, state, opts)
    end
  end

  defp should_decompose?(task) do
    # Complex tasks get decomposed
    (task.estimated_complexity || 5.0) >= 5.0 and
    task.task_type != :implementation
  end

  defp decompose_and_recurse(task, strategy, state, opts) do
    # Execute Lua decomposition
    case HTDAGLuaExecutor.decompose_task(strategy, task, state) do
      {:ok, []} ->
        # No decomposition needed, execute atomically
        execute_atomic_task(task, strategy, state, opts)

      {:ok, subtasks} ->
        Logger.info("Decomposed into #{length(subtasks)} subtasks", task_id: task.id)

        # Add subtasks to DAG
        dag = Enum.reduce(subtasks, state.dag, fn subtask, acc_dag ->
          HTDAGCore.add_task(acc_dag, subtask)
        end)

        # Update parent task as "in progress"
        dag = HTDAGCore.mark_in_progress(dag, task.id)

        # Update state
        new_state = %{state | dag: dag}

        # Let DAG loop handle execution (automatic ordering!)
        {:ok, %{decomposed: true, subtask_count: length(subtasks)}}

      error ->
        error
    end
  end

  defp execute_atomic_task(task, strategy, state, opts) do
    # 1. Spawn agents via Lua
    case HTDAGLuaExecutor.spawn_agents(strategy, task, state) do
      {:ok, spawn_config} ->
        # 2. Spawn actual agents
        agents = Enum.map(spawn_config.agents, &AgentSpawner.spawn/1)

        # 3. Get orchestration plan via Lua
        case HTDAGLuaExecutor.orchestrate_execution(strategy, task, agents, []) do
          {:ok, orchestration} ->
            # 4. Execute orchestration plan
            results = execute_orchestration(orchestration, agents, task, state)

            # 5. Check completion via Lua
            case HTDAGLuaExecutor.check_completion(strategy, task, results) do
              {:ok, %{"status" => "completed"} = completion} ->
                {:ok, completion}

              {:ok, %{"status" => "needs_rework"} = completion} ->
                {:error, {:needs_rework, completion["reasoning"]}}

              error ->
                error
            end

          error -> error
        end

      error -> error
    end
  end

  defp execute_orchestration(orchestration, agents, task, state) do
    # Execute phases from orchestration plan
    orchestration["execution_plan"]
    |> Enum.reduce(%{}, fn phase, acc_results ->
      execute_phase(phase, agents, task, state, acc_results)
    end)
  end

  defp execute_phase(phase, agents, task, state, previous_results) do
    # Execute assignments in this phase
    phase_results = phase["assignments"]
    |> Enum.map(fn assignment ->
      agent = Enum.find(agents, & &1.id == assignment["agent_id"])

      # Agent executes its assigned subtasks
      subtask_ids = assignment["subtask_ids"] || []
      results = Enum.map(subtask_ids, fn subtask_id ->
        Agent.execute_task(agent, subtask_id, previous_results)
      end)

      {assignment["agent_id"], results}
    end)
    |> Enum.into(%{})

    # Merge with previous results
    Map.merge(previous_results, phase_results)
  end

  defp execute_with_default_strategy(task, state, opts) do
    # Simple fallback: spawn single code_developer agent
    {:ok, agent} = AgentSpawner.spawn(%{
      role: "code_developer",
      config: %{tools: [], confidence_threshold: 0.8}
    })

    Agent.execute_task(agent, task)
  end
end
```

### Agent Spawner Module (New)

```elixir
defmodule Singularity.Agents.AgentSpawner do
  @moduledoc """
  Spawns agents from Lua configurations.
  """

  alias Singularity.Agent

  def spawn(agent_config) do
    role = agent_config.role || agent_config["role"]
    behavior_id = agent_config.behavior_id || agent_config["behavior_id"]
    config = agent_config.config || agent_config["config"] || %{}

    # Spawn agent with role and behavior
    {:ok, agent_pid} = Agent.start_link(
      id: generate_agent_id(),
      role: String.to_atom(role),
      behavior_id: behavior_id,
      config: config
    )

    %{
      id: generate_agent_id(),
      pid: agent_pid,
      role: role,
      config: config
    }
  end

  defp generate_agent_id do
    "agent-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end
```

### Summary

**REMOVED:** ~100 lines of hardcoded logic
- Model selection
- Prompt building
- RAG integration (move to Lua)
- Operation params

**ADDED:** Lua-powered execution
- Strategy loading
- Decomposition
- Agent spawning
- Orchestration
- Completion validation

**AUTOMATIC:** Task ordering
- HTDAGCore.select_next_task() respects dependencies
- No manual ordering needed
- Lua just defines subtasks with deps
- DAG figures out execution order

**Result:** HTDAGExecutor becomes **thin orchestration layer** with all logic in hot-reload Lua!
