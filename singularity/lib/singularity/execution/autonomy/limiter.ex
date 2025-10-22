defmodule Singularity.Execution.Autonomy.Limiter do
  @moduledoc """
  Simple ETS-backed rate limiter so agents do not enqueue unlimited
  self-improvement attempts. Defaults to 100 improvements per 24 hours
  (configurable via `IMP_LIMIT_PER_DAY`).
  """

  @table :singularity_improvement_limiter
  @default_limit 100
  @window_seconds 86_400

  @doc "Ensure the ETS table exists. Safe to call multiple times."
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Returns true when the caller is allowed to perform another improvement
  in the current window. The counter is tracked per agent id.
  """
  @spec allow?(String.t()) :: boolean()
  def allow?(agent_id) when is_binary(agent_id) do
    ensure_table()

    limit = daily_limit()
    now = System.system_time(:second)

    case :ets.lookup(@table, agent_id) do
      [] ->
        :ets.insert(@table, {agent_id, 1, now})
        true

      [{^agent_id, count, window_start}] ->
        cond do
          now - window_start >= @window_seconds ->
            :ets.insert(@table, {agent_id, 1, now})
            true

          count < limit ->
            :ets.insert(@table, {agent_id, count + 1, window_start})
            true

          true ->
            false
        end
    end
  end

  @doc "Reset the limiter for an agent (e.g. after rollback)."
  @spec reset(String.t()) :: :ok
  def reset(agent_id) when is_binary(agent_id) do
    ensure_table()
    :ets.delete(@table, agent_id)
    :ok
  end

  defp daily_limit do
    System.get_env("IMP_LIMIT_PER_DAY")
    |> case do
      nil ->
        @default_limit

      value ->
        case Integer.parse(value) do
          {int, _} when int > 0 -> int
          _ -> @default_limit
        end
    end
  end
end
