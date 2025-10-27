defmodule Singularity.Planner.RefactorPlanner do
  @moduledoc """
  Build HTDAG-style task graphs from analyzer results.

  Enhanced planner that orchestrates the full agent ecosystem:
  - Technology detection (TechnologyAgent)
  - Quality enforcement (QualityEnforcer)
  - Dead code monitoring (DeadCodeMonitor)
  - Code refactoring (RefactorWorker)
  - Learning and assimilation (AssimilateWorker)

  This is a lightweight planner that converts CodeEngine or heuristic outputs into
  a map of tasks with dependencies. Each task is a map with keys:
    - :id (string)
    - :type (:task | :approval)
    - :worker ({Module, :function} | :approval)
    - :args (map)
    - :depends_on (list of ids)

  The planner returns deterministic, testable HTDAG maps with proper worker references.
  """

  require Logger
  alias Singularity.Workflows

  @spec plan(map()) :: {:ok, %{nodes: [map()], workflow_id: String.t()}} | {:error, term()}
  def plan(%{codebase_id: codebase_id, issues: issues} = _analysis) when is_list(issues) do
    # Build comprehensive HTDAG nodes with all agent types integrated
    pre_nodes = pre_analysis_nodes(codebase_id)
    beam_nodes = beam_analysis_nodes(codebase_id, issues)
    beam_dependencies = Enum.map(beam_nodes, & &1.id)

    all_nodes =
      []
      # Phase 0: Pre-analysis (tech stack detection)
      |> Kernel.++(pre_nodes)
      # Phase 0b: Beam/OTP analysis per relevant file
      |> Kernel.++(beam_nodes)
      # Phase 1: Code smells and refactoring per issue
      |> Kernel.++(refactor_nodes(issues, codebase_id, beam_dependencies))
      # Phase 2: Quality gates
      |> Kernel.++(quality_nodes(codebase_id, issues))
      # Phase 3: Dead code monitoring
      |> Kernel.++(dead_code_nodes(codebase_id))
      # Phase 4: Final integration and learning
      |> Kernel.++(integration_nodes(codebase_id, issues))

    {:ok,
     %{
       nodes: all_nodes,
       workflow_id: "full_refactor_#{codebase_id}_#{:erlang.unique_integer([:positive])}"
     }}
  end

  def plan(_), do: {:error, :invalid_analysis}

  @doc """
  Detect issues for a codebase, build the refactor workflow, persist it through
  `Singularity.Workflows`, and optionally execute it.

  ## Options

    * `:issues` - Provide a precomputed list of issues (skips detection)
    * `:execute` - When true, immediately execute the persisted workflow
    * `:dry_run` - When executing, run in dry-run mode (default: true)

  Returns `{:ok, result}` with the workflow id, planned nodes, detected issues,
  and optional execution summary when executed. Detection or execution failures
  bubble up as `{:error, reason}`.
  """
  @spec create_workflow(String.t(), keyword()) ::
          {:ok,
           %{
             workflow_id: String.t(),
             nodes: [map()],
             issues: [map()],
             execution_summary: map() | nil
           }}
          | {:error, term()}
  def create_workflow(codebase_id, opts \\ []) when is_binary(codebase_id) do
    with {:ok, issues} <- resolve_issues(codebase_id, opts),
         {:ok, %{nodes: nodes, workflow_id: workflow_id}} <-
           plan(%{codebase_id: codebase_id, issues: issues}),
         {:ok, persisted_id} <-
           Workflows.create_workflow(%{
             type: :refactor_workflow,
             workflow_id: workflow_id,
             nodes: nodes,
             payload: %{codebase_id: codebase_id, issues: issues}
           }) do
      result = %{workflow_id: persisted_id, nodes: nodes, issues: issues, execution_summary: nil}

      case Keyword.get(opts, :execute, false) do
        true -> execute_created_workflow(result, opts)
        false -> {:ok, result}
      end
    end
  end

  def create_workflow(_, _opts), do: {:error, :invalid_codebase}

  defp execute_created_workflow(%{workflow_id: workflow_id} = result, opts) do
    dry_run = Keyword.get(opts, :dry_run, true)

    case Workflows.execute_workflow(workflow_id, dry_run: dry_run) do
      {:ok, summary} -> {:ok, %{result | execution_summary: summary}}
      {:error, reason} -> {:error, {:execution_failed, reason}}
    end
  end

  defp resolve_issues(codebase_id, opts) do
    case Keyword.get(opts, :issues) do
      nil -> detect_smells(codebase_id)
      issues when is_list(issues) -> {:ok, issues}
      fun when is_function(fun, 1) -> fun.(codebase_id)
      other -> {:error, {:invalid_issues, other}}
    end
  end

  # Phase 0: Pre-analysis nodes using existing agents
  defp pre_analysis_nodes(codebase_id) do
    [
      # Detect technology stack
      %{
        id: "phase0_tech_detect",
        type: :task,
        worker: {Singularity.Agents.TechnologyAgent, :detect_technologies},
        args: %{codebase_id: codebase_id},
        depends_on: [],
        description: "Detect technology stack in codebase"
      },
      # Analyze dependencies
      %{
        id: "phase0_deps_analyze",
        type: :task,
        worker: {Singularity.Agents.TechnologyAgent, :analyze_dependencies},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase0_tech_detect"],
        description: "Analyze dependency patterns"
      }
    ]
  end

  # Phase 0b: Beam analysis nodes per unique path
  defp beam_analysis_nodes(codebase_id, issues) do
    issues
    |> Enum.map(& &1[:path])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.with_index(1)
    |> Enum.map(fn {path, idx} ->
      id = "phase0_beam_analyze_#{idx}"
      language = beam_language_from_path(path)

      %{
        id: id,
        type: :task,
        worker: {Singularity.Execution.BeamAnalysisWorker, :analyze_file},
        args: %{
          codebase_id: codebase_id,
          path: path,
          language: language
        },
        depends_on: ["phase0_deps_analyze"],
        description: "Analyze BEAM patterns for #{path}"
      }
    end)
  end

  defp beam_language_from_path(path) do
    case Path.extname(path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".erl" -> "erlang"
      ".gleam" -> "gleam"
      _ -> "elixir"
    end
  end

  # Phase 1: Refactoring nodes per issue
  defp refactor_nodes(issues, codebase_id, beam_dependencies) do
    Enum.with_index(issues, 1)
    |> Enum.flat_map(fn {issue, idx} ->
      base = "phase1_task_#{idx}_#{issue[:short] || "issue"}"

      analyze_id = base <> "_analyze"
      transform_id = base <> "_transform"
      test_id = base <> "_test"

      [
        # Analyze node: inspect code for the issue
        %{
          id: analyze_id,
          type: :task,
          worker: {Singularity.Execution.RefactorWorker, :analyze},
          args: %{issue: issue, codebase_id: codebase_id},
          depends_on: ["phase0_deps_analyze"] ++ beam_dependencies,
          description: "Analyze: #{issue[:description]}"
        },
        # Transform node: apply refactoring patch
        %{
          id: transform_id,
          type: :task,
          worker: {Singularity.Execution.RefactorWorker, :transform},
          args: %{issue: issue, codebase_id: codebase_id},
          depends_on: [analyze_id],
          description: "Transform: #{issue[:description]}"
        },
        # Test node: validate changes
        %{
          id: test_id,
          type: :task,
          worker: {Singularity.Execution.RefactorWorker, :validate},
          args: %{issue: issue, codebase_id: codebase_id},
          depends_on: [transform_id],
          description: "Validate: #{issue[:description]}"
        }
      ]
    end)
  end

  # Phase 2: Quality enforcement nodes
  defp quality_nodes(codebase_id, issues) do
    test_ids =
      Enum.with_index(issues, 1)
      |> Enum.map(fn {issue, idx} ->
        "phase1_task_#{idx}_#{issue[:short] || "issue"}_test"
      end)

    [
      # Quality enforcement gate (depends on all transforms being tested)
      %{
        id: "phase2_quality_enforce",
        type: :task,
        worker: {Singularity.Agents.QualityEnforcer, :enforce_quality_standards},
        args: %{codebase_id: codebase_id, files: []},
        depends_on: test_ids,
        description: "Enforce quality standards on refactored code"
      },
      # Get quality report
      %{
        id: "phase2_quality_report",
        type: :task,
        worker: {Singularity.Agents.QualityEnforcer, :get_quality_report},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase2_quality_enforce"],
        description: "Generate quality compliance report"
      }
    ]
  end

  # Phase 3: Dead code monitoring
  defp dead_code_nodes(codebase_id) do
    [
      %{
        id: "phase3_dead_code_scan",
        type: :task,
        worker: {Singularity.Agents.DeadCodeMonitor, :scan_dead_code},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase2_quality_report"],
        description: "Scan for dead code annotations"
      },
      %{
        id: "phase3_dead_code_analyze",
        type: :task,
        worker: {Singularity.Agents.DeadCodeMonitor, :analyze_dead_code},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase3_dead_code_scan"],
        description: "Analyze and categorize dead code"
      }
    ]
  end

  # Phase 4: Final integration and learning
  defp integration_nodes(codebase_id, issues) do
    test_ids =
      Enum.with_index(issues, 1)
      |> Enum.map(fn {issue, idx} ->
        "phase1_task_#{idx}_#{issue[:short] || "issue"}_test"
      end)

    [
      # Manual approval gate before integration
      %{
        id: "phase4_approval_merge",
        type: :approval,
        reason: "manual_review_before_integration",
        depends_on: ["phase3_dead_code_analyze"],
        description: "Manual review and approval for code integration"
      },
      # Learn from changes
      %{
        id: "phase4_learn",
        type: :task,
        worker: {Singularity.Execution.AssimilateWorker, :learn},
        args: %{codebase_id: codebase_id, issues: issues},
        depends_on: ["phase4_approval_merge"],
        description: "Record patterns from successful refactorings"
      },
      # Integrate changes
      %{
        id: "phase4_integrate",
        type: :task,
        worker: {Singularity.Execution.AssimilateWorker, :integrate},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase4_learn"],
        description: "Merge refactored code to main branch"
      },
      # Final report
      %{
        id: "phase4_report",
        type: :task,
        worker: {Singularity.Execution.AssimilateWorker, :report},
        args: %{codebase_id: codebase_id},
        depends_on: ["phase4_integrate"],
        description: "Generate final improvement metrics"
      }
    ]
  end

  @doc """
  Lightweight smell detector demo. In a real system this would call CodeEngine
  and heuristics to find code smells. Here it returns a small list of example
  issues when a codebase_id is present to drive the planner/demo.
  """
  @spec detect_smells(String.t() | term()) :: {:ok, [map()]} | {:error, term()}
  def detect_smells(codebase_id) when not is_nil(codebase_id) do
    # Demo: pretend large codebases have two issues
    issues = [
      %{
        short: "long_function",
        description: "Function exceeds recommended length",
        path: "lib/foo.ex",
        severity: :medium
      },
      %{
        short: "deep_nesting",
        description: "Deeply nested conditionals",
        path: "lib/bar.ex",
        severity: :high
      }
    ]

    {:ok, issues}
  end

  def detect_smells(_), do: {:ok, []}
end
