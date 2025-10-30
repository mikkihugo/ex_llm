defmodule CentralCloud.Infrastructure.IntelligenceEndpoint do
  @moduledoc """
  Legacy NATS/QuantumFlow endpoint for infrastructure registry queries.

  The asynchronous request handling is now done via pgmq consumers
  (`CentralCloud.Consumers.InfrastructureRegistryConsumer`).  This module
  remains as a lightweight GenServer so existing supervision trees stay
  intact, but the actual logic simply logs that the dedicated consumer will
  handle requests.
  """

  use GenServer
  require Logger

  @impl true
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Infrastructure endpoint initialised – pgmq consumer handles registry requests")
    {:ok, %{}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}
end
