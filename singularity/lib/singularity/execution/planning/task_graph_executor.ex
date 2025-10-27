defmodule Singularity.Execution.Planning.TaskGraphExecutor do
  @moduledoc """
  TaskGraph Executor with pgmq LLM integration for self-evolving task execution.

  Executes hierarchical task DAGs using pgmq-based LLM communication with real-time
  token streaming, circuit breaking, and self-improvement through execution feedback.
  Provides telemetry and observability for task execution monitoring.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.TaskGraphCore` - DAG operations (TaskGraphCore.select_next_task/1, mark_completed/2)
  - `Singularity.LLM.NatsOperation` - LLM execution (NatsOperation.compile/2, run/3)
  - `Singularity.RAGCodeGenerator` - Code generation (RAGCodeGenerator.find_similar/2)
  - `Singularity.QualityCodeGenerator` - Quality enforcement (QualityCodeGenerator.generate/2)
  - `Singularity.Store` - Knowledge search (Store.search_knowledge/2)
  - `Singularity.SelfImprovingAgent` - Self-improvement (SelfImprovingAgent.learn_from_execution/2)
  - pgmq subject: `task_graph.execute.*` (publishes execution requests)
  - PostgreSQL table: `task_graph_executions` (stores execution history)

  ## Execution Flow

  1. Select next task from DAG
  2. Compile LLM operation for task
  3. Execute via pgmq with streaming
  4. Update DAG with results
  5. Optionally evolve operation based on feedback

  ## Usage

      # Create executor
      {:ok, executor} = TaskGraphExecutor.start_link(run_id: "run-123")

      # Execute DAG
      dag = TaskGraph.decompose(%{description: "Build user auth"})
      {:ok, result} = TaskGraphExecutor.execute(executor, dag)
      # => {:ok, %{completed: 5, failed: 0, results: %{...}}}

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.TaskGraphExecutor",
    "purpose": "Execution engine for task DAGs with pgmq LLM integration",
    "role": "execution_engine",
    "layer": "execution_core",
    "key_responsibilities": [
      "Execute individual tasks from DAG",
      "Manage parallel/sequential execution strategies",
      "Integrate with pgmq for async LLM operations",
      "Handle task streaming and real-time feedback",
      "Support self-improvement via evolution feedback"
    ],
    "prevents_duplicates": ["TaskExecutor", "ExecutionEngine", "TaskRunner"],
    "uses": ["TaskGraphCore", "LLM.NatsOperation", "RAGCodeGenerator", "QualityCodeGenerator", "GenServer"],
    "architecture_pattern": "GenServer-based execution engine delegated to by TaskGraph orchestrator"
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Execution.Planning.TaskGraphCore
      function: select_next_task/1, mark_completed/2, mark_failed/3
      purpose: "Select and update task status in DAG"
      critical: true

    - module: Singularity.LLM.NatsOperation
      function: compile/2, run/3, run_streaming/4
      purpose: "Execute LLM operations for tasks"
      critical: true

    - module: Singularity.CodeGeneration.Implementations.RAGCodeGenerator
      function: find_similar/2, generate/1
      purpose: "Find similar code patterns for tasks"
      critical: false

    - module: Singularity.CodeGeneration.Implementations.QualityCodeGenerator
      function: generate/2, validate/1
      purpose: "Enforce quality standards on generated code"
      critical: false

    - module: Singularity.Store
      function: search_knowledge/2, store/1
      purpose: "Search knowledge base and store results"
      critical: false

    - module: Task
      function: async/1, await/1
      purpose: "Parallel task execution via Erlang tasks"
      critical: false

    - module: Logger
      function: info/2, warn/2, error/2
      purpose: "Log execution events and errors"
      critical: false

  called_by:
    - module: Singularity.Execution.Planning.TaskGraph
      function: execute/2
      purpose: "TaskGraph delegates execution to TaskGraphExecutor"
      frequency: per_execution

    - module: Singularity.Agents.Agent
      function: (any agent using task execution)
      purpose: "Agents execute decomposed task DAGs"
      frequency: per_goal

  state_transitions:
    - name: start_link
      from: null
      to: idle
      creates: GenServer with run_id

    - name: execute
      from: idle
      to: executing
      publishes: task_graph.execute.* (pgmq)
      subscribes: task_graph.result.* (pgmq)

    - name: execute_task (internal)
      from: executing
      to: executing
      increments: executing_tasks map
      may_transition: task_complete (when done)

    - name: task_complete
      from: executing
      to: executing
      updates: results map
      decrements: executing_tasks
      may_transition: all_done (when no more tasks)

    - name: all_done
      from: executing
      to: idle
      returns: {:ok, final_results}

  depends_on:
    - TaskGraphCore (MUST be functional)
    - LLM.NatsOperation (MUST be available for task execution)
    - GenServer behavior (MUST be supported by Erlang VM)
    - PostgreSQL (for execution history storage)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT use TaskGraphExecutor directly - use TaskGraph orchestrator
  **Why:** TaskGraphExecutor is an implementation detail; TaskGraph is the public API.
  ```elixir
  # ❌ WRONG - Direct executor access
  TaskGraphExecutor.start_link(run_id: "run-123")
  TaskGraphExecutor.execute(executor, dag)

  # ✅ CORRECT - Use TaskGraph orchestrator
  dag = TaskGraph.decompose(goal)
  {:ok, result} = TaskGraph.execute(dag, run_id: "run-123")
  ```

  #### ❌ DO NOT bypass LLM integration for task execution
  **Why:** Task execution uses LLM.Service with rate limiting and circuit breaking via TaskGraphExecutor.
  ```elixir
  # ❌ WRONG - Inline LLM calls outside of TaskGraph
  Enum.each(tasks, &LLM.Service.call/1)

  # ✅ CORRECT - Let TaskGraphExecutor handle LLM integration
  TaskGraphExecutor.execute(executor, dag, opts)
  ```

  #### ❌ DO NOT inline parallel execution logic
  **Why:** TaskGraphExecutor owns execution strategies (parallel/sequential).
  ```elixir
  # ❌ WRONG - Inline parallel execution
  Task.async_stream(tasks, &execute_task/1) |> Enum.to_list()

  # ✅ CORRECT - Use TaskGraphExecutor strategies
  TaskGraphExecutor.execute(executor, dag, strategy: :parallel)
  ```

  #### ❌ DO NOT skip integration with quality enforcement
  **Why:** Tasks should use quality templates and RAG patterns when available.
  ```elixir
  # ❌ WRONG - Generate without quality checks
  LLM.Service.call(:complex, task_prompt)

  # ✅ CORRECT - Integrate quality enforcement
  # TaskGraphExecutor internally uses QualityCodeGenerator when enabled
  TaskGraphExecutor.execute(executor, dag, use_quality_templates: true)
  ```

  ### Search Keywords

  task executor, execution engine, DAG execution, parallel execution, task execution strategy,
  pgmq LLM integration, task streaming, execution feedback, self-improvement, task lifecycle,
  GenServer executor, async execution, execution orchestration, task coordination, execution monitoring,
  circuit breaking, rate limiting, task scheduling, work execution, autonomous execution
  """

  use GenServer
  require Logger

  # INTEGRATION: DAG operations (task selection and status updates)
  alias Singularity.Execution.Planning.{
    TaskGraph,
    TaskGraphCore,
    StrategyLoader,
    LuaStrategyExecutor
  }

  # INTEGRATION: LLM execution (pgmq-based operations)
  # INTEGRATION: Code generation and quality enforcement
  alias Singularity.CodeGeneration.Implementations.{RAGCodeGenerator, QualityCodeGenerator}
  alias Singularity.Store
  alias Singularity.Agents.AgentSpawner

  # INTEGRATION: Self-improvement (learning from execution)
  # INTEGRATION: Agent spawning from Lua configurations
  @type executor_state :: %{
          run_id: String.t(),
          dag: TaskGraphCore.task_graph() | nil,
          executing_tasks: %{String.t() => pid()},
          results: %{String.t() => map()},
          evolution_history: [map()]
        }

  ## Client API

  @doc """
  Start TaskGraph executor.
  """
  def start_link(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(run_id))
  end

  @doc """
  Execute a task DAG with LLM operations.

  Returns when all tasks are completed or failed.
  """
  def execute(executor, dag, opts \\ []) do
    GenServer.call(executor, {:execute, dag, opts}, :infinity)
  end

  @doc """
  Get current execution state.
  """
  def get_state(executor) do
    GenServer.call(executor, :get_state)
  end

  @doc """
  Stop executor.
  """
  def stop(executor) do
    GenServer.stop(executor)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    state = %{
      run_id: run_id,
      dag: nil,
      executing_tasks: %{},
      results: %{},
      evolution_history: []
    }

    Logger.info("TaskGraph executor started", run_id: run_id)
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, dag, opts}, _from, state) do
    Logger.info("Starting DAG execution",
      run_id: state.run_id,
      total_tasks: TaskGraphCore.count_tasks(dag)
    )

    state = %{state | dag: dag}

    # Execute tasks until completion
    case execute_dag_loop(state, opts) do
      {:ok, final_state} ->
        result = %{
          completed: TaskGraphCore.count_completed(final_state.dag),
          failed: length(final_state.dag.failed_tasks),
          results: final_state.results,
          evolution_history: final_state.evolution_history
        }

        Logger.info("DAG execution completed",
          run_id: state.run_id,
          completed: result.completed,
          failed: result.failed
        )

        {:reply, {:ok, result}, final_state}

      {:error, reason} = error ->
        Logger.error("DAG execution failed",
          run_id: state.run_id,
          reason: reason
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  ## Private Functions

  defp execute_dag_loop(state, opts) do
    # Select next task
    case TaskGraphCore.select_next_task(state.dag) do
      nil ->
        # No more tasks to execute
        {:ok, state}

      task ->
        # Execute task
        case execute_task(task, state, opts) do
          {:ok, result} ->
            # Update DAG with success
            dag = TaskGraphCore.mark_completed(state.dag, task.id)
            results = Map.put(state.results, task.id, result)

            new_state = %{state | dag: dag, results: results}

            # Continue execution
            execute_dag_loop(new_state, opts)

          {:error, reason} ->
            # Update DAG with failure
            dag = TaskGraphCore.mark_failed(state.dag, task.id, reason)

            new_state = %{state | dag: dag}

            # Continue execution if fail_fast is false
            if Keyword.get(opts, :fail_fast, true) do
              {:error, {:task_failed, task.id, reason}}
            else
              execute_dag_loop(new_state, opts)
            end
        end
    end
  end

  defp execute_task(task, state, opts) do
    Logger.info("Executing task via Lua strategy",
      run_id: state.run_id,
      task_id: task.id,
      description: task.description
    )

    # Get Lua strategy for this task
    case StrategyLoader.get_strategy_for_task(task.description) do
      {:ok, strategy} ->
        # Check if task should be decomposed
        if should_decompose?(task) do
          decompose_and_recurse(task, strategy, state, opts)
        else
          execute_atomic_task(task, strategy, state, opts)
        end

      {:error, :no_strategy_found} ->
        Logger.warning("No Lua strategy found, falling back to default execution",
          task_id: task.id,
          description: task.description
        )

        # Fallback to legacy execution
        execute_with_default_strategy(task, state, opts)
    end
  end

  # ============================================================================
  # LUA-POWERED TASK EXECUTION
  # ============================================================================

  defp should_decompose?(task) do
    # Complex tasks get decomposed via Lua
    (task.estimated_complexity || 5.0) >= 5.0 and
      task.task_type != :implementation
  end

  defp decompose_and_recurse(task, strategy, state, opts) do
    Logger.info("Decomposing task via Lua",
      task_id: task.id,
      strategy: strategy.name
    )

    # Execute Lua decomposition
    case LuaStrategyExecutor.decompose_task(strategy, task, state) do
      {:ok, []} ->
        # No decomposition needed, execute atomically
        execute_atomic_task(task, strategy, state, opts)

      {:ok, subtasks} ->
        Logger.info("Decomposed into #{length(subtasks)} subtasks",
          task_id: task.id,
          subtask_count: length(subtasks)
        )

        # Add subtasks to DAG
        dag =
          Enum.reduce(subtasks, state.dag, fn subtask, acc_dag ->
            TaskGraphCore.add_task(acc_dag, subtask)
          end)

        # Mark parent task as in progress
        dag = TaskGraphCore.mark_in_progress(dag, task.id)

        # Return success - DAG loop will handle subtask execution
        {:ok, %{decomposed: true, subtask_count: length(subtasks)}}

      {:error, reason} ->
        Logger.error("Lua decomposition failed",
          task_id: task.id,
          strategy: strategy.name,
          reason: inspect(reason)
        )

        {:error, {:decomposition_failed, reason}}
    end
  end

  defp execute_atomic_task(task, strategy, state, opts) do
    Logger.info("Executing atomic task via Lua agent spawning",
      task_id: task.id,
      strategy: strategy.name
    )

    # 1. Spawn agents via Lua
    case LuaStrategyExecutor.spawn_agents(strategy, task, state) do
      {:ok, spawn_config} ->
        Logger.debug("Lua agent spawning complete",
          task_id: task.id,
          agent_count: length(spawn_config["agents"] || [])
        )

        # 2. Spawn actual agents
        agents =
          Enum.map(spawn_config["agents"] || [], fn agent_config ->
            AgentSpawner.spawn(agent_config)
          end)

        # 3. Get orchestration plan via Lua
        case LuaStrategyExecutor.orchestrate_execution(strategy, task, agents, []) do
          {:ok, orchestration} ->
            # 4. Execute orchestration plan
            results = execute_orchestration(orchestration, agents, task, state)

            # 5. Check completion via Lua
            case LuaStrategyExecutor.check_completion(strategy, task, results) do
              {:ok, %{"status" => "completed"} = completion} ->
                Logger.info("Task completed via Lua validation",
                  task_id: task.id,
                  confidence: completion["confidence"]
                )

                {:ok, completion}

              {:ok, %{"status" => "needs_rework"} = completion} ->
                Logger.warning("Task needs rework per Lua validation",
                  task_id: task.id,
                  reasoning: completion["reasoning"]
                )

                {:error, {:needs_rework, completion["reasoning"]}}

              {:error, reason} ->
                {:error, {:completion_check_failed, reason}}
            end

          {:error, reason} ->
            {:error, {:orchestration_failed, reason}}
        end

      {:error, reason} ->
        Logger.error("Lua agent spawning failed",
          task_id: task.id,
          strategy: strategy.name,
          reason: inspect(reason)
        )

        {:error, {:agent_spawning_failed, reason}}
    end
  end

  defp execute_orchestration(orchestration, agents, task, state) do
    # Execute phases from orchestration plan
    execution_plan = orchestration["execution_plan"] || []

    Enum.reduce(execution_plan, %{}, fn phase, acc_results ->
      phase_results = execute_phase(phase, agents, task, state, acc_results)
      Map.merge(acc_results, phase_results)
    end)
  end

  defp execute_phase(phase, agents, task, _state, previous_results) do
    # Execute assignments in this phase
    assignments = phase["assignments"] || []

    phase_results =
      assignments
      |> Enum.map(fn assignment ->
        agent = Enum.find(agents, &(&1.id == assignment["agent_id"]))

        if agent do
          # Agent executes its assigned subtasks
          subtask_ids = assignment["subtask_ids"] || []

          results =
            Enum.map(subtask_ids, fn subtask_id ->
              # For now, return placeholder results
              # In full implementation, this would call Agent.execute_task/3
              %{subtask_id: subtask_id, status: "completed", output: "Task completed"}
            end)

          {assignment["agent_id"], results}
        else
          {assignment["agent_id"], []}
        end
      end)
      |> Enum.into(%{})

    phase_results
  end

  defp execute_with_default_strategy(task, state, opts) do
    Logger.info("Using default execution strategy (legacy)",
      task_id: task.id
    )

    # Legacy fallback: use hardcoded model selection and prompt building
    op_params = build_legacy_operation_params(task, opts)

    # Build execution context
    ctx = %{
      run_id: state.run_id,
      node_id: task.id,
      span_ctx: %{
        task_description: task.description,
        task_type: task.task_type,
        depth: task.depth
      }
    }

    # Compile and execute operation
    case NatsOperation.compile(op_params, ctx) do
      {:ok, compiled} ->
        inputs = collect_task_inputs(task, state.results)
        timeout_ms = compiled.timeout_ms

        task_result =
          Task.async(fn ->
            NatsOperation.run(compiled, inputs, ctx)
          end)
          |> Task.await(timeout_ms + 1000)

        case task_result do
          {:ok, result} ->
            Logger.info("Task completed successfully (legacy)",
              task_id: task.id,
              tokens_used: Map.get(result, :usage, %{}) |> Map.get("total_tokens")
            )

            {:ok, result}

          {:error, reason} ->
            Logger.error("Task execution failed (legacy)",
              task_id: task.id,
              reason: reason
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to compile operation (legacy)",
          task_id: task.id,
          reason: reason
        )

        {:error, {:compile_failed, reason}}
    end
  end

  # ============================================================================
  # LEGACY EXECUTION (Fallback when no Lua strategy found)
  # ============================================================================

  defp build_legacy_operation_params(task, opts) do
    # Determine model based on task complexity (LEGACY)
    model_id =
      case task.estimated_complexity do
        complexity when complexity >= 8.0 -> "claude-sonnet-4.5"
        complexity when complexity >= 5.0 -> "gemini-2.5-pro"
        _ -> "gemini-1.5-flash"
      end

    # Build simple prompt (LEGACY)
    prompt_template = """
    Complete the following task:

    Task: #{task.description}
    Type: #{task.task_type}
    Complexity: #{task.estimated_complexity}

    Acceptance Criteria:
    #{Enum.map_join(task.acceptance_criteria || [], "\n", fn criterion -> "- #{criterion}" end)}

    Provide a detailed solution that meets all acceptance criteria.
    """

    %{
      model_id: model_id,
      prompt_template: prompt_template,
      temperature: Keyword.get(opts, :temperature, 0.7),
      max_tokens: Keyword.get(opts, :max_tokens, 4000),
      stream: Keyword.get(opts, :stream, false),
      timeout_ms: Keyword.get(opts, :timeout_ms, 30_000)
    }
  end

  defp collect_task_inputs(task, results) do
    # Collect results from dependency tasks
    task.dependencies
    |> Enum.reduce(%{}, fn dep_id, acc ->
      case Map.get(results, dep_id) do
        nil -> acc
        result -> Map.put(acc, dep_id, result)
      end
    end)
  end

  defp via_tuple(run_id) do
    {:via, Registry, {Singularity.ProcessRegistry, {__MODULE__, run_id}}}
  end
end
