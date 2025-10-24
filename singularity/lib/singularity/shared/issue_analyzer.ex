defmodule Singularity.Shared.IssueAnalyzer do
  @moduledoc """
  Unified Issue Analysis Pattern - Base behavior for all "scan → identify → suggest → prioritize" workflows.

  Consolidates analysis pattern from multiple modules:
  - Feedback.Analyzer (agent metrics analysis)
  - AstQualityAnalyzer (code quality issues)
  - Refactoring.Analyzer (refactoring suggestions)
  - Any future analyzers

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Shared.IssueAnalyzer",
    "purpose": "Unified issue analysis workflow pattern",
    "layer": "shared_infrastructure",
    "replaces": ["Feedback.Analyzer pattern", "AstQualityAnalyzer pattern", "Refactoring.Analyzer pattern"],
    "status": "production"
  }
  ```

  ## Architecture Diagram
  ```mermaid
  graph TD
      Analyzer1["Feedback.Analyzer"]
      Analyzer2["AstQualityAnalyzer"]
      Analyzer3["Refactoring.Analyzer"]
      Base["IssueAnalyzer Behavior"]

      Analyzer1 -->|implements| Base
      Analyzer2 -->|implements| Base
      Analyzer3 -->|implements| Base

      Base -->|defines workflow| Workflow["1. scan/1<br/>2. identify_issues/1<br/>3. generate_suggestions/1<br/>4. prioritize_issues/1"]
  ```

  ## Typical Usage Pattern

  ```elixir
  defmodule MyAnalyzer do
    @behaviour Singularity.Shared.IssueAnalyzer

    @impl IssueAnalyzer
    def scan(input) do
      # Return list of items to analyze
      [item1, item2, ...]
    end

    @impl IssueAnalyzer
    def identify_issues(items) do
      # Scan items for issues
      [
        %{type: :low_success_rate, severity: :high, value: 0.65},
        %{type: :high_cost, severity: :medium, value: 125.50},
        ...
      ]
    end

    @impl IssueAnalyzer
    def generate_suggestions(issues) do
      # For each issue type, suggest fixes
      [
        %{type: :low_success_rate, suggestions: ["Add patterns", "Increase complexity"]},
        %{type: :high_cost, suggestions: ["Use cheaper model", "Cache results"]},
        ...
      ]
    end

    @impl IssueAnalyzer
    def prioritize_issues(issues) do
      # Return priority score (0-100)
      # Higher = more urgent
      issues
      |> Enum.map(fn issue ->
        priority = case issue.severity do
          :critical -> 100
          :high -> 70
          :medium -> 50
          :low -> 20
        end
        %{issue | priority: priority}
      end)
    end
  end

  # Then use it:
  items = MyAnalyzer.scan(input_data)
  issues = MyAnalyzer.identify_issues(items)
  suggestions = MyAnalyzer.generate_suggestions(issues)
  prioritized = MyAnalyzer.prioritize_issues(issues)

  # Or use the runner:
  {:ok, analysis} = IssueAnalyzer.run(MyAnalyzer, input_data)
  # => %{items: [...], issues: [...], suggestions: [...], prioritized: [...]}
  ```

  ## Data Structures

  ### Issue Map
  ```elixir
  %{
    type: :atom,                 # Issue type: :low_success_rate, :high_cost, etc.
    severity: :atom,             # :critical, :high, :medium, :low
    value: number(),             # Measured value (0-100, cost in USD, etc.)
    description: String.t(),     # Human readable description
    source: atom() | nil         # Where issue came from (optional)
  }
  ```

  ### Suggestion Map
  ```elixir
  %{
    type: :atom,                 # Issue type this addresses
    suggestions: [String.t()],   # List of actionable suggestions
    priority: number()           # Sort priority (0-100)
  }
  ```

  ## Call Graph (Machine-Readable)

  ```yaml
  calls_out: null
  # This is a behavior - implementations call out to domain-specific modules

  called_by:
    - module: Singularity.Execution.Feedback.Analyzer
      count: "1+"
      purpose: Agent performance analysis

    - module: Singularity.CodeQuality.AstQualityAnalyzer
      count: "1+"
      purpose: Code quality analysis

    - module: Singularity.Refactoring.Analyzer
      count: "1+"
      purpose: Refactoring detection

    - module: "[Future analyzers]"
      count: "*"
      purpose: Any new analysis workflows
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** implement "scan → identify → suggest → prioritize" in multiple analyzers
  - ❌ **DO NOT** duplicate issue data structures and severity scoring
  - ✅ **DO** use `@behaviour IssueAnalyzer` for new analysis modules
  - ✅ **DO** reuse issue/suggestion data structures
  - ✅ **DO** call `IssueAnalyzer.run/2` to execute full workflow
  """

  require Logger

  @doc """
  Scan input data and return items to analyze.

  Each implementation provides domain-specific scanning logic.
  """
  @callback scan(input :: any()) :: [any()]

  @doc """
  Identify issues in the provided items.

  Returns a list of issue maps with:
  - `:type` - Issue classification
  - `:severity` - :critical, :high, :medium, :low
  - `:value` - Measured quantity
  - `:description` - Human readable issue
  """
  @callback identify_issues(items :: [any()]) :: [map()]

  @doc """
  Generate suggestions to address identified issues.

  Returns a list of suggestion maps with:
  - `:type` - Issue type this addresses
  - `:suggestions` - List of actionable suggestions
  - `:priority` - Sort priority (0-100)
  """
  @callback generate_suggestions(issues :: [map()]) :: [map()]

  @doc """
  Prioritize issues by severity/urgency.

  Returns issues augmented with priority scores (0-100, where 100 is most urgent).
  """
  @callback prioritize_issues(issues :: [map()]) :: [map()]

  @doc """
  Run complete analysis workflow.

  Executes: scan → identify_issues → generate_suggestions → prioritize_issues

  Returns complete analysis result with all stages.
  """
  def run(analyzer_module, input_data) do
    try do
      items = analyzer_module.scan(input_data)
      issues = analyzer_module.identify_issues(items)
      suggestions = analyzer_module.generate_suggestions(issues)
      prioritized = analyzer_module.prioritize_issues(issues)

      {:ok,
       %{
         items: items,
         issues: issues,
         suggestions: suggestions,
         prioritized: prioritized
       }}
    rescue
      e ->
        Logger.error("Analysis workflow failed",
          analyzer: inspect(analyzer_module),
          error: inspect(e)
        )
        {:error, :analysis_failed}
    end
  end

  @doc """
  Calculate severity score based on issue severity levels.

  Useful for prioritizing issues consistently across analyzers.

  ## Returns

  Score 0-100 where 100 is most critical.
  """
  def severity_score(severity) do
    case severity do
      :critical -> 100
      :high -> 70
      :medium -> 50
      :low -> 30
      :info -> 10
      _ -> 0
    end
  end

  @doc """
  Determine overall health based on issues found.

  Common health determination logic.
  """
  def determine_health([]), do: :healthy

  def determine_health(issues) do
    critical_count = Enum.count(issues, fn i -> i.severity == :critical end)
    high_count = Enum.count(issues, fn i -> i.severity == :high end)

    cond do
      critical_count > 0 -> :critical
      high_count >= 2 -> :unhealthy
      length(issues) >= 3 -> :needs_improvement
      true -> :degraded
    end
  end

  @doc """
  Build standard issue map.

  Helper for creating consistent issue structures.
  """
  def build_issue(type, severity, value, description \\ "", source \\ nil) do
    %{
      type: type,
      severity: severity,
      value: value,
      description: description,
      source: source
    }
  end

  @doc """
  Build standard suggestion map.

  Helper for creating consistent suggestion structures.
  """
  def build_suggestion(type, suggestions, priority \\ 50) when is_list(suggestions) do
    %{
      type: type,
      suggestions: suggestions,
      priority: priority
    }
  end

  @doc """
  Validate issue structure.

  Ensures issue has required fields.
  """
  def valid_issue?(%{type: t, severity: s, value: v}) when is_atom(t) and is_atom(s) and is_number(v), do: true
  def valid_issue?(_), do: false

  @doc """
  Validate suggestion structure.

  Ensures suggestion has required fields.
  """
  def valid_suggestion?(%{type: t, suggestions: sugg}) when is_atom(t) and is_list(sugg), do: true
  def valid_suggestion?(_), do: false
end
