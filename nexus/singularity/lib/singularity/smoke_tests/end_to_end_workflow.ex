defmodule Singularity.SmokeTests.EndToEndWorkflow do
  @moduledoc """
  End-to-end smoke test demonstrating the full workflow:
  Detect smells → Plan → Persist → Execute (dry-run) → Request approval → Apply

  Run this with:
    iex(1)> Singularity.SmokeTests.EndToEndWorkflow.run_smoke_test()
  """

  require Logger
  alias Singularity.Planner.RefactorPlanner
  alias Singularity.Workflows
  alias Singularity.Agents.SelfImprovementAgent
  alias Singularity.Agents.Arbiter

  def run_smoke_test do
    Logger.info("=" <> String.duplicate("=", 60))
    Logger.info("Starting End-to-End Workflow Smoke Test")
    Logger.info("=" <> String.duplicate("=", 60))

    # Step 1: Detect code smells
    Logger.info("\n[Step 1] Detecting code smells...")
    codebase_id = "test_codebase_#{:erlang.unique_integer([:positive])}"
    {:ok, smells} = RefactorPlanner.detect_smells(codebase_id)
    Logger.info("Found #{length(smells)} code smells")
    Enum.each(smells, fn smell -> Logger.info("  - #{smell[:short]}: #{smell[:description]}") end)

    # Step 2: Generate HTDAG workflow
    Logger.info("\n[Step 2] Planning refactoring workflow...")
    {:ok, workflow_plan} = RefactorPlanner.plan(%{codebase_id: codebase_id, issues: smells})
    Logger.info("Generated workflow with #{length(workflow_plan.nodes)} nodes")
    Enum.each(workflow_plan.nodes, fn node ->
      Logger.info("  - #{node.id}: #{inspect(node.worker)}")
    end)

    # Step 3: Persist workflow to unified system
    Logger.info("\n[Step 3] Persisting workflow to PgFlow...")
    workflow_attrs = Map.merge(workflow_plan, %{
      type: :workflow,
      status: :pending,
      payload: %{codebase_id: codebase_id, smells: smells}
    })
    {:ok, workflow_id} = Workflows.create_workflow(workflow_attrs)
    Logger.info("Persisted workflow: #{workflow_id}")

    # Step 4: Execute workflow in dry-run mode
    Logger.info("\n[Step 4] Executing workflow in dry-run mode...")
    {:ok, exec_summary} = Workflows.execute_workflow(workflow_id, dry_run: true)
    Logger.info("Executed #{exec_summary.node_count} nodes")
    Logger.info("Execution timestamp: #{exec_summary.timestamp}")

    # Step 5: Request approval via arbiter
    Logger.info("\n[Step 5] Requesting workflow approval...")
    {:ok, approval_token} = Workflows.request_approval(workflow_id, "smoke_test_approval")
    Logger.info("Approval token: #{String.slice(approval_token, 0..8)}...")

    # Step 6: Apply workflow with approval (dry-run)
    Logger.info("\n[Step 6] Applying workflow with approval token (dry-run)...")
    {:ok, apply_result} = Workflows.apply_with_approval(workflow_id, approval_token, dry_run: true)
    Logger.info("Applied workflow with result: #{inspect(apply_result)}")

    # Step 7: Fetch and display final workflow state
    Logger.info("\n[Step 7] Final workflow state...")
    {:ok, final_wf} = Workflows.fetch_workflow(workflow_id)
    Logger.info("Final status: #{final_wf.status}")
    Logger.info("Workflow ID: #{final_wf.workflow_id}")
    Logger.info("Node count: #{length(final_wf.nodes)}")

    Logger.info("\n" <> String.duplicate("=", 62))
    Logger.info("✅ End-to-End Smoke Test PASSED")
    Logger.info("=" <> String.duplicate("=", 60))

    {:ok, %{
      workflow_id: workflow_id,
      node_count: exec_summary.node_count,
      approval_token: approval_token,
      status: final_wf.status
    }}
  end

  def run_with_self_improvement_agent do
    Logger.info("\n" <> String.duplicate("=", 62))
    Logger.info("Running workflow with SelfImprovementAgent...")
    Logger.info("=" <> String.duplicate("=", 60))

    # Start the agent
    {:ok, _pid} = SelfImprovementAgent.start_link([])

    # Suggest a workflow-based improvement
    workflow = %{
      workflow_id: "test_wf_#{:erlang.unique_integer([:positive])}",
      type: :workflow,
      nodes: [
        %{id: "task_1", type: :task, worker: {Singularity.Execution.RefactorWorker, :analyze}, args: %{}}
      ]
    }

    Logger.info("Requesting workflow approval...")
    {:ok, token} = SelfImprovementAgent.request_workflow_approval(workflow)
    Logger.info("Got approval token: #{String.slice(token, 0..8)}...")

    Logger.info("Applying workflow with approval...")
    {:ok, result} = SelfImprovementAgent.apply_workflow_with_approval(token)
    Logger.info("Result: #{inspect(result)}")

    {:ok, result}
  end
end
