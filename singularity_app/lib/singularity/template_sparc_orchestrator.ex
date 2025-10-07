defmodule Singularity.TemplateSparcOrchestrator do
  @moduledoc """
  Orchestrates Template Performance DAG + SPARC HTDAG integration.

  Two-DAG architecture:
  - Template Performance DAG (top) - Selects best templates via ML
  - SPARC HTDAG (bottom) - Executes tasks hierarchically

  Creates a feedback loop:
  1. Template DAG selects optimal template
  2. SPARC HTDAG executes with that template
  3. Performance metrics flow back to Template DAG
  4. Template DAG learns and improves selection
  """

  use GenServer
  require Logger

  alias Singularity.Planning.HTDAG
  alias Singularity.MethodologyExecutor

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
  Execute a task with optimal template selection and HTDAG decomposition
  """
  def execute(goal, opts \\ []) do
    GenServer.call(__MODULE__, {:execute, goal, opts}, :infinity)
  end

  @doc """
  Get execution statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
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
      Singularity.TemplatePerformanceTracker.get_best_template(task_type, language)

    Logger.info("Template DAG selected: #{template_id}")

    # 2. Create SPARC HTDAG for task decomposition
    sparc_dag = HTDAG.decompose(goal)

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

    Singularity.TemplatePerformanceTracker.record_usage(
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

  defp execute_with_template(sparc_dag, template_id, opts) do
    # Get tasks from HTDAG
    tasks = get_all_tasks(sparc_dag)

    # Execute each task with the selected template
    Enum.reduce_while(tasks, {:ok, []}, fn task, {:ok, results} ->
      case execute_task_with_template(task, template_id, opts) do
        {:ok, result} ->
          # Mark task completed in HTDAG
          HTDAG.mark_completed(sparc_dag, task.id)
          {:cont, {:ok, [result | results]}}

        {:error, reason} ->
          # Mark task failed in HTDAG
          HTDAG.mark_failed(sparc_dag, task.id, reason)
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
    # Get all tasks from HTDAG in execution order
    tasks = []

    Enum.reduce_while(1..100, {sparc_dag, tasks}, fn _, {dag, acc} ->
      case HTDAG.select_next_task(dag) do
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
      String.contains?(goal.description, ["NATS", "consumer"]) -> "nats_consumer"
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
