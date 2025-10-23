defmodule Singularity.Agents.Workflows.CodeQualityImprovementWorkflow do
  @moduledoc """
  Code Quality Improvement Workflow - Automated agent workflow for improving code quality.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Workflows.CodeQualityImprovementWorkflow",
    "type": "agent_workflow",
    "purpose": "Autonomous workflow for detecting and fixing code quality issues",
    "layer": "agents/workflows",
    "uses_ast_grep": true,
    "autonomous": true
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[execute_quality_improvement_workflow] --> B[scan_codebase_for_issues]
      B --> C{Issues Found?}
      C -->|Yes| D[categorize_and_prioritize_issues]
      D --> E[generate_fix_plan]
      E --> F[execute_auto_fixes]
      F --> G[verify_fixes_dont_break_tests]
      G --> H{Tests Pass?}
      H -->|Yes| I[commit_improvements]
      H -->|No| J[rollback_changes]
      I --> K[generate_improvement_report]
      C -->|No| K
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.CodeQuality.AstSecurityScanner (security scanning)
    - Singularity.CodeQuality.AstQualityAnalyzer (quality analysis)
    - Singularity.ParserEngine (AST operations)
    - Singularity.Agent (agent orchestration)

  called_by:
    - Scheduled jobs (daily quality checks)
    - Git hooks (pre-push quality gates)
    - Manual triggers (via NATS or CLI)
  ```

  ## Anti-Patterns

  ❌ **DO NOT** auto-commit without test verification
  ❌ **DO NOT** fix issues without understanding impact
  ❌ **DO NOT** skip rollback on test failures

  ## Search Keywords

  agent workflow, autonomous quality, code improvement, automated refactoring,
  quality automation, self-improving code, agent orchestration
  """

  alias Singularity.CodeQuality.AstSecurityScanner
  alias Singularity.CodeQuality.AstQualityAnalyzer
  alias Singularity.ParserEngine
  alias Singularity.Agent

  require Logger

  @workflow_name "code_quality_improvement"
  @test_timeout 120_000  # 2 minutes for tests

  # ============================================================================
  # Public API - Workflow Execution
  # ============================================================================

  @doc """
  Execute complete code quality improvement workflow.

  This is an autonomous agent workflow that:
  1. Scans codebase for quality and security issues
  2. Prioritizes issues by severity and impact
  3. Automatically fixes safe issues
  4. Runs tests to verify fixes don't break anything
  5. Commits improvements or rolls back on failures
  6. Generates report of all actions taken

  ## Parameters
  - `codebase_path` - Root directory of codebase
  - `opts` - Options:
    - `:auto_commit` - Automatically commit fixes (default: false)
    - `:run_tests` - Run tests before committing (default: true)
    - `:max_fixes` - Maximum number of issues to fix (default: 50)
    - `:dry_run` - Preview without making changes (default: false)

  ## Returns
  - `{:ok, workflow_report}` - Workflow completed successfully
  - `{:error, reason}` - Workflow failed

  ## Examples

      iex> CodeQualityImprovementWorkflow.execute_quality_improvement_workflow(
      ...>   "lib/",
      ...>   auto_commit: true,
      ...>   run_tests: true
      ...> )
      {:ok, %{
        issues_found: 24,
        issues_fixed: 18,
        issues_skipped: 6,
        tests_passed: true,
        committed: true,
        commit_sha: "abc123..."
      }}
  """
  @spec execute_quality_improvement_workflow(String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def execute_quality_improvement_workflow(codebase_path, opts \\ []) do
    Logger.info("Starting autonomous quality improvement workflow: #{codebase_path}")

    auto_commit = Keyword.get(opts, :auto_commit, false)
    run_tests = Keyword.get(opts, :run_tests, true)
    max_fixes = Keyword.get(opts, :max_fixes, 50)
    dry_run = Keyword.get(opts, :dry_run, false)

    workflow_state = %{
      codebase_path: codebase_path,
      auto_commit: auto_commit,
      run_tests: run_tests,
      max_fixes: max_fixes,
      dry_run: dry_run,
      started_at: DateTime.utc_now()
    }

    with {:ok, state} <- scan_codebase_for_all_issues(workflow_state),
         {:ok, state} <- categorize_and_prioritize_all_issues(state),
         {:ok, state} <- generate_automated_fix_plan(state),
         {:ok, state} <- execute_all_automated_fixes(state),
         {:ok, state} <- verify_fixes_with_test_suite(state),
         {:ok, state} <- commit_improvements_if_approved(state) do
      report = generate_comprehensive_workflow_report(state)

      Logger.info("Quality improvement workflow complete: #{report.summary.issues_fixed} fixes applied")
      {:ok, report}
    else
      {:error, reason} = error ->
        Logger.error("Quality improvement workflow failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Execute security-focused improvement workflow.

  Focuses only on security vulnerabilities, with higher urgency.
  """
  @spec execute_security_improvement_workflow(String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def execute_security_improvement_workflow(codebase_path, opts \\ []) do
    opts = Keyword.merge(opts, categories: [:security], min_severity: :medium)
    execute_quality_improvement_workflow(codebase_path, opts)
  end

  @doc """
  Execute refactoring-focused improvement workflow.

  Focuses on code quality issues like long functions, duplication, etc.
  """
  @spec execute_refactoring_improvement_workflow(String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def execute_refactoring_improvement_workflow(codebase_path, opts \\ []) do
    opts = Keyword.merge(opts, categories: [:long_functions, :duplicate_code, :nested_conditionals])
    execute_quality_improvement_workflow(codebase_path, opts)
  end

  # ============================================================================
  # Public API - Scheduled Workflows
  # ============================================================================

  @doc """
  Run daily automated quality checks (scheduled job).

  Scans codebase, reports issues, but doesn't auto-fix unless configured.
  """
  @spec run_daily_quality_check(String.t()) :: {:ok, map()}
  def run_daily_quality_check(codebase_path) do
    Logger.info("Running daily quality check: #{codebase_path}")

    execute_quality_improvement_workflow(codebase_path,
      auto_commit: false,
      dry_run: true
    )
  end

  @doc """
  Run weekly comprehensive quality improvement (scheduled job).

  More aggressive - attempts to auto-fix issues and commits if tests pass.
  """
  @spec run_weekly_quality_improvement(String.t()) :: {:ok, map()}
  def run_weekly_quality_improvement(codebase_path) do
    Logger.info("Running weekly quality improvement: #{codebase_path}")

    execute_quality_improvement_workflow(codebase_path,
      auto_commit: true,
      run_tests: true,
      max_fixes: 100
    )
  end

  # ============================================================================
  # Private Workflow Steps
  # ============================================================================

  defp scan_codebase_for_all_issues(state) do
    Logger.info("Step 1: Scanning codebase for issues")

    with {:ok, security_report} <-
           AstSecurityScanner.scan_codebase_for_vulnerabilities(state.codebase_path),
         {:ok, quality_report} <-
           AstQualityAnalyzer.analyze_codebase_quality(state.codebase_path) do
      all_issues =
        (security_report.critical ++
           security_report.high ++
           security_report.medium ++
           security_report.low ++
           quality_report.issues)
        |> Enum.take(state.max_fixes)

      state =
        Map.merge(state, %{
          security_report: security_report,
          quality_report: quality_report,
          all_issues: all_issues
        })

      Logger.info("Found #{length(all_issues)} issues to address")
      {:ok, state}
    end
  end

  defp categorize_and_prioritize_all_issues(state) do
    Logger.info("Step 2: Categorizing and prioritizing issues")

    # Sort by severity, then by auto-fixability
    prioritized_issues =
      state.all_issues
      |> Enum.sort_by(fn issue ->
        severity_score = get_severity_numeric_score(issue.severity)
        fixable_bonus = if Map.has_key?(issue, :auto_fix), do: 100, else: 0
        -(severity_score + fixable_bonus)  # Negative for descending order
      end)

    # Group into fixable vs manual review needed
    {auto_fixable, manual_review} =
      Enum.split_with(prioritized_issues, fn issue ->
        Map.has_key?(issue, :auto_fix) and not is_nil(issue.auto_fix)
      end)

    state =
      Map.merge(state, %{
        prioritized_issues: prioritized_issues,
        auto_fixable_issues: auto_fixable,
        manual_review_issues: manual_review
      })

    Logger.info("Categorized: #{length(auto_fixable)} auto-fixable, #{length(manual_review)} need manual review")
    {:ok, state}
  end

  defp generate_automated_fix_plan(state) do
    Logger.info("Step 3: Generating automated fix plan")

    fix_plan =
      state.auto_fixable_issues
      |> Enum.map(fn issue ->
        %{
          issue: issue,
          action: determine_fix_action_for_issue(issue),
          estimated_impact: estimate_fix_impact(issue),
          requires_review: requires_human_review_before_fix?(issue)
        }
      end)

    state = Map.put(state, :fix_plan, fix_plan)

    Logger.info("Generated fix plan with #{length(fix_plan)} actions")
    {:ok, state}
  end

  defp execute_all_automated_fixes(state) do
    if state.dry_run do
      Logger.info("Step 4: Skipping fixes (dry run mode)")
      {:ok, Map.put(state, :fixes_applied, [])}
    else
      Logger.info("Step 4: Executing automated fixes")

      fixes_applied =
        for plan_item <- state.fix_plan,
            not plan_item.requires_review do
          apply_single_automated_fix(plan_item, state)
        end

      successful_fixes = Enum.filter(fixes_applied, fn {status, _} -> status == :ok end)
      failed_fixes = Enum.filter(fixes_applied, fn {status, _} -> status == :error end)

      state =
        Map.merge(state, %{
          fixes_applied: successful_fixes,
          fixes_failed: failed_fixes
        })

      Logger.info("Applied #{length(successful_fixes)} fixes, #{length(failed_fixes)} failed")
      {:ok, state}
    end
  end

  defp verify_fixes_with_test_suite(state) do
    if not state.run_tests or state.dry_run do
      Logger.info("Step 5: Skipping test verification")
      {:ok, Map.put(state, :tests_passed, :skipped)}
    else
      Logger.info("Step 5: Running tests to verify fixes")

      case run_test_suite_with_timeout(state.codebase_path) do
        {:ok, :passed} ->
          Logger.info("✅ All tests passed - fixes are safe")
          {:ok, Map.put(state, :tests_passed, true)}

        {:error, :failed} ->
          Logger.error("❌ Tests failed - rolling back fixes")
          rollback_all_applied_fixes(state)
          {:error, "Tests failed after applying fixes"}

        {:error, :timeout} ->
          Logger.error("⏱️  Tests timed out")
          {:error, "Test suite timeout"}
      end
    end
  end

  defp commit_improvements_if_approved(state) do
    if not state.auto_commit or state.dry_run or length(state.fixes_applied) == 0 do
      Logger.info("Step 6: Skipping commit (auto_commit=false or dry_run or no fixes)")
      {:ok, Map.put(state, :committed, false)}
    else
      Logger.info("Step 6: Committing improvements")

      commit_message = generate_commit_message_for_fixes(state)

      case commit_code_quality_improvements(state.codebase_path, commit_message) do
        {:ok, commit_sha} ->
          Logger.info("✅ Committed improvements: #{commit_sha}")
          {:ok, Map.merge(state, %{committed: true, commit_sha: commit_sha})}

        {:error, reason} ->
          Logger.error("Failed to commit: #{inspect(reason)}")
          {:error, "Commit failed: #{inspect(reason)}"}
      end
    end
  end

  # ============================================================================
  # Private Helpers - Fix Execution
  # ============================================================================

  defp determine_fix_action_for_issue(issue) do
    case issue.auto_fix do
      {:replace, replacement} ->
        {:replace_pattern, issue.pattern, replacement, issue.language}

      {:remove, _} ->
        {:remove_code, issue.pattern, issue.language}

      _ ->
        :manual_review
    end
  end

  defp estimate_fix_impact(issue) do
    # Simple heuristic - would be more sophisticated in production
    case issue.severity do
      :critical -> :high_impact
      :high -> :medium_impact
      :medium -> :low_impact
      :low -> :minimal_impact
      :info -> :minimal_impact
    end
  end

  defp requires_human_review_before_fix?(issue) do
    # Critical security issues should always be reviewed
    issue.severity == :critical
  end

  defp apply_single_automated_fix(plan_item, state) do
    issue = plan_item.issue

    case plan_item.action do
      {:replace_pattern, find_pattern, replace_pattern, language} ->
        replace_pattern_in_file(
          issue.file,
          find_pattern,
          replace_pattern,
          language,
          state.dry_run
        )

      {:remove_code, pattern, language} ->
        remove_pattern_from_file(issue.file, pattern, language, state.dry_run)

      :manual_review ->
        {:skipped, "Requires manual review"}
    end
  end

  defp replace_pattern_in_file(file_path, find_pattern, replace_pattern, language, dry_run) do
    with {:ok, content} <- File.read(file_path),
         {:ok, new_content} <-
           ParserEngine.ast_grep_replace(content, find_pattern, replace_pattern, language) do
      if dry_run do
        {:ok, :dry_run}
      else
        # Backup original
        File.write!("#{file_path}.bak", content)

        # Write fixed version
        File.write!(file_path, new_content)

        {:ok, :fixed}
      end
    else
      error -> {:error, error}
    end
  end

  defp remove_pattern_from_file(file_path, pattern, language, dry_run) do
    # Removing code is risky - just mark for manual review
    {:skipped, "Code removal requires manual review"}
  end

  defp rollback_all_applied_fixes(state) do
    Logger.warning("Rolling back all applied fixes")

    for {status, result} <- state.fixes_applied, status == :ok do
      # Restore from .bak files
      file_path = result.file

      if File.exists?("#{file_path}.bak") do
        File.cp!("#{file_path}.bak", file_path)
        File.rm!("#{file_path}.bak")
      end
    end

    :ok
  end

  # ============================================================================
  # Private Helpers - Testing & Git
  # ============================================================================

  defp run_test_suite_with_timeout(codebase_path) do
    task =
      Task.async(fn ->
        case System.cmd("mix", ["test"], cd: codebase_path, stderr_to_stdout: true) do
          {_, 0} -> :passed
          {_, _} -> :failed
        end
      end)

    case Task.yield(task, @test_timeout) || Task.shutdown(task) do
      {:ok, :passed} -> {:ok, :passed}
      {:ok, :failed} -> {:error, :failed}
      nil -> {:error, :timeout}
    end
  end

  defp commit_code_quality_improvements(codebase_path, message) do
    with {_, 0} <- System.cmd("git", ["add", "."], cd: codebase_path),
         {_, 0} <- System.cmd("git", ["commit", "-m", message], cd: codebase_path),
         {sha, 0} <- System.cmd("git", ["rev-parse", "HEAD"], cd: codebase_path) do
      {:ok, String.trim(sha)}
    else
      {error, _code} -> {:error, error}
    end
  end

  defp generate_commit_message_for_fixes(state) do
    """
    chore: Automated code quality improvements

    Applied #{length(state.fixes_applied)} automated fixes:
    - Security: #{count_fixes_by_type(state.fixes_applied, :security)}
    - Quality: #{count_fixes_by_type(state.fixes_applied, :quality)}

    🤖 Generated by Singularity Quality Improvement Workflow
    """
  end

  # ============================================================================
  # Private Helpers - Reporting
  # ============================================================================

  defp generate_comprehensive_workflow_report(state) do
    %{
      workflow: @workflow_name,
      status: :completed,
      summary: %{
        issues_found: length(state.all_issues),
        issues_fixed: length(state.fixes_applied),
        issues_skipped: length(state.manual_review_issues),
        tests_passed: state[:tests_passed] == true,
        committed: state[:committed] == true,
        commit_sha: state[:commit_sha]
      },
      security_summary: %{
        critical: length(state.security_report.critical),
        high: length(state.security_report.high),
        medium: length(state.security_report.medium)
      },
      quality_summary: %{
        score: state.quality_report.score,
        total_issues: state.quality_report.summary.total
      },
      timing: %{
        started_at: state.started_at,
        completed_at: DateTime.utc_now(),
        duration_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
      },
      manual_review_needed: state.manual_review_issues
    }
  end

  defp get_severity_numeric_score(severity) do
    %{critical: 100, high: 75, medium: 50, low: 25, info: 10}[severity] || 0
  end

  defp count_fixes_by_type(fixes, type) do
    Enum.count(fixes, fn {_status, result} ->
      result[:type] == type
    end)
  end
end
