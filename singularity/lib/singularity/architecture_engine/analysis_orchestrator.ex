defmodule Singularity.Architecture.AnalysisOrchestrator do
  @moduledoc """
  Analysis Orchestrator - Config-driven orchestration of all code/system analyzers.

  Automatically discovers and runs any enabled analyzer (Feedback, Quality,
  Refactoring, etc.). No hardcoding needed - purely config-driven.

  Similar to `PatternDetector` but for analysis operations instead of pattern detection.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.AnalysisOrchestrator",
    "purpose": "Config-driven orchestration of all system analyzers",
    "layer": "domain_service",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Input[\"Input to Analyze\"]
      Orchestrator[\"AnalysisOrchestrator.analyze/2\"]
      Config[\"Config: analyzer_types\"]

      Orchestrator -->|loads| Config
      Config -->|enabled: true| Feedback[\"FeedbackAnalyzer\"]
      Config -->|enabled: true| Quality[\"QualityAnalyzer\"]
      Config -->|enabled: true| Refactoring[\"RefactoringAnalyzer\"]

      Feedback -->|analyze/2| Results1[\"Feedback Analysis\"]
      Quality -->|analyze/2| Results2[\"Quality Analysis\"]
      Refactoring -->|analyze/2| Results3[\"Refactoring Analysis\"]

      Input -->|routed to| Feedback
      Input -->|routed to| Quality
      Input -->|routed to| Refactoring
  ```

  ## Usage Examples

  ```elixir
  # Analyze with ALL enabled analyzers
  {:ok, results} = AnalysisOrchestrator.analyze(agent_metrics)
  # => %{
  #   feedback: [%{type: \"success_rate\", severity: \"high\"}, ...],
  #   quality: [%{type: \"duplication\", severity: \"medium\"}, ...],
  #   refactoring: [%{type: \"complexity\", severity: \"high\"}, ...]
  # }

  # Analyze with specific analyzers only
  {:ok, results} = AnalysisOrchestrator.analyze(
    agent_metrics,
    analyzer_types: [:feedback, :quality]
  )
  # => %{
  #   feedback: [...],
  #   quality: [...]
  # }

  # Analyze with filtering
  {:ok, results} = AnalysisOrchestrator.analyze(
    agent_metrics,
    min_severity: \"medium\",
    limit: 10
  )

  # Learn from analysis results
  :ok = AnalysisOrchestrator.learn_pattern(:feedback, analysis_result)
  ```

  ## Configuration

  ```elixir
  # config/config.exs
  config :singularity, :analyzer_types,
    feedback: %{
      module: Singularity.Architecture.Analyzers.FeedbackAnalyzer,
      enabled: true,
      description: \"Identify agent improvement opportunities from metrics\"
    },
    quality: %{
      module: Singularity.Architecture.Analyzers.QualityAnalyzer,
      enabled: true,
      description: \"Analyze code quality issues and violations\"
    },
    refactoring: %{
      module: Singularity.Architecture.Analyzers.RefactoringAnalyzer,
      enabled: true,
      description: \"Identify refactoring needs and opportunities\"
    }
  ```

  ## Call Graph

  ```yaml
  calls_out:
    - module: \"[Enabled Analyzer Implementations]\"
      function: \"analyze/2\"
      purpose: \"Perform analysis\"
      critical: true

    - module: \"[Enabled Analyzer Implementations]\"
      function: \"learn_pattern/1\"
      purpose: \"Learn from results\"
      critical: false

    - module: Singularity.Architecture.AnalyzerType
      function: \"load_enabled_analyzers/0\"
      purpose: \"Discover analyzers from config\"
      critical: true

    - module: Logger
      function: \"[info|error]/2\"
      purpose: \"Logging progress\"
      critical: false

  called_by:
    - module: Singularity.Execution.Feedback.Analyzer
      count: \"1+\"
      purpose: \"Agent feedback analysis\"

    - module: Singularity.Refactoring.Analyzer
      count: \"1+\"
      purpose: \"Refactoring analysis\"

    - module: \"[Future analysis consumers]\"
      count: \"*\"
      purpose: \"Any analysis workflows\"
  ```

  ## Anti-Patterns (Prevents Duplicates)

  ### ❌ DO NOT create new hardcoded analyzer lists
  **Why:** Config-driven discovery already handles all analyzers.
  **Use instead:**
  ```elixir
  # ❌ WRONG - hardcoded analyzer list
  analyzers = [FeedbackAnalyzer, QualityAnalyzer, RefactoringAnalyzer]

  # ✅ CORRECT - load from config
  AnalysisOrchestrator.analyze(input)
  ```

  ### ❌ DO NOT call individual analyzers directly
  **Why:** AnalysisOrchestrator provides unified analysis with parallel execution.
  **Use instead:**
  ```elixir
  # ❌ WRONG
  FeedbackAnalyzer.analyze(input)

  # ✅ CORRECT
  AnalysisOrchestrator.analyze(input, analyzer_types: [:feedback])
  ```

  ### ❌ DO NOT hardcode analyzer selection
  **Why:** Config-driven discovery enables better analyzer evolution.
  **Use instead:** Add analyzer to config:
  ```elixir
  config :singularity, :analyzer_types,
    my_analyzer: %{
      module: Singularity.Architecture.Analyzers.MyAnalyzer,
      enabled: true
    }
  ```

  ### Search Keywords

  analysis orchestrator, code analysis, feedback analyzer, quality analyzer, refactoring analyzer,
  config driven analysis, parallel analysis, analyzer orchestration, system analysis,
  analyzer types, analysis results, microservice analyzer
  """

  require Logger
  alias Singularity.Architecture.AnalyzerType

  @doc """
  Run analysis using all enabled analyzers.

  ## Options

  - `:analyzer_types` - List of analyzer types to run (default: all enabled)
  - `:min_severity` - Filter results by minimum severity (default: none)
  - `:limit` - Maximum results per analyzer (default: unlimited)

  ## Returns

  `{:ok, %{analyzer_type => [analysis_results]}}` or `{:error, reason}`

  Example:
  ```
  {:ok, %{
    feedback: [%{type: \"success_rate\", ...}],
    quality: [%{type: \"duplication\", ...}],
    refactoring: [%{type: \"complexity\", ...}]
  }}
  ```
  """
  def analyze(input, opts \\ []) do
    try do
      # Load all enabled analyzers from config
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()

      # Filter by requested analyzer types if specified
      analyzer_types = Keyword.get(opts, :analyzer_types, nil)

      analyzers_to_run =
        if analyzer_types do
          Enum.filter(enabled_analyzers, fn {type, _} -> type in analyzer_types end)
        else
          enabled_analyzers
        end

      # Run all analyzers in parallel (independent operations)
      results =
        analyzers_to_run
        |> Enum.map(fn {analyzer_type, analyzer_config} ->
          Task.async(fn -> run_analyzer(analyzer_type, analyzer_config, input, opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      Logger.info("Analysis complete",
        analyses_found: Enum.map(results, fn {type, analyses} -> {type, length(analyses)} end)
      )

      {:ok, results}
    rescue
      e ->
        Logger.error("Analysis failed", error: inspect(e))
        {:error, :analysis_failed}
    end
  end

  @doc """
  Learn from an analysis result for a specific analyzer type.
  """
  def learn_pattern(analyzer_type, analysis_result) when is_atom(analyzer_type) do
    case AnalyzerType.get_analyzer_module(analyzer_type) do
      {:ok, module} ->
        Logger.info("Learning from analysis for #{analyzer_type}")
        module.learn_pattern(analysis_result)

      {:error, reason} ->
        Logger.error("Cannot learn from analysis for #{analyzer_type}",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Get all configured analyzer types and their status.
  """
  def get_analyzer_types_info do
    AnalyzerType.load_enabled_analyzers()
    |> Enum.map(fn {type, config} ->
      description = AnalyzerType.get_description(type)

      %{
        name: type,
        enabled: true,
        description: description,
        module: config[:module]
      }
    end)
  end

  # Private helpers

  defp run_analyzer(analyzer_type, analyzer_config, input, opts) do
    try do
      module = analyzer_config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{analyzer_type} analyzer")
        results = module.analyze(input, opts)

        # Filter and limit results
        filtered =
          results
          |> filter_by_severity(opts)
          |> limit_results(opts)

        Logger.debug("#{analyzer_type} analyzer found #{length(filtered)} issues")
        {analyzer_type, filtered}
      else
        Logger.warning("Analyzer module not found for #{analyzer_type}")
        {analyzer_type, []}
      end
    rescue
      e ->
        Logger.error("Analyzer failed for #{analyzer_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {analyzer_type, []}
    end
  end

  defp filter_by_severity(results, opts) do
    case Keyword.get(opts, :min_severity) do
      nil ->
        results

      min_severity ->
        severity_order = %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
        min_order = severity_order[min_severity] || 0

        Enum.filter(results, fn result ->
          result_severity = result[:severity] || "low"
          severity_order[result_severity] || 0 >= min_order
        end)
    end
  end

  defp limit_results(results, opts) do
    case Keyword.get(opts, :limit) do
      nil -> results
      limit -> Enum.take(results, limit)
    end
  end
end
