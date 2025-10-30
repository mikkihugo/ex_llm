defmodule Singularity.Agents.Coordination.TaskGraphAgentBridge do
  @moduledoc """
  Task Graph ↔ Agent Coordination Bridge - Integrates TaskGraph with AgentRouter.

  Provides a bridge layer between TaskGraphOrchestrator (goal decomposition) and
  the Agent Coordination Router (task execution). This allows decomposed tasks from
  TaskGraph to be intelligently routed to agents based on their capabilities and
  current availability.

  ## Architecture

  ```
  TaskGraphOrchestrator
      ↓ decomposes goals → task DAG
  TaskGraphAgentBridge
      ↓ adapts task format + handles execution
  AgentRouter
      ↓ selects best agent
  Agents (SelfImproving, QualityEnforcer, CostOptimized)
      ↓ executes work
  ```

  ## Usage

  ### Option A: Direct execution (one-off)
  ```elixir
  task = %{
    id: 1,
    goal: "Refactor UserController for readability",
    domain: :refactoring,
    input_type: :code,
    output_type: :code
  }

  {:ok, result} = TaskGraphAgentBridge.execute_task(task, timeout: 30_000)
  ```

  ### Option B: In TaskGraph execution loop
  ```elixir
  # Instead of calling your_llm_service in TaskGraphExecutor, call:
  {:ok, result} = TaskGraphAgentBridge.execute_task(task)

  # If agent routing fails, falls back to LLM (graceful degradation)
  ```

  ### Option C: Task DAG execution (preserves dependencies)
  ```elixir
  tasks = [
    %{id: 1, goal: "Analyze", domain: :analysis, depends_on: []},
    %{id: 2, goal: "Refactor", domain: :refactoring, depends_on: [1]}
  ]

  {:ok, results} = TaskGraphAgentBridge.execute_task_dag(tasks, timeout: 60_000)
  ```

  ## Task Mapping

  TaskGraph goals are mapped to coordination router task format:

  ```elixir
  # TaskGraph task
  %{
    id: 1,
    goal: "Refactor code for performance",
    description: "...",
    estimated_tokens: 1000
  }

  # ↓ converted to

  # Coordination router task
  %{
    id: 1,
    goal: "Refactor code for performance",
    domain: :refactoring,           # inferred from goal/description
    complexity: :medium,             # inferred from estimated_tokens
    input_type: :code,               # default or inferred
    output_type: :code,              # default or inferred
    source: :task_graph              # origin tracking
  }
  ```

  ## Fallback Strategy

  If agent routing fails:
  1. Log the failure with full context
  2. Return error (caller decides: retry, fallback to LLM, or escalate)
  3. Optional: Future versions could have graceful LLM fallback

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Coordination.TaskGraphAgentBridge",
    "purpose": "Bridge between TaskGraph decomposition and Agent execution",
    "layer": "coordination",
    "pattern": "Adapter/Bridge pattern",
    "responsibilities": [
      "Convert TaskGraph task format to coordination router format",
      "Route tasks to AgentRouter for intelligent execution",
      "Handle task DAG execution with dependencies",
      "Map inferred domains and complexity levels",
      "Provide fallback and error handling"
    ]
  }
  ```
  """

  require Logger
  alias Singularity.Agents.Coordination.AgentRouter
  alias Singularity.LLM.Config
  alias Singularity.Agents.Coordination.ExecutionCoordinator

  @doc """
  Execute a single TaskGraph-originated task via agent routing.

  Converts the task to coordination router format and routes to best agent.
  Returns `{:ok, result}` or `{:error, reason}`.

  ## Parameters

  - `task` - Task map from TaskGraph with keys:
    - `:id` - Task ID (required)
    - `:goal` - Goal description (required)
    - `:description` - Full description (optional)
    - `:estimated_tokens` - Token estimate (optional)
    - Any other fields are preserved in output

  - `opts` - Options:
    - `:timeout` - Execution timeout in ms (default: 30_000)
    - `:retry_count` - Times to retry on transient failures (default: 1)

  ## Examples

      iex> task = %{id: 1, goal: "Refactor UserController"}
      iex> TaskGraphAgentBridge.execute_task(task, timeout: 30_000)
      {:ok, %{result: "...", agent: :refactoring_agent}}

      iex> task = %{id: 2, goal: "Analyze code quality"}
      iex> TaskGraphAgentBridge.execute_task(task)
      {:error, :no_agents_found}
  """
  @spec execute_task(map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def execute_task(task, opts \\ []) when is_map(task) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    Logger.debug("TaskGraph agent bridge executing task",
      task_id: task[:id],
      goal: task[:goal]
    )

    # Convert task to coordination router format
    router_task = convert_to_router_task(task)

    # Route and execute
    case AgentRouter.route_task(router_task,
           timeout: timeout,
           retry_count: Keyword.get(opts, :retry_count, 1)
         ) do
      {:ok, result} ->
        Logger.info("TaskGraph task executed via agent router",
          task_id: task[:id],
          agent: result[:agent]
        )

        {:ok, result}

      {:error, reason} ->
        Logger.warning("TaskGraph agent routing failed, falling back",
          task_id: task[:id],
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Execute a task DAG (with dependencies) via agent coordination.

  Respects task dependencies and executes tasks in valid order,
  allowing parallel execution where dependencies permit.

  Returns `{:ok, results_map}` where results_map is `%{task_id => result}`.

  ## Examples

      iex> tasks = [
      ...>   %{id: 1, goal: "Analyze", depends_on: []},
      ...>   %{id: 2, goal: "Refactor", depends_on: [1]}
      ...> ]
      iex> TaskGraphAgentBridge.execute_task_dag(tasks)
      {:ok, %{1 => %{...}, 2 => %{...}}}
  """
  @spec execute_task_dag([map()], keyword()) :: {:ok, map()} | {:error, atom()}
  def execute_task_dag(tasks, opts \\ []) when is_list(tasks) do
    timeout = Keyword.get(opts, :timeout, 300_000)
    execution_id = generate_execution_id()

    Logger.info("TaskGraph agent bridge executing task DAG",
      execution_id: execution_id,
      task_count: length(tasks)
    )

    # Convert all tasks to router format
    router_tasks = Enum.map(tasks, &convert_to_router_task/1)

    # Execute via ExecutionCoordinator (handles dependencies + parallel execution)
    case ExecutionCoordinator.execute_task_dag(execution_id, router_tasks, timeout: timeout) do
      {:ok, results} ->
        Logger.info("TaskGraph DAG executed successfully",
          execution_id: execution_id,
          completed_tasks: map_size(results)
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("TaskGraph DAG execution failed",
          execution_id: execution_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Private

  @doc false
  defp convert_to_router_task(task) do
    # Infer domain from goal text
    domain = infer_domain(task[:goal], task[:description])

    # Get provider from task context or default to "auto"
    provider = task[:provider] || "auto"

    # Infer complexity using centralized config (database → TaskTypeRegistry fallback)
    complexity = infer_complexity(task[:estimated_tokens], task[:description], provider)

    # Build router task
    %{
      id: task[:id],
      goal: task[:goal],
      domain: domain,
      complexity: complexity,
      input_type: task[:input_type] || :code,
      output_type: task[:output_type] || :code,
      description: task[:description],
      source: :task_graph,
      original_task: task
    }
  end

  @doc false
  defp infer_domain(goal, description \\ nil) when is_binary(goal) do
    text = (goal <> " " <> (description || "")) |> String.downcase()

    cond do
      String.match?(text, ~r/refactor|improve|clean|optimize/) -> :refactoring
      String.match?(text, ~r/quality|test|validate|enforce/) -> :code_quality
      String.match?(text, ~r/document|comment|explain|doc/) -> :documentation
      String.match?(text, ~r/arch|design|structure/) -> :architecture
      String.match?(text, ~r/performance|speed|optimize/) -> :performance
      String.match?(text, ~r/security|safe|protect/) -> :security
      # default
      true -> :code_quality
    end
  end

  @doc false
  defp infer_complexity(estimated_tokens, description \\ nil, provider \\ "auto") do
    # If token estimate provided, use it
    if estimated_tokens do
      cond do
        estimated_tokens > 5000 -> :complex
        estimated_tokens > 2000 -> :medium
        true -> :simple
      end
    else
      # Use centralized LLM.Config to get complexity based on description
      context = %{description: description}

      case Config.get_task_complexity(provider, context) do
        {:ok, complexity} ->
          complexity

        {:error, _} ->
          # Fallback: infer from description text
          infer_complexity_from_description(description)
      end
    end
  end

  defp infer_complexity_from_description(description) do
    desc_text = (description || "") |> String.downcase()

    cond do
      String.match?(desc_text, ~r/large|multi|complex|architecture/) -> :complex
      String.match?(desc_text, ~r/module|file|component/) -> :medium
      true -> :medium
    end
  end

  @doc false
  defp generate_execution_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16() |> String.downcase()
  end
end
