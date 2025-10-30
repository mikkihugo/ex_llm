defmodule Singularity.Monitoring.AgentTaskTracker do
  @moduledoc """
  Agent task lifecycle tracker (QuantumFlow port).

  The legacy branch pushed task events through Phoenix PubSub. In the QuantumFlow layout we rely
  on Telemetry and structured logging instead, which keeps the module dependency-free while
  preserving the behavioural pattern (start/completion/failure hooks).

  Every helper emits both a Telemetry event and a debug log entry so dashboards and
  OpenTelemetry exporters can consume the stream.
  """

  require Logger

  @type task_id :: String.t()
  @type task_metadata :: map()

  @doc """
  Record that an agent task has started.
  """
  @spec track_start(task_metadata()) :: :ok
  def track_start(%{id: _id} = task) do
    emit(:started, task)
    :ok
  end

  @doc """
  Record successful task completion.
  """
  @spec track_completion(task_id(), task_metadata()) :: :ok
  def track_completion(task_id, result_metadata \\ %{}) do
    emit(:completed, Map.put(result_metadata, :id, task_id))
    :ok
  end

  @doc """
  Record a task failure with reason map.
  """
  @spec track_failure(task_id(), any(), task_metadata()) :: :ok
  def track_failure(task_id, reason, context \\ %{}) do
    context =
      context
      |> Map.put(:id, task_id)
      |> Map.put(:reason, sanitize_reason(reason))

    emit(:failed, context)
    :ok
  end

  @doc """
  Emit an in-progress heartbeat. Helpful for long-lived QuantumFlow workflows.
  """
  @spec track_progress(task_id(), non_neg_integer(), task_metadata()) :: :ok
  def track_progress(task_id, step, metadata \\ %{}) do
    emit(:progress, metadata |> Map.put(:id, task_id) |> Map.put(:step, step))
    :ok
  end

  defp emit(event, metadata) do
    event_path = [:singularity, :agent_task, event]
    :telemetry.execute(event_path, %{count: 1}, metadata)

    Logger.debug(fn ->
      formatted = inspect(metadata, pretty: true, limit: :infinity)
      "[agent_task_tracker] #{event} #{formatted}"
    end)
  end

  defp sanitize_reason(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> sanitize_reason()
  end

  defp sanitize_reason(reason) when is_map(reason) do
    reason
    |> Enum.into(%{}, fn {key, value} ->
      {key, sanitize_scalar(value)}
    end)
  end

  defp sanitize_reason(reason), do: sanitize_scalar(reason)

  defp sanitize_scalar(value) when is_binary(value), do: value
  defp sanitize_scalar(value) when is_atom(value), do: Atom.to_string(value)
  defp sanitize_scalar(value) when is_number(value), do: value

  defp sanitize_scalar(value) do
    inspect(value, limit: 10)
  end
end
