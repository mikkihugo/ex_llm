defmodule Nexus.Application do
  use Application

  @moduledoc """
  Nexus Application - Unified Control Panel

  Starts Phoenix web server and NATS client to connect to:
  - Singularity (core OTP app)
  - Genesis (experimentation engine)
  - CentralCloud (learning aggregation)
  """

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry
      Telemetry,
      # Phoenix pubsub
      {Phoenix.PubSub, name: Nexus.PubSub},
      # NATS client for connecting to backend systems
      Nexus.NatsClient,
      # Phoenix endpoint
      NexusWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Nexus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NexusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
