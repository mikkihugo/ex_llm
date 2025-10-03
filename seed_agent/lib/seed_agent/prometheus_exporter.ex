defmodule SeedAgent.PrometheusExporter do
  @moduledoc false

  alias SeedAgent.HotReload.Manager

  @spec render() :: binary()
  def render do
    queue_depth = Manager.queue_depth()
    nodes = Node.list()

    [
      "# HELP seed_agent_hot_reload_queue_depth Number of pending improvement tasks",
      "# TYPE seed_agent_hot_reload_queue_depth gauge",
      "seed_agent_hot_reload_queue_depth #{queue_depth}",
      "# HELP seed_agent_cluster_nodes Count of connected BEAM nodes",
      "# TYPE seed_agent_cluster_nodes gauge",
      "seed_agent_cluster_nodes #{length(nodes)}"
    ]
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end
end
