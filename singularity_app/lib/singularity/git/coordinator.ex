defmodule Singularity.Git.Coordinator do
  @moduledoc """
  Public façade for the Git tree coordinator.

  Functions return `{:error, :disabled}` when the coordinator is not enabled
  so callers can gracefully fall back to rule-based execution.
  """

  alias Singularity.Git.{Supervisor, TreeCoordinator}

  @type agent_id :: term()
  @type task :: map()
  @type result :: map()

  @spec enabled?() :: boolean()
  def enabled?, do: Supervisor.enabled?()

  @spec assign_task(agent_id, task, keyword()) :: any()
  def assign_task(agent_id, task, opts \\ []) do
    with true <- enabled?() do
      opts = Keyword.put_new(opts, :use_llm, true)
      TreeCoordinator.assign_task(agent_id, task, opts)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec submit_work(agent_id, result) :: any()
  def submit_work(agent_id, result) do
    with true <- enabled?() do
      TreeCoordinator.submit_work(agent_id, result)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec merge_status(term()) :: any()
  def merge_status(correlation_id) do
    with true <- enabled?() do
      TreeCoordinator.merge_status(correlation_id)
    else
      _ -> {:error, :disabled}
    end
  end

  @spec merge_all_for_epic(term()) :: any()
  def merge_all_for_epic(correlation_id) do
    with true <- enabled?() do
      TreeCoordinator.merge_all_for_epic(correlation_id)
    else
      _ -> {:error, :disabled}
    end
  end
end
