defmodule Singularity.Agents.Arbiter do
  @moduledoc """
  Approval arbiter responsible for issuing and authorizing QuantumFlow workflow tokens.

  Tokens are persisted in PostgreSQL (`workflow_approval_tokens`) for durability so we no
  longer rely on transient ETS caches. Notifications are published through QuantumFlow's
  messaging helpers so CentralCloud and Observer receive instant updates.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.WorkflowApprovalToken
  alias Singularity.Infrastructure.QuantumFlow.Queue

  @token_ttl_ms 60_000
  @cleanup_interval_ms 60_000

  @type token :: String.t()

  # GenServer lifecycle -----------------------------------------------------------------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    expire_overdue_tokens()
    schedule_cleanup()
    {:noreply, state}
  end

  # Public API --------------------------------------------------------------------------

  @doc """
  Issue a generic approval token for an arbitrary payload.
  """
  @spec issue_approval(map(), keyword()) :: token | {:error, term()}
  def issue_approval(payload, opts \\ []) when is_map(payload) do
    issue_token(:approval, payload, opts)
  end

  @doc """
  Issue a workflow-specific approval token.
  """
  @spec issue_workflow_approval(map(), keyword()) :: token | {:error, term()}
  def issue_workflow_approval(workflow_map, opts \\ []) when is_map(workflow_map) do
    issue_token(:workflow_approval, workflow_map, opts)
  end

  @doc """
  Authorize a workflow execution using a previously issued token.
  """
  @spec authorize_workflow(token()) :: :ok | {:error, term()}
  def authorize_workflow(token) when is_binary(token) do
    consume_token(token)
  end

  @doc """
  Authorize an edit gate using a token.
  """
  @spec authorize_edit(token(), map()) :: :ok | {:error, term()}
  def authorize_edit(token, _context) when is_binary(token) do
    consume_token(token)
  end

  # Internal helpers --------------------------------------------------------------------

  defp issue_token(kind, payload, opts) do
    token = generate_token()
    issued_at = DateTime.utc_now()
    expires_at = DateTime.add(issued_at, @token_ttl_ms, :millisecond)

    attrs = %{
      token: token,
      workflow_slug: Keyword.get(opts, :workflow_slug),
      payload: %{
        type: kind,
        data: payload,
        issued_at: issued_at,
        expires_at: expires_at
      },
      expires_at: expires_at,
      status: "pending"
    }

    case Repo.insert(WorkflowApprovalToken.creation_changeset(attrs)) do
      {:ok, _record} ->
        publish_notification(kind, token, payload, issued_at, expires_at, opts)
        token

      {:error, changeset} ->
        Logger.error("Failed to persist approval token", errors: inspect(changeset.errors))
        {:error, changeset}
    end
  end

  defp consume_token(token) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      query =
        from t in WorkflowApprovalToken,
          where: t.token == ^token,
          lock: "FOR UPDATE"

      case Repo.one(query) do
        nil ->
          Repo.rollback(:not_found)

        %WorkflowApprovalToken{status: "consumed"} ->
          Repo.rollback(:consumed)

        %WorkflowApprovalToken{status: "expired"} ->
          Repo.rollback(:expired)

        %WorkflowApprovalToken{} = record ->
          cond do
            DateTime.compare(record.expires_at, now) == :lt ->
              Repo.update!(WorkflowApprovalToken.expire_changeset(record, now))
              Repo.rollback(:expired)

            true ->
              case Repo.update(WorkflowApprovalToken.consume_changeset(record, now)) do
                {:ok, updated} -> updated
                {:error, changeset} -> Repo.rollback({:error, changeset})
              end
          end
      end
    end)
    |> case do
      {:ok, _record} -> :ok
      {:error, :not_found} -> {:error, :not_found}
      {:error, :consumed} -> {:error, :already_used}
      {:error, :expired} -> {:error, :expired}
      {:error, {:error, changeset}} -> {:error, changeset}
    end
  end

  defp publish_notification(kind, token, payload, issued_at, expires_at, opts) do
    queue =
      case kind do
        :workflow_approval -> "workflow_approval_notifications"
        _ -> Keyword.get(opts, :queue, "approval_notifications")
      end

    message = %{
      type: to_string(kind),
      token: token,
      issued_at: issued_at,
      expires_at: expires_at,
      payload: payload
    }

    case Queue.send_with_notify(queue, message, Repo) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Approval notification dispatch failed", reason: inspect(reason))
    end
  end

  defp expire_overdue_tokens do
    now = DateTime.utc_now()

    {count, _} =
      from(t in WorkflowApprovalToken,
        where: t.status == "pending" and t.expires_at <= ^now,
        update: [set: [status: "expired", consumed_at: ^now, updated_at: ^now]]
      )
      |> Repo.update_all([])

    if count > 0 do
      Logger.debug("Expired overdue approval tokens", count: count)
    end

    :ok
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
