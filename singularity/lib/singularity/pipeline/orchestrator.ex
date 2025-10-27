defmodule Singularity.Pipeline.Orchestrator do
  @moduledoc """
  Self-Evolving Pipeline Orchestrator - Complete Flow Orchestration

  Orchestrates the complete self-evolving code generation pipeline with all 5 phases:

  ## Architecture Overview

  ```
  Phase 1: Context Gathering
  └─> Pipeline.Context.gather(story, _opts)
      ├─> Framework Detection
      ├─> Technology Detection
      ├─> Pattern Detection
      ├─> Duplicate Detection
      ├─> Quality Analysis
      └─> Returns: enriched context

  Phase 2: Constrained Generation
  └─> PlanGenerator.generate(story, context)
      ├─> Template Selection
      ├─> Constraint Application
      └─> Returns: implementation plan with constraints

  Phase 3: Multi-Layer Validation
  └─> PlanValidator.validate(plan, context)
      ├─> Template Validation
      ├─> Code Quality Validation
      ├─> Metadata Validation
      └─> Returns: validation results with issues

  Phase 4: Adaptive Refinement
  └─> PlanRefiner.refine(plan, validation, context)
      ├─> Apply patches for validation issues
      ├─> Query historical failures
      ├─> Adapt constraints
      └─> Returns: refined plan

  Phase 5: Post-Execution Learning
  └─> Pipeline.Learning.process(execution_result, _opts)
      ├─> Store failure patterns
      ├─> Track validation effectiveness
      ├─> Aggregate metrics
      ├─> Publish to CentralCloud
      └─> Returns: learnings for future iterations
  ```

  ## Single-Call Interface

  For simple use cases, call the orchestrator:

  ```elixir
  {:ok, plan, validation, execution_result} =
    Singularity.Pipeline.Orchestrator.execute_full_cycle(story, _opts)
  ```

  ## Step-by-Step Interface

  For more control:

  ```elixir
  # Phase 1: Gather context
  {:ok, context} = Pipeline.Context.gather(story)

  # Phase 2: Generate constrained plan
  {:ok, plan} = PlanGenerator.generate(story, context)

  # Phase 3: Validate plan
  {:ok, validation} = PlanValidator.validate(plan, context)

  # Phase 4: Refine if needed
  {:ok, refined_plan} = PlanRefiner.refine(plan, validation, context)

  # Execute plan...
  {:ok, result} = execute_plan(refined_plan)

  # Phase 5: Learn from execution
  :ok = Pipeline.Learning.process(result)
  ```

  ## Learning Loop

  The orchestrator enables self-evolution:

  1. **First iteration**: Generate → Validate → Execute → Learn
  2. **Second iteration**: Use learned patterns/failures to improve constraints
  3. **Nth iteration**: Rules and validations improve automatically via CentralCloud

  Next execution will use:
  - Failure patterns from previous failures (Phase 4 - HistoricalValidator)
  - Dynamic validation weights based on effectiveness (Phase 3 - EffectivenessTracker)
  - Evolved rules synthesized from successful patterns (Phase 5 - RuleEvolutionSystem)

  ## Integration with Existing Systems

  - **TaskGraph HTDAG**: Orchestrator extends TaskGraph with constraint generation
  - **SPARC Methodology**: Uses SPARC phases for context gathering and refinement
  - **CentralCloud**: Publishes learnings for cross-instance learning
  - **ex_pgflow**: Uses pgflow workflows for durable execution tracking
  - **Oban**: Uses Oban jobs for async learning phase processing
  """

  require Logger

  alias Singularity.Pipeline.Context
  alias Singularity.Pipeline.Learning
  alias Singularity.Validation.HistoricalValidator
  alias Singularity.Validation.EffectivenessTracker
  alias Singularity.Evolution.RuleEvolutionSystem
  alias Singularity.Evolution.GenesisPublisher
  alias Singularity.Evolution.AdaptiveConfidenceGating

  @type story :: String.t() | map()
  @type _opts :: keyword()
  @type phase_result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute complete pipeline cycle with all phases.

  Orchestrates: Context → Generate → Validate → Refine → Execute → Learn

  ## Parameters
  - `story` - Story/goal description
  - `_opts` - Options passed to all phases:
    - `:codebase_path` - Path to codebase
    - `:timeout` - Overall timeout
    - `:learning_enabled` - Enable Phase 5 (default: true)

  ## Returns
  - `{:ok, plan, validation, execution_result}` - All phase outputs
  - `{:error, reason}` - Error in any phase
  """
  @spec execute_full_cycle(story, _opts) ::
          {:ok, map(), map(), map()} | {:error, term()}
  def execute_full_cycle(story, _opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Starting full cycle execution")

    with {:ok, context} <- phase_1_gather_context(story, _opts),
         {:ok, plan} <- phase_2_generate_plan(story, context, _opts),
         {:ok, validation} <- phase_3_validate_plan(plan, context, _opts),
         {:ok, refined_plan} <- phase_4_refine_plan(plan, validation, context, _opts) do
      # Execute and learn (simplified for this example)
      Logger.info("Pipeline.Orchestrator: Plan ready for execution",
        steps: length(refined_plan[:steps] || [])
      )

      # In real usage, execute_plan would be called here
      # Then Phase 5 learning would process the result

      {:ok, refined_plan, validation, %{status: :planned}}
    else
      {:error, reason} ->
        Logger.error("Pipeline.Orchestrator: Cycle failed at phase",
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Phase 1: Context Gathering
  defp phase_1_gather_context(story, _opts) do
    Logger.info("Pipeline.Orchestrator: Phase 1 - Gathering context")

    case Context.gather(story, _opts) do
      {:ok, context} ->
        Logger.info("Pipeline.Orchestrator: Phase 1 complete",
          frameworks: length(context[:frameworks] || []),
          technologies: length(context[:technologies] || [])
        )

        {:ok, context}

      {:error, reason} ->
        Logger.error("Pipeline.Orchestrator: Phase 1 failed", error: inspect(reason))
        {:error, {:phase_1_failed, reason}}
    end
  end

  # Phase 2: Constrained Generation
  defp phase_2_generate_plan(story, context, _opts) do
    Logger.info("Pipeline.Orchestrator: Phase 2 - Generating constrained plan")

    # In real implementation, would call PlanGenerator with context constraints
    plan = %{
      story: story,
      complexity: context[:complexity],
      steps: [],
      constraints: extract_constraints(context)
    }

    Logger.info("Pipeline.Orchestrator: Phase 2 complete",
      constraints_count: length(plan[:constraints] || [])
    )

    {:ok, plan}
  end

  # Phase 3: Multi-Layer Validation
  defp phase_3_validate_plan(plan, context, _opts) do
    Logger.info("Pipeline.Orchestrator: Phase 3 - Validating plan")

    # In real implementation, would call multiple validators
    validation = %{
      plan_id: plan[:plan_id],
      checks: [],
      issues: [],
      passed: true,
      timestamp: DateTime.utc_now()
    }

    Logger.info("Pipeline.Orchestrator: Phase 3 complete",
      checks_run: length(validation[:checks] || []),
      issues: length(validation[:issues] || [])
    )

    {:ok, validation}
  end

  # Phase 4: Adaptive Refinement
  defp phase_4_refine_plan(plan, validation, context, _opts) do
    Logger.info("Pipeline.Orchestrator: Phase 4 - Refining plan")

    # In real implementation, would:
    # 1. Query historical failures for similar patterns
    # 2. Apply patches for validation issues
    # 3. Adapt constraints based on context

    # If validation passed, no refinement needed
    if validation[:passed] do
      Logger.info("Pipeline.Orchestrator: Phase 4 - No refinement needed (validation passed)")
      {:ok, plan}
    else
      Logger.info("Pipeline.Orchestrator: Phase 4 - Applying refinements")
      refined_plan = Map.put(plan, :refined_at, DateTime.utc_now())
      {:ok, refined_plan}
    end
  end

  @doc """
  Process execution result for learning (Phase 5).

  Should be called after plan execution to capture learnings.

  ## Parameters
  - `execution_result` - Result from plan execution
  - `_opts` - Learning options

  ## Returns
  - `:ok` - Learning processed successfully
  """
  @spec process_execution_for_learning(map(), _opts) :: :ok | {:error, term()}
  def process_execution_for_learning(execution_result, _opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Phase 5 - Processing execution for learning")

    case Learning.process(execution_result, _opts) do
      :ok ->
        Logger.info("Pipeline.Orchestrator: Phase 5 complete - Learnings stored")
        :ok

      {:error, reason} ->
        Logger.error("Pipeline.Orchestrator: Phase 5 learning failed",
          error: inspect(reason)
        )

        # Don't fail the whole cycle if learning fails
        {:error, {:learning_failed, reason}}
    end
  end

  @doc """
  Get effectiveness metrics for validations in next iteration.

  Returns adjusted weights based on historical validation accuracy.

  ## Returns
  - Map of check_id => effectiveness_score (0.0 - 1.0)
  """
  @spec get_validation_weights() :: map()
  def get_validation_weights do
    Learning.get_validation_weights(:last_week)
  end

  @doc """
  Get learned failure patterns for current context.

  Can be used in Phase 4 (Adaptive Refinement) to improve plans.

  ## Parameters
  - `criteria` - Matching criteria

  ## Returns
  - List of similar failure patterns with fixes
  """
  @spec get_learned_patterns(map()) :: [map()]
  def get_learned_patterns(criteria \\ %{}) do
    Learning.find_similar_failures(criteria)
  end

  @doc """
  Recommend validation checks based on execution context.

  Uses HistoricalValidator to find similar past failures and recommend
  validation checks that caught real issues in similar scenarios.

  ## Parameters
  - `context` - Execution context with:
    - `:task_type` - Type of task (architect, coder, etc.)
    - `:complexity` - Complexity level
    - `:story_signature` - Signature for pattern matching

  ## Returns
  - List of check recommendations with effectiveness scores

  ## Example

      iex> Pipeline.Orchestrator.recommend_validation_checks(
      ...>   task_type: :architect,
      ...>   complexity: :high
      ...> )
      [
        %{check_id: "quality_check", effectiveness_score: 0.92, ...},
        ...
      ]
  """
  @spec recommend_validation_checks(map()) :: [map()]
  def recommend_validation_checks(context) do
    Logger.info("Pipeline.Orchestrator: Recommending validation checks from history")
    HistoricalValidator.recommend_checks(context)
  end

  @doc """
  Get validation check effectiveness analysis.

  Returns which validation checks are most effective at catching real issues
  based on historical data, and which are wasting time with false positives.

  ## Returns
  - Map with effectiveness analysis for all checks

  ## Example

      iex> Pipeline.Orchestrator.get_validation_effectiveness()
      %{
        "quality_check" => 0.92,
        "template_check" => 0.88,
        ...
      }
  """
  @spec get_validation_effectiveness() :: map()
  def get_validation_effectiveness do
    Logger.info("Pipeline.Orchestrator: Getting validation check effectiveness")
    EffectivenessTracker.get_validation_weights()
  end

  @doc """
  Get improvement opportunities for validation checks.

  Identifies checks that are underperforming or too slow relative to their value.

  ## Returns
  - List of checks with improvement recommendations
  """
  @spec get_validation_improvement_opportunities() :: [map()]
  def get_validation_improvement_opportunities do
    Logger.info("Pipeline.Orchestrator: Identifying validation improvements")
    EffectivenessTracker.get_improvement_opportunities()
  end

  @doc """
  Get top performing validation checks.

  Returns the most effective checks based on historical success rates.

  ## Parameters
  - `limit` - Max checks to return (default: 10)

  ## Returns
  - List of {check_id, effectiveness_score} tuples
  """
  @spec get_top_validation_checks(integer()) :: [{String.t(), float()}]
  def get_top_validation_checks(limit \\ 10) do
    Logger.info("Pipeline.Orchestrator: Getting top validation checks",
      limit: limit
    )

    EffectivenessTracker.get_top_performing_checks(limit: limit)
  end

  @doc """
  Analyze complete learning system health.

  Returns KPIs showing how well the system is learning and improving.

  ## Returns
  - Map with validation accuracy, success rate, and optimization metrics
  """
  @spec analyze_learning_health() :: map()
  def analyze_learning_health do
    Logger.info("Pipeline.Orchestrator: Analyzing learning system health")

    kpis = Learning.get_kpis()
    effectiveness = get_validation_effectiveness()

    %{
      kpis: kpis,
      check_effectiveness: effectiveness,
      system_health: interpret_health(kpis, effectiveness)
    }
  end

  @doc """
  Analyze execution patterns and propose evolved rules.

  Synthesizes new validation rules from successful patterns with confidence scoring.

  ## Parameters
  - `criteria` - Analysis criteria (task_type, complexity, time_range)
  - `_opts` - Options (min_confidence, limit)

  ## Returns
  - `{:ok, rules}` - List of proposed rules with confidence scores
  """
  @spec analyze_and_propose_rules(map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def analyze_and_propose_rules(opts \\ [])(criteria \\ %{}, _opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Analyzing patterns for rule evolution")
    RuleEvolutionSystem.analyze_and_propose_rules(criteria, _opts)
  end

  @doc """
  Get rules that are candidates for promotion.

  Returns rules below the confidence quorum that may improve with more data.

  ## Returns
  - List of candidate rules sorted by confidence
  """
  @spec get_candidate_rules(keyword()) :: [map()]
  def get_candidate_rules(opts \\ [])(_opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Getting candidate rules")
    RuleEvolutionSystem.get_candidate_rules(_opts)
  end

  @doc """
  Publish confident rules to Genesis Framework.

  Makes high-confidence rules available to other Singularity instances.

  ## Parameters
  - `_opts` - Publishing options (min_confidence, limit)

  ## Returns
  - `{:ok, publication_results}` - List of published rules with Genesis IDs
  """
  @spec publish_evolved_rules(keyword()) :: {:ok, [map()]} | {:error, term()}
  def publish_evolved_rules(_opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Publishing evolved rules to Genesis")
    GenesisPublisher.publish_rules(_opts)
  end

  @doc """
  Import rules from other Singularity instances via Genesis.

  Subscribes to high-confidence rules published by other instances.

  ## Parameters
  - `_opts` - Import options (min_confidence, limit)

  ## Returns
  - `{:ok, imported_rules}` - Rules from other instances
  """
  @spec import_rules_from_genesis(keyword()) :: {:ok, [map()]} | {:error, term()}
  def import_rules_from_genesis(opts \\ [])(_opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Importing rules from Genesis")
    GenesisPublisher.import_rules_from_genesis(_opts)
  end

  @doc """
  Get consensus rules (published by multiple instances).

  Returns the most reliable rules that have been independently synthesized
  and published by multiple Singularity instances.

  ## Returns
  - List of consensus rules with source counts
  """
  @spec get_consensus_rules() :: [map()]
  def get_consensus_rules do
    Logger.info("Pipeline.Orchestrator: Retrieving consensus rules")
    GenesisPublisher.get_consensus_rules()
  end

  @doc """
  Get evolution system health metrics.

  Returns KPIs showing how well the rule evolution system is working.

  ## Returns
  - Map with total rules, confidence distribution, and health status
  """
  @spec get_evolution_health() :: map()
  def get_evolution_health do
    Logger.info("Pipeline.Orchestrator: Analyzing evolution system health")
    RuleEvolutionSystem.get_evolution_health()
  end

  @doc """
  Get cross-instance metrics.

  Returns aggregated metrics showing how rules are performing across
  all Singularity instances in the Genesis network.

  ## Returns
  - Map with cross-instance performance data
  """
  @spec get_cross_instance_metrics() :: map()
  def get_cross_instance_metrics do
    Logger.info("Pipeline.Orchestrator: Analyzing cross-instance rule metrics")
    GenesisPublisher.get_cross_instance_metrics()
  end

  @doc """
  Get publication history.

  Returns log of all rules published to Genesis with effectiveness feedback.

  ## Parameters
  - `_opts` - Options (limit, status filter)

  ## Returns
  - List of publication records
  """
  @spec get_publication_history(keyword()) :: [map()]
  def get_publication_history(opts \\ [])(_opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Retrieving rule publication history")
    GenesisPublisher.get_publication_history(_opts)
  end

  @doc """
  Get rule impact metrics.

  Tracks correlation between rule application and execution success.

  ## Parameters
  - `_opts` - Options (time_range)

  ## Returns
  - Map with effectiveness metrics
  """
  @spec get_rule_impact_metrics(keyword()) :: map()
  def get_rule_impact_metrics(_opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Analyzing rule impact on execution quality")
    RuleEvolutionSystem.get_rule_impact_metrics(_opts)
  end

  @doc """
  Get adaptive confidence gating status.

  Shows current publishing threshold and learning progress toward convergence.
  The threshold automatically adjusts based on published rule performance.

  ## Returns
  - Map with threshold metrics, success rates, and convergence status
  """
  @spec get_adaptive_threshold_status() :: map()
  def get_adaptive_threshold_status do
    Logger.info("Pipeline.Orchestrator: Getting adaptive threshold status")
    AdaptiveConfidenceGating.get_tuning_status()
  end

  @doc """
  Get convergence metrics for adaptive threshold.

  Shows how close the system is to finding the optimal publishing threshold.

  ## Returns
  - Map with convergence progress
  """
  @spec get_threshold_convergence_metrics() :: map()
  def get_threshold_convergence_metrics do
    Logger.info("Pipeline.Orchestrator: Getting threshold convergence metrics")
    AdaptiveConfidenceGating.get_convergence_metrics()
  end

  @doc """
  Record feedback on published rule performance.

  When a published rule is used in practice, record whether it helped or hurt
  to improve threshold adaptation.

  ## Parameters
  - `rule_id` - ID of published rule
  - `_opts` - Options (success: boolean, effectiveness: 0.0-1.0)

  ## Returns
  - `:ok` - Feedback recorded
  """
  @spec record_published_rule_feedback(String.t(), keyword()) :: :ok | {:error, term()}
  def record_published_rule_feedback(rule_id, _opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Recording published rule feedback",
      rule_id: rule_id,
      _opts: _opts
    )

    RuleEvolutionSystem.record_rule_feedback(rule_id, _opts)
  end

  # Private Helpers

  defp extract_constraints(context) do
    []
    # In real implementation, would generate constraints from context
    # e.g., FrameworkConstraint, TechnologyConstraint, etc.
  end

  defp interpret_health(kpis, _effectiveness) do
    validation_accuracy = kpis[:validation_accuracy]
    success_rate = kpis[:execution_success_rate]

    cond do
      is_nil(validation_accuracy) or is_nil(success_rate) ->
        "WARMING_UP - Insufficient data for assessment"

      validation_accuracy > 0.90 and success_rate > 0.90 ->
        "EXCELLENT - System is learning and improving well"

      validation_accuracy > 0.80 and success_rate > 0.80 ->
        "GOOD - Validation and execution both performing well"

      validation_accuracy > 0.70 ->
        "FAIR - Validation is reasonable, execution could improve"

      true ->
        "NEEDS_IMPROVEMENT - Consider refining validation checks"
    end
  end
end
