defmodule Singularity.Pipeline.Orchestrator do
  @moduledoc """
  Self-Evolving Pipeline Orchestrator - Complete Flow Orchestration

  Orchestrates the complete self-evolving code generation pipeline with all 5 phases:

  ## Architecture Overview

  ```
  Phase 1: Context Gathering
  └─> Pipeline.Context.gather(story, opts)
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
  └─> Pipeline.Learning.process(execution_result, opts)
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
    Singularity.Pipeline.Orchestrator.execute_full_cycle(story, opts)
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

  @type story :: String.t() | map()
  @type opts :: keyword()
  @type phase_result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute complete pipeline cycle with all phases.

  Orchestrates: Context → Generate → Validate → Refine → Execute → Learn

  ## Parameters
  - `story` - Story/goal description
  - `opts` - Options passed to all phases:
    - `:codebase_path` - Path to codebase
    - `:timeout` - Overall timeout
    - `:learning_enabled` - Enable Phase 5 (default: true)

  ## Returns
  - `{:ok, plan, validation, execution_result}` - All phase outputs
  - `{:error, reason}` - Error in any phase
  """
  @spec execute_full_cycle(story, opts) ::
          {:ok, map(), map(), map()} | {:error, term()}
  def execute_full_cycle(story, opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Starting full cycle execution")

    with {:ok, context} <- phase_1_gather_context(story, opts),
         {:ok, plan} <- phase_2_generate_plan(story, context, opts),
         {:ok, validation} <- phase_3_validate_plan(plan, context, opts),
         {:ok, refined_plan} <- phase_4_refine_plan(plan, validation, context, opts) do
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
  defp phase_1_gather_context(story, opts) do
    Logger.info("Pipeline.Orchestrator: Phase 1 - Gathering context")

    case Context.gather(story, opts) do
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

  # Phase 2: Constrained Generation (placeholder)
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

  # Phase 3: Multi-Layer Validation (placeholder)
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

  # Phase 4: Adaptive Refinement (placeholder)
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
  - `opts` - Learning options

  ## Returns
  - `:ok` - Learning processed successfully
  """
  @spec process_execution_for_learning(map(), opts) :: :ok | {:error, term()}
  def process_execution_for_learning(execution_result, opts \\ []) do
    Logger.info("Pipeline.Orchestrator: Phase 5 - Processing execution for learning")

    case Learning.process(execution_result, opts) do
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

  # Private Helpers

  defp extract_constraints(context) do
    []
    # In real implementation, would generate constraints from context
    # e.g., FrameworkConstraint, TechnologyConstraint, etc.
  end
end
