defmodule Singularity.JobQueue.Testing do
  @moduledoc """
  Test helpers for draining queues. Delegates to Oban.Testing where available.
  """

  @doc """
  Drain a queue in tests. Accepts the queue name and optional options.
  """
  @spec drain_queue(binary(), keyword()) :: Oban.Testing.drain_result()
  def drain_queue(queue, opts \\ []) when is_binary(queue) do
    Oban.drain_queue(queue: queue, with_scheduled: true, with_limit: false, max_attempts: 20, repo: Singularity.Repo, conf: Oban, tags: [], errors: :raise)
  end
end
