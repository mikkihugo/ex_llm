defmodule Singularity.Workflows do
  @moduledoc """
  Read-only helpers for inspecting QuantumFlow workflows persisted in PostgreSQL.

  This module delegates to `QuantumFlow.Workflow` and the `quantum_flow_workflows`
  table managed by the QuantumFlow runtime. No ETS/cache layer is used.
  """

  alias QuantumFlow.{Repo, Workflow}
  alias QuantumFlow.WorkflowRun

  import Ecto.Query

  @doc """
  Fetch a workflow run by ID from the database.
  """
  @spec fetch_run(Workflow.run_id()) :: {:ok, WorkflowRun.t()} | :not_found
  def fetch_run(run_id) do
    case Repo.get(WorkflowRun, run_id) do
      %WorkflowRun{} = run -> {:ok, run}
      nil -> :not_found
    end
  end

  @doc """
  List recent workflow runs filtered by status/type.
  """
  @spec list_runs(keyword()) :: [WorkflowRun.t()]
  def list_runs(opts \\ []) do
    WorkflowRun
    |> maybe_filter_status(opts)
    |> maybe_filter_type(opts)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^Keyword.get(opts, :limit, 100))
    |> Repo.all()
  end

  defp maybe_filter_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil -> query
      status -> from(r in query, where: r.status == ^status)
    end
  end

  defp maybe_filter_type(query, opts) do
    case Keyword.get(opts, :workflow) do
      nil -> query
      type -> from(r in query, where: r.workflow_slug == ^type)
    end
  end
end
