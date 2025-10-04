defmodule Singularity.Health do
  @moduledoc false

  defstruct [:http_status, :body]

  alias Singularity.HotReload.Manager

  @max_queue_depth 100
  @queue_warning_threshold 75

  def deep_health do
    cluster_nodes = Node.list()
    queue_depth = safe_queue_depth()
    memory_info = get_memory_info()

    {http_status, health_status} = determine_health(queue_depth)

    status =
      %{
        status: health_status,
        cluster_nodes: Enum.map(cluster_nodes, &Atom.to_string/1),
        queue_depth: queue_depth,
        queue_status: queue_status(queue_depth),
        memory: memory_info,
        system_time: DateTime.utc_now() |> DateTime.to_iso8601(),
        node: Atom.to_string(Node.self())
      }

    %__MODULE__{http_status: http_status, body: status}
  end

  defp safe_queue_depth do
    try do
      Manager.queue_depth()
    catch
      :exit, _ -> 0
    end
  end

  defp determine_health(queue_depth) do
    cond do
      queue_depth >= @max_queue_depth -> {503, "degraded"}
      queue_depth >= @queue_warning_threshold -> {200, "warning"}
      true -> {200, "ok"}
    end
  end

  defp queue_status(queue_depth) do
    cond do
      queue_depth >= @max_queue_depth -> "full"
      queue_depth >= @queue_warning_threshold -> "high"
      queue_depth > 0 -> "active"
      true -> "empty"
    end
  end

  defp get_memory_info do
    %{
      total: :erlang.memory(:total),
      processes: :erlang.memory(:processes),
      system: :erlang.memory(:system),
      atom: :erlang.memory(:atom),
      binary: :erlang.memory(:binary)
    }
  end
end
