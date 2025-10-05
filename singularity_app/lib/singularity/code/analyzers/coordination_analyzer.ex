defmodule Singularity.Analysis.CoordinationAnalyzer do
  @moduledoc """
  Analyzes coordination patterns in the codebase to determine:
  - Coupling score (how tightly modules depend on each other)
  - Debug complexity (how hard it is to trace failures)
  - Observability gaps (black box workflows)
  - Coordination maturity (early_stage | scaling | enterprise)

  Used to make data-driven decisions about adopting patterns like:
  - Correlation IDs
  - Event-driven architecture
  - Workflow tracking
  """

  require Logger
  alias Singularity.Analysis.Summary

  @type coordination_health :: %{
          coupling_score: float(),
          debug_complexity: float(),
          observability_score: float(),
          coordination_maturity: :early_stage | :scaling | :enterprise,
          recommendations: [recommendation()],
          metrics: metrics()
        }

  @type recommendation :: %{
          pattern: atom(),
          priority: :critical | :high | :medium | :low,
          roi_score: float(),
          reasoning: String.t(),
          effort_estimate: String.t()
        }

  @type metrics :: %{
          direct_calls: non_neg_integer(),
          event_driven_calls: non_neg_integer(),
          modules_with_correlation: non_neg_integer(),
          total_coordinator_modules: non_neg_integer(),
          workflows_without_tracking: [String.t()],
          avg_call_chain_depth: float()
        }

  @doc """
  Analyze coordination health of the codebase.

  Returns metrics and recommendations for improving coordination.
  """
  @spec analyze_coordination_health(String.t()) :: coordination_health()
  def analyze_coordination_health(codebase_path \\ ".") do
    Logger.info("Analyzing coordination health", path: codebase_path)

    # Gather raw metrics
    metrics = gather_metrics(codebase_path)

    # Calculate scores
    coupling_score = calculate_coupling_score(metrics)
    debug_complexity = calculate_debug_complexity(metrics)
    observability_score = calculate_observability_score(metrics)

    # Determine maturity
    maturity = determine_maturity(metrics)

    # Generate recommendations
    recommendations =
      generate_recommendations(coupling_score, debug_complexity, observability_score, maturity)

    %{
      coupling_score: coupling_score,
      debug_complexity: debug_complexity,
      observability_score: observability_score,
      coordination_maturity: maturity,
      recommendations: recommendations,
      metrics: metrics
    }
  end

  ## Metrics Gathering

  defp gather_metrics(codebase_path) do
    coordination_files = find_coordination_files(codebase_path)

    %{
      direct_calls: count_direct_calls(coordination_files),
      event_driven_calls: count_event_driven_calls(coordination_files),
      modules_with_correlation: count_correlation_usage(coordination_files),
      total_coordinator_modules: length(coordination_files),
      workflows_without_tracking: identify_untracked_workflows(coordination_files),
      avg_call_chain_depth: measure_avg_call_depth(coordination_files)
    }
  end

  defp find_coordination_files(codebase_path) do
    # Find files that coordinate agents/workflows
    patterns = [
      "#{codebase_path}/lib/**/autonomy/*.ex",
      "#{codebase_path}/lib/**/planning/*.ex",
      "#{codebase_path}/lib/**/coordination/*.ex"
    ]

    Enum.flat_map(patterns, fn pattern ->
      Path.wildcard(pattern)
    end)
  end

  defp count_direct_calls(files) do
    # Count GenServer.call, Module.function_name patterns (tight coupling)
    Enum.reduce(files, 0, fn file, acc ->
      content = File.read!(file)

      direct_call_patterns = [
        ~r/GenServer\.call\(/,
        ~r/[A-Z][a-zA-Z]+\.[a-z_]+\(/,
        # Aliased module direct calls
        ~r/alias.*\n.*\1\./
      ]

      calls =
        Enum.reduce(direct_call_patterns, 0, fn pattern, count ->
          count + length(Regex.scan(pattern, content))
        end)

      acc + calls
    end)
  end

  defp count_event_driven_calls(files) do
    # Count PubSub.broadcast, PubSub.subscribe patterns (loose coupling)
    Enum.reduce(files, 0, fn file, acc ->
      content = File.read!(file)

      event_patterns = [
        ~r/PubSub\.broadcast\(/,
        ~r/PubSub\.subscribe\(/,
        ~r/Phoenix\.PubSub/
      ]

      events =
        Enum.reduce(event_patterns, 0, fn pattern, count ->
          count + length(Regex.scan(pattern, content))
        end)

      acc + events
    end)
  end

  defp count_correlation_usage(files) do
    # Count files that use correlation_id pattern
    Enum.count(files, fn file ->
      content = File.read!(file)
      String.contains?(content, "correlation_id") or String.contains?(content, "correlationId")
    end)
  end

  defp identify_untracked_workflows(files) do
    # Identify workflows (GenServer handle_call/cast) without state tracking
    Enum.flat_map(files, fn file ->
      content = File.read!(file)

      # Find all handle_call/cast functions
      workflows =
        Regex.scan(~r/def handle_(?:call|cast)\(\{:([a-z_]+)/, content)
        |> Enum.map(fn [_, workflow_name] -> workflow_name end)

      # Check if there's any ETS/state tracking for these workflows
      has_tracking =
        String.contains?(content, ":ets.") or String.contains?(content, "workflow_context")

      if has_tracking do
        []
      else
        Enum.map(workflows, fn workflow ->
          "#{Path.basename(file)}:#{workflow}"
        end)
      end
    end)
  end

  defp measure_avg_call_depth(files) do
    # Measure average depth of call chains (A calls B calls C = depth 3)
    # Simplified: count nested function calls in coordination logic
    depths =
      Enum.map(files, fn file ->
        content = File.read!(file)

        # Count indentation levels as proxy for call depth
        content
        |> String.split("\n")
        |> Enum.map(fn line ->
          # Count leading spaces / 2 (assuming 2-space indent)
          indent = String.length(line) - String.length(String.trim_leading(line))
          div(indent, 2)
        end)
        |> Enum.max(fn -> 0 end)
      end)

    if Enum.empty?(depths), do: 0.0, else: Enum.sum(depths) / length(depths)
  end

  ## Score Calculation

  defp calculate_coupling_score(metrics) do
    # High direct calls = high coupling (bad)
    # High event-driven calls = low coupling (good)
    total_calls = metrics.direct_calls + metrics.event_driven_calls

    if total_calls == 0 do
      # Neutral if no coordination yet
      0.5
    else
      # Normalize to 0.0 (perfect decoupling) to 1.0 (tight coupling)
      metrics.direct_calls / total_calls
    end
  end

  defp calculate_debug_complexity(metrics) do
    # No correlation IDs = high complexity
    # Deep call chains = high complexity
    correlation_coverage =
      metrics.modules_with_correlation / max(metrics.total_coordinator_modules, 1)

    # Normalize to 0-1
    depth_penalty = min(metrics.avg_call_chain_depth / 10, 1.0)

    # Combine: lack of correlation + deep chains = hard to debug
    (1.0 - correlation_coverage) * 0.6 + depth_penalty * 0.4
  end

  defp calculate_observability_score(metrics) do
    # More untracked workflows = lower observability
    # Normalize to 0.0 (no visibility) to 1.0 (full visibility)
    untracked_count = length(metrics.workflows_without_tracking)

    # Assume 10+ untracked workflows = very bad (0.0)
    # 0 untracked = perfect (1.0)
    max(0.0, 1.0 - untracked_count / 10)
  end

  defp determine_maturity(metrics) do
    cond do
      # Enterprise: 10+ coordinator modules, extensive event-driven
      metrics.total_coordinator_modules >= 10 and metrics.event_driven_calls > 50 ->
        :enterprise

      # Scaling: 5+ coordinators, some events, growing complexity
      metrics.total_coordinator_modules >= 5 or metrics.direct_calls > 20 ->
        :scaling

      # Early stage: < 5 coordinators, mostly direct calls
      true ->
        :early_stage
    end
  end

  ## Recommendations

  defp generate_recommendations(coupling, debug_complexity, observability, maturity) do
    [
      evaluate_correlation_ids(debug_complexity),
      evaluate_event_driven(coupling, maturity),
      evaluate_workflow_tracking(observability),
      evaluate_time_escalation(maturity),
      evaluate_perf_monitoring(maturity)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.priority, fn a, b ->
      priority_value(a) >= priority_value(b)
    end)
  end

  defp evaluate_correlation_ids(debug_complexity) when debug_complexity > 0.6 do
    %{
      pattern: :correlation_ids,
      priority: :critical,
      roi_score: 5.0,
      reasoning:
        "Debug complexity score #{Float.round(debug_complexity, 2)} - difficult to trace failures without correlation IDs",
      effort_estimate: "2-4 hours (add UUID to workflow contexts)"
    }
  end

  defp evaluate_correlation_ids(_), do: nil

  defp evaluate_event_driven(coupling, maturity)
       when coupling > 0.6 and maturity in [:scaling, :enterprise] do
    %{
      pattern: :event_driven_architecture,
      priority: :high,
      roi_score: 4.0,
      reasoning:
        "Coupling score #{Float.round(coupling, 2)} with #{maturity} maturity - tight coupling detected across multiple coordinators",
      effort_estimate: "1-2 days (refactor direct calls to PubSub events)"
    }
  end

  defp evaluate_event_driven(coupling, :early_stage) when coupling > 0.7 do
    %{
      pattern: :event_driven_architecture,
      priority: :low,
      roi_score: 2.0,
      reasoning:
        "High coupling (#{Float.round(coupling, 2)}) but early stage - consider deferring until more coordinators added",
      effort_estimate: "1-2 days (may be premature)"
    }
  end

  defp evaluate_event_driven(_, _), do: nil

  defp evaluate_workflow_tracking(observability) when observability < 0.5 do
    %{
      pattern: :workflow_tracking,
      priority: :high,
      roi_score: 3.5,
      reasoning:
        "Observability score #{Float.round(observability, 2)} - many workflows are black boxes without state tracking",
      effort_estimate: "4-6 hours (add ETS tracking for active workflows)"
    }
  end

  defp evaluate_workflow_tracking(_), do: nil

  defp evaluate_time_escalation(:enterprise) do
    %{
      pattern: :time_based_escalation,
      priority: :medium,
      roi_score: 2.5,
      reasoning: "Enterprise maturity - time-based escalation may help with SLA management",
      effort_estimate: "4-8 hours (implement escalation timers)"
    }
  end

  defp evaluate_time_escalation(_), do: nil

  defp evaluate_perf_monitoring(:enterprise) do
    %{
      pattern: :performance_monitoring,
      priority: :medium,
      roi_score: 2.0,
      reasoning: "Enterprise scale - performance monitoring helps detect bottlenecks",
      effort_estimate: "2-4 hours (add execution time alerts)"
    }
  end

  defp evaluate_perf_monitoring(_), do: nil

  defp priority_value(%{priority: :critical}), do: 4
  defp priority_value(%{priority: :high}), do: 3
  defp priority_value(%{priority: :medium}), do: 2
  defp priority_value(%{priority: :low}), do: 1

  ## Formatting

  @doc "Format analysis results for human consumption"
  def format_results(health) do
    """
    ## Coordination Health Analysis

    ### Scores (0.0 = good, 1.0 = needs improvement)
    - Coupling Score: #{Float.round(health.coupling_score, 2)}
    - Debug Complexity: #{Float.round(health.debug_complexity, 2)}
    - Observability Score: #{Float.round(health.observability_score, 2)} (higher is better)

    ### Maturity Level: #{health.coordination_maturity}

    ### Metrics
    - Direct calls (tight coupling): #{health.metrics.direct_calls}
    - Event-driven calls (loose coupling): #{health.metrics.event_driven_calls}
    - Modules with correlation IDs: #{health.metrics.modules_with_correlation}/#{health.metrics.total_coordinator_modules}
    - Workflows without tracking: #{length(health.metrics.workflows_without_tracking)}
    - Average call chain depth: #{Float.round(health.metrics.avg_call_chain_depth, 1)}

    ### Recommendations (prioritized by ROI)
    #{format_recommendations(health.recommendations)}

    ### Untracked Workflows
    #{format_untracked_workflows(health.metrics.workflows_without_tracking)}
    """
  end

  defp format_recommendations([]), do: "✅ No improvements needed - coordination health is good!"

  defp format_recommendations(recommendations) do
    Enum.map_join(recommendations, "\n\n", fn rec ->
      """
      **#{rec.priority |> to_string() |> String.upcase()}: #{rec.pattern}** (ROI: #{rec.roi_score}/5.0)
      - Reasoning: #{rec.reasoning}
      - Effort: #{rec.effort_estimate}
      """
    end)
  end

  defp format_untracked_workflows([]), do: "✅ All workflows have state tracking"

  defp format_untracked_workflows(workflows) do
    Enum.map_join(workflows, "\n", fn workflow -> "- #{workflow}" end)
  end
end
