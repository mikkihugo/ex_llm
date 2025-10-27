defmodule Singularity.Git.GitTreeSyncProxy do
  @moduledoc """
  Git Tree Sync Proxy - Wraps GitTreeSyncCoordinator with enable/disable control.

  Returns {:error, :disabled} when git coordination is disabled,
  otherwise proxies all calls to GitTreeSyncCoordinator.
  """

  alias Singularity.Git.{Supervisor, GitTreeSyncCoordinator}

  @type agent_id :: term()
  @type task :: map()
  @type result :: map()

  @spec enabled?() :: boolean()
  def enabled?, do: Supervisor.enabled?()

  @spec assign_task(agent_id, task, keyword()) :: any()
  def assign_task(agent_id, task, opts \\ []) do
    with true <- enabled?() do
      opts = Keyword.put_new(opts, :use_llm, true)
      GitTreeSyncCoordinator.assign_task(agent_id, task, opts)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec submit_work(agent_id, result) :: any()
  def submit_work(agent_id, result) do
    with true <- enabled?() do
      GitTreeSyncCoordinator.submit_work(agent_id, result)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec merge_status(term()) :: any()
  def merge_status(correlation_id) do
    with true <- enabled?() do
      GitTreeSyncCoordinator.merge_status(correlation_id)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec merge_all_for_epic(term()) :: any()
  def merge_all_for_epic(correlation_id) do
    with true <- enabled?() do
      GitTreeSyncCoordinator.merge_all_for_epic(correlation_id)
    else
      _ -> {:error, :disabled}
    end
  end
end
