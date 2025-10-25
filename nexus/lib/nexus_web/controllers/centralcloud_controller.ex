defmodule NexusWeb.CentralCloudController do
  use NexusWeb, :controller

  @doc """
  Get CentralCloud system status
  """
  def status(conn, _params) do
    # TODO: Implement NATS request to centralcloud.status
    json(conn, %{
      system: "CentralCloud",
      status: "online",
      insights: 156,
      mode: "Learning Aggregation"
    })
  end

  @doc """
  Get insights aggregated from all Singularity instances
  """
  def insights(conn, _params) do
    # TODO: Implement NATS request to centralcloud.insights
    json(conn, %{
      system: "CentralCloud",
      total_instances: 2,
      insights: [
        %{
          title: "Pattern: Async Worker Pattern",
          frequency: 45,
          instances: 2,
          confidence: 0.92
        },
        %{
          title: "Technology: NATS Messaging",
          frequency: 38,
          instances: 2,
          confidence: 0.88
        }
      ]
    })
  end
end
