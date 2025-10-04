defmodule Singularity.PrometheusExporter do
  @moduledoc false

  alias Singularity.HotReload.Manager

  @spec render() :: binary()
  def render do
    queue_depth = Manager.queue_depth()
    nodes = Node.list()

    [
      "# HELP singularity_hot_reload_queue_depth Number of pending improvement tasks",
      "# TYPE singularity_hot_reload_queue_depth gauge",
      "singularity_hot_reload_queue_depth #{queue_depth}",
      "# HELP singularity_cluster_nodes Count of connected BEAM nodes",
      "# TYPE singularity_cluster_nodes gauge",
      "singularity_cluster_nodes #{length(nodes)}"
    ]
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end
end
