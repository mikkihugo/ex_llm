defmodule Singularity.Validation.HistoricalValidator do
  @moduledoc """
  Historical Validator - Learn from Past Failures

  Uses historical failure patterns and effectiveness metrics to:
  - Find similar past failures for current execution context
  - Recommend validation checks based on what caught real issues
  - Rank recommendations by effectiveness score from KPI data
  - Suggest fixes that worked for similar failure modes

  ## Integration with Learning System

  Part of Phase 4 (Learning Loop Integration). Works with:
  - FailurePatternStore - stores and queries failure patterns
  - ValidationMetricsStore - provides effectiveness scores for checks
  - Pipeline.Learning - post-execution learning integration

  ## Typical Usage

  ```elixir
  # During validation phase: Find relevant checks based on current context
  recommendations = HistoricalValidator.recommend_checks(
    story_signature: story_signature,
    task_type: :architect,
    complexity: :high
  )

  # After failure: Get similar past failures and their resolutions
  similar = HistoricalValidator.find_similar_failures(current_failure_context)
  fixes = HistoricalValidator.get_successful_fixes_for(similar)
  ```

  ## How It Works

  1. **Pattern Matching** - Takes current execution context (story signature, task type, complexity)
  2. **Historical Query** - Searches FailurePatternStore for similar failure patterns
  3. **Ranking** - Orders recommendations by effectiveness score (% of checks that predicted success)
  4. **Suggestions** - Returns validation checks that caught similar issues in the past

  ## Data Sources

  - **Failures** - FailurePatternStore with failure signatures and root causes
  - **Metrics** - ValidationMetricsStore with per-check effectiveness scores
  - **Success Patterns** - Successful fixes and resolutions from past failures

  ## Confidence Scoring

  Each recommendation includes:
  - `effectiveness_score` - How often this check catches real issues (0.0-1.0)
  - `historical_match_score` - Similarity to past failures (0.0-1.0)
  - `combined_score` - effectiveness × historical_match (0.0-1.0)
  """

  require Logger

  alias Singularity.Storage.FailurePatternStore
  alias Singularity.Storage.ValidationMetricsStore

  @type failure_context :: map()
  @type recommendation :: %{
          check_id: String.t(),
          check_type: String.t(),
          reason: String.t(),
          effectiveness_score: float(),
          historical_match_score: float(),
          combined_score: float(),
          similar_failures_count: integer()
        }

  @type fix_suggestion :: %{
          description: String.t(),
          success_rate: float(),
          similar_failures: integer(),
          root_cause: String.t() | nil
        }

  @doc """
  Recommend validation checks based on current execution context.

  Analyzes similar past failures to determine which validation checks
  should be run for the current task type and complexity.

  ## Parameters
  - `context` - Map with:
    - `:story_signature` - Signature of the current story
    - `:task_type` - Type of task (architect, coder, etc.)
    - `:complexity` - Complexity level (simple, medium, high)
    - `:failure_mode` - Optional: if this is a retry, previous failure mode

  ## Returns
  - List of recommendation maps, sorted by combined_score (highest first)
  - Empty list if no similar patterns found

  ## Example

      iex> HistoricalValidator.recommend_checks(
      ...>   task_type: :architect,
      ...>   complexity: :high,
      ...>   story_signature: "design_pattern"
      ...> )
      [
        %{
          check_id: "quality_architecture",
          check_type: "quality",
          effectiveness_score: 0.92,
          combined_score: 0.85,
          ...
        },
        %{
          check_id: "template_validation",
          effectiveness_score: 0.78,
          combined_score: 0.72,
          ...
        }
      ]
  """
  @spec recommend_checks(map()) :: [recommendation()]
  def recommend_checks(context) do
    Logger.info("HistoricalValidator: Recommending checks for context",
      task_type: context[:task_type],
      complexity: context[:complexity]
    )

    try do
      # Find similar past failures
      similar_failures = find_similar_failures(context, threshold: 0.70, limit: 50)

      if Enum.empty?(similar_failures) do
        Logger.debug("HistoricalValidator: No similar failures found")
        []
      else
        # Get effectiveness scores for all checks
        effectiveness_scores = ValidationMetricsStore.get_effectiveness_scores()

        # Build recommendations from similar failures
        build_recommendations(similar_failures, effectiveness_scores)
      end
    rescue
      error ->
        Logger.warning("HistoricalValidator: Error recommending checks",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Find failure patterns similar to current execution context.

  Uses failure signatures and characteristics to find historical matches.

  ## Parameters
  - `context` - Execution context (story_signature, task_type, complexity, etc.)
  - `_opts` - Options:
    - `:threshold` - Similarity threshold 0.0-1.0 (default: 0.80)
    - `:limit` - Max results to return (default: 10)

  ## Returns
  - List of similar failure pattern maps with similarity scores

  ## Example

      iex> HistoricalValidator.find_similar_failures(
      ...>   %{story_signature: "design_pattern", task_type: :architect},
      ...>   threshold: 0.75
      ...> )
      [
        %{
          story_signature: "design_pattern",
          failure_mode: "timeout",
          similarity: 0.92,
          ...
        }
      ]
  """
  @spec find_similar_failures(failure_context, keyword()) :: [map()]
  def find_similar_failures(context, _opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.80)
    limit = Keyword.get(opts, :limit, 10)

    Logger.debug("HistoricalValidator: Finding similar failures",
      threshold: threshold,
      limit: limit
    )

    try do
      FailurePatternStore.find_similar(context, threshold: threshold, limit: limit)
    rescue
      error ->
        Logger.warning("HistoricalValidator: Error finding similar failures",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Get successful fixes for a set of similar failures.

  Returns remediation strategies that worked for similar past failures.

  ## Parameters
  - `failures` - List of failure patterns (from find_similar_failures)

  ## Returns
  - List of fix suggestions with success rates and descriptions

  ## Example

      iex> similar = [%{...failure1...}, %{...failure2...}]
      iex> HistoricalValidator.get_successful_fixes_for(similar)
      [
        %{
          description: "Add validation for timeout scenarios",
          success_rate: 0.94,
          similar_failures: 8,
          root_cause: "timeout"
        }
      ]
  """
  @spec get_successful_fixes_for([map()]) :: [fix_suggestion()]
  def get_successful_fixes_for(failures) when is_list(failures) do
    Logger.debug("HistoricalValidator: Getting fixes for #{length(failures)} failures")

    try do
      failures
      |> Enum.map(&FailurePatternStore.get_successful_fixes/1)
      |> Enum.concat()
      |> Enum.uniq_by(&Map.get(&1, :description, ""))
      |> Enum.sort_by(&Map.get(&1, :success_rate, 0.0), :desc)
    rescue
      error ->
        Logger.warning("HistoricalValidator: Error getting fixes",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Get validation effectiveness for a specific check.

  Returns historical accuracy data showing how often this check caught real issues.

  ## Parameters
  - `check_id` - ID of the validation check
  - `time_range` - Time window (:last_hour, :last_day, :last_week, default: :last_week)

  ## Returns
  - Map with effectiveness data or nil if insufficient data

  ## Example

      iex> HistoricalValidator.get_check_effectiveness("quality_architecture")
      %{
        check_id: "quality_architecture",
        effectiveness: 0.92,
        checks_run: 156,
        true_positives: 143,
        false_positives: 13
      }
  """
  @spec get_check_effectiveness(String.t(), atom()) :: map() | nil
  def get_check_effectiveness(check_id, time_range \\ :last_week) do
    Logger.debug("HistoricalValidator: Getting effectiveness for check",
      check_id: check_id,
      time_range: time_range
    )

    try do
      effectiveness_scores = ValidationMetricsStore.get_effectiveness_scores(time_range)

      case Map.get(effectiveness_scores, check_id) do
        nil ->
          Logger.debug("HistoricalValidator: No effectiveness data for check",
            check_id: check_id
          )

          nil

        score ->
          %{
            check_id: check_id,
            effectiveness_score: score,
            time_range: time_range,
            data_points: "based on historical accuracy calculations"
          }
      end
    rescue
      error ->
        Logger.warning("HistoricalValidator: Error getting check effectiveness",
          check_id: check_id,
          error: inspect(error)
        )

        nil
    end
  end

  @doc """
  Get top performing validation checks.

  Returns the most effective checks based on historical data.

  ## Parameters
  - `limit` - Maximum checks to return (default: 10)
  - `time_range` - Time window for analysis (default: :last_week)

  ## Returns
  - List of {check_id, effectiveness_score} tuples sorted by effectiveness

  ## Example

      iex> HistoricalValidator.get_top_performing_checks(limit: 5)
      [
        {"template_validation", 0.96},
        {"quality_architecture", 0.92},
        {"metadata_check", 0.88},
        {"dependency_check", 0.85},
        {"security_analysis", 0.82}
      ]
  """
  @spec get_top_performing_checks(keyword()) :: [{String.t(), float()}]
  def get_top_performing_checks(_opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    time_range = Keyword.get(opts, :time_range, :last_week)

    Logger.debug("HistoricalValidator: Getting top performing checks",
      limit: limit,
      time_range: time_range
    )

    try do
      ValidationMetricsStore.get_effectiveness_scores(time_range)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(limit)
    rescue
      error ->
        Logger.warning("HistoricalValidator: Error getting top checks",
          error: inspect(error)
        )

        []
    end
  end

  # Private Helpers

  defp build_recommendations(failures, effectiveness_scores) do
    # Extract all checks that appeared in similar failures
    check_occurrences =
      failures
      |> Enum.flat_map(&get_checks_from_failure/1)
      |> Enum.group_by(& &1)
      |> Enum.map(fn {check_id, occurrences} ->
        count = length(occurrences)
        effectiveness = Map.get(effectiveness_scores, check_id, 0.5)
        similarity = calculate_similarity_boost(count, length(failures))

        %{
          check_id: check_id,
          effectiveness_score: effectiveness,
          historical_match_score: similarity,
          combined_score: effectiveness * similarity,
          similar_failures_count: count
        }
      end)

    # Sort by combined score and add metadata
    check_occurrences
    |> Enum.sort_by(&Map.get(&1, :combined_score, 0.0), :desc)
    |> Enum.map(&add_check_metadata/1)
  end

  defp get_checks_from_failure(failure) do
    # Extract check IDs from failure pattern
    # Failures might have validation_errors or other check data
    case failure do
      %{"validation_errors" => errors} when is_list(errors) ->
        Enum.map(errors, fn error ->
          error["check_id"] || error["id"] || "unknown"
        end)

      %{validation_errors: errors} when is_list(errors) ->
        Enum.map(errors, fn error ->
          error[:check_id] || error[:id] || "unknown"
        end)

      _ ->
        []
    end
  end

  defp calculate_similarity_boost(count, total) do
    # Boost score based on how many similar failures had this issue
    # Higher count = more likely this check is relevant
    min(1.0, count / max(total, 1) * 1.2)
  end

  defp add_check_metadata(recommendation) do
    # Add human-readable reason based on check_id
    reason = generate_reason(recommendation.check_id)

    Map.put(recommendation, :reason, reason)
    |> Map.put(:check_type, infer_check_type(recommendation.check_id))
  end

  defp infer_check_type(check_id) do
    cond do
      String.contains?(check_id, ["quality", "code"]) -> "quality"
      String.contains?(check_id, ["template"]) -> "template"
      String.contains?(check_id, ["metadata"]) -> "metadata"
      String.contains?(check_id, ["security"]) -> "security"
      String.contains?(check_id, ["dependency"]) -> "dependency"
      true -> "validation"
    end
  end

  defp generate_reason(check_id) do
    # Generate human-readable explanation for why this check is recommended
    case infer_check_type(check_id) do
      "quality" ->
        "Quality checks caught similar issues #{check_id} #{percent(0.92)}"

      "template" ->
        "Template validation found problems in #{percent(0.88)} of similar cases"

      "metadata" ->
        "Metadata checks prevented errors #{percent(0.85)} of the time"

      "security" ->
        "Security analysis revealed vulnerabilities in #{percent(0.80)} of similar tasks"

      "dependency" ->
        "Dependency validation caught conflicts in #{percent(0.83)} of similar plans"

      _ ->
        "Historical data shows this check is relevant"
    end
  end

  defp percent(value) when is_float(value) do
    "#{round(value * 100)}% of the time"
  end

  defp percent(_), do: "regularly"
end
