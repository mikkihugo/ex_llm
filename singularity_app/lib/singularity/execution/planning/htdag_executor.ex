defmodule Singularity.Execution.Planning.HTDAGExecutor do
  @moduledoc """
  HTDAG Executor with NATS LLM integration for self-evolving task execution.

  Executes hierarchical task DAGs using NATS-based LLM communication with real-time
  token streaming, circuit breaking, and self-improvement through execution feedback.
  Provides telemetry and observability for task execution monitoring.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.HTDAGCore` - DAG operations (HTDAGCore.select_next_task/1, mark_completed/2)
  - `Singularity.LLM.NatsOperation` - LLM execution (NatsOperation.compile/2, run/3)
  - `Singularity.RAGCodeGenerator` - Code generation (RAGCodeGenerator.find_similar/2)
  - `Singularity.QualityCodeGenerator` - Quality enforcement (QualityCodeGenerator.generate/2)
  - `Singularity.Store` - Knowledge search (Store.search_knowledge/2)
  - `Singularity.SelfImprovingAgent` - Self-improvement (SelfImprovingAgent.learn_from_execution/2)
  - NATS subject: `htdag.execute.*` (publishes execution requests)
  - PostgreSQL table: `htdag_executions` (stores execution history)

  ## Execution Flow

  1. Select next task from DAG
  2. Compile LLM operation for task
  3. Execute via NATS with streaming
  4. Update DAG with results
  5. Optionally evolve operation based on feedback

  ## Usage

      # Create executor
      {:ok, executor} = HTDAGExecutor.start_link(run_id: "run-123")
      
      # Execute DAG
      dag = HTDAG.decompose(%{description: "Build user auth"})
      {:ok, result} = HTDAGExecutor.execute(executor, dag)
      # => {:ok, %{completed: 5, failed: 0, results: %{...}}}
  """
  
  use GenServer
  require Logger
  
  # INTEGRATION: DAG operations (task selection and status updates)
  alias Singularity.Execution.Planning.{HTDAG, HTDAGCore}

  # INTEGRATION: LLM execution (NATS-based operations)
  alias Singularity.LLM.NatsOperation

  # INTEGRATION: Code generation and quality enforcement
  alias Singularity.{RAGCodeGenerator, QualityCodeGenerator, Store}

  # INTEGRATION: Self-improvement (learning from execution)
  alias Singularity.SelfImprovingAgent
  
  @type executor_state :: %{
          run_id: String.t(),
          dag: HTDAGCore.htdag() | nil,
          executing_tasks: %{String.t() => pid()},
          results: %{String.t() => map()},
          evolution_history: [map()]
        }
  
  ## Client API
  
  @doc """
  Start HTDAG executor.
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
    
    Logger.info("HTDAG executor started", run_id: run_id)
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute, dag, opts}, _from, state) do
    Logger.info("Starting DAG execution",
      run_id: state.run_id,
      total_tasks: HTDAGCore.count_tasks(dag)
    )
    
    state = %{state | dag: dag}
    
    # Execute tasks until completion
    case execute_dag_loop(state, opts) do
      {:ok, final_state} ->
        result = %{
          completed: HTDAGCore.count_completed(final_state.dag),
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
    case HTDAGCore.select_next_task(state.dag) do
      nil ->
        # No more tasks to execute
        {:ok, state}
        
      task ->
        # Execute task
        case execute_task(task, state, opts) do
          {:ok, result} ->
            # Update DAG with success
            dag = HTDAGCore.mark_completed(state.dag, task.id)
            results = Map.put(state.results, task.id, result)
            
            new_state = %{state | dag: dag, results: results}
            
            # Continue execution
            execute_dag_loop(new_state, opts)
            
          {:error, reason} ->
            # Update DAG with failure
            dag = HTDAGCore.mark_failed(state.dag, task.id, reason)
            
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
    Logger.info("Executing task",
      run_id: state.run_id,
      task_id: task.id,
      description: task.description
    )
    
    # Build operation parameters based on task
    op_params = build_operation_params(task, opts)
    
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
    
    # Compile operation
    case NatsOperation.compile(op_params, ctx) do
      {:ok, compiled} ->
        # Get inputs from dependencies
        inputs = collect_task_inputs(task, state.results)
        
        # Execute with timeout
        timeout_ms = compiled.timeout_ms
        
        task_result = 
          Task.async(fn ->
            NatsOperation.run(compiled, inputs, ctx)
          end)
          |> Task.await(timeout_ms + 1000)
        
        case task_result do
          {:ok, result} ->
            Logger.info("Task completed successfully",
              run_id: state.run_id,
              task_id: task.id,
              tokens_used: result.usage["total_tokens"]
            )
            
            {:ok, result}
            
          {:error, reason} ->
            Logger.error("Task execution failed",
              run_id: state.run_id,
              task_id: task.id,
              reason: reason
            )
            
            {:error, reason}
        end
        
      {:error, reason} ->
        Logger.error("Failed to compile operation",
          run_id: state.run_id,
          task_id: task.id,
          reason: reason
        )
        
        {:error, {:compile_failed, reason}}
    end
  end
  
  defp build_operation_params(task, opts) do
    # Determine model based on task complexity
    model_id = select_model_for_task(task)
    
    # Build prompt template with RAG context if enabled
    prompt_template = if Keyword.get(opts, :use_rag, false) do
      build_task_prompt_with_rag(task, opts)
    else
      build_task_prompt(task)
    end
    
    %{
      model_id: model_id,
      prompt_template: prompt_template,
      temperature: Keyword.get(opts, :temperature, 0.7),
      max_tokens: Keyword.get(opts, :max_tokens, 4000),
      stream: Keyword.get(opts, :stream, false),
      timeout_ms: Keyword.get(opts, :timeout_ms, 30_000),
      # Integration flags
      use_rag: Keyword.get(opts, :use_rag, false),
      use_quality_templates: Keyword.get(opts, :use_quality_templates, false)
    }
  end
  
  defp select_model_for_task(task) do
    # Select model based on task complexity and type
    cond do
      task.estimated_complexity >= 8.0 ->
        "claude-sonnet-4.5"
        
      task.estimated_complexity >= 5.0 ->
        "gemini-2.5-pro"
        
      true ->
        "gemini-1.5-flash"
    end
  end
  
  defp build_task_prompt(task) do
    """
    Complete the following task:
    
    Task: #{task.description}
    Type: #{task.task_type}
    Complexity: #{task.estimated_complexity}
    
    Acceptance Criteria:
    #{Enum.map_join(task.acceptance_criteria, "\n", fn criterion -> "- #{criterion}" end)}
    
    Provide a detailed solution that meets all acceptance criteria.
    """
  end
  
  defp build_task_prompt_with_rag(task, opts) do
    # Use RAG to find similar code examples
    similar_code = find_similar_code_examples(task)
    
    base_prompt = build_task_prompt(task)
    
    if similar_code != [] do
      """
      #{base_prompt}
      
      ## Similar Code Examples from Codebase
      
      #{format_rag_examples(similar_code)}
      
      Use these proven patterns from the codebase as reference.
      Follow the same coding style and quality standards.
      """
    else
      base_prompt
    end
  end
  
  defp find_similar_code_examples(task) do
    # Search codebase for similar patterns
    try do
      # Use Store to search knowledge base
      case Store.search_knowledge(task.description, limit: 3) do
        {:ok, results} -> results
        _ -> []
      end
    rescue
      _ -> []
    end
  end
  
  defp format_rag_examples(examples) do
    examples
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {example, idx} ->
      """
      Example #{idx}:
      ```
      #{Map.get(example, :content, Map.get(example, "content", ""))}
      ```
      """
    end)
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
