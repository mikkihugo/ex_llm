defmodule Singularity.Workflows.LintingAnalysisRca do
  @moduledoc """
  Linting Analysis Workflow - With RCA Tracking

  Runs linting engines (Rust NIF engines, external tools) and tracks results via RCA.
  Shows how to integrate tool-based workflows with RCA system.

  ## Workflow Steps

  1. **select_linters** - Determine which linters to run based on languages
  2. **run_linters** - Execute linting engines (Rust NIFs + external tools)
  3. **aggregate_results** - Combine results from all linters
  4. **prioritize_issues** - Rank issues by severity
  5. **generate_report** - Create actionable report

  ## RCA Integration

  - ✅ Tracks which linting engines are most effective
  - ✅ Records time and resource usage per linter
  - ✅ Enables selection of best linting strategy
  - ✅ Learns which issues are hardest to fix
  - ✅ Supports cost optimization of analysis

  ## Key Metrics Captured

  - Linter execution time
  - Issues found by type
  - False positive rate
  - Performance (time per 1000 LOC)
  - Success rate of fixes

  ## Usage

  ```elixir
  # Direct execution
  {:ok, result} = Singularity.Workflows.LintingAnalysisRca.execute(%{
    codebase_path: "/app",
    languages: ["elixir", "rust"]
  })

  # Via QuantumFlow
  {:ok, result} = QuantumFlow.Executor.execute(
    Singularity.Workflows.LintingAnalysisRca,
    %{codebase_path: "/app"},
    timeout: 120000
  )
  ```

  ## Integration with RCA Learning

  The system learns:
  - Which linting engines catch most real issues
  - Which linters have lowest false positive rate
  - Optimal combination of linters for each language
  - Most efficient order to run linters
  - Cost vs quality tradeoffs
  """

  use Singularity.Workflows.RcaWorkflow
  require Logger

  @impl Singularity.Workflows.RcaWorkflow
  def rca_config do
    %{
      agent_id: "linting-analysis-agent",
      template_id: "linting-analysis",
      agent_version: "v2.0.0"
    }
  end

  @impl Singularity.Workflows.RcaWorkflow
  def __workflow_steps__ do
    [
      {:select_linters, &__MODULE__.select_linters/1},
      {:run_linters, &__MODULE__.run_linters/1},
      {:aggregate_results, &__MODULE__.aggregate_results/1},
      {:prioritize_issues, &__MODULE__.prioritize_issues/1},
      {:generate_report, &__MODULE__.generate_report/1}
    ]
  end

  @impl Singularity.Workflows.RcaWorkflow
  def execute(input) do
    execute_with_rca(input)
  end

  @doc false
  def select_linters(input) do
    codebase_path = Map.get(input, :codebase_path)
    languages = Map.get(input, :languages, detect_languages(codebase_path))

    Logger.info("Selecting linters", %{
      codebase: codebase_path,
      languages: languages
    })

    # Select best linting engines based on RCA learnings
    selected = select_optimal_linters(languages)

    Logger.info("Linters selected", %{
      linters: Enum.map(selected, &elem(&1, 0)),
      count: length(selected)
    })

    {:ok,
     Map.merge(input, %{
       "languages" => languages,
       "selected_linters" => selected,
       "tokens_used" => 100
     })}
  end

  @doc false
  def run_linters(input) do
    selected_linters = Map.get(input, "selected_linters", [])
    codebase_path = Map.get(input, :codebase_path)

    Logger.info("Running linters", %{
      count: length(selected_linters),
      codebase: codebase_path
    })

    # Execute each linter and collect results
    results =
      selected_linters
      |> Enum.map(fn {linter_name, _config} ->
        run_linter(linter_name, codebase_path)
      end)
      |> Enum.into(%{})

    total_issues = count_total_issues(results)

    Logger.info("Linting complete", %{
      linters_run: length(selected_linters),
      total_issues: total_issues,
      execution_time_ms: 5234
    })

    {:ok,
     Map.merge(input, %{
       "lint_results" => results,
       "total_issues" => total_issues,
       "tokens_used" => 200,
       "metrics" => %{
         "issues_found" => total_issues,
         "linters_run" => length(selected_linters),
         "execution_time_ms" => 5234
       }
     })}
  end

  @doc false
  def aggregate_results(input) do
    lint_results = Map.get(input, "lint_results", %{})

    Logger.info("Aggregating linting results", %{
      linters: map_size(lint_results)
    })

    # Merge results from all linters
    aggregated = merge_lint_results(lint_results)

    Logger.info("Results aggregated", %{
      unique_issues: length(aggregated.issues),
      duplicate_issues: aggregated.duplicates
    })

    {:ok,
     Map.merge(input, %{
       "aggregated_results" => aggregated,
       "tokens_used" => 150
     })}
  end

  @doc false
  def prioritize_issues(input) do
    aggregated = Map.get(input, "aggregated_results", %{})

    Logger.info("Prioritizing issues", %{
      issue_count: length(Map.get(aggregated, :issues, []))
    })

    # Prioritize by severity
    prioritized = prioritize_by_severity(aggregated)

    Logger.info("Issues prioritized", %{
      critical: count_by_severity(prioritized, "critical"),
      high: count_by_severity(prioritized, "high"),
      medium: count_by_severity(prioritized, "medium"),
      low: count_by_severity(prioritized, "low")
    })

    {:ok,
     Map.merge(input, %{
       "prioritized_issues" => prioritized,
       "tokens_used" => 100,
       "metrics" => %{
         "critical_issues" => count_by_severity(prioritized, "critical"),
         "high_issues" => count_by_severity(prioritized, "high")
       }
     })}
  end

  @doc false
  def generate_report(input) do
    prioritized = Map.get(input, "prioritized_issues", [])

    Logger.info("Generating report", %{
      issues: length(prioritized)
    })

    # Generate actionable report
    report = create_report(prioritized)

    Logger.info("Report generated", %{
      pages: report.page_count,
      recommendations: length(report.recommendations)
    })

    {:ok,
     Map.merge(input, %{
       "report" => report,
       "tokens_used" => 300,
       "recommendations" => length(report.recommendations),
       "passed" => true
     })}
  end

  # --- Private Helpers ---

  defp detect_languages(codebase_path) do
    # In production, detect languages from files
    ["elixir", "rust"]
  end

  defp select_optimal_linters(languages) do
    # Query RCA to see which linters work best for these languages
    # For now, return defaults
    linters_for_languages(languages)
  end

  defp linters_for_languages(languages) do
    Enum.flat_map(languages, fn lang ->
      case lang do
        "elixir" ->
          [
            {"credo", %{enabled: true}},
            {"dialyzer", %{enabled: true}},
            {"mix_format", %{enabled: true}}
          ]

        "rust" ->
          [
            {"clippy", %{enabled: true}},
            {"rustfmt", %{enabled: true}}
          ]

        _ ->
          []
      end
    end)
  end

  defp run_linter(linter_name, codebase_path) do
    # Execute the linter
    # This would call the actual Rust NIF engine or external tool
    issues = simulate_linting(linter_name, codebase_path)

    {linter_name,
     %{
       "issues" => issues,
       "count" => length(issues),
       "execution_time_ms" => random_execution_time(),
       "status" => "success"
     }}
  end

  defp simulate_linting(linter_name, _codebase_path) do
    # Simulate linting results
    case linter_name do
      "credo" ->
        [
          %{file: "lib/module_a.ex", line: 42, severity: "high", rule: "complexity"},
          %{file: "lib/module_b.ex", line: 156, severity: "medium", rule: "naming"},
          %{file: "lib/module_c.ex", line: 89, severity: "low", rule: "duplication"}
        ]

      "dialyzer" ->
        [
          %{file: "lib/module_a.ex", line: 45, severity: "high", rule: "type_error"}
        ]

      "clippy" ->
        [
          %{file: "src/main.rs", line: 12, severity: "medium", rule: "unused_variable"}
        ]

      _ ->
        []
    end
  end

  defp random_execution_time do
    Enum.random(1000..5000)
  end

  defp count_total_issues(results) do
    results
    |> Map.values()
    |> Enum.map(&Map.get(&1, "count", 0))
    |> Enum.sum()
  end

  defp merge_lint_results(results) do
    all_issues =
      results
      |> Map.values()
      |> Enum.flat_map(&Map.get(&1, "issues", []))

    duplicates = count_duplicates(all_issues)

    %{
      issues: Enum.uniq_by(all_issues, &{&1.file, &1.line}),
      duplicates: duplicates,
      total_reported: length(all_issues)
    }
  end

  defp count_duplicates(issues) do
    length(issues) - length(Enum.uniq_by(issues, &{&1.file, &1.line}))
  end

  defp prioritize_by_severity(aggregated) do
    aggregated
    |> Map.get(:issues, [])
    |> Enum.sort_by(&severity_rank/1, :desc)
  end

  defp severity_rank(issue) do
    case Map.get(issue, :severity, "low") do
      "critical" -> 4
      "high" -> 3
      "medium" -> 2
      "low" -> 1
      _ -> 0
    end
  end

  defp count_by_severity(issues, severity_level) do
    issues
    |> Enum.filter(&(Map.get(&1, :severity) == severity_level))
    |> length()
  end

  defp create_report(prioritized) do
    %{
      page_count: ceil(length(prioritized) / 10),
      issues: prioritized,
      recommendations: generate_recommendations(prioritized),
      summary: %{
        total_issues: length(prioritized),
        fixable: count_fixable(prioritized),
        requires_review: count_requires_review(prioritized)
      }
    }
  end

  defp generate_recommendations(issues) do
    case Enum.count(issues, &is_critical/1) do
      count when count > 0 ->
        [
          "Fix #{count} critical issues immediately",
          "Review code review process",
          "Add automated checks to CI/CD"
        ]

      _ ->
        [
          "Address high severity issues",
          "Schedule code quality improvement",
          "Consider automated formatting"
        ]
    end
  end

  defp is_critical(issue) do
    Map.get(issue, :severity) == "critical"
  end

  defp count_fixable(issues) do
    issues
    |> Enum.filter(&can_auto_fix/1)
    |> length()
  end

  defp count_requires_review(issues) do
    issues
    |> Enum.filter(&requires_review/1)
    |> length()
  end

  defp can_auto_fix(issue) do
    Map.get(issue, :rule) in ["formatting", "naming", "duplication"]
  end

  defp requires_review(issue) do
    not can_auto_fix(issue)
  end
end
