defmodule Singularity.Architecture.AnalyzerType do
  @moduledoc """
  Analyzer Type Behavior - Contract for all code/system analyzers.

  Defines the interface that all analyzers must implement to be used with
  the config-driven `AnalysisOrchestrator`. Similar to `PatternType` for patterns,
  but for analysis operations (feedback, quality, refactoring, architecture, etc.).

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.AnalyzerType",
    "purpose": "Behavior contract for config-driven analyzer orchestration",
    "type": "behavior/protocol",
    "layer": "architecture_engine",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Config[\"Config: analyzer_types\"]
      Orchestrator[\"AnalysisOrchestrator\"]
      Behavior[\"AnalyzerType Behavior\"]

      Config -->|enabled: true| Analyzer1[\"FeedbackAnalyzer\"]
      Config -->|enabled: true| Analyzer2[\"QualityAnalyzer\"]
      Config -->|enabled: true| Analyzer3[\"RefactoringAnalyzer\"]

      Orchestrator -->|discover| Behavior
      Behavior -->|implemented by| Analyzer1
      Behavior -->|implemented by| Analyzer2
      Behavior -->|implemented by| Analyzer3

      Analyzer1 -->|analyze/2| Results1[\"Analysis Results\"]
      Analyzer2 -->|analyze/2| Results2[\"Analysis Results\"]
      Analyzer3 -->|analyze/2| Results3[\"Analysis Results\"]
  ```

  ## Configuration Example

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

  ## Implementation Guide

  All analyzers implementing this behavior must provide:

  1. **analyzer_type/0** - Returns atom identifying the analyzer (`:feedback`, `:quality`, etc.)
  2. **description/0** - Human-readable description of what it analyzes
  3. **supported_types/0** - List of analysis types it can produce
  4. **analyze/2** - Main analysis function: `analyze(input, _opts) -> [analysis_results]`
  5. **learn_pattern/1** - Optional: Learn from successful analyses

  ## Example Implementation

  ```elixir
  defmodule Singularity.Architecture.Analyzers.FeedbackAnalyzer do
    @behaviour Singularity.Architecture.AnalyzerType

    @impl true
    def analyzer_type, do: :feedback

    @impl true
    def description, do: \"Identify agent improvement opportunities\"

    @impl true
    def supported_types do
      [\"success_rate\", \"cost\", \"latency\", \"error_patterns\"]
    end

    @impl true
    def analyze(input, _opts \\\\ []) do
      # Analyze input and return list of analysis results
      [
        %{
          type: \"success_rate\",
          severity: \"high\",
          message: \"Agent success rate below 90%\"
        }
      ]
    end

    @impl true
    def learn_pattern(result) do
      # Optional: Update confidence based on results
      :ok
    end
  end
  ```

  ## Call Graph (YAML)

  ```yaml
  calls_out:
    - module: \"[Enabled Analyzer Implementations]\"
      function: \"analyze/2\"
      purpose: \"Perform specific analysis\"
      critical: true

    - module: \"[Enabled Analyzer Implementations]\"
      function: \"learn_pattern/1\"
      purpose: \"Learn from analysis results\"
      critical: false

    - module: Logger
      function: \"[info|warn|error]/2\"
      purpose: \"Logging analysis progress\"
      critical: false

  called_by:
    - module: Singularity.Architecture.AnalysisOrchestrator
      count: \"1+\"
      purpose: \"Config-driven discovery and execution\"

    - module: \"[Future analysis consumers]\"
      count: \"*\"
      purpose: \"Any analysis workflows\"
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** create hardcoded analyzer lists in orchestrator
  - ❌ **DO NOT** scatter analyzer implementations across directories
  - ❌ **DO NOT** call analyzers directly instead of through orchestrator
  - ✅ **DO** always use `AnalysisOrchestrator.analyze/2` which routes through config
  - ✅ **DO** add new analyzers only via config, not code
  - ✅ **DO** implement analyzers as `@behaviour AnalyzerType` modules
  - ✅ **DO** organize all analyzers in `architecture_engine/analyzers/` directory

  ## Search Keywords

  analyzer, orchestration, config-driven, feedback, quality, refactoring,
  code-analysis, behavior, pattern, discovery, analysis-results
  """

  require Logger

  @doc """
  Returns the atom identifier for this analyzer.

  Examples: `:feedback`, `:quality`, `:refactoring`, `:architecture`
  """
  @callback analyzer_type() :: atom()

  @doc """
  Returns human-readable description of what this analyzer does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of analysis types this analyzer can produce.

  Examples: `["success_rate", "cost", "latency"]`
  """
  @callback supported_types() :: [String.t()]

  @doc """
  Perform analysis on the given input.

  Returns list of analysis results: `[%{type: string, severity: string, ...}]`
  """
  @callback analyze(input :: any(), _opts :: Keyword.t()) :: [map()]

  @doc """
  Learn from successful analysis results.

  Called after analysis to update confidence/patterns based on results.
  """
  @callback learn_pattern(result :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled analyzers from config.

  Returns: `[{analyzer_type, config_map}, ...]`
  """
  def load_enabled_analyzers do
    :singularity
    |> Application.get_env(:analyzer_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  @doc """
  Check if a specific analyzer is enabled.
  """
  def enabled?(analyzer_type) when is_atom(analyzer_type) do
    analyzers = load_enabled_analyzers()
    Enum.any?(analyzers, fn {type, _config} -> type == analyzer_type end)
  end

  @doc """
  Get the module implementing a specific analyzer type.
  """
  def get_analyzer_module(analyzer_type) when is_atom(analyzer_type) do
    case Application.get_env(:singularity, :analyzer_types, %{})[analyzer_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :analyzer_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get description for a specific analyzer type.
  """
  def get_description(analyzer_type) when is_atom(analyzer_type) do
    case get_analyzer_module(analyzer_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown analyzer"
        end

      {:error, _} ->
        "Unknown analyzer"
    end
  end
end
