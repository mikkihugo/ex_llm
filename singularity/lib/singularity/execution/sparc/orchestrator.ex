defmodule Singularity.Execution.SPARC.Orchestrator do
  @moduledoc """
  SPARC Orchestrator - Template-driven SPARC execution with TaskGraph integration.

  Two-DAG architecture:
  - Template Performance DAG (top) - Selects best templates via ML
  - SPARC TaskGraph (bottom) - Executes tasks hierarchically

  ## Quick Start

  ```elixir
  # Execute with optimal template selection
  {:ok, results, metrics} = SPARC.Orchestrator.execute(goal)

  # Get execution statistics
  stats = SPARC.Orchestrator.get_stats()
  # => %{total_executions: 42, success_rate: 0.95, ...}
  ```

  ## Public API

  - `execute(goal, _opts)` - Execute goal with template selection and TaskGraph
  - `get_stats/0` - Get execution statistics and performance history

  ## Key Features

  - **Dual DAG architecture** - Template selection + task execution
  - **Performance feedback** - Metrics flow back to template selector
  - **Quality evaluation** - Auto-scores generated code
  - **Template learning** - Improves template selection over time

  ## Feedback Loop

  1. Template DAG selects optimal template
  2. SPARC TaskGraph executes with that template
  3. Performance metrics flow back to Template DAG
  4. Template DAG learns and improves selection

  ## Error Handling

  Returns `{:ok, results, metrics}` on success or `{:error, reason}` on failure.

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.SPARC.Orchestrator",
    "purpose": "Dual-DAG orchestration of template selection and SPARC task execution",
    "role": "orchestrator",
    "layer": "domain_services",
    "alternatives": {
      "MethodologyExecutor": "Generic methodology execution - use SPARC.Orchestrator for SPARC-specific",
      "TaskGraph": "Task decomposition only - SPARC.Orchestrator adds template selection",
      "TemplatePerformanceTracker": "Template metrics only - SPARC.Orchestrator adds execution"
    },
    "disambiguation": {
      "vs_methodology": "SPARC.Orchestrator is specialized for SPARC methodology with dual DAGs",
      "vs_task_graph": "SPARC.Orchestrator wraps TaskGraph with template selection layer",
      "vs_template_tracker": "SPARC.Orchestrator executes + tracks; TemplatePerformanceTracker only tracks"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Goal[Goal Input]
      Orchestrator[SPARC.Orchestrator]
      TemplateDAG[Template Performance DAG]
      TaskGraph[SPARC TaskGraph]
      Executor[MethodologyExecutor]

      Goal -->|1. execute| Orchestrator
      Orchestrator -->|2. get best template| TemplateDAG
      TemplateDAG -->|3. template_id| Orchestrator
      Orchestrator -->|4. decompose| TaskGraph
      TaskGraph -->|5. tasks| Orchestrator
      Orchestrator -->|6. execute with template| Executor
      Executor -->|7. results| Orchestrator
      Orchestrator -->|8. evaluate quality| Metrics[Quality Metrics]
      Metrics -->|9. feedback| TemplateDAG
      Orchestrator -->|10. return| Results[Results + Metrics]

      style Orchestrator fill:#90EE90
      style TemplateDAG fill:#FFD700
      style TaskGraph fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Quality.TemplateTracker
      function: get_best_template/2
      purpose: Select optimal template based on ML performance history
      critical: true

    - module: Singularity.Execution.Planning.TaskGraph
      function: decompose/1
      purpose: Break goal into hierarchical task DAG
      critical: true

    - module: Singularity.MethodologyExecutor
      function: execute_phase_only/3
      purpose: Execute individual tasks with selected template
      critical: true

    - module: Singularity.Quality.TemplateTracker
      function: record_usage/3
      purpose: Record performance metrics for template learning
      critical: true

  called_by:
    - module: Singularity.Execution.ExecutionOrchestrator
      purpose: SPARC strategy execution
      frequency: medium

    - module: Singularity.Agents.*
      purpose: Agent task execution with SPARC methodology
      frequency: medium

  depends_on:
    - TemplatePerformanceTracker (MUST be started for template selection)
    - TaskGraph (stateless module)
    - MethodologyExecutor (stateless module)

  supervision:
    supervised: true
    reason: "GenServer maintaining execution state and performance history"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT bypass template selection
  **Why:** Template DAG learns and improves template selection over time.
  **Use instead:**
  ```elixir
  # ❌ WRONG - hardcoded template
  execute_with_template(goal, "my-favorite-template")

  # ✅ CORRECT - let orchestrator select
  SPARC.Orchestrator.execute(goal)
  ```

  #### ❌ DO NOT skip performance recording
  **Why:** Metrics enable template learning and selection improvement.
  **Use instead:** Always use `execute/2` which records metrics automatically.

  #### ❌ DO NOT create separate SPARC executors
  **Why:** SPARC.Orchestrator already provides complete SPARC execution!
  **Use instead:** Extend SPARC.Orchestrator with new capabilities.

  ### Search Keywords

  sparc orchestrator, template selection, dual dag, task graph execution,
  performance feedback, template learning, sparc methodology, quality evaluation,
  methodology executor, task decomposition, performance tracking
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Planning.TaskGraph
  alias Singularity.MethodologyExecutor
  alias Singularity.Knowledge.TemplateService

  defstruct [
    :template_dag,
    :sparc_dag,
    :current_execution,
    :performance_history,
    :active_tasks
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a task with optimal template selection and TaskGraph decomposition
  """
  def execute(goal, _opts \\ []) do
    GenServer.call(__MODULE__, {:execute, goal, _opts}, :infinity)
  end

  @doc """
  Get execution statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      # Will connect to TemplateOptimizer
      template_dag: nil,
      # Will be created per execution
      sparc_dag: nil,
      current_execution: nil,
      performance_history: [],
      active_tasks: %{}
    }

    Logger.info("DAG Orchestrator initialized - connecting two DAGs")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, goal, opts}, _from, state) do
    Logger.info("Starting orchestrated execution for: #{inspect(goal)}")

    # 1. Get best template from Template Performance DAG
    task_type = extract_task_type(goal)
    language = Keyword.get(opts, :language, "elixir")

    {:ok, template_id} =
      Singularity.Quality.TemplateTracker.get_best_template(task_type, language)

    Logger.info("Template DAG selected: #{template_id}")

    # 2. Create SPARC TaskGraph for task decomposition
    sparc_dag = TaskGraph.decompose(goal)

    # 3. Execute tasks with selected template
    execution_start = DateTime.utc_now()

    result = execute_with_template(sparc_dag, template_id, opts)

    execution_time = DateTime.diff(DateTime.utc_now(), execution_start, :millisecond)

    # 4. Record performance back to Template DAG
    metrics = %{
      time_ms: execution_time,
      quality: evaluate_quality(result),
      success: result != nil,
      lines: count_lines(result),
      complexity: estimate_complexity(result),
      coverage: 0.0,
      feedback: %{source: "orchestrator", auto_evaluated: true}
    }

    Singularity.Quality.TemplateTracker.record_usage(
      template_id,
      %{type: task_type, language: language, description: goal.description},
      metrics
    )

    # 5. Update state
    new_state = %{
      state
      | sparc_dag: sparc_dag,
        current_execution: %{
          goal: goal,
          template: template_id,
          result: result,
          metrics: metrics
        },
        performance_history:
          [
            %{template: template_id, metrics: metrics, timestamp: DateTime.utc_now()}
            | state.performance_history
          ]
          # Keep last 100
          |> Enum.take(100)
    }

    {:reply, {:ok, result, metrics}, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      current_execution: state.current_execution,
      total_executions: length(state.performance_history),
      average_time_ms: calculate_avg_time(state.performance_history),
      success_rate: calculate_success_rate(state.performance_history),
      template_usage: group_by_template(state.performance_history)
    }

    {:reply, stats, state}
  end

  # Private Functions

  defp execute_with_template(sparc_dag, template_id, _opts) do
    # Get tasks from TaskGraph
    tasks = get_all_tasks(sparc_dag)

    # Execute each task with the selected template
    Enum.reduce_while(tasks, {:ok, []}, fn task, {:ok, results} ->
      case execute_task_with_template(task, template_id, _opts) do
        {:ok, result} ->
          # Mark task completed in TaskGraph
          TaskGraph.mark_completed(sparc_dag, task.id)
          {:cont, {:ok, [result | results]}}

        {:error, reason} ->
          # Mark task failed in TaskGraph
          TaskGraph.mark_failed(sparc_dag, task.id, reason)
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, results} -> Enum.reverse(results) |> Enum.join("\n")
      {:error, _} -> nil
    end
  end

  defp execute_task_with_template(task, template_id, opts) do
    # Use SPARC Coordinator with specific template
    MethodologyExecutor.execute_phase_only(
      task.phase || :completion,
      task.description,
      Keyword.put(opts, :template, template_id)
    )
  end

  defp get_all_tasks(sparc_dag) do
    # Get all tasks from TaskGraph in execution order
    tasks = []

    Enum.reduce_while(1..100, {sparc_dag, tasks}, fn _, {dag, acc} ->
      case TaskGraph.select_next_task(dag) do
        nil -> {:halt, acc}
        task -> {:cont, {dag, [task | acc]}}
      end
    end)
    |> Enum.reverse()
  end

  defp extract_task_type(goal) do
    cond do
      String.contains?(goal.description, ["API", "endpoint"]) -> "api_endpoint"
      String.contains?(goal.description, ["service", "microservice"]) -> "microservice"
      String.contains?(goal.description, ["message", "consumer"]) -> "message_consumer"
      String.contains?(goal.description, ["component", "UI"]) -> "web_component"
      true -> "general"
    end
  end

  defp evaluate_quality(nil), do: 0.0

  defp evaluate_quality(result) do
    score = 0.5

    # Has error handling?
    score =
      score + if String.contains?(result, ["try", "catch", "rescue", "with"]), do: 0.1, else: 0

    # Has structure?
    score =
      score +
        if String.contains?(result, ["def", "defmodule", "function", "class"]), do: 0.2, else: 0

    # Reasonable length?
    lines = count_lines(result)
    score = score + if lines > 10 && lines < 1000, do: 0.2, else: 0

    min(score, 1.0)
  end

  defp count_lines(nil), do: 0
  defp count_lines(result), do: result |> String.split("\n") |> length()

  defp estimate_complexity(nil), do: 1

  defp estimate_complexity(result) do
    # Count decision points
    decision_points = ~r/if|case|cond|for|while|catch|rescue/
    matches = Regex.scan(decision_points, result)
    length(matches) + 1
  end

  defp calculate_avg_time(history) do
    if Enum.empty?(history) do
      0
    else
      total = Enum.reduce(history, 0, fn h, acc -> acc + h.metrics.time_ms end)
      div(total, length(history))
    end
  end

  defp calculate_success_rate(history) do
    if Enum.empty?(history) do
      0.0
    else
      success_count = Enum.count(history, fn h -> h.metrics.success end)
      success_count / length(history)
    end
  end

  defp group_by_template(history) do
    history
    |> Enum.group_by(& &1.template)
    |> Enum.map(fn {template, uses} ->
      {template, length(uses)}
    end)
    |> Enum.into(%{})
  end
end
