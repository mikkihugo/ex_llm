defmodule Singularity.Agents.Coordination.AgentRouter do
  @moduledoc """
  Agent Router - Route tasks to best-fit agents based on capabilities.

  Core routing engine that:
  1. Takes a task from the task graph
  2. Queries CapabilityRegistry for candidate agents
  3. Scores candidates by fit (domain, I/O, success rate, availability)
  4. Executes with best agent
  5. Reports outcomes for learning

  ## Example

  ```elixir
  task = %{
    id: 1,
    goal: "Analyze code quality issues",
    domain: :code_quality,
    complexity: :medium,
    input_type: :codebase,
    output_type: :analysis
  }

  # Find and execute with best agent
  {:ok, result} = AgentRouter.route_task(task)

  # Or get ranked candidates without executing
  candidates = AgentRouter.find_agents_for_task(task, top: 3)
  # => [{:quality_enforcer, 0.95}, {:architect, 0.78}, {:refactoring_agent, 0.65}]
  ```
  """

  require Logger
  alias Singularity.Agents.Coordination.CapabilityRegistry
  alias Singularity.Agents.Coordination.ExecutionCoordinator

  @doc """
  Route a single task to the best agent and execute it.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  def route_task(task, opts \\ []) when is_map(task) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    retry_count = Keyword.get(opts, :retry_count, 1)

    case find_best_agent_for_task(task) do
      nil ->
        Logger.error("[AgentRouter] No agents found for task",
          task_id: task[:id],
          domain: task[:domain]
        )

        {:error, :no_agents_found}

      agent_name ->
        execute_with_retries(agent_name, task, timeout, retry_count)
    end
  end

  @doc """
  Route a task DAG (list of tasks with dependencies), executing respecting dependencies.

  Returns `{:ok, results_map}` where results_map is `%{task_id => result}`.
  """
  def route_task_dag(tasks, opts \\ []) when is_list(tasks) do
    Logger.info("[AgentRouter] Routing task DAG", task_count: length(tasks))

    execution_id = generate_execution_id()
    timeout = Keyword.get(opts, :timeout, 300_000)

    case ExecutionCoordinator.execute_task_dag(execution_id, tasks, opts) do
      {:ok, results} ->
        Logger.info("[AgentRouter] Task DAG completed successfully",
          execution_id: execution_id,
          task_count: length(tasks)
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("[AgentRouter] Task DAG failed",
          execution_id: execution_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Find the best agent for a task without executing.

  Returns agent_name (atom) or nil if no suitable agents found.
  """
  def find_best_agent_for_task(task) when is_map(task) do
    candidates = CapabilityRegistry.top_agents_for_task(task, 5)

    case candidates do
      [] ->
        nil

      [{best_agent, _score} | _] ->
        best_agent
    end
  end

  @doc """
  Find top N agents for a task, ranked by fit score.

  Returns list of `{agent_name, fit_score}` tuples, sorted by score descending.
  """
  def find_agents_for_task(task, opts \\ []) when is_map(task) do
    top = Keyword.get(opts, :top, 3)
    CapabilityRegistry.top_agents_for_task(task, top)
  end

  @doc """
  Get agent capability info.
  """
  def get_agent_capability(agent_name) when is_atom(agent_name) do
    CapabilityRegistry.get_capability(agent_name)
  end

  @doc """
  List all agents that can handle a specific domain.
  """
  def agents_for_domain(domain) when is_atom(domain) do
    CapabilityRegistry.agents_for_domain(domain)
  end

  # Private

  defp execute_with_retries(agent_name, task, timeout, retry_count) when retry_count > 0 do
    case execute_task(agent_name, task, timeout) do
      {:ok, result} ->
        Logger.info("[AgentRouter] Task executed successfully",
          task_id: task[:id],
          agent: agent_name
        )

        {:ok, result}

      {:error, reason} ->
        if should_retry?(reason) and retry_count > 1 do
          Logger.warn("[AgentRouter] Task failed, retrying",
            task_id: task[:id],
            agent: agent_name,
            reason: inspect(reason),
            retries_left: retry_count - 1
          )

          # Try next-best agent
          case find_next_best_agent(task, agent_name) do
            nil ->
              {:error, reason}

            next_agent ->
              execute_with_retries(next_agent, task, timeout, retry_count - 1)
          end
        else
          Logger.error("[AgentRouter] Task failed after retries",
            task_id: task[:id],
            agent: agent_name,
            reason: inspect(reason)
          )

          {:error, reason}
        end
    end
  end

  defp execute_task(agent_name, task, timeout) do
    # Delegate to ExecutionCoordinator for actual execution
    ExecutionCoordinator.execute_task(agent_name, task, timeout)
  end

  defp find_next_best_agent(task, exclude_agent) when is_atom(exclude_agent) do
    candidates = CapabilityRegistry.top_agents_for_task(task, 5)

    candidates
    |> Enum.reject(fn {agent, _score} -> agent == exclude_agent end)
    |> case do
      [] -> nil
      [{next_agent, _score} | _] -> next_agent
    end
  end

  defp should_retry?(reason) do
    case reason do
      :timeout -> true
      :busy -> true
      :temporary_failure -> true
      _ -> false
    end
  end

  defp generate_execution_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16() |> String.downcase()
  end
end
