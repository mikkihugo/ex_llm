defmodule Observer.HITL do
  @moduledoc """
  Context module for human-in-the-loop (HITL) approvals managed by Observer.

  Provides convenience functions for listing pending approvals, creating new
  approval entries, and recording the final human decision.
  """

  import Ecto.Query

  alias Observer.HITL.Approval
  alias Observer.Repo

  @type approval_id :: Ecto.UUID.t()

  @doc """
  List approvals with optional filters.

  Supported options:
    * `:status` - Filter by approval status (`:pending`, `:approved`, etc.)
    * `:task_type` - Filter by task type string
    * `:limit` - Limit number of results (default 100)
  """
  @spec list_approvals(Keyword.t()) :: [Approval.t()]
  def list_approvals(opts \\ []) do
    status = Keyword.get(opts, :status)
    task_type = Keyword.get(opts, :task_type)
    limit = Keyword.get(opts, :limit, 100)

    Approval
    |> maybe_filter_status(status)
    |> maybe_filter_task_type(task_type)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  List only pending approvals, optionally filtered by task type.
  """
  @spec list_pending_approvals(Keyword.t()) :: [Approval.t()]
  def list_pending_approvals(opts \\ []) do
    opts
    |> Keyword.put(:status, :pending)
    |> list_approvals()
  end

  @doc """
  Fetch a single approval by ID.
  """
  @spec get_approval!(approval_id()) :: Approval.t()
  def get_approval!(id) do
    Repo.get!(Approval, id)
  end

  @doc """
  Fetch an approval by request_id, returning nil if it does not exist.
  """
  @spec get_by_request_id(String.t()) :: Approval.t() | nil
  def get_by_request_id(request_id) do
    Repo.one(from a in Approval, where: a.request_id == ^request_id, limit: 1)
  end

  @doc """
  Create a new approval entry. Defaults status to `:pending`.
  """
  @spec create_approval(map()) :: {:ok, Approval.t()} | {:error, Ecto.Changeset.t()}
  def create_approval(attrs \ %{}) do
    attrs = Map.put_new(attrs, :status, :pending)

    %Approval{}
    |> Approval.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Approve an existing pending approval.
  """
  @spec approve(Approval.t(), map()) :: {:ok, Approval.t()} | {:error, term()}
  def approve(%Approval{} = approval, attrs \\ %{}) do
    decide(approval, :approved, attrs)
  end

  @doc """
  Reject an existing pending approval.
  """
  @spec reject(Approval.t(), map()) :: {:ok, Approval.t()} | {:error, term()}
  def reject(%Approval{} = approval, attrs \\ %{}) do
    decide(approval, :rejected, attrs)
  end

  @doc """
  Cancel an approval (e.g. request expired before decision).
  """
  @spec cancel(Approval.t(), map()) :: {:ok, Approval.t()} | {:error, term()}
  def cancel(%Approval{} = approval, attrs \\ %{}) do
    decide(approval, :cancelled, attrs)
  end

  defp decide(%Approval{} = approval, status, attrs) do
    if Approval.pending?(approval) do
      attrs = Map.put(attrs, :status, status)

      approval
      |> Approval.decision_changeset(attrs)
      |> Repo.update()
    else
      {:error, :already_decided}
    end
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [a], a.status == ^status)

  defp maybe_filter_task_type(query, nil), do: query
  defp maybe_filter_task_type(query, task_type), do: where(query, [a], a.task_type == ^task_type)
end
