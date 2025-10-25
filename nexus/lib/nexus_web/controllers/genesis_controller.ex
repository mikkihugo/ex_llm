defmodule NexusWeb.GenesisController do
  use NexusWeb, :controller

  @doc """
  Get Genesis system status
  """
  def status(conn, _params) do
    # TODO: Implement NATS request to genesis.status
    json(conn, %{
      system: "Genesis",
      status: "online",
      experiments: 12,
      mode: "Experimentation Engine"
    })
  end

  @doc """
  Create a new experiment in Genesis
  """
  def create_experiment(conn, params) do
    # TODO: Implement NATS request to genesis.experiment.create
    case params do
      %{"name" => name, "description" => description} ->
        json(conn, %{
          system: "Genesis",
          experiment_id: UUID.uuid4(),
          status: "creating",
          name: name,
          description: description
        })

      _ ->
        send_resp(conn, 400, "Missing name or description")
    end
  end
end
