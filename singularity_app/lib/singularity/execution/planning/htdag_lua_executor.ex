defmodule Singularity.Execution.Planning.HTDAGLuaExecutor do
  @moduledoc """
  Executes Lua scripts for HTDAG execution strategies.

  Provides functions to execute each type of strategy script:
  - Decomposition: Break tasks into subtasks
  - Agent Spawning: Determine which agents to spawn
  - Orchestration: Define agent collaboration patterns
  - Completion: Validate task completion

  All scripts execute in sandboxed Lua environment via `Singularity.LuaRunner`.

  ## Usage

      alias Singularity.Execution.Planning.{HTDAGLuaExecutor, HTDAGExecutionStrategy}

      # Decompose task
      {:ok, subtasks} = HTDAGLuaExecutor.decompose_task(strategy, task, context)

      # Spawn agents
      {:ok, agent_configs} = HTDAGLuaExecutor.spawn_agents(strategy, task, context)

      # Get orchestration plan
      {:ok, plan} = HTDAGLuaExecutor.orchestrate_execution(strategy, task, agents, subtasks)

      # Check completion
      {:ok, completion} = HTDAGLuaExecutor.check_completion(strategy, task, results)
  """

  require Logger
  alias Singularity.LuaRunner
  alias Singularity.Execution.Planning.{HTDAGCore, HTDAGExecutionStrategy}

  ## Decomposition

  @doc """
  Execute decomposition script to break task into subtasks.

  ## Input Context (Lua)

      context = {
        task = {
          id = "task-123",
          description = "Build feature X",
          estimated_complexity = 8.5,
          task_type = "goal",
          depth = 0
        },
        codebase = {
          languages = {"elixir", "typescript"},
          frameworks = {"phoenix", "react"}
        }
      }

  ## Expected Output (Lua)

      return {
        subtasks = {
          {description = "Design database schema", estimated_complexity = 3.0, ...},
          {description = "Implement API", estimated_complexity = 5.0, ...}
        },
        strategy = "sequential",
        reasoning = "Dependencies require sequential execution"
      }

  ## Returns

  `{:ok, [subtask_map]}` - List of subtask maps ready for HTDAG
  `{:error, reason}` - Execution failed
  """
  @spec decompose_task(HTDAGExecutionStrategy.t(), map(), map()) ::
          {:ok, [map()]} | {:error, term()}
  def decompose_task(strategy, task, context \\ %{}) do
    if strategy.decomposition_script do
      lua_context = build_decomposition_context(task, context)

      case LuaRunner.execute_rule(strategy.decomposition_script, lua_context) do
        {:ok, result} ->
          subtasks = parse_subtasks(result["subtasks"] || [], task)
          {:ok, subtasks}

        {:error, reason} ->
          Logger.error("Decomposition script failed",
            strategy: strategy.name,
            task: task.description,
            error: inspect(reason)
          )

          {:error, {:decomposition_failed, reason}}
      end
    else
      {:error, :no_decomposition_script}
    end
  end

  ## Agent Spawning

  @doc """
  Execute agent spawning script to determine which agents to spawn.

  ## Input Context (Lua)

      context = {
        task = {id = "task-123", description = "...", ...},
        available_agents = {
          {id = "agent-001", role = "code_developer", status = "idle", load = 0.2}
        },
        resources = {
          cpu_available = 0.7,
          memory_available = 0.8,
          max_concurrent_agents = 5
        }
      }

  ## Expected Output (Lua)

      return {
        agents = {
          {role = "security_engineer", behavior_id = "...", spawn_mode = "dedicated", ...}
        },
        orchestration = {pattern = "leader_follower", leader = 1},
        reasoning = "Security task requires dedicated security agent"
      }

  ## Returns

  `{:ok, %{agents: [agent_config], orchestration: %{...}}}` - Agent spawn configurations
  `{:error, reason}` - Execution failed
  """
  @spec spawn_agents(HTDAGExecutionStrategy.t(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def spawn_agents(strategy, task, context \\ %{}) do
    if strategy.agent_spawning_script do
      lua_context = build_agent_spawning_context(task, context)

      case LuaRunner.execute_rule(strategy.agent_spawning_script, lua_context) do
        {:ok, result} ->
          agent_configs = parse_agent_configs(result["agents"] || [])
          orchestration = result["orchestration"] || %{}

          {:ok, %{agents: agent_configs, orchestration: orchestration, reasoning: result["reasoning"]}}

        {:error, reason} ->
          Logger.error("Agent spawning script failed",
            strategy: strategy.name,
            task: task.description,
            error: inspect(reason)
          )

          {:error, {:agent_spawning_failed, reason}}
      end
    else
      {:error, :no_agent_spawning_script}
    end
  end

  ## Orchestration

  @doc """
  Execute orchestration script to define agent collaboration pattern.

  ## Input Context (Lua)

      context = {
        task = {id = "task-123", ...},
        agents = {
          {id = "agent-001", role = "code_developer"},
          {id = "agent-002", role = "security_engineer"}
        },
        subtasks = {
          {id = "subtask-1", description = "..."}
        }
      }

  ## Expected Output (Lua)

      return {
        execution_plan = {
          {phase = "implementation", assignments = {...}, wait_for_completion = true},
          {phase = "review", assignments = {...}, approval_required = true}
        },
        coordination = {type = "pipeline", backpressure = true},
        channels = {
          {name = "updates", subscribers = {"agent-001", "agent-002"}}
        },
        reasoning = "Pipeline pattern ensures review after implementation"
      }

  ## Returns

  `{:ok, execution_plan}` - Detailed execution plan with phases and assignments
  `{:error, reason}` - Execution failed
  """
  @spec orchestrate_execution(HTDAGExecutionStrategy.t(), map(), list(), list()) ::
          {:ok, map()} | {:error, term()}
  def orchestrate_execution(strategy, task, agents, subtasks) do
    if strategy.orchestration_script do
      lua_context = build_orchestration_context(task, agents, subtasks)

      case LuaRunner.execute_rule(strategy.orchestration_script, lua_context) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          Logger.error("Orchestration script failed",
            strategy: strategy.name,
            task: task.description,
            error: inspect(reason)
          )

          {:error, {:orchestration_failed, reason}}
      end
    else
      {:error, :no_orchestration_script}
    end
  end

  ## Completion Checking

  @doc """
  Execute completion script to validate task completion.

  ## Input Context (Lua)

      context = {
        task = {
          id = "task-123",
          acceptance_criteria = {"Criterion 1", "Criterion 2"}
        },
        execution_results = {
          {subtask_id = "task-123-1", status = "completed", agent_id = "agent-001"}
        },
        tests = {
          unit_tests = {passed = 12, failed = 0},
          integration_tests = {passed = 5, failed = 0}
        },
        code_quality = {
          complexity = 4.2,
          coverage = 0.94,
          security_score = 0.98
        }
      }

  ## Expected Output (Lua)

      return {
        status = "completed",  -- or "needs_rework"
        confidence = 0.95,
        reasoning = "All tests passed, quality gates met",
        actual_complexity = 8.2,
        artifacts = {"lib/file1.ex", "lib/file2.ex"}
      }

  ## Returns

  `{:ok, completion_result}` - Completion status with confidence and reasoning
  `{:error, reason}` - Execution failed
  """
  @spec check_completion(HTDAGExecutionStrategy.t(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def check_completion(strategy, task, execution_data) do
    if strategy.completion_script do
      lua_context = build_completion_context(task, execution_data)

      case LuaRunner.execute_rule(strategy.completion_script, lua_context) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          Logger.error("Completion script failed",
            strategy: strategy.name,
            task: task.description,
            error: inspect(reason)
          )

          {:error, {:completion_check_failed, reason}}
      end
    else
      {:error, :no_completion_script}
    end
  end

  ## Context Builders

  defp build_decomposition_context(task, additional_context) do
    %{
      task: %{
        id: task.id || task[:id],
        description: task.description || task[:description],
        estimated_complexity: task.estimated_complexity || task[:estimated_complexity] || 5.0,
        task_type: to_string(task.task_type || task[:task_type] || :implementation),
        depth: task.depth || task[:depth] || 0,
        sparc_phase: task.sparc_phase || task[:sparc_phase]
      },
      codebase: additional_context[:codebase] || %{},
      constraints: additional_context[:constraints] || %{}
    }
  end

  defp build_agent_spawning_context(task, additional_context) do
    %{
      task: %{
        id: task.id || task[:id],
        description: task.description || task[:description],
        estimated_complexity: task.estimated_complexity || task[:estimated_complexity] || 5.0,
        task_type: to_string(task.task_type || task[:task_type] || :implementation),
        sparc_phase: task.sparc_phase || task[:sparc_phase],
        code_files: task.code_files || task[:code_files] || []
      },
      available_agents: additional_context[:available_agents] || [],
      resources: additional_context[:resources] || %{
        cpu_available: 0.8,
        memory_available: 0.8,
        max_concurrent_agents: 5
      }
    }
  end

  defp build_orchestration_context(task, agents, subtasks) do
    %{
      task: %{
        id: task.id || task[:id],
        description: task.description || task[:description],
        sparc_phase: task.sparc_phase || task[:sparc_phase]
      },
      agents: Enum.map(agents, &agent_to_lua/1),
      subtasks: Enum.map(subtasks, &subtask_to_lua/1)
    }
  end

  defp build_completion_context(task, execution_data) do
    %{
      task: %{
        id: task.id || task[:id],
        description: task.description || task[:description],
        acceptance_criteria: task.acceptance_criteria || task[:acceptance_criteria] || []
      },
      execution_results: execution_data[:results] || [],
      tests: execution_data[:tests] || %{},
      code_quality: execution_data[:code_quality] || %{}
    }
  end

  ## Parsers

  defp parse_subtasks(lua_subtasks, parent_task) when is_list(lua_subtasks) do
    Enum.map(lua_subtasks, fn lua_subtask ->
      %{
        id: generate_subtask_id(parent_task),
        description: lua_subtask["description"] || "Unnamed subtask",
        task_type: parse_task_type(lua_subtask["task_type"]),
        depth: (parent_task.depth || 0) + 1,
        parent_id: parent_task.id,
        children: [],
        dependencies: lua_subtask["dependencies"] || [],
        status: :pending,
        sparc_phase: parse_sparc_phase(lua_subtask["sparc_phase"]),
        estimated_complexity: lua_subtask["estimated_complexity"] || 5.0,
        actual_complexity: nil,
        code_files: lua_subtask["code_files"] || [],
        acceptance_criteria: lua_subtask["acceptance_criteria"] || []
      }
    end)
  end

  defp parse_subtasks(_, _parent_task), do: []

  defp parse_agent_configs(lua_agents) when is_list(lua_agents) do
    Enum.map(lua_agents, fn agent ->
      %{
        agent_id: agent["agent_id"],
        role: agent["role"],
        behavior_id: agent["behavior_id"],
        priority: agent["priority"] || "normal",
        spawn_mode: agent["spawn_mode"] || "dedicated",
        config: agent["config"] || %{}
      }
    end)
  end

  defp parse_agent_configs(_), do: []

  defp parse_task_type("goal"), do: :goal
  defp parse_task_type("milestone"), do: :milestone
  defp parse_task_type("implementation"), do: :implementation
  defp parse_task_type(_), do: :implementation

  defp parse_sparc_phase("specification"), do: :specification
  defp parse_sparc_phase("pseudocode"), do: :pseudocode
  defp parse_sparc_phase("architecture"), do: :architecture
  defp parse_sparc_phase("refinement"), do: :refinement
  defp parse_sparc_phase("completion_phase"), do: :completion_phase
  defp parse_sparc_phase(_), do: nil

  defp agent_to_lua(agent) when is_map(agent) do
    %{
      "id" => agent.id || agent[:id],
      "role" => to_string(agent.role || agent[:role] || "generalist"),
      "status" => to_string(agent.status || agent[:status] || "active"),
      "load" => agent.load || agent[:load] || 0.0
    }
  end

  defp subtask_to_lua(subtask) when is_map(subtask) do
    %{
      "id" => subtask.id || subtask[:id],
      "description" => subtask.description || subtask[:description] || "",
      "status" => to_string(subtask.status || subtask[:status] || :pending)
    }
  end

  defp generate_subtask_id(parent_task) do
    parent_id = parent_task.id || parent_task[:id]
    "#{parent_id}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end
end
