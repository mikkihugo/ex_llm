defmodule Singularity.HotReload.SafeCodeChangeDispatcher do
  @moduledoc """
  Thin facade that ensures hot-reload guardrails are used when other systems
  (like TaskGraph auto-fixes) generate code changes outside the dedicated
  self-improving agent loop.

  The gateway will:
    * Start (or reuse) a self-improving agent for dispatching improvements.
    * Merge contextual metadata to preserve audit trails.
    * Forward the payload through the existing improvement queue so validation,
      hot reload, and rollback safeguards remain in effect.
  """

  require Logger

  alias Singularity.ProcessRegistry
  alias Singularity.SelfImprovingAgent

  @default_agent_id "task_graph-runtime"

  @doc """
  Dispatch an improvement payload through the self-improving agent safeguards.

  ## Options

    * `:agent_id` - reuse a specific agent identifier (defaults to #{@default_agent_id})
    * `:agent_opts` - keyword list forwarded to `SelfImprovingAgent.start_link/1`
    * `:metadata` - map merged into the payload metadata before dispatch
  """
  @spec dispatch(map(), keyword()) :: :ok | {:error, term()}
  def dispatch(payload, opts \\ []) when is_map(payload) do
    agent_id =
      opts
      |> Keyword.get(:agent_id, @default_agent_id)
      |> to_string()

    agent_opts = Keyword.get(opts, :agent_opts, [])
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- ensure_agent_started(agent_id, agent_opts),
         enriched <- merge_metadata(payload, metadata),
         :ok <- forward(agent_id, enriched) do
      :ok
    else
      {:error, reason} = error ->
        Logger.warning("Failed to dispatch improvement via gateway",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        error
    end
  end

  defp ensure_agent_started(agent_id, extra_opts) do
    case Registry.lookup(ProcessRegistry, {:agent, agent_id}) do
      [{pid, _}] when is_pid(pid) ->
        :ok

      [] ->
        case SelfImprovingAgent.start_link(Keyword.put(extra_opts, :id, agent_id)) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp merge_metadata(payload, metadata) do
    existing =
      payload
      |> Map.get("metadata") ||
        Map.get(payload, :metadata) ||
        %{}

    merged =
      existing
      |> Map.new(fn
        {k, v} when is_atom(k) -> {Atom.to_string(k), v}
        other -> other
      end)
      |> Map.merge(normalize_keys(metadata))

    payload
    |> Map.put("metadata", merged)
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      other -> other
    end)
  end

  defp normalize_keys(other), do: %{"extra" => other}

  defp forward(agent_id, payload) do
    case SelfImprovingAgent.improve(agent_id, payload) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
