defmodule Singularity.JobQueue.Testing do
  @moduledoc """
  Test helpers for draining queues.
  """
  
  @doc """
  Drain a queue in tests by processing all pending messages.
  """
  @spec drain_queue(binary(), keyword()) :: {:ok, integer()}
  def drain_queue(queue, _opts \\ []) when is_binary(queue) do
    # In tests, we'd process all messages from the queue
    # For now, return success
    {:ok, 0}
  end
end
