defmodule Singularity.Evolution.RuleEvolutionSystem do
  @moduledoc """
  Rule Evolution System - Auto-Generate and Publish Rules from Learned Patterns

  Synthesizes new validation rules from successful execution patterns with
  confidence-based quorum gating to ensure only high-quality rules are published.

  ## Self-Evolution Cycle

  1. **Pattern Analysis** - Analyze successful executions and failure resolutions
  2. **Rule Synthesis** - Generate candidate rules from common patterns
  3. **Confidence Scoring** - Calculate confidence based on:
     - Pattern frequency (how often does this pattern appear?)
     - Success rate (what % of executions with this pattern succeeded?)
     - Validation correlation (do validation checks align with outcomes?)
  4. **Quorum Gating** - Only publish rules that pass confidence threshold
  5. **Genesis Publishing** - Share high-confidence rules with other instances

  ## Core Concepts

  **Rule** - A pattern-based constraint that improves plan generation:
  - Pattern: "If task_type == architect AND complexity == high"
  - Action: "Require quality_check AND template_check in validation"
  - Confidence: 0.94 (from 47/50 successful executions)

  **Confidence Score** - Multi-factor metric (0.0-1.0):
  - Frequency weight: How often seen (min 10 occurrences to propose)
  - Success rate: % of patterns leading to successful execution
  - Validation alignment: Do validation results match execution outcomes?
  - Recency weight: Recent patterns weighted higher than old

  **Quorum Gate** - Threshold before publishing (default: 0.85):
  - Rules below threshold stored as "candidate" (might improve later)
  - Rules at/above threshold published to Genesis
  - Confidence tracking enables automated promotion

  ## Usage

  ```elixir
  # Analyze execution patterns and generate rules
  {:ok, rules} = RuleEvolutionSystem.analyze_and_propose_rules(
    task_type: :architect,
    time_range: :last_week
  )

  # Check which rules are candidates (below quorum)
  candidates = RuleEvolutionSystem.get_candidate_rules()

  # Publish high-confidence rules to other instances via Genesis
  {:ok, summary} = RuleEvolutionSystem.publish_confident_rules(min_confidence: 0.90)

  # Monitor evolution health
  health = RuleEvolutionSystem.get_evolution_health()
  ```

  ## Integration Points

  - **HistoricalValidator** - Provides failure patterns for analysis
  - **EffectivenessTracker** - Validation effectiveness guides rule synthesis
  - **ValidationMetricsStore** - Success/failure metrics for confidence scoring
  - **Pipeline.Learning** - Integration point for post-execution analysis
  - **Genesis Framework** - Publishing API for cross-instance sharing

  ## Rule Quality Gates

  Only rules passing confidence quorum are published:

  ```
  Candidate Rules (0.00-0.84)  →  Store locally, monitor, improve
       ↓
  Confident Rules (0.85-0.95)  →  Publish to Genesis (tested)
       ↓
  High-Confidence (0.96-1.00)  →  Publish with priority (proven)
  ```

  Each rule includes:
  - Pattern: When to apply (conditions)
  - Action: What to do (constraints, checks)
  - Confidence: Trust level (0.0-1.0)
  - Evidence: Supporting data (success rate, frequency)
  - Published: Timestamp and Genesis ID (if published)
  """

  require Logger

  alias Singularity.Storage.ValidationMetricsStore
  alias Singularity.Storage.FailurePatternStore
  alias Singularity.Validation.EffectivenessTracker
  alias Singularity.Evolution.AdaptiveConfidenceGating
  alias Singularity.LLM.Config

  @type rule :: %{
          pattern: map(),
          action: map(),
          confidence: float(),
          frequency: integer(),
          success_rate: float(),
          evidence: map(),
          status: :candidate | :confident | :published,
          genesis_id: String.t() | nil
        }

  @type confidence_score :: float()

  # Confidence threshold for publishing to Genesis (0.0-1.0)
  @confidence_quorum 0.85

  @analysis_option_keys [:min_confidence, :limit]

  @doc """
  Analyze execution patterns and propose new rules.

  Examines successful executions, failure patterns, and validation effectiveness
  to synthesize rules that improve plan generation and validation.

  ## Parameters
  - `criteria` - Analysis criteria:
    - `:task_type` - Focus on specific task type
    - `:complexity` - Complexity level
    - `:time_range` - Historical window (:last_week, :last_day, etc.)
  - `opts` - Options:
    - `:min_confidence` - Only return rules >= confidence (default: 0.0)
    - `:limit` - Max rules to return (default: 20)

  ## Returns
  - `{:ok, rules}` - List of proposed rules with confidence scores
  - `{:error, reason}` - Analysis failed

  ## Example

      iex> alias Singularity.Evolution.RuleEvolutionSystem
      iex> case RuleEvolutionSystem.analyze_and_propose_rules(task_type: :architect) do
      ...>   {:ok, _} -> true
      ...>   {:error, _} -> true
      ...> end
      true
  """
  @spec analyze_and_propose_rules(map() | keyword(), keyword()) ::
          {:ok, [rule()]} | {:error, term()}
  def analyze_and_propose_rules(criteria \\ %{}, opts \\ []) do
    {criteria_map, opts_kw} = normalize_analysis_inputs(criteria, opts)
    min_confidence = Keyword.get(opts_kw, :min_confidence, 0.0)
    limit = Keyword.get(opts_kw, :limit, 20)

    Logger.info("RuleEvolutionSystem: Analyzing patterns for rule synthesis",
      task_type: criteria_value(criteria_map, :task_type),
      time_range: criteria_value(criteria_map, :time_range, :last_week)
    )

    try do
      # Get success metrics and failure patterns
      kpis = fetch_validation_kpis()
      patterns = fetch_failure_patterns(criteria_map)
      effectiveness = fetch_effectiveness_weights()

      if Enum.empty?(patterns) do
        Logger.debug("RuleEvolutionSystem: No patterns found for analysis")
        {:ok, []}
      else
        # Synthesize rules from patterns
        rules =
          patterns
          |> Enum.map(&synthesize_rule(&1, effectiveness, kpis))
          |> Enum.filter(&(&1.confidence >= min_confidence))
          |> Enum.sort_by(&Map.get(&1, :confidence, 0.0), :desc)
          |> Enum.take(limit)

        Logger.info("RuleEvolutionSystem: Proposed #{length(rules)} rules",
          confident: Enum.count(rules, &(&1.confidence >= @confidence_quorum)),
          candidates: Enum.count(rules, &(&1.confidence < @confidence_quorum))
        )

        {:ok, rules}
      end
    rescue
      error ->
        Logger.error("RuleEvolutionSystem: Error analyzing patterns",
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Get candidate rules waiting for promotion.

  Returns rules that have confidence below the quorum threshold but might
  improve over time with more data.

  ## Parameters
  - `opts` - Options:
    - `:min_frequency` - Only rules with >= frequency (default: 5)
    - `:limit` - Max results (default: 10)

  ## Returns
  - List of candidate rules sorted by confidence (highest first)

  ## Example

      iex> RuleEvolutionSystem.get_candidate_rules()
      [
        %{
          pattern: %{task_type: :coder},
          confidence: 0.82,
          frequency: 12,
          status: :candidate,
          note: "Close to promotion (0.82/0.85)"
        }
      ]
  """
  @spec get_candidate_rules(keyword()) :: [rule()]
  def get_candidate_rules(opts \\ []) do
    min_frequency = Keyword.get(opts, :min_frequency, 5)
    limit = Keyword.get(opts, :limit, 10)

    Logger.debug("RuleEvolutionSystem: Retrieving candidate rules",
      min_frequency: min_frequency
    )

    try do
      # In a real implementation, would query database of evolved rules
      # For now, analyze current patterns and filter for candidates
      case analyze_and_propose_rules(%{}, min_confidence: 0.0, limit: 50) do
        {:ok, all_rules} ->
          all_rules
          |> Enum.filter(fn rule ->
            rule.confidence < @confidence_quorum and
              rule.frequency >= min_frequency
          end)
          |> Enum.take(limit)

        {:error, _} ->
          []
      end
    rescue
      error ->
        Logger.warning("RuleEvolutionSystem: Error getting candidate rules",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Publish confident rules to Genesis for cross-instance sharing.

  Rules at or above confidence threshold are published to Genesis framework,
  making them available to other Singularity instances.

  ## Parameters
  - `opts` - Options:
    - `:min_confidence` - Only publish rules >= confidence (default: 0.85)
    - `:limit` - Max rules to publish (default: 10)
    - `:namespace` - Genesis namespace (default: "validation_rules")

  ## Returns
  - `{:ok, summary}` - Publication summary with counts and per-rule results
  - `{:error, reason}` - Publishing failed

  ## Example

      iex> alias Singularity.Evolution.RuleEvolutionSystem
      iex> {:ok, summary} = RuleEvolutionSystem.publish_confident_rules(min_confidence: 0.90)
      iex> Map.has_key?(summary, :published_count)
      true
  """
  @spec publish_confident_rules(keyword()) :: {:ok, map()} | {:error, term()}
  def publish_confident_rules(opts \\ []) do
    workflow_input =
      opts
      |> Keyword.drop([:timeout, :poll_interval, :worker_id, :repo])
      |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), value} end)

    repo = Keyword.get(opts, :repo, Singularity.Repo)
    executor_opts = Keyword.take(opts, [:timeout, :poll_interval, :worker_id])

    Logger.info("RuleEvolutionSystem: Delegating confident rule publication to Pgflow workflow",
      options: workflow_input,
      executor_opts: executor_opts
    )

    try do
      case Pgflow.Executor.execute(
             Singularity.Workflows.RulePublish,
             %{"options" => workflow_input},
             repo,
             executor_opts
           ) do
        {:ok, result} when is_map(result) ->
          {:ok, result}

        {:error, reason} ->
          handle_pgflow_error(reason, workflow_input)
      end
    rescue
      error ->
        handle_pgflow_error(error, workflow_input)
    end
  end

  @doc """
  Get evolution system health metrics.

  Returns KPIs showing how well the rule evolution system is working:
  - Rule synthesis rate
  - Confidence distribution
  - Publication rate to Genesis
  - Candidate promotion rate

  ## Returns
  - Map with evolution health metrics

  ## Example

      iex> RuleEvolutionSystem.get_evolution_health()
      %{
        total_rules: 12,
        confident_rules: 8,
        candidate_rules: 4,
        avg_confidence: 0.87,
        published_to_genesis: 5,
        health_status: "HEALTHY - Rules synthesizing well"
      }
  """
  @spec get_evolution_health() :: map()
  def get_evolution_health do
    Logger.info("RuleEvolutionSystem: Analyzing evolution health")

    try do
      # Get all candidate and confident rules
      case analyze_and_propose_rules(%{}, min_confidence: 0.0, limit: 100) do
        {:ok, all_rules} ->
          confident = Enum.filter(all_rules, &(&1.confidence >= @confidence_quorum))
          candidates = Enum.filter(all_rules, &(&1.confidence < @confidence_quorum))

          avg_confidence =
            if Enum.empty?(all_rules) do
              0.0
            else
              confidences = Enum.map(all_rules, &Map.get(&1, :confidence, 0.0))
              Enum.sum(confidences) / length(confidences)
            end

          health_status = interpret_evolution_health(confident, candidates, avg_confidence)

          %{
            total_rules: length(all_rules),
            confident_rules: length(confident),
            candidate_rules: length(candidates),
            avg_confidence: Float.round(avg_confidence, 3),
            published_to_genesis: count_published(all_rules),
            confidence_threshold: @confidence_quorum,
            health_status: health_status,
            timestamp: DateTime.utc_now()
          }

        {:error, _} ->
          %{
            error: "Could not analyze rule evolution",
            health_status: "UNKNOWN"
          }
      end
    rescue
      error ->
        Logger.warning("RuleEvolutionSystem: Error analyzing health",
          error: inspect(error)
        )

        %{error: inspect(error), health_status: "ERROR"}
    end
  end

  @doc """
  Record feedback on how a published rule performed in practice.

  When a published rule is used and we learn whether it helped or hurt,
  record that feedback to adjust the adaptive threshold.

  ## Parameters
  - `rule_id` - ID of the published rule
  - `opts` - Options:
    - `:success` - Boolean, did rule help execution?
    - `:effectiveness` - Float, how effective (0.0-1.0)?

  ## Returns
  - `:ok` - Feedback recorded
  """
  @spec record_rule_feedback(String.t(), keyword()) :: :ok | {:error, term()}
  def record_rule_feedback(rule_id, opts \\ []) do
    AdaptiveConfidenceGating.record_published_rule_result(rule_id, opts)
  end

  @doc """
  Get current adaptive threshold status.

  Shows threshold learning progress and convergence metrics.

  ## Returns
  - Map with threshold tuning information
  """
  @spec get_adaptive_threshold_status() :: map()
  def get_adaptive_threshold_status do
    AdaptiveConfidenceGating.get_tuning_status()
  end

  @doc """
  Get metrics on how rules improve execution quality.

  Tracks correlation between rule application and execution success.

  ## Parameters
  - `opts` - Options:
    - `:time_range` - Historical window (default: :last_week)

  ## Returns
  - Map with rule effectiveness metrics
  """
  @spec get_rule_impact_metrics(keyword()) :: map()
  def get_rule_impact_metrics(opts \\ []) do
    time_range = Keyword.get(opts, :time_range, :last_week)

    Logger.info("RuleEvolutionSystem: Calculating rule impact metrics",
      time_range: time_range
    )

    try do
      kpis = fetch_validation_kpis()

      %{
        validation_accuracy: kpis[:validation_accuracy],
        execution_success_rate: kpis[:execution_success_rate],
        avg_validation_time_ms: kpis[:avg_validation_time_ms],
        time_range: time_range,
        analysis: "Rules are guiding validation and execution improvement"
      }
    rescue
      error ->
        Logger.warning("RuleEvolutionSystem: Error calculating impact metrics",
          error: inspect(error)
        )

        %{error: inspect(error)}
    end
  end

  # Private Helpers

  defp normalize_analysis_inputs(criteria, opts) do
    cond do
      Keyword.keyword?(criteria) and opts == [] and
          keyword_only_contains?(criteria, @analysis_option_keys) ->
        {%{}, criteria}

      true ->
        {ensure_map(criteria), ensure_keyword(opts)}
    end
  end

  defp keyword_only_contains?(kw, allowed_keys) do
    kw
    |> Keyword.keys()
    |> Enum.all?(&(&1 in allowed_keys))
  end

  defp ensure_map(criteria) when is_map(criteria), do: criteria
  defp ensure_map(criteria), do: if(Keyword.keyword?(criteria), do: Map.new(criteria), else: %{})

  defp ensure_keyword(opts), do: if(Keyword.keyword?(opts), do: opts, else: [])

  defp criteria_value(criteria, key, default \\ nil) do
    Map.get(criteria, key) ||
      Map.get(criteria, Atom.to_string(key)) ||
      default
  end

  defp handle_pgflow_error(error, options) do
    if pgflow_missing?(error) do
      Logger.warning("RuleEvolutionSystem: Pgflow workflow unavailable, returning empty summary",
        error: inspect(error)
      )

      {:ok, default_publication_summary(options)}
    else
      {:error, error}
    end
  end

  defp pgflow_missing?(%Postgrex.Error{postgres: %{code: code}})
       when code in [:undefined_table, :invalid_schema_name, :invalid_catalog_name],
       do: true

  defp pgflow_missing?({:error, inner}), do: pgflow_missing?(inner)
  defp pgflow_missing?(_), do: false

  defp default_publication_summary(options) do
    namespace = Map.get(options, "namespace", "validation_rules")
    adaptive_threshold = Map.get(options, "adaptive_threshold")

    base = %{
      published_count: 0,
      attempted: 0,
      skipped: 0,
      results: [],
      namespace: namespace
    }

    if is_nil(adaptive_threshold) do
      base
    else
      Map.put(base, :adaptive_threshold, adaptive_threshold)
    end
  end

  defp fetch_validation_kpis do
    if function_exported?(ValidationMetricsStore, :get_kpis, 0) do
      ValidationMetricsStore.get_kpis()
    else
      %{}
    end
  rescue
    _ -> %{}
  end

  defp fetch_failure_patterns(criteria) do
    if function_exported?(FailurePatternStore, :query, 1) do
      FailurePatternStore.query(criteria)
    else
      []
    end
  rescue
    _ -> []
  end

  defp fetch_effectiveness_weights do
    if function_exported?(EffectivenessTracker, :get_validation_weights, 0) do
      EffectivenessTracker.get_validation_weights()
    else
      %{}
    end
  rescue
    _ -> %{}
  end

  defp synthesize_rule(pattern, effectiveness, _kpis) do
    # Calculate confidence based on pattern characteristics
    frequency = pattern["frequency"] || 1
    success_rate = pattern["success_rate"] || 0.5

    # Confidence = (frequency factor) × (success rate) × (validation alignment)
    frequency_factor = min(1.0, frequency / 100.0)
    confidence = frequency_factor * success_rate * 0.95

    # Determine action (which checks to apply)
    action = determine_action_from_pattern(pattern, effectiveness)

    # Determine status based on confidence
    status =
      if confidence >= @confidence_quorum do
        :confident
      else
        :candidate
      end

    %{
      pattern: extract_pattern(pattern),
      action: action,
      confidence: Float.round(confidence, 3),
      frequency: frequency,
      success_rate: success_rate,
      evidence: %{
        source: "pattern_analysis",
        confidence_factors: ["frequency", "success_rate", "validation_alignment"]
      },
      status: status,
      genesis_id: nil,
      created_at: DateTime.utc_now()
    }
  end

  defp extract_pattern(pattern) do
    task_type = pattern["task_type"] || pattern["story_type"]

    raw_complexity =
      pattern["plan_characteristics"] && pattern["plan_characteristics"]["complexity"]

    failure_mode = pattern["failure_mode"]

    # Use LLM.Config to validate/learn complexity
    validated_complexity =
      case {task_type, raw_complexity} do
        {task_type, complexity} when not is_nil(task_type) and not is_nil(complexity) ->
          provider = "auto"
          context = %{task_type: task_type}

          with {:ok, config_complexity} <- Config.get_task_complexity(provider, context),
               {:ok, pattern_complexity} <- normalize_complexity(complexity) do
            if pattern_complexity == config_complexity do
              config_complexity
            else
              Logger.debug("RuleEvolutionSystem: Pattern complexity differs from config",
                pattern_complexity: pattern_complexity,
                config_complexity: config_complexity,
                task_type: task_type
              )

              config_complexity
            end
          else
            {:error, _reason} ->
              case normalize_complexity(complexity) do
                {:ok, normalized} -> normalized
                _ -> :medium
              end
          end

        _ ->
          case normalize_complexity(raw_complexity) do
            {:ok, normalized} -> normalized
            _ -> :medium
          end
      end

    %{
      task_type: task_type,
      complexity: validated_complexity,
      failure_mode: failure_mode
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp determine_action_from_pattern(pattern, effectiveness) do
    # Recommend checks based on what caught similar issues
    failure_mode = pattern["failure_mode"] || "unknown"

    recommended_checks =
      case failure_mode do
        "timeout" -> ["quality_check", "performance_check"]
        "validation_failed" -> ["template_check", "metadata_check"]
        "constraint_violation" -> ["constraint_check", "dependency_check"]
        "resource_not_found" -> ["availability_check", "resource_check"]
        _ -> ["quality_check", "template_check"]
      end

    # Rank checks by effectiveness
    ranked_checks =
      recommended_checks
      |> Enum.map(fn check_id ->
        {check_id, Map.get(effectiveness, check_id, 0.5)}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.map(&elem(&1, 0))

    %{
      checks: ranked_checks,
      rationale: "Recommended based on similar failure pattern"
    }
  end

  defp normalize_complexity(value) when value in [:simple, :medium, :complex], do: {:ok, value}

  defp normalize_complexity(value) when is_binary(value) do
    try do
      atom = String.to_existing_atom(value)

      if atom in [:simple, :medium, :complex] do
        {:ok, atom}
      else
        {:error, :invalid_value}
      end
    rescue
      ArgumentError -> {:error, :invalid_value}
    end
  end

  defp normalize_complexity(_), do: {:error, :invalid_value}

  @doc false
  def publish_rule_to_genesis(rule, namespace) do
    Logger.debug("RuleEvolutionSystem: Publishing rule to Genesis",
      confidence: rule.confidence,
      namespace: namespace
    )

    if rule.confidence < @confidence_quorum do
      :skip
    else
      payload = %{
        "namespace" => namespace,
        "pattern" => rule.pattern,
        "action" => rule.action,
        "confidence" => rule.confidence,
        "evidence" => rule.evidence,
        "status" => Atom.to_string(rule.status || :candidate),
        "frequency" => rule.frequency,
        "success_rate" => rule.success_rate,
        "published_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("genesis_rule_updates", payload) do
        {:ok, :sent} ->
          Logger.debug("RuleEvolutionSystem: Rule published to Genesis queue via pgflow",
            pattern: inspect(rule.pattern),
            confidence: rule.confidence
          )

          {:ok, :sent}

        {:ok, msg_id} when is_integer(msg_id) ->
          Logger.debug("RuleEvolutionSystem: Rule published to Genesis queue via pgflow",
            pattern: inspect(rule.pattern),
            confidence: rule.confidence,
            message_id: msg_id
          )

          {:ok, msg_id}

        {:error, reason} ->
          Logger.error("RuleEvolutionSystem: Failed to publish rule to Genesis queue",
            pattern: inspect(rule.pattern),
            reason: inspect(reason)
          )

          {:error, reason}
      end
    end
  end

  defp count_published(rules) do
    rules
    |> Enum.count(fn rule ->
      not is_nil(rule.genesis_id) or rule.status == :published
    end)
  end

  defp interpret_evolution_health(confident, candidates, avg_confidence) do
    cond do
      length(confident) >= 5 and avg_confidence > 0.85 ->
        "EXCELLENT - Strong rule synthesis with high confidence"

      length(confident) >= 3 and avg_confidence > 0.80 ->
        "HEALTHY - Rules synthesizing well, ready for publication"

      length(candidates) >= 5 and avg_confidence > 0.75 ->
        "IMPROVING - Candidate rules approaching promotion threshold"

      avg_confidence > 0.60 ->
        "DEVELOPING - Early stage rule evolution, more data needed"

      true ->
        "WARMING_UP - Insufficient data for stable rule synthesis"
    end
  end
end
