defmodule CentralCloud.LLMTeamOrchestrator do
  @moduledoc """
  Orchestrates multi-agent LLM team for pattern validation.

  Workflow:
  1. Analyst discovers pattern (Claude Opus)
  2. Validator validates technical correctness (GPT-4.1)
  3. Critic finds weaknesses (Gemini 2.5 Pro)
  4. Researcher validates against industry (Claude Sonnet)
  5. Coordinator builds consensus (GPT-5-mini)

  All agents run sequentially, with each agent seeing previous assessments.
  Returns final consensus with production-readiness decision.
  """

  require Logger
  alias CentralCloud.TemplateLoader
  alias CentralCloud.Repo
  alias CentralCloud.PatternValidation

  @doc """
  Run full LLM team validation on codebase.

  Returns consensus result with all agent assessments.

  ## Examples

      {:ok, consensus} = LLMTeamOrchestrator.validate_pattern(
        "mikkihugo/singularity",
        code_samples
      )

  ## Options

  - `:pattern_type` - "architecture" | "quality" (default: "architecture")
  - `:skip_cache` - Skip cached validations (default: false)
  """
  def validate_pattern(codebase_id, code_samples, opts \\ []) do
    pattern_type = Keyword.get(opts, :pattern_type, "architecture")
    skip_cache = Keyword.get(opts, :skip_cache, false)

    Logger.info("Starting LLM Team validation for #{codebase_id} (#{pattern_type})")

    # Check cache first (unless skip_cache = true)
    cached_result =
      if !skip_cache do
        case get_cached_validation(codebase_id, pattern_type) do
          {:ok, cached} ->
            Logger.info("Using cached validation for #{codebase_id}")
            {:ok, cached}

          :not_found ->
            nil
        end
      end

    # Return cached result if found
    if cached_result, do: cached_result, else: run_full_validation(codebase_id, code_samples, pattern_type)
  end

  defp run_full_validation(codebase_id, code_samples, pattern_type) do
    # Run full LLM team workflow
    with {:ok, analyst_result} <- run_analyst(code_samples, codebase_id, pattern_type),
         {:ok, validator_result} <- run_validator(analyst_result, codebase_id),
         {:ok, critic_result} <- run_critic(analyst_result, validator_result, codebase_id),
         {:ok, researcher_result} <-
           run_researcher(analyst_result, validator_result, critic_result, codebase_id),
         {:ok, consensus} <-
           run_coordinator(
             analyst_result,
             validator_result,
             critic_result,
             researcher_result,
             codebase_id
           ) do
      # Store results in database
      store_validation_results(
        codebase_id,
        analyst_result,
        validator_result,
        critic_result,
        researcher_result,
        consensus
      )

      {:ok, consensus}
    else
      {:error, reason} = error ->
        Logger.error("LLM Team validation failed: #{inspect(reason)}")
        error
    end
  end

  ## Private Functions - Agent Runners

  defp run_analyst(code_samples, codebase_id, pattern_type) do
    Logger.info("Running Pattern Analyst (Claude Opus)...")

    with {:ok, prompt} <-
           TemplateLoader.load("architecture/llm_team/analyst-discover-pattern.lua", %{
             pattern_type: pattern_type,
             code_samples: code_samples,
             codebase_id: codebase_id
           }),
         {:ok, result} <- call_llm_via_nats(prompt, :claude_opus, :pattern_analyzer) do
      {:ok, result}
    end
  end

  defp run_validator(analyst_result, codebase_id) do
    Logger.info("Running Pattern Validator (GPT-4.1)...")

    pattern = get_first_pattern(analyst_result)

    with {:ok, prompt} <-
           TemplateLoader.load("architecture/llm_team/validator-validate-pattern.lua", %{
             pattern: pattern,
             analyst_assessment: analyst_result,
             codebase_id: codebase_id
           }),
         {:ok, result} <- call_llm_via_nats(prompt, :gpt4_1, :pattern_validator) do
      {:ok, result}
    end
  end

  defp run_critic(analyst_result, validator_result, codebase_id) do
    Logger.info("Running Pattern Critic (Gemini 2.5 Pro)...")

    pattern = get_first_pattern(analyst_result)

    with {:ok, prompt} <-
           TemplateLoader.load("architecture/llm_team/critic-critique-pattern.lua", %{
             pattern: pattern,
             analyst_assessment: analyst_result,
             validator_assessment: validator_result,
             codebase_id: codebase_id
           }),
         {:ok, result} <- call_llm_via_nats(prompt, :gemini_2_5_pro, :pattern_critic) do
      {:ok, result}
    end
  end

  defp run_researcher(analyst_result, validator_result, critic_result, codebase_id) do
    Logger.info("Running Pattern Researcher (Claude Sonnet)...")

    pattern = get_first_pattern(analyst_result)

    with {:ok, prompt} <-
           TemplateLoader.load("architecture/llm_team/researcher-research-pattern.lua", %{
             pattern: pattern,
             analyst_assessment: analyst_result,
             validator_assessment: validator_result,
             critic_assessment: critic_result,
             codebase_id: codebase_id
           }),
         {:ok, result} <- call_llm_via_nats(prompt, :claude_sonnet, :pattern_researcher) do
      {:ok, result}
    end
  end

  defp run_coordinator(analyst_result, validator_result, critic_result, researcher_result, codebase_id) do
    Logger.info("Running Team Coordinator (GPT-5-mini)...")

    pattern = get_first_pattern(analyst_result)

    with {:ok, prompt} <-
           TemplateLoader.load("architecture/llm_team/coordinator-build-consensus.lua", %{
             pattern: pattern,
             analyst_assessment: analyst_result,
             validator_assessment: validator_result,
             critic_assessment: critic_result,
             researcher_assessment: researcher_result,
             codebase_id: codebase_id
           }),
         {:ok, result} <- call_llm_via_nats(prompt, :gpt5_mini, :consensus_builder) do
      {:ok, result}
    end
  end

  ## Private Functions - LLM Integration

  defp call_llm_via_nats(prompt, provider, task_type) do
    # TODO: Call Singularity LLM service via NATS
    # For now, return placeholder
    Logger.warn("TODO: Call LLM via NATS (provider: #{provider}, task: #{task_type})")

    # Placeholder response
    {:ok,
     %{
       "status" => "placeholder",
       "message" => "LLM call via NATS not yet implemented",
       "prompt_preview" => String.slice(prompt, 0, 200),
       "provider" => provider,
       "task_type" => task_type
     }}
  end

  ## Private Functions - Helpers

  defp get_first_pattern(analyst_result) when is_map(analyst_result) do
    case Map.get(analyst_result, "patterns_discovered") do
      [first | _] -> first
      _ -> %{}
    end
  end

  defp get_first_pattern(_), do: %{}

  defp get_cached_validation(codebase_id, pattern_type) do
    # TODO: Query database for recent validation
    # For now, always return not_found
    :not_found
  end

  defp store_validation_results(
         codebase_id,
         analyst_result,
         validator_result,
         critic_result,
         researcher_result,
         consensus
       ) do
    Logger.info("Storing validation results for #{codebase_id}")

    # TODO: Store in pattern_validations table
    # For now, just log
    Logger.debug("""
    Validation results:
    - Analyst score: #{get_in(analyst_result, ["overall_score"]) || "N/A"}
    - Validator score: #{get_in(validator_result, ["technical_score"]) || "N/A"}
    - Critic score: #{get_in(critic_result, ["critical_score"]) || "N/A"}
    - Researcher score: #{get_in(researcher_result, ["evidence_score"]) || "N/A"}
    - Consensus score: #{get_in(consensus, ["consensus_score"]) || "N/A"}
    """)

    :ok
  end
end
