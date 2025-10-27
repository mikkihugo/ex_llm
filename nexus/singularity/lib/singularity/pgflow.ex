defmodule Singularity.PgFlow do
  @moduledoc """
  Main context for PgFlow operations.
  """

  alias Singularity.PgFlow.Repo
  alias Singularity.PgFlow.Workflow

  defdelegate persist_workflow(attrs), to: __MODULE__, as: :create_workflow
  defdelegate fetch_workflow(id), to: __MODULE__, as: :get_workflow

  def create_workflow(attrs) do
    %Workflow{}
    |> Workflow.changeset(attrs)
    |> Repo.insert()
  end

  def get_workflow(id) do
    Repo.get_by(Workflow, workflow_id: id)
  end

  def update_workflow_status(workflow, status) do
    workflow
    |> Workflow.changeset(%{status: status})
    |> Repo.update()
  end
end
