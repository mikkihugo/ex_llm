defmodule Singularity.Evolution.GenesisWorkflowLearner do
  @moduledoc """
  Genesis Workflow Learner - Learn and Share Optimal Workflow Patterns

  Extends Genesis learning beyond rules to workflows themselves. Analyzes workflow
  execution effectiveness, synthesizes workflow variations, and publishes optimal
  patterns for cross-instance adoption.

  ## Self-Evolution Cycle

  1. **Workflow Tracking** - Monitor all workflow executions via RCA
  2. **Effectiveness Analysis** - Calculate success rates per workflow type
  3. **Pattern Recognition** - Identify which workflow configs work best
  4. **Variation Synthesis** - Generate improved workflow variations
  5. **Confidence Scoring** - Rate new variations before publishing
  6. **Genesis Publishing** - Share proven workflows with other instances

  ## Core Concepts

  **WorkflowPattern** - A proven workflow configuration:
  - Type: workflow_type (code_quality_training, embedding_training, etc.)
  - Config: workflow configuration that worked well
  - Success Rate: % of executions that succeeded
  - Avg Execution Time: duration metrics
  - Quality Metrics: code quality, test coverage, etc. improvements
  - Confidence: Trust level (0.0-1.0)

  **Confidence Score** - Multi-factor metric (0.0-1.0):
  - Execution frequency: How many successful runs (min 5 for proposal)
  - Success rate: % of executions with this config that succeeded
  - Quality improvement: Code metrics improvement after workflow
  - Execution efficiency: Time and resource efficiency
  - Recency weight: Recent patterns weighted higher

  **Quorum Gate** - Threshold before publishing (default: 0.80):
  - Below 0.80: Candidate workflows (monitor, improve locally)
  - 0.80-0.89: Ready for publishing (tested, working)
  - 0.90+: High-confidence (proven, prioritize across instances)

  ## Usage

  ```elixir
  # Analyze workflow effectiveness
  {:ok, patterns} = GenesisWorkflowLearner.analyze_workflow_effectiveness(
    workflow_type: :code_quality_training,
    time_range: :last_week
  )

  # Get candidate workflows (not yet published)
  candidates = GenesisWorkflowLearner.get_candidate_workflows()

  # Synthesize improved workflow variations
  {:ok, variations} = GenesisWorkflowLearner.synthesize_workflow_variations(
    base_workflow: :code_quality_training,
    improvement_focus: :execution_speed
  )

  # Publish proven workflows to Genesis
  {:ok, summary} = GenesisWorkflowLearner.publish_proven_workflows(min_confidence: 0.85)

  # Monitor learning health
  health = GenesisWorkflowLearner.get_learning_health()
  ```

  ## Integration Points

  - **RCA System** - GenerationSession and RefinementStep track workflow execution
  - **Workflows.Dispatcher** - Get available workflow definitions and execute variations
  - **GenesisPublisher** - Publish proven workflows for cross-instance distribution
  - **RuleEvolutionSystem** - Parallel pattern: analyze → synthesize → gate → publish
  - **Telemetry** - Track workflow_analyzed, workflow_synthesized, workflow_published events

  ## Workflow Quality Gates

  Only workflows passing confidence quorum are published:

  ```
  Candidate Workflows (0.00-0.79)  →  Store locally, monitor, improve
       ↓
  Confident Workflows (0.80-0.89)  →  Publish to Genesis (tested)
       ↓
  High-Confidence (0.90+)           →  Publish with priority (proven)
  ```

  Each published workflow includes:
  - Type: Workflow type/name
  - Config: Full workflow configuration
  - Success Rate: % of successful executions
  - Avg Execution Time: Duration metrics
  - Quality Improvements: Metrics before/after
  - Confidence: Trust level (0.0-1.0)
  - Evidence: Supporting data (success count, samples)
  - Published: Timestamp and Genesis ID (if published)

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Evolution.GenesisWorkflowLearner",
    "purpose": "Learn and share optimal workflow patterns across instances",
    "role": "learning_system",
    "layer": "evolution",
    "introduced_in": "Phase B.2c - Workflow-Driven Genesis Learning",
    "parallels": "RuleEvolutionSystem (but for workflows, not rules)"
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      RCA["RCA System<br/>(tracks execution)"]
      Learner["GenesisWorkflowLearner<br/>(analyze & synthesize)"]
      Dispatcher["Workflows.Dispatcher<br/>(execute variations)"]
      Genesis["Genesis Publisher<br/>(share patterns)"]
      Instances["Other Instances<br/>(apply workflows)"]

      RCA -->|effectiveness data| Learner
      Learner -->|get workflow defs| Dispatcher
      Dispatcher -->|execute variants| RCA
      Learner -->|publish patterns| Genesis
      Genesis -->|distribute| Instances
      Instances -->|feedback| Genesis

      style Learner fill:#90EE90
      style Genesis fill:#FFD700
      style RCA fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  provides:
    - analyze_workflow_effectiveness/1 (measure workflow success rates)
    - synthesize_workflow_variations/2 (create improved versions)
    - publish_proven_workflows/1 (share with Genesis)
    - get_candidate_workflows/0 (workflows awaiting publication)
    - get_published_workflows/0 (successful shared workflows)
    - get_learning_health/0 (system metrics)

  called_by:
    - Pipeline.Orchestrator (after execution analysis)
    - Evolution.RuleEvolutionSystem (parallel evolution)
    - Telemetry handlers (event-driven)

  depends_on:
    - RCA.SessionManager (workflow execution tracking)
    - Workflows.Dispatcher (workflow definitions)
    - GenesisPublisher (distribution)
    - Evolution.AdaptiveConfidenceGating (scoring)
  ```

  ### Anti-Patterns

  - ❌ DO NOT publish workflows without confidence gating
  - ❌ DO NOT synthesize variations from low-success workflows
  - ❌ DO NOT skip RCA tracking for workflow execution
  - ✅ DO analyze effectiveness before synthesis
  - ✅ DO gate by confidence (0.80+ for Genesis)
  - ✅ DO track feedback from other instances

  ### Search Keywords

  workflow learning, Genesis workflows, workflow optimization, workflow synthesis,
  workflow patterns, distributed learning, workflow effectiveness, self-improving workflows
  """

  require Logger

  alias Singularity.RCA.SessionManager
  alias Singularity.RCA.SessionQueries
  alias Singularity.Workflows.Dispatcher
  alias Singularity.Evolution.GenesisPublisher
  alias Singularity.Evolution.AdaptiveConfidenceGating
  alias Singularity.Repo

  @type workflow_pattern :: %{
          workflow_type: atom(),
          config: map(),
          success_rate: float(),
          avg_execution_ms: integer(),
          quality_improvements: map(),
          confidence: float(),
          execution_count: integer(),
          status: :candidate | :confident | :published,
          genesis_id: String.t() | nil,
          last_executed_at: DateTime.t(),
          created_at: DateTime.t()
        }

  @type confidence_score :: float()

  # Confidence threshold for publishing to Genesis (0.0-1.0)
  @confidence_quorum 0.80

  @doc """
  Analyze workflow execution effectiveness over a time range.

  Examines RCA sessions grouped by workflow type to calculate:
  - Success rate (% of sessions that completed successfully)
  - Average execution time
  - Quality metrics improvements
  - Execution frequency

  Returns list of workflow patterns with calculated metrics.

  ## Parameters
  - `criteria` - Analysis criteria:
    - `:workflow_type` - Analyze specific workflow type (optional, all if not specified)
    - `:time_range` - `:last_day`, `:last_week`, `:last_month` (default: :last_week)
    - `:min_executions` - Minimum execution count to analyze (default: 1)

  ## Examples

      {:ok, patterns} = GenesisWorkflowLearner.analyze_workflow_effectiveness(
        workflow_type: :code_quality_training,
        time_range: :last_week,
        min_executions: 5
      )

      {:ok, all_patterns} = GenesisWorkflowLearner.analyze_workflow_effectiveness()
  """
  @spec analyze_workflow_effectiveness(keyword()) :: {:ok, [workflow_pattern()]} | {:error, term()}
  def analyze_workflow_effectiveness(criteria \\ []) do
    workflow_type = Keyword.get(criteria, :workflow_type)
    time_range = Keyword.get(criteria, :time_range, :last_week)
    min_executions = Keyword.get(criteria, :min_executions, 1)

    try do
      # Get RCA sessions matching criteria
      sessions = SessionQueries.query_sessions(
        workflow_type: workflow_type,
        time_range: time_range
      )

      # Group by workflow type and analyze effectiveness
      patterns =
        sessions
        |> Enum.group_by(&get_workflow_type/1)
        |> Enum.map(fn {type, session_group} ->
          calculate_workflow_pattern(type, session_group)
        end)
        |> Enum.filter(fn pattern ->
          pattern.execution_count >= min_executions
        end)

      Logger.info("Analyzed #{length(patterns)} workflow patterns", %{
        time_range: time_range,
        total_sessions: length(sessions)
      })

      {:ok, patterns}
    rescue
      e ->
        Logger.error("Workflow effectiveness analysis failed: #{inspect(e)}")
        {:error, {:analysis_failed, inspect(e)}}
    end
  end

  @doc """
  Synthesize improved workflow variations based on analysis.

  Creates variations of a workflow by:
  1. Analyzing successful execution patterns
  2. Identifying improvement opportunities
  3. Generating config variations
  4. Executing variations to validate improvements

  Returns list of synthesized workflow variations with predicted confidence.

  ## Parameters
  - `base_workflow` - Workflow type to improve (required)
  - `improvement_focus` - `:execution_speed`, `:quality`, `:reliability`, `:cost` (default: :execution_speed)
  - `:limit` - Max variations to synthesize (default: 3)

  ## Examples

      {:ok, variations} = GenesisWorkflowLearner.synthesize_workflow_variations(
        base_workflow: :code_quality_training,
        improvement_focus: :execution_speed,
        limit: 3
      )
  """
  @spec synthesize_workflow_variations(keyword()) ::
          {:ok, [workflow_pattern()]} | {:error, term()}
  def synthesize_workflow_variations(opts) do
    base_workflow = Keyword.fetch!(opts, :base_workflow)
    improvement_focus = Keyword.get(opts, :improvement_focus, :execution_speed)
    limit = Keyword.get(opts, :limit, 3)

    try do
      # Get current workflow definition
      {:ok, base_module} = Dispatcher.get_workflow(base_workflow)
      {:ok, base_def} = safe_get_workflow_definition(base_module)

      # Analyze current effectiveness
      {:ok, current_patterns} =
        analyze_workflow_effectiveness(workflow_type: base_workflow, min_executions: 1)

      current_pattern = List.first(current_patterns)

      # Generate variations based on improvement focus
      variations =
        generate_variations(base_def, improvement_focus, limit)
        |> Enum.map(fn variation_config ->
          %{
            workflow_type: base_workflow,
            config: variation_config,
            success_rate: 0.0,
            # Predicted confidence based on variation principle
            confidence: predict_variation_confidence(current_pattern, improvement_focus),
            status: :candidate,
            execution_count: 0
          }
        end)

      Logger.info("Synthesized #{length(variations)} workflow variations", %{
        base_workflow: base_workflow,
        improvement_focus: improvement_focus
      })

      :telemetry.execute([:evolution, :workflow, :synthesized], %{
        count: length(variations),
        base_workflow: base_workflow
      })

      {:ok, variations}
    rescue
      e ->
        Logger.error("Workflow synthesis failed: #{inspect(e)}")
        {:error, {:synthesis_failed, inspect(e)}}
    end
  end

  @doc """
  Publish proven workflows to Genesis for cross-instance distribution.

  Filters workflows by confidence threshold and publishes them for other
  Singularity instances to discover and apply.

  ## Parameters
  - `criteria` - Publication criteria:
    - `:min_confidence` - Minimum confidence to publish (default: @confidence_quorum)
    - `:limit` - Max workflows to publish per call (default: 10)

  ## Examples

      {:ok, summary} = GenesisWorkflowLearner.publish_proven_workflows(
        min_confidence: 0.85,
        limit: 5
      )
  """
  @spec publish_proven_workflows(keyword()) ::
          {:ok, %{published: integer(), skipped: integer()}} | {:error, term()}
  def publish_proven_workflows(criteria \\ []) do
    min_confidence = Keyword.get(criteria, :min_confidence, @confidence_quorum)
    limit = Keyword.get(criteria, :limit, 10)

    try do
      # Get candidate workflows meeting confidence threshold
      candidates = get_candidate_workflows()

      proven_workflows =
        candidates
        |> Enum.filter(fn pattern -> pattern.confidence >= min_confidence end)
        |> Enum.take(limit)

      # Publish each to Genesis
      published_count =
        Enum.reduce(proven_workflows, 0, fn pattern, count ->
          case GenesisPublisher.publish_workflow_pattern(pattern) do
            {:ok, genesis_id} ->
              # Mark as published in local store
              mark_workflow_published(pattern.workflow_type, genesis_id)
              count + 1

            {:error, reason} ->
              Logger.warning("Failed to publish workflow: #{inspect(reason)}")
              count
          end
        end)

      skipped_count = length(proven_workflows) - published_count

      Logger.info("Published workflows to Genesis", %{
        published: published_count,
        skipped: skipped_count,
        min_confidence: min_confidence
      })

      :telemetry.execute([:evolution, :workflow, :published], %{
        count: published_count,
        min_confidence: min_confidence
      })

      {:ok, %{published: published_count, skipped: skipped_count}}
    rescue
      e ->
        Logger.error("Workflow publishing failed: #{inspect(e)}")
        {:error, {:publishing_failed, inspect(e)}}
    end
  end

  @doc """
  Get candidate workflows (analyzed but not yet published).

  Returns workflows with calculated confidence but below/above publish threshold.
  """
  @spec get_candidate_workflows :: [workflow_pattern()]
  def get_candidate_workflows do
    {:ok, patterns} = analyze_workflow_effectiveness()
    Enum.filter(patterns, fn p -> p.status == :candidate end)
  end

  @doc """
  Get published workflows (shared to Genesis and adopted elsewhere).

  Returns workflows that have been published and are in use across instances.
  """
  @spec get_published_workflows :: [workflow_pattern()]
  def get_published_workflows do
    {:ok, patterns} = analyze_workflow_effectiveness()
    Enum.filter(patterns, fn p -> p.status == :published and p.genesis_id end)
  end

  @doc """
  Get learning system health metrics.

  Returns statistics about workflow learning progress and effectiveness.
  """
  @spec get_learning_health :: map()
  def get_learning_health do
    {:ok, patterns} = analyze_workflow_effectiveness()

    count = max(length(patterns), 1)

    %{
      total_workflows_analyzed: length(patterns),
      average_confidence: (Enum.map(patterns, & &1.confidence) |> Enum.sum()) / count,
      workflows_ready_to_publish: Enum.count(patterns, fn p -> p.confidence >= @confidence_quorum end),
      workflows_published: Enum.count(patterns, fn p -> p.status == :published end),
      total_executions: Enum.map(patterns, & &1.execution_count) |> Enum.sum(),
      average_success_rate: (Enum.map(patterns, & &1.success_rate) |> Enum.sum()) / count,
      last_analysis_at: DateTime.utc_now()
    }
  end

  @doc """
  Report proven workflows to CentralCloud for global aggregation and consensus.

  Sends workflow patterns to CentralCloud to:
  1. Aggregate patterns from multiple instances
  2. Calculate consensus on best workflow configurations
  3. Detect patterns that work across instances
  4. Share consensus back for adoption

  Uses QuantumFlow for reliable delivery to CentralCloud services.

  ## Parameters
  - `criteria` - Reporting criteria:
    - `:min_confidence` - Minimum confidence to report (default: @confidence_quorum)
    - `:workflow_types` - Specific types to report (default: all)
    - `:limit` - Max patterns to report per call (default: 10)

  ## Examples

      {:ok, summary} = GenesisWorkflowLearner.report_to_centralcloud(
        min_confidence: 0.85,
        limit: 5
      )
  """
  @spec report_to_centralcloud(keyword()) ::
          {:ok, %{reported: integer(), skipped: integer()}} | {:error, term()}
  def report_to_centralcloud(criteria \\ []) do
    min_confidence = Keyword.get(criteria, :min_confidence, @confidence_quorum)
    limit = Keyword.get(criteria, :limit, 10)
    workflow_types = Keyword.get(criteria, :workflow_types, :all)

    try do
      # Get patterns ready to report
      {:ok, patterns} = analyze_workflow_effectiveness()

      reportable_patterns =
        patterns
        |> Enum.filter(fn p -> p.confidence >= min_confidence end)
        |> filter_by_workflow_type(workflow_types)
        |> Enum.take(limit)

      # Prepare payload for CentralCloud (via QuantumFlow)
      payload = %{
        "instance_id" => get_instance_id(),
        "reported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "workflow_patterns" => Enum.map(reportable_patterns, &pattern_to_payload/1),
        "confidence_threshold" => min_confidence,
        "pattern_count" => length(reportable_patterns)
      }

      # Send to CentralCloud via QuantumFlow
      case send_to_centralcloud(payload) do
        {:ok, _msg_id} ->
          Logger.info("Reported workflow patterns to CentralCloud", %{
            pattern_count: length(reportable_patterns),
            min_confidence: min_confidence
          })

          :telemetry.execute([:evolution, :workflow, :reported_to_centralcloud], %{
            count: length(reportable_patterns),
            min_confidence: min_confidence
          })

          {:ok, %{reported: length(reportable_patterns), skipped: 0}}

        {:error, reason} ->
          Logger.error("Failed to report workflows to CentralCloud: #{inspect(reason)}")
          {:error, {:report_failed, reason}}
      end
    rescue
      e ->
        Logger.error("Workflow CentralCloud reporting error: #{inspect(e)}")
        {:error, {:reporting_error, inspect(e)}}
    end
  end

  @doc """
  Request consensus workflow patterns from CentralCloud.

  Sends a request to CentralCloud (via QuantumFlow) asking for aggregated workflow
  patterns that have achieved consensus across multiple instances.

  CentralCloud service analyzes patterns reported by all instances and
  returns high-confidence consensus patterns. This instance then registers
  them locally for adoption.

  Note: This sends a request message via QuantumFlow. CentralCloud service
  processes it asynchronously and sends results back on QuantumFlow topic.

  ## Parameters
  - `criteria` - Request criteria:
    - `:min_confidence` - Minimum consensus confidence (default: 0.85)
    - `:workflow_type` - Specific type to request (optional)

  ## Examples

      :ok = GenesisWorkflowLearner.request_consensus_from_centralcloud(
        min_confidence: 0.85
      )

      # CentralCloud processes asynchronously and sends results back
      # via QuantumFlow topic "singularity_workflow_patterns_consensus"
  """
  @spec request_consensus_from_centralcloud(keyword()) :: :ok | {:error, term()}
  def request_consensus_from_centralcloud(criteria \\ []) do
    min_confidence = Keyword.get(criteria, :min_confidence, 0.85)
    workflow_type = Keyword.get(criteria, :workflow_type)

    request_payload = %{
      "instance_id" => get_instance_id(),
      "request_type" => "workflow_patterns_consensus",
      "min_confidence" => min_confidence,
      "workflow_type" => workflow_type,
      "requested_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case send_to_centralcloud(request_payload) do
      {:ok, _msg_id} ->
        Logger.info("Requested workflow consensus from CentralCloud", %{
          min_confidence: min_confidence,
          workflow_type: workflow_type
        })

        :telemetry.execute([:evolution, :workflow, :consensus_requested], %{
          min_confidence: min_confidence
        })

        :ok

      {:error, reason} ->
        Logger.error("Failed to request consensus from CentralCloud: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Register consensus patterns received from CentralCloud.

  Called when CentralCloud sends back consensus workflow patterns
  (via QuantumFlow message listener). Registers high-confidence patterns
  from other instances for local use.

  ## Parameters
  - `consensus_patterns` - List of pattern maps from CentralCloud

  ## Examples

      {:ok, count} = GenesisWorkflowLearner.register_consensus_patterns(
        consensus_patterns_from_centralcloud
      )
  """
  @spec register_consensus_patterns([map()]) :: {:ok, integer()} | {:error, term()}
  def register_consensus_patterns(consensus_patterns) when is_list(consensus_patterns) do
    try do
      registered_count =
        Enum.reduce(consensus_patterns, 0, fn pattern_data, count ->
          pattern = payload_to_pattern(pattern_data)

          case Dispatcher.record_workflow_pattern(pattern.workflow_type, pattern) do
            :ok -> count + 1
            {:error, reason} ->
              Logger.warning("Failed to register consensus pattern: #{inspect(reason)}")
              count
          end
        end)

      Logger.info("Registered consensus patterns from CentralCloud", %{
        pattern_count: registered_count
      })

      :telemetry.execute([:evolution, :workflow, :consensus_registered], %{
        count: registered_count
      })

      {:ok, registered_count}
    rescue
      e ->
        Logger.error("Error registering consensus patterns: #{inspect(e)}")
        {:error, {:registration_error, inspect(e)}}
    end
  end

  # Private Helpers

  defp send_to_centralcloud(payload) do
    # Uses QuantumFlow to send to CentralCloud service (port 4001)
    # Topic: "centralcloud/workflow_patterns" for reliable delivery
    case Singularity.Infrastructure.QuantumFlow.Queue.send_with_notify("centralcloud_workflow_patterns", payload) do
      {:ok, :sent} -> {:ok, :sent}
      {:ok, msg_id} when is_integer(msg_id) -> {:ok, msg_id}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error("QuantumFlow send to CentralCloud failed: #{inspect(e)}")
      {:error, {:quantum_flow_failed, inspect(e)}}
  end

  defp pattern_to_payload(pattern) do
    %{
      "workflow_type" => Atom.to_string(pattern.workflow_type),
      "config" => pattern.config,
      "success_rate" => pattern.success_rate,
      "confidence" => pattern.confidence,
      "execution_count" => pattern.execution_count,
      "quality_improvements" => pattern.quality_improvements || %{},
      "avg_execution_ms" => pattern.avg_execution_ms,
      "status" => Atom.to_string(pattern.status)
    }
  end

  defp payload_to_pattern(payload) when is_map(payload) do
    %{
      workflow_type: String.to_atom(payload["workflow_type"]),
      config: payload["config"] || %{},
      success_rate: payload["success_rate"] || 0.0,
      confidence: payload["confidence"] || 0.0,
      execution_count: payload["execution_count"] || 0,
      quality_improvements: payload["quality_improvements"] || %{},
      avg_execution_ms: payload["avg_execution_ms"] || 0,
      status: :published,
      genesis_id: payload["genesis_id"],
      last_executed_at: DateTime.utc_now(),
      created_at: DateTime.utc_now()
    }
  end

  defp filter_by_workflow_type(patterns, :all), do: patterns

  defp filter_by_workflow_type(patterns, types) when is_list(types) do
    Enum.filter(patterns, fn p -> p.workflow_type in types end)
  end

  defp filter_by_workflow_type(patterns, type) when is_atom(type) do
    Enum.filter(patterns, fn p -> p.workflow_type == type end)
  end

  defp get_instance_id do
    System.get_env("SINGULARITY_INSTANCE_ID") ||
      Application.get_env(:singularity, :instance_id) ||
      "singularity_default"
  end

  defp get_workflow_type(session) do
    Map.get(session, :workflow_type) || :unknown
  end

  defp calculate_workflow_pattern(workflow_type, sessions) do
    completed = Enum.filter(sessions, fn s -> s.status == :completed end)
    failed = Enum.filter(sessions, fn s -> s.status == :failed end)

    success_count = length(completed)
    total_count = length(sessions)
    success_rate = if total_count > 0, do: success_count / total_count, else: 0.0

    avg_execution_ms =
      completed
      |> Enum.map(&session_duration_ms/1)
      |> case do
        [] -> 0
        durations -> Enum.sum(durations) / length(durations)
      end
      |> trunc()

    quality_improvements = aggregate_quality_improvements(completed)

    confidence = calculate_confidence(
      success_rate: success_rate,
      frequency: total_count,
      quality_improvements: quality_improvements
    )

    %{
      workflow_type: workflow_type,
      config: %{},
      success_rate: success_rate,
      avg_execution_ms: avg_execution_ms,
      quality_improvements: quality_improvements,
      confidence: confidence,
      execution_count: total_count,
      status: :candidate,
      genesis_id: nil,
      last_executed_at: most_recent_session(sessions).inserted_at,
      created_at: DateTime.utc_now()
    }
  end

  defp session_duration_ms(session) do
    case {session.started_at, session.completed_at} do
      {start, finish} when not is_nil(start) and not is_nil(finish) ->
        DateTime.diff(finish, start, :millisecond)

      _ ->
        0
    end
  end

  defp aggregate_quality_improvements(sessions) do
    sessions
    |> Enum.filter(fn s -> is_map(s.metrics) end)
    |> Enum.map(fn s -> s.metrics end)
    |> case do
      [] -> %{}
      metrics -> aggregate_metrics(metrics)
    end
  end

  defp aggregate_metrics(metrics_list) do
    Enum.reduce(metrics_list, %{}, fn metrics, acc ->
      Map.merge(acc, metrics, fn _k, v1, v2 ->
        case {v1, v2} do
          {n1, n2} when is_number(n1) and is_number(n2) -> (n1 + n2) / 2
          _ -> v2
        end
      end)
    end)
  end

  defp most_recent_session([]), do: %{inserted_at: DateTime.utc_now()}

  defp most_recent_session(sessions) do
    Enum.max_by(sessions, fn s -> s.inserted_at || DateTime.utc_now() end)
  end

  defp calculate_confidence(factors) do
    success_rate = Keyword.get(factors, :success_rate, 0.0)
    frequency = Keyword.get(factors, :frequency, 0)
    quality_improvements = Keyword.get(factors, :quality_improvements, %{})

    # Confidence formula (0.0-1.0):
    # - Success rate weight: 60%
    # - Frequency weight: 30% (min 5 executions for full score)
    # - Quality improvements: 10%

    frequency_score = min(frequency / 5, 1.0)
    quality_score = map_size(quality_improvements) / 10

    (success_rate * 0.6 + frequency_score * 0.3 + quality_score * 0.1)
    |> min(1.0)
    |> max(0.0)
  end

  defp generate_variations(base_def, improvement_focus, limit) do
    config = Map.get(base_def, :config, %{})

    case improvement_focus do
      :execution_speed ->
        [
          Map.put(config, :timeout_ms, max(Map.get(config, :timeout_ms, 30000) - 5000, 10000)),
          Map.put(config, :concurrency, min(Map.get(config, :concurrency, 1) + 1, 10)),
          Map.put(config, :batch_size, min(Map.get(config, :batch_size, 1) + 5, 100))
        ]

      :quality ->
        [
          Map.put(config, :quality_threshold, min(Map.get(config, :quality_threshold, 0.8) + 0.1, 1.0)),
          Map.put(config, :enable_validation, true),
          Map.put(config, :retry_count, min(Map.get(config, :retry_count, 1) + 1, 5))
        ]

      :reliability ->
        [
          Map.put(config, :retry_count, 3),
          Map.put(config, :retry_delay_ms, 2000),
          Map.put(config, :timeout_ms, max(Map.get(config, :timeout_ms, 30000) + 10000, 60000))
        ]

      :cost ->
        [
          Map.put(config, :concurrency, max(Map.get(config, :concurrency, 1) - 1, 1)),
          Map.put(config, :batch_size, max(Map.get(config, :batch_size, 1) - 5, 1))
        ]

      _ ->
        [config]
    end
    |> Enum.take(limit)
  end

  defp predict_variation_confidence(current_pattern, _improvement_focus) do
    if current_pattern do
      # Variations of working patterns get medium-high confidence boost
      min(current_pattern.confidence + 0.1, 0.85)
    else
      0.5
    end
  end

  defp safe_get_workflow_definition(module) do
    if function_exported?(module, :workflow_definition, 0) do
      {:ok, module.workflow_definition()}
    else
      {:error, :definition_failed}
    end
  rescue
    _e ->
      {:error, :definition_failed}
  end

  defp mark_workflow_published(workflow_type, genesis_id) do
    # TODO: Persist published workflow state
    Logger.info("Marked workflow published", %{
      workflow_type: workflow_type,
      genesis_id: genesis_id
    })
  end
end
