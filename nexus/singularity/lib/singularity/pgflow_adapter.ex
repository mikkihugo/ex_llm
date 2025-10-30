defmodule Singularity.PgFlowAdapter do
  @moduledoc """
  PgFlow Adapter - Interface to workflow persistence and retrieval.

  Provides access to workflow data stored in PostgreSQL via pgmq/ex_pgflow.
  """

  alias Singularity.PgFlow

  @doc """
  Fetch a workflow by token.

  Returns workflow data including payload with expiration information.
  """
  @spec fetch_workflow(String.t()) :: {:ok, map()} | :not_found
  def fetch_workflow(token) when is_binary(token) do
    case PgFlow.get_workflow(token) do
      nil ->
        :not_found

      workflow when is_map(workflow) ->
        # Convert Ecto schema to plain map with expected structure
        {:ok,
         %{
           id: workflow.workflow_id,
           payload: %{
             token: workflow.workflow_id,
             # Default 1 hour
             expires_at:
               workflow.expires_at || :erlang.system_time(:millisecond) + 60 * 60 * 1000,
             permissions: workflow.permissions || ["execute"],
             created_at: workflow.inserted_at
           },
           status: workflow.status || "active"
         }}

      _ ->
        :not_found
    end
  end
end
