defmodule Singularity.Agents.CostOptimizedAgent do
  @moduledoc """
  Cost-optimized agent: Rules-first, Cache-second, LLM-fallback.

  Strategy:
  1. Try rules (free, fast) - 90% of cases
  2. Check LLM cache (free) - 5% of cases
  3. Call LLM (expensive) - 5% of cases

  Tracks cost and makes intelligent decisions about when LLM is worth it.
  """

  use GenServer
  require Logger

  alias Singularity.{Autonomy, LLM, ProcessRegistry}
  alias Autonomy.{RuleEngine, Correlation}

  defstruct [
    :id,
    :specialization,
    :workspace,
    :current_branch,
    :status,
    :lifetime_cost,
    :llm_calls_count,
    :rule_calls_count
  ]

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end

  @doc """
  Process a task using hybrid approach.

  Returns:
  - {:autonomous, result, cost: 0.0} - Rules handled it
  - {:llm_assisted, result, cost: 0.0} - Cache hit
  - {:llm_assisted, result, cost: 0.06} - LLM call made
  """
  def process_task(agent_id, task) do
    GenServer.call(via_tuple(agent_id), {:process_task, task}, :infinity)
  end

  def get_stats(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_stats)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id],
      specialization: opts[:specialization],
      workspace: opts[:workspace],
      current_branch: nil,
      status: :idle,
      lifetime_cost: 0.0,
      llm_calls_count: 0,
      rule_calls_count: 0
    }

    Logger.info("Hybrid agent started",
      id: state.id,
      specialization: state.specialization
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:process_task, task}, _from, state) do
    correlation_id = Correlation.start("hybrid_agent_task")

    Logger.info("Processing task",
      agent_id: state.id,
      task_id: task.id,
      correlation_id: correlation_id
    )

    # Phase 1: Try rules first (free)
    {result, cost, method, new_state} = try_rules_first(task, state, correlation_id)

    {:reply, {method, result, cost: cost}, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      id: state.id,
      specialization: state.specialization,
      status: state.status,
      lifetime_cost: state.lifetime_cost,
      llm_calls: state.llm_calls_count,
      rule_calls: state.rule_calls_count,
      cost_per_task:
        if state.llm_calls_count + state.rule_calls_count > 0 do
          state.lifetime_cost / (state.llm_calls_count + state.rule_calls_count)
        else
          0.0
        end
    }

    {:reply, stats, state}
  end

  ## Core Logic

  defp try_rules_first(task, state, correlation_id) do
    # Execute all relevant rules
    rule_category = task_to_rule_category(task)

    # Rule engine handles its own correlation; we keep ours for logs
    rule_result = RuleEngine.execute_category(rule_category, task)

    case rule_result do
      {:autonomous, result} when result.confidence >= 0.9 ->
        # Rules are confident - use their result (FREE)
        Logger.info("Rules handled task autonomously",
          agent_id: state.id,
          confidence: result.confidence,
          correlation_id: correlation_id
        )

        generated_code = apply_rule_result(task, result, state.workspace)

        new_state = %{state | rule_calls_count: state.rule_calls_count + 1, status: :idle}

        {generated_code, 0.0, :autonomous, new_state}

      _ ->
        # Rules not confident - try cache or LLM
        try_llm_with_cache(task, rule_result, state, correlation_id)
    end
  end

  defp try_llm_with_cache(task, rule_result, state, correlation_id) do
    # Check semantic similarity cache
    case check_semantic_cache(task) do
      {:ok, cached_result} ->
        # Cache hit - adapt cached response (FREE)
        Logger.info("LLM cache hit via semantic similarity",
          agent_id: state.id,
          correlation_id: correlation_id
        )

        adapted_code = adapt_cached_response(cached_result, task, state.workspace)

        new_state = %{
          state
          | # Cache is like free rule
            rule_calls_count: state.rule_calls_count + 1,
            status: :idle
        }

        {adapted_code, 0.0, :cached, new_state}

      :miss ->
        # Cache miss - call LLM (EXPENSIVE)
        call_llm(task, rule_result, state, correlation_id)
    end
  end

  defp call_llm(task, rule_result, state, correlation_id) do
    Logger.warning("Calling LLM - will incur cost",
      agent_id: state.id,
      task_id: task.id,
      rule_confidence: rule_result && elem(rule_result, 1).confidence,
      correlation_id: correlation_id
    )

    # Build prompt with context from rules
    prompt = build_llm_prompt(task, rule_result, state.specialization)

    # Select cheapest model that can do the job
    {provider, model} = select_optimal_model(task.complexity)

    # Call LLM
    case LLM.Provider.call(provider, %{
           model: model,
           prompt: prompt,
           system_prompt: system_prompt_for_specialization(state.specialization),
           max_tokens: 4000,
           temperature: 0.7,
           correlation_id: correlation_id
         }) do
      {:ok, response} ->
        # Write code to workspace
        code_result = write_llm_code_to_workspace(response.content, task, state.workspace)

        new_state = %{
          state
          | llm_calls_count: state.llm_calls_count + 1,
            lifetime_cost: state.lifetime_cost + response.cost_usd,
            status: :idle
        }

        Logger.info("LLM call successful",
          agent_id: state.id,
          cost: response.cost_usd,
          tokens: response.tokens_used,
          duration_ms: response.duration_ms,
          correlation_id: correlation_id
        )

        {code_result, response.cost_usd, :llm_assisted, new_state}

      {:error, :budget_exceeded} ->
        # Budget exceeded - fall back to rule result even if low confidence
        Logger.error("Budget exceeded - falling back to rules",
          agent_id: state.id,
          correlation_id: correlation_id
        )

        fallback_code = apply_rule_result(task, elem(rule_result, 1), state.workspace)

        new_state = %{state | rule_calls_count: state.rule_calls_count + 1}

        {fallback_code, 0.0, :fallback, new_state}

      {:error, reason} ->
        Logger.error("LLM call failed",
          agent_id: state.id,
          reason: reason,
          correlation_id: correlation_id
        )

        {:error, reason, 0.0, state}
    end
  end

  ## Helper Functions

  defp task_to_rule_category(task) do
    case task.type do
      :code_generation -> :code_quality
      :refactoring -> :refactoring
      :testing -> :code_quality
      :documentation -> :code_quality
      _ -> :code_quality
    end
  end

  defp apply_rule_result(task, rule_result, workspace) do
    # Rules give us confidence and reasoning, but not actual code
    # Use template-based generation for high-confidence cases
    template = get_template_for_task(task)

    case template do
      nil ->
        # No template - need LLM
        {:need_llm, rule_result}

      template_code ->
        # Fill template with task details
        filled_code = fill_template(template_code, task)

        # Write to workspace
        file_path = Path.join([workspace, task.target_file || "generated.ex"])
        File.write!(file_path, filled_code)

        %{
          file: file_path,
          content: filled_code,
          method: :rule_based,
          confidence: rule_result.confidence
        }
    end
  end

  defp check_semantic_cache(task) do
    # TODO: Use pgvector to find similar past LLM calls
    # For now, simple exact match
    :miss
  end

  defp adapt_cached_response(cached_result, task, workspace) do
    # Adapt previous LLM response to new task
    # (Simple version - could use lightweight LLM for adaptation)
    cached_result
  end

  defp build_llm_prompt(task, rule_result, specialization) do
    rule_context =
      if rule_result do
        """

        Rule-based analysis found:
        - Confidence: #{elem(rule_result, 1).confidence}
        - Reasoning: #{elem(rule_result, 1).reasoning}
        """
      else
        ""
      end

    """
    You are a #{specialization} agent in a self-evolving AI system.

    Task: #{task.description}

    #{if task.acceptance_criteria, do: "Acceptance Criteria:\n#{Enum.join(task.acceptance_criteria, "\n")}", else: ""}
    #{rule_context}

    Generate production-ready code following best practices.
    """
  end

  defp select_optimal_model(complexity) do
    case complexity do
      # Cheapest: $0.075/M tokens
      :simple -> {:gemini, "gemini-1.5-flash"}
      # Mid: $1/M tokens
      :medium -> {:claude, "claude-3-5-haiku-20241022"}
      # Best: $3/M tokens
      :complex -> {:claude, "claude-3-5-sonnet-20241022"}
    end
  end

  defp system_prompt_for_specialization(specialization) do
    case specialization do
      :rust_developer ->
        "You are an expert Rust developer. Write idiomatic, safe, performant Rust code."

      :elixir_developer ->
        "You are an expert Elixir developer. Write functional, concurrent, fault-tolerant code using OTP patterns."

      :frontend_developer ->
        "You are an expert frontend developer. Write modern, accessible, performant UI code."

      _ ->
        "You are an expert software developer. Write clean, maintainable, well-tested code."
    end
  end

  defp write_llm_code_to_workspace(llm_response, task, workspace) do
    # Extract code from LLM response (may include markdown)
    code = extract_code_from_response(llm_response)

    # Determine file path
    file_path = Path.join([workspace, task.target_file || infer_filename(code)])

    # Write code
    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, code)

    %{
      file: file_path,
      content: code,
      method: :llm_generated,
      raw_response: llm_response
    }
  end

  defp extract_code_from_response(response) do
    # Extract code from markdown blocks
    case Regex.run(~r/```(?:\w+)?\n(.*?)```/s, response) do
      [_, code] -> String.trim(code)
      # No markdown, assume entire response is code
      nil -> response
    end
  end

  defp infer_filename(code) do
    cond do
      String.contains?(code, "defmodule") -> "generated.ex"
      String.contains?(code, "fn main()") -> "main.rs"
      String.contains?(code, "function") -> "index.js"
      true -> "generated.txt"
    end
  end

  defp get_template_for_task(_task) do
    # TODO: Load templates from database
    nil
  end

  defp fill_template(template, task) do
    template
    |> String.replace("{{TASK_NAME}}", task.name)
    |> String.replace("{{TASK_DESCRIPTION}}", task.description)
  end

  defp via_tuple(id) do
    {:via, Registry, {ProcessRegistry, {:agent, id}}}
  end
end
