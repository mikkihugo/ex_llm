defmodule Singularity.Agents.Arbiter do
  @moduledoc """
  Simple approval arbiter for edits and HTDAG task execution.

  This is intentionally lightweight: it issues short-lived tokens for planned edits
  and can authorize/consume them. Tokens are stored in an ETS table under
  :singularity_arbiter_tokens.
  """

  use GenServer
  require Logger

  @table :singularity_arbiter_tokens
  @token_ttl_ms 60_000

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def issue_approval(payload, _opts \\ []) do
    token = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    now = :erlang.system_time(:millisecond)
    entry = %{token: token, payload: payload, issued_at: now, expires_at: now + @token_ttl_ms}
    # store in local ETS for fast lookup
    :ets.insert(@table, {token, entry})
    # also persist into Workflows so approvals are visible as full records
    workflow = %{workflow_id: token, type: :approval, payload: entry}

    try do
      Singularity.Workflows.create_workflow(workflow)
    rescue
      _ -> :ok
    end

    token
  end

  @doc "Issue an approval for a planned workflow. Persists to Workflows for visibility."
  def issue_workflow_approval(workflow_map, _opts \\ []) when is_map(workflow_map) do
    token = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    now = :erlang.system_time(:millisecond)

    entry = %{
      token: token,
      workflow: workflow_map,
      issued_at: now,
      expires_at: now + @token_ttl_ms
    }

    :ets.insert(@table, {token, entry})
    record = %{workflow_id: token, type: :workflow_approval, payload: entry}

    try do
      Singularity.Workflows.create_workflow(record)
    rescue
      _ -> :ok
    end

    token
  end

  @doc "Authorize a workflow execution using a token"
  def authorize_workflow(token) when is_binary(token) do
    # Prefer Workflows-backed check (visibility), fall back to local ETS
    case Singularity.Workflows.fetch_workflow(token) do
      {:ok, workflow} when is_map(workflow) ->
        entry = Map.get(workflow, :payload)
        now = :erlang.system_time(:millisecond)

        if entry && entry.expires_at > now do
          :ets.delete(@table, token)
          # remove persisted record for safety/consumption
          try do
            Singularity.Workflows.update_workflow_status(token, :consumed)
          rescue
            _ -> :ok
          end

          :ok
        else
          # expired
          :ets.delete(@table, token)
          {:error, :expired}
        end

      :not_found ->
        # fallback to local ETS lookup
        case :ets.lookup(@table, token) do
          [{^token, entry}] ->
            now = :erlang.system_time(:millisecond)

            if entry.expires_at > now do
              :ets.delete(@table, token)
              :ok
            else
              :ets.delete(@table, token)
              {:error, :expired}
            end

          [] ->
            {:error, :not_found}
        end
    end
  end

  @doc "Authorize a workflow execution using a token"
  def authorize_workflow(token) when is_binary(token) do
    case Singularity.PgFlowAdapter.fetch_workflow(token) do
      {:ok, workflow} when is_map(workflow) ->
        entry = Map.get(workflow, :payload)
        now = :erlang.system_time(:millisecond)

        if entry && entry.expires_at > now do
          :ets.delete(@table, token)

          try do
            :ets.delete(:pgflow_workflows, token)
          rescue
            _ -> :ok
          end

          :ok
        else
          :ets.delete(@table, token)
          {:error, :expired}
        end

      :not_found ->
        {:error, :not_found}
    end
  end

  def authorize_edit(token, _context) when is_binary(token) do
    # Prefer PgFlow-backed check (visibility), fall back to local ETS
    case Singularity.PgFlowAdapter.fetch_workflow(token) do
      {:ok, workflow} when is_map(workflow) ->
        entry = Map.get(workflow, :payload) || Map.get(workflow, :payload)
        now = :erlang.system_time(:millisecond)

        if entry && entry.expires_at > now do
          # consume token from both stores
          :ets.delete(@table, token)
          # remove persisted record for safety/consumption
          try do
            :ets.delete(:pgflow_workflows, token)
          rescue
            _ -> :ok
          end

          :ok
        else
          # expired
          :ets.delete(@table, token)

          try do
            :ets.delete(:pgflow_workflows, token)
          rescue
            _ -> :ok
          end

          {:error, :expired}
        end

      :not_found ->
        # fallback to local ETS lookup
        case :ets.lookup(@table, token) do
          [{^token, entry}] ->
            now = :erlang.system_time(:millisecond)

            if entry.expires_at > now do
              :ets.delete(@table, token)
              :ok
            else
              :ets.delete(@table, token)
              {:error, :expired}
            end

          [] ->
            {:error, :not_found}
        end
    end
  end

  ## GenServer callbacks
  def init(_state) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    # schedule periodic cleanup
    schedule_cleanup()
    {:ok, %{}}
  end

  def handle_info(:cleanup, state) do
    now = :erlang.system_time(:millisecond)

    for {token, entry} <- :ets.tab2list(@table) do
      if entry.expires_at <= now do
        :ets.delete(@table, token)
      end
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @token_ttl_ms)
  end
end
