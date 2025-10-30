defmodule Singularity.Workflows do
  @moduledoc """
  Unified HTDAG + PgFlow workflow management system.

  Consolidates:
  - Workflow persistence (replaces PgFlowAdapter)
  - Workflow execution (replaces HTDAG.Executor)
  - Approval/authorization (integrates with Arbiter)

  All workflows are stored in ETS `:pgflow_workflows` table for immediate visibility,
  with optional database persistence for durability.
  """

  require Logger
  alias Singularity.Agents.Arbiter
  alias Singularity.Architecture.PatternDetector

  @table :pgflow_workflows

  def init do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    :ok
  rescue
    _ -> :ok
  end

  @doc "Create and persist a workflow. Returns {:ok, workflow_id}."
  def create_workflow(attrs) when is_map(attrs) do
    init()

    id = attrs[:workflow_id] || Map.get(attrs, :id) || "wf_#{:erlang.unique_integer([:positive])}"
    now = DateTime.utc_now()

    workflow = %{
      id: id,
      workflow_id: id,
      type: Map.get(attrs, :type, :workflow),
      status: Map.get(attrs, :status, :pending),
      payload: Map.get(attrs, :payload, %{}),
      nodes: Map.get(attrs, :nodes, []),
      created_at: now,
      updated_at: now
    }

    :ets.insert(@table, {id, workflow})
    {:ok, id}
  end

  @doc "Fetch a workflow by ID."
  def fetch_workflow(id) do
    case :ets.lookup(@table, id) do
      [{^id, workflow}] -> {:ok, workflow}
      [] -> :not_found
    end
  end

  @doc "Update workflow status."
  def update_workflow_status(id, status) when is_binary(status) do
    case fetch_workflow(id) do
      {:ok, workflow} ->
        updated = Map.put(workflow, :status, status)
        :ets.insert(@table, {id, updated})
        {:ok, updated}

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc "List all workflows of a given type."
  def list_workflows_by_type(type) when is_atom(type) or is_binary(type) do
    init()

    @table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, wf} -> wf.type == type end)
    |> Enum.map(fn {_id, wf} -> wf end)
  end

  @doc "Execute a workflow by ID (dry-run by default). Returns execution summary."
  def execute_workflow(id, opts \\ []) do
    case fetch_workflow(id) do
      {:ok, workflow} -> execute_workflow_map(workflow, opts)
      :not_found -> {:error, :not_found}
    end
  end

  @doc "Execute a workflow map directly."
  def execute_workflow_map(workflow, opts \\ []) when is_map(workflow) do
    workflow_id = workflow.id || workflow.workflow_id || "wf_unknown"
    dry_run = Keyword.get(opts, :dry_run, true)

    Logger.info("Executing workflow #{workflow_id} (dry_run=#{dry_run})")

    nodes = workflow.nodes || []

    # Execute each node sequentially (can add parallel/barrier logic later)
    results =
      Enum.map(nodes, fn node ->
        execute_node(node, opts)
      end)

    # Persist execution result
    update_workflow_status(workflow_id, :executed)

    execution_summary = %{
      workflow_id: workflow_id,
      dry_run: dry_run,
      node_count: length(nodes),
      results: results,
      timestamp: DateTime.utc_now()
    }

    {:ok, execution_summary}
  end

  defp execute_node(%{type: :task, worker: worker, args: args} = node, opts) do
    Logger.debug("Executing task node: #{inspect(node)}")

    case apply_worker(worker, args, opts) do
      {:ok, out} -> %{node_id: node.id, status: :ok, result: out}
      {:error, reason} -> %{node_id: node.id, status: :error, reason: reason}
    end
  end

  defp execute_node(%{type: :approval, reason: reason} = node, _opts) do
    Logger.debug("Approval node reached: #{reason}")
    %{node_id: node.id, status: :paused, reason: :requires_approval}
  end

  defp execute_node(%{type: :parallel, children: children} = node, opts) do
    Logger.debug("Parallel node with #{length(children)} children")

    tasks =
      Enum.map(children, fn child ->
        Task.async(fn -> execute_node(child, opts) end)
      end)

    results = Enum.map(tasks, &Task.await(&1, 30_000))
    %{node_id: node.id, status: :ok, results: results}
  end

  defp execute_node(%{type: :barrier, children: children} = node, opts) do
    Logger.debug("Barrier node with #{length(children)} children")

    results = Enum.map(children, fn child -> execute_node(child, opts) end)
    %{node_id: node.id, status: :ok, results: results}
  end

  defp execute_node(node, _opts) do
    Logger.warning("Unknown node type: #{inspect(node)}")
    %{node_id: node.id, status: :unknown}
  end

  defp apply_worker({module, function}, args, opts) when is_atom(module) and is_atom(function) do
    try do
      if function_exported?(module, function, 2) do
        apply(module, function, [args, opts])
      else
        {:error, :worker_unavailable}
      end
    rescue
      e -> {:error, {:exception, e}}
    end
  end

  defp apply_worker(_other, _args, _opts) do
    {:error, :invalid_worker}
  end

  @doc "Request workflow approval and get a short-lived token."
  def request_approval(workflow_id, reason \\ "manual_review") do
    token = Arbiter.issue_workflow_approval(%{workflow_id: workflow_id, reason: reason}, [])
    {:ok, token}
  end

  @doc "Apply a workflow with Arbiter approval token (consumes token)."
  def apply_with_approval(workflow_id, approval_token, opts \\ []) do
    case Arbiter.authorize_workflow(approval_token) do
      :ok ->
        execute_workflow(workflow_id, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Schedule a pattern rescan workflow for the given repo path.

  Returns {:ok, execution_summary} or {:error, reason}.
  """
  def schedule_pattern_rescan(repo_path, metadata \\ %{}) when is_binary(repo_path) do
    init()

    workflow_id = "pattern_rescan:" <> Integer.to_string(:erlang.unique_integer([:positive]))

    workflow = %{
      id: workflow_id,
      type: :pattern_rescan,
      status: :pending,
      payload: Map.put(metadata, :repo_path, repo_path),
      nodes: [
        %{
          id: :pattern_rescan,
          type: :task,
          worker: {__MODULE__, :pattern_rescan_worker},
          args: %{repo_path: repo_path, metadata: metadata}
        }
      ]
    }

    with {:ok, _} <- create_workflow(workflow),
         {:ok, summary} <- execute_workflow_map(workflow, dry_run: false) do
      {:ok, summary}
    else
      {:error, reason} = error ->
        Logger.error("Failed to schedule pattern rescan workflow",
          repo_path: repo_path,
          reason: inspect(reason)
        )

        error
    end
  end

  @doc false
  def pattern_rescan_worker(%{repo_path: repo_path, metadata: metadata}, _opts) do
    measurement_start = System.monotonic_time(:millisecond)

    case PatternDetector.detect(repo_path) do
      {:ok, detections} ->
        duration = System.monotonic_time(:millisecond) - measurement_start

        :telemetry.execute(
          [:singularity, :pattern_rescan, :completed],
          %{duration_ms: duration, detections_found: length(detections)},
          Map.merge(metadata || %{}, %{repo_path: repo_path, status: :ok})
        )

        {:ok, %{detections: detections}}

      {:error, reason} ->
        duration = System.monotonic_time(:millisecond) - measurement_start

        :telemetry.execute(
          [:singularity, :pattern_rescan, :failed],
          %{duration_ms: duration},
          Map.merge(metadata || %{}, %{
            repo_path: repo_path,
            status: :error,
            error: inspect(reason)
          })
        )

        {:error, reason}
    end
  rescue
    error ->
      :telemetry.execute(
        [:singularity, :pattern_rescan, :failed],
        %{},
        Map.merge(metadata || %{}, %{
          repo_path: repo_path,
          status: :exception,
          error: inspect(error)
        })
      )

      {:error, {:exception, error}}
  end
end
