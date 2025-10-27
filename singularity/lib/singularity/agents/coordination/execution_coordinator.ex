defmodule Singularity.Agents.Coordination.ExecutionCoordinator do
  @moduledoc """
  Execution Coordinator - Manage parallel agent execution with dependency tracking.

  Handles:
  - Task graph topological ordering
  - Parallel execution respecting dependencies
  - Agent invocation and result collection
  - Timeout and failure recovery
  - Real-time execution tracking

  ## Example

  ```elixir
  tasks = [
    %{id: 1, goal: "Analyze", domain: :code_quality, depends_on: []},
    %{id: 2, goal: "Refactor", domain: :refactoring, depends_on: [1]},
    %{id: 3, goal: "Test", domain: :testing, depends_on: [2]}
  ]

  {:ok, results} = ExecutionCoordinator.execute_task_dag("exec-123", tasks)
  # => {:ok, %{1 => analysis_result, 2 => refactored_code, 3 => test_results}}
  ```
  """

  require Logger

  @doc """
  Execute a task DAG with parallel execution where dependencies allow.

  Returns `{:ok, results_map}` or `{:error, reason}`.
  """
  def execute_task_dag(execution_id, tasks, opts \\ []) when is_list(tasks) do
    Logger.info("[ExecutionCoordinator] Starting task DAG execution",
      execution_id: execution_id,
      task_count: length(tasks)
    )

    timeout = Keyword.get(opts, :timeout, 300_000)

    try do
      # Create task index for quick lookup
      task_map = Map.new(tasks, &{&1.id, &1})

      # Find execution order respecting dependencies
      ordered = topological_sort(tasks)

      # Track results as we go
      results = %{}
      completed = MapSet.new()

      # Execute tasks
      case execute_ordered(ordered, task_map, results, completed, timeout, execution_id) do
        {:ok, final_results} ->
          Logger.info("[ExecutionCoordinator] Task DAG completed successfully",
            execution_id: execution_id,
            task_count: length(final_results)
          )

          {:ok, final_results}

        {:error, reason} ->
          Logger.error("[ExecutionCoordinator] Task DAG execution failed",
            execution_id: execution_id,
            reason: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      e ->
        Logger.error("[ExecutionCoordinator] Exception during task DAG execution",
          execution_id: execution_id,
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :execution_failed}
    end
  end

  @doc """
  Execute a single task with the specified agent.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def execute_task(agent_name, task, timeout) when is_atom(agent_name) and is_map(task) do
    Logger.debug("[ExecutionCoordinator] Executing task with agent",
      task_id: task[:id],
      agent: agent_name
    )

    # Invoke agent to execute task
    # Agents are GenServers that accept {:execute_task, task, from} messages
    try do
      case call_agent(agent_name, {:execute_task, task}, timeout) do
        {:ok, result} ->
          Logger.debug("[ExecutionCoordinator] Task execution succeeded",
            task_id: task[:id],
            agent: agent_name
          )

          {:ok, result}

        {:error, reason} ->
          {:error, reason}

        :timeout ->
          {:error, :timeout}
      end
    rescue
      e ->
        Logger.error("[ExecutionCoordinator] Agent execution failed",
          task_id: task[:id],
          agent: agent_name,
          error: inspect(e)
        )

        {:error, e}
    end
  end

  # Private

  @doc false
  def topological_sort(tasks) when is_list(tasks) do
    # Topological sort using Kahn's algorithm
    # Tasks with no dependencies come first

    task_map = Map.new(tasks, &{&1.id, &1})

    # Build in-degree map
    in_degrees =
      tasks
      |> Enum.reduce(%{}, fn task, acc ->
        Map.put(acc, task.id, length(task[:depends_on] || []))
      end)

    # Find all tasks with no dependencies
    queue =
      in_degrees
      |> Enum.filter(fn {_id, degree} -> degree == 0 end)
      |> Enum.map(fn {id, _degree} -> id end)

    # Sort
    sorted = sort_tasks(queue, in_degrees, task_map, [])

    if length(sorted) == length(tasks) do
      sorted
    else
      # Circular dependency detected
      raise "Circular dependency in task graph"
    end
  end

  defp sort_tasks([], _in_degrees, _task_map, acc) do
    Enum.reverse(acc)
  end

  defp sort_tasks([task_id | queue], in_degrees, task_map, acc) do
    # Find all tasks that depend on this one
    dependents =
      task_map
      |> Enum.filter(fn {_id, task} ->
        Enum.member?(task[:depends_on] || [], task_id)
      end)
      |> Enum.map(fn {id, _task} -> id end)

    # Decrease in-degree for all dependents
    new_in_degrees =
      Enum.reduce(dependents, in_degrees, fn dep_id, degrees ->
        current = Map.get(degrees, dep_id, 0)
        Map.put(degrees, dep_id, current - 1)
      end)

    # Find newly available tasks (in-degree now 0)
    newly_available =
      dependents
      |> Enum.filter(fn id -> Map.get(new_in_degrees, id) == 0 end)

    new_queue = queue ++ newly_available

    sort_tasks(new_queue, new_in_degrees, task_map, [task_id | acc])
  end

  defp execute_ordered([], _task_map, results, _completed, _timeout, _execution_id) do
    {:ok, results}
  end

  defp execute_ordered(
         [task_id | rest],
         task_map,
         results,
         completed,
         timeout,
         execution_id
       ) do
    task = Map.get(task_map, task_id)

    # Check dependencies
    deps = task[:depends_on] || []

    if Enum.all?(deps, &MapSet.member?(completed, &1)) do
      # All dependencies completed, can execute this task
      case execute_task_with_router(task, timeout, execution_id) do
        {:ok, result} ->
          new_results = Map.put(results, task_id, result)
          new_completed = MapSet.put(completed, task_id)
          execute_ordered(rest, task_map, new_results, new_completed, timeout, execution_id)

        {:error, reason} ->
          {:error, reason}
      end
    else
      # Dependencies not ready - wait and retry
      Process.sleep(100)
      execute_ordered([task_id | rest], task_map, results, completed, timeout, execution_id)
    end
  end

  defp execute_task_with_router(task, timeout, execution_id) do
    # Use AgentRouter to find and execute with best agent
    alias Singularity.Agents.Coordination.AgentRouter

    Logger.debug("[ExecutionCoordinator] Routing task",
      task_id: task[:id],
      execution_id: execution_id
    )

    case AgentRouter.route_task(task, timeout: timeout) do
      {:ok, result} ->
        # Record execution for learning
        record_execution_outcome(task, result, execution_id)
        {:ok, result}

      {:error, reason} ->
        Logger.error("[ExecutionCoordinator] Task routing failed",
          task_id: task[:id],
          execution_id: execution_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp record_execution_outcome(task, result, execution_id) do
    # Hook for workflow learning via WorkflowLearner
    alias Singularity.Agents.Coordination.WorkflowLearner

    success = Map.get(result, :error) == nil

    Logger.debug("[ExecutionCoordinator] Recording execution outcome",
      task_id: task[:id],
      execution_id: execution_id,
      success: success
    )

    # Build outcome record for learning system
    outcome = %{
      agent: result[:agent] || :unknown,
      task_id: task[:id],
      task_domain: task[:domain],
      success: success,
      latency_ms: result[:latency_ms] || 0,
      tokens_used: result[:tokens_used],
      quality_score: result[:quality_score],
      feedback: nil,
      error: result[:error],
      metadata: %{
        execution_id: execution_id,
        goal: task[:goal],
        complexity: task[:complexity],
        source: task[:source]
      }
    }

    # Record in learning system (async, fire-and-forget)
    try do
      WorkflowLearner.record_outcome(outcome)
    rescue
      e ->
        Logger.warn("[ExecutionCoordinator] Failed to record learning outcome",
          task_id: task[:id],
          error: inspect(e)
        )
    end
  end

  defp call_agent(agent_name, message, timeout) do
    # Convert agent name to PID
    case Agent.get(agent_name, & &1) do
      pid when is_pid(pid) ->
        GenServer.call(pid, message, timeout)

      _ ->
        {:error, :agent_not_found}
    end
  rescue
    _ ->
      # Agent not registered or call failed
      {:error, :agent_unavailable}
  end
end
