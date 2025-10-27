defmodule Singularity.Architecture.Analyzers.FeedbackAnalyzer do
  @moduledoc """
  Feedback Analyzer - Identifies agent improvement opportunities from metrics.

  Analyzes aggregated agent metrics to identify improvement opportunities and
  generate actionable suggestions for the evolution system.

  Implements `@behaviour AnalyzerType` for config-driven orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Analyzers.FeedbackAnalyzer",
    "type": "analyzer",
    "purpose": "Identify agent improvement opportunities from execution metrics",
    "layer": "architecture_engine",
    "behavior": "AnalyzerType",
    "registered_in": "config :singularity, :analyzer_types, feedback: ...",
    "scope": "Agent performance metrics (success rate, cost, latency, errors)"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[analyze/2] --> B[Execution.Feedback.Analyzer]
      B --> C[success_rate analysis]
      B --> D[cost analysis]
      B --> E[latency analysis]
      B --> F[error patterns]
      C --> G[format results]
      D --> G
      E --> G
      F --> G
      G --> H[severity classification]
      H --> I[return improvements]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.Execution.Feedback.Analyzer (metrics analysis)
    - Logger (error handling and learning)

  called_by:
    - Singularity.Architecture.AnalysisOrchestrator
    - Agent evolution system
    - Cost optimization pipelines
    - Performance monitoring
  ```

  ## Anti-Patterns

  - ❌ `MetricsAnalyzer` - Use FeedbackAnalyzer for agent improvements
  - ❌ `PerformanceOptimizer` - Use feedback for optimization suggestions
  - ✅ Use AnalysisOrchestrator for discovery
  - ✅ Pair with agents.supervisor for feedback loop

  ## Analysis Rules

  ### Success Rate Issues
  - **Threshold**: < 90%
  - **Cause**: Agent failing more than acceptable
  - **Suggestion**: Add high-confidence patterns to prompt

  ### Cost Issues
  - **Threshold**: > $0.10 per task (configurable)
  - **Cause**: Using expensive models or doing extra work
  - **Suggestion**: Optimize model selection

  ### Latency Issues
  - **Threshold**: > 2000ms per task
  - **Cause**: Slow execution, cache misses, network delays
  - **Suggestion**: Improve caching strategy, parallelize work

  ## Search Keywords

  feedback analysis, agent metrics, performance improvement, cost optimization,
  latency analysis, success rate, error patterns, evolution system, agent feedback
  """

  @behaviour Singularity.Architecture.AnalyzerType
  require Logger
  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Execution.Feedback.Analyzer

  @impl true
  def analyzer_type, do: :feedback

  @impl true
  def description, do: "Identify agent improvement opportunities from metrics"

  @impl true
  def supported_types do
    ["success_rate", "cost", "latency", "error_patterns"]
  end

  @impl true
  def analyze(agent_id, opts \\ []) when is_binary(agent_id) do
    try do
      case Analyzer.analyze_agent(agent_id) do
        {:ok, analysis} ->
          # Convert analysis to standard format
          format_analysis_results(analysis)

        {:error, _reason} ->
          []
      end
    rescue
      e ->
        Logger.error("Feedback analysis failed for #{agent_id}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_pattern(result) do
    # Update analysis confidence in pattern store based on results
    case result do
      %{agent_id: agent_id, success: true} ->
        Logger.info("Feedback analysis was actionable for #{agent_id}")
        :ok

      %{agent_id: agent_id, success: false} ->
        Logger.info("Feedback analysis was not actionable for #{agent_id}")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp format_analysis_results(analysis) do
    # Convert feedback analyzer results to standard format
    Enum.flat_map(analysis.issues || [], fn issue ->
      [
        %{
          type: Atom.to_string(issue.type),
          severity: classify_severity(issue),
          message: format_issue_message(issue),
          agent_id: analysis.agent_id,
          analyzed_at: analysis.analyzed_at
        }
      ]
    end)
  end

  defp classify_severity(%{value: value, threshold: threshold}) do
    ratio = if threshold != 0, do: value / threshold, else: 1.0

    cond do
      ratio > 2.0 -> "critical"
      ratio > 1.5 -> "high"
      ratio > 1.2 -> "medium"
      true -> "low"
    end
  end

  defp format_issue_message(%{type: type, value: value, threshold: threshold}) do
    case type do
      :low_success_rate ->
        "Success rate #{Float.round(value * 100, 1)}% is below threshold #{Float.round(threshold * 100, 1)}%"

      :high_cost ->
        "Cost $#{Float.round(value, 2)} exceeds threshold $#{Float.round(threshold, 2)}"

      :high_latency ->
        "Latency #{Float.round(value, 0)}ms exceeds threshold #{Float.round(threshold, 0)}ms"

      _ ->
        "Issue detected: #{inspect(type)}"
    end
  end
end
