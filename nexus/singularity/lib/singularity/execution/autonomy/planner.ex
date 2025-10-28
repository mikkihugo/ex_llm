defmodule Singularity.Execution.Autonomy.Planner do
  @moduledoc """
  Produces new strategy payloads for self-improving agents using context-aware Lua scripts.

  ## Integration Points

  - Vision management (strategic goals via SafeWorkPlanner)
  - TaskGraph decomposition (hierarchical tasks)
  - SPARC methodology (structured implementation)
  - Pattern mining (learned best practices)
  - Refactoring triggers (need-based evolution)

  ## Lua-Based Code Generation

  Uses modular Lua scripts from `templates_data/prompt_library/agents/`:
  - `vision-task-implementation.lua` - Reads agent structure, similar implementations, learned patterns
  - `refactor-deduplication.lua` - Analyzes duplicated code across files, finds utility examples
  - `refactor-simplification.lua` - Reads complex code, finds well-structured examples, checks git history

  Each script assembles context BEFORE calling the LLM (90% cost savings vs tool-based exploration).
  """

  require Logger

  alias Singularity.Execution.{SafeWorkPlanner, StoryDecomposer}
  alias Singularity.Refactoring.Analyzer
  alias Singularity.Learning.PatternMiner
  alias Singularity.LLM.Service

  @default_reason "stagnation"

  @spec generate_strategy_payload(map(), map()) :: map()
  def generate_strategy_payload(state, context) do
    # Check if there's a vision-driven goal or refactoring need
    case get_current_goal(state) do
      {:vision_task, task} ->
        generate_from_vision_task(state, context, task)

      {:refactoring, refactoring_need} ->
        generate_from_refactoring(state, context, refactoring_need)

      :none ->
        generate_simple_improvement(state, context)
    end
  end

  ## Vision-Driven Generation

  defp get_current_goal(_state) do
    # Priority 1: Check for critical refactoring needs
    case Analyzer.analyze_refactoring_need() do
      [need | _] when need.severity == :critical ->
        {:refactoring, need}

      _ ->
        # Priority 2: Check SAFe vision-driven tasks (WSJF prioritized)
        case SafeWorkPlanner.get_next_work() do
          nil ->
            :none

          feature ->
            {:vision_task, feature}
        end
    end
  end

  defp generate_from_vision_task(state, context, task) do
    Logger.info("Generating code for vision task: #{task.description}")

    # Retrieve learned patterns
    patterns = PatternMiner.retrieve_patterns_for_task(task)

    # Use SPARC to decompose the task
    case StoryDecomposer.decompose_story(task) do
      {:ok, sparc_result} ->
        # Generate implementation code
        code = generate_implementation_code(task, sparc_result, patterns)

        build_payload(state, context, code, %{
          source: :vision_task,
          task_id: task.id,
          task_description: task.description,
          patterns_used: Enum.map(patterns, & &1.name)
        })

      {:error, reason} ->
        Logger.error("SPARC decomposition failed: #{inspect(reason)}")
        generate_simple_improvement(state, context)
    end
  end

  defp generate_from_refactoring(state, context, refactoring_need) do
    Logger.info("Generating refactoring: #{refactoring_need.type}")

    # Generate refactoring code based on need type
    code =
      case refactoring_need.type do
        :code_duplication ->
          generate_deduplication_code(refactoring_need)

        :technical_debt ->
          generate_simplification_code(refactoring_need)

        _ ->
          build_module_simple(state, context)
      end

    build_payload(state, context, code, %{
      source: :refactoring,
      refactoring_type: refactoring_need.type,
      affected_files: length(refactoring_need.affected_files)
    })
  end

  defp generate_simple_improvement(state, context) do
    code = build_module_simple(state, context)
    build_payload(state, context, code, %{source: :simple})
  end

  ## Code Generation Helpers

  defp generate_implementation_code(task, sparc_result, patterns) do
    # Get agent_id from task or generate placeholder
    agent_id = Map.get(task, :agent_id) || Map.get(task, "agent_id") || "unknown"

    # Use Lua script for context-aware code generation
    script_context = %{
      task: task,
      sparc_result: sparc_result,
      patterns: patterns,
      agent_id: agent_id
    }

    case Service.call_with_script(
           "agents/generate-agent-code.lua",
           script_context,
           complexity: :complex,
           task_type: :coder
         ) do
      {:ok, %{content: code}} ->
        extract_elixir_code(code)

      {:error, reason} ->
        Logger.error("Lua script code generation failed: #{inspect(reason)}")
        # Fallback to placeholder
        "defmodule Placeholder do\n  def placeholder, do: :ok\nend"
    end
  end

  defp generate_deduplication_code(refactoring_need) do
    # Use Lua script for context-aware deduplication
    script_context = %{
      refactoring_need: refactoring_need
    }

    case Service.call_with_script(
           "agents/refactor-extract-common.lua",
           script_context,
           complexity: :complex,
           task_type: :architect
         ) do
      {:ok, %{content: code}} ->
        extract_elixir_code(code)

      {:error, reason} ->
        Logger.error("Lua script deduplication generation failed: #{inspect(reason)}")
        "defmodule Placeholder do\n  def placeholder, do: :ok\nend"
    end
  end

  defp generate_simplification_code(refactoring_need) do
    # Use Lua script for context-aware simplification
    script_context = %{
      refactoring_need: refactoring_need
    }

    case Service.call_with_script(
           "agents/refactor-simplify.lua",
           script_context,
           complexity: :complex,
           task_type: :architect
         ) do
      {:ok, %{content: code}} ->
        extract_elixir_code(code)

      {:error, reason} ->
        Logger.error("Lua script simplification generation failed: #{inspect(reason)}")
        "defmodule Placeholder do\n  def placeholder, do: :ok\nend"
    end
  end

  defp extract_elixir_code(text) do
    # Remove markdown code blocks if present
    text
    |> String.replace(~r/```elixir\n/, "")
    |> String.replace(~r/```\n?/, "")
    |> String.trim()
  end

  defp build_module_simple(state, context) do
    agent_id = Map.fetch!(state, :id)
    reason = context |> Map.get(:reason, @default_reason) |> to_string()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    module_base = module_basename(agent_id)
    module_name = "Singularity.Dynamic.Strategy#{module_base}#{unique_suffix()}"
    score = Map.get(context, :score, state[:last_score] || 1.0)
    samples = Map.get(context, :samples, 0)
    stagnation = Map.get(context, :stagnation, 0)

    build_module(module_name, agent_id, reason, timestamp, score, samples, stagnation)
  end

  defp build_payload(state, context, code, extra_metadata) do
    agent_id = Map.fetch!(state, :id)
    reason = context |> Map.get(:reason, @default_reason) |> to_string()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    score = Map.get(context, :score, state[:last_score] || 1.0)
    samples = Map.get(context, :samples, 0)
    stagnation = Map.get(context, :stagnation, 0)

    %{
      "code" => code,
      "module" => extract_module_name(code),
      "metadata" =>
        Map.merge(
          %{
            "agent_id" => agent_id,
            "reason" => reason,
            "generated_at" => timestamp,
            "samples" => samples,
            "score" => score,
            "stagnation_cycles" => stagnation
          },
          extra_metadata
        )
    }
  end

  defp extract_module_name(code) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, code) do
      [_, module_name] -> module_name
      _ -> "Unknown"
    end
  end

  defp module_basename(agent_id) do
    agent_id
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9]/, "_")
    |> String.trim("_")
  end

  defp unique_suffix do
    System.system_time(:millisecond)
  end

  defp build_module(module_name, agent_id, reason, timestamp, score, samples, stagnation) do
    summary =
      "Agent #{agent_id} improved because #{reason} (score=#{Float.round(score, 4)}, " <>
        "samples=#{samples}, stagnation=#{stagnation})"

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Auto-generated strategy for #{agent_id} at #{timestamp}.
      Triggered because: #{reason}.
      \"\"\"

      @summary #{inspect(summary)}

      @doc "Respond to the given input with the current strategy summary."
      @spec respond(term()) :: {:ok, term()} | {:error, term()}
      def respond(input) do
        {:ok, %{summary: @summary, input: input}}
      end
    end
    """
  end

  @doc """
  Estimate effort for a task description.

  ## Parameters
  - `description` - Task description
  - `context` - Additional context for estimation

  ## Returns
  - Effort estimation result
  """
  def estimate_effort(description, context \\ %{}) do
    try do
      # Extract complexity factors
      complexity = analyze_complexity(description, context)

      # Estimate based on historical data and patterns
      effort_estimate = calculate_effort_estimate(complexity, context)

      # Provide confidence level
      confidence = calculate_confidence(complexity)

      {:ok,
       %{
         description: description,
         estimated_effort: effort_estimate,
         complexity_score: complexity.score,
         confidence_level: confidence,
         factors: complexity.factors,
         breakdown: effort_estimate.breakdown
       }}
    rescue
      e ->
        Logger.error("Error estimating effort", error: inspect(e), description: description)
        {:error, :effort_estimation_failed}
    end
  end

  ## Private Functions

  ## Effort Estimation Helpers

  defp analyze_complexity(description, context) do
    factors = []

    # Length-based complexity
    word_count = String.split(description, ~r/\s+/) |> length()

    length_factor =
      cond do
        word_count < 10 -> 1
        word_count < 50 -> 2
        word_count < 100 -> 3
        true -> 4
      end

    factors = [{:length, length_factor} | factors]

    # Technical complexity indicators
    tech_indicators = [
      "api",
      "database",
      "authentication",
      "security",
      "integration",
      "microservice"
    ]

    tech_matches =
      Enum.count(tech_indicators, fn indicator ->
        String.contains?(String.downcase(description), indicator)
      end)

    tech_factor = min(tech_matches + 1, 4)
    factors = [{:technical, tech_factor} | factors]

    # Domain complexity
    domain_keywords = Map.get(context, :domain_keywords, [])

    domain_matches =
      Enum.count(domain_keywords, fn keyword ->
        String.contains?(String.downcase(description), String.downcase(keyword))
      end)

    domain_factor = if domain_matches > 0, do: 2, else: 1
    factors = [{:domain, domain_factor} | factors]

    # Calculate overall score
    score = Enum.reduce(factors, 0, fn {_, factor}, acc -> acc + factor end) / length(factors)

    %{score: score, factors: factors}
  end

  defp calculate_effort_estimate(complexity, context) do
    # Default 1 day
    base_effort = Map.get(context, :base_effort_hours, 8)

    # Adjust based on complexity
    multiplier =
      case complexity.score do
        score when score < 1.5 -> 0.5
        score when score < 2.5 -> 1.0
        score when score < 3.5 -> 1.5
        _ -> 2.0
      end

    estimated_hours = base_effort * multiplier

    # Breakdown by phases
    analysis_hours = estimated_hours * 0.2
    design_hours = estimated_hours * 0.3
    implementation_hours = estimated_hours * 0.4
    testing_hours = estimated_hours * 0.1

    %{
      total_hours: estimated_hours,
      breakdown: %{
        analysis: analysis_hours,
        design: design_hours,
        implementation: implementation_hours,
        testing: testing_hours
      }
    }
  end

  defp calculate_confidence(complexity) do
    # Higher confidence for simpler tasks
    case complexity.score do
      score when score < 2.0 -> :high
      score when score < 3.0 -> :medium
      _ -> :low
    end
  end
end
