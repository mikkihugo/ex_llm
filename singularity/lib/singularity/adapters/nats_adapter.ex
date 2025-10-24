defmodule Singularity.Adapters.NatsAdapter do
  @moduledoc """
  NATS Adapter - Async task execution via NATS messaging.

  Implements @behaviour TaskAdapter for executing tasks through NATS pub/sub
  messaging for distributed task processing.

  ## Features

  - Distributed task execution
  - Async message-based execution
  - Cross-instance task routing
  - Request/reply pattern support

  ## Capabilities

  - `["async", "distributed", "messaging", "cross_instance"]`
  """

  @behaviour Singularity.Execution.TaskAdapter

  require Logger

  @impl Singularity.Execution.TaskAdapter
  def adapter_type, do: :nats_adapter

  @impl Singularity.Execution.TaskAdapter
  def description do
    "Async task execution via NATS messaging"
  end

  @impl Singularity.Execution.TaskAdapter
  def capabilities do
    ["async", "distributed", "messaging", "cross_instance", "pub_sub"]
  end

  @impl Singularity.Execution.TaskAdapter
  def execute(task, opts \\ []) do
    Logger.debug("NATS adapter: Publishing task", task_type: task[:type])

    # Extract task details
    task_type = task[:type]
    args = task[:args] || %{}
    task_id = generate_task_id()

    # Build NATS message
    message = %{
      task_id: task_id,
      task_type: task_type,
      args: args,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Publish to NATS
    case Singularity.Nats.Client.publish("task.#{task_type}", Jason.encode!(message)) do
      :ok ->
        Logger.debug("NATS adapter: Task published",
          task_type: task_type,
          task_id: task_id
        )
        {:ok, "nats:#{task_id}"}

      {:error, reason} ->
        Logger.error("NATS adapter: Failed to publish task", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp generate_task_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
