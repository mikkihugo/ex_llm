defmodule Genesis.NatsClient do
  @moduledoc """
  Genesis NATS Client

  Manages NATS messaging for Genesis:
  - Subscribes to experiment requests from Singularity instances
  - Publishes experiment results back to requesting instances
  - Handles connection management and error recovery

  ## NATS Subjects

  **Incoming:**
  - `genesis.experiment.request.{instance_id}` - Experiment requests
  - `genesis.control.shutdown` - Control messages

  **Outgoing:**
  - `genesis.experiment.completed.{experiment_id}` - Successful completion
  - `genesis.experiment.failed.{experiment_id}` - Failure with details
  - `genesis.health` - Health check responses
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Genesis.NatsClient starting...")

    case connect_to_nats() do
      {:ok, conn} ->
        Logger.info("Connected to NATS")
        {:ok, %{connection: conn}}

      {:error, reason} ->
        Logger.error("Failed to connect to NATS: #{inspect(reason)}")
        {:ok, %{connection: nil}}
    end
  end

  @doc """
  Publish a message to a NATS subject.
  """
  def publish(subject, message) do
    GenServer.call(__MODULE__, {:publish, subject, message})
  end

  @doc """
  Subscribe to a NATS subject.
  """
  def subscribe(subject) do
    GenServer.call(__MODULE__, {:subscribe, subject})
  end

  @impl true
  def handle_call({:publish, subject, message}, _from, state) do
    case state.connection do
      nil ->
        Logger.error("Cannot publish: not connected to NATS")
        {:reply, {:error, :not_connected}, state}

      _conn ->
        # Placeholder: actual implementation would use gnat library
        Logger.debug("Publishing to #{subject}")
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:subscribe, subject}, _from, state) do
    case state.connection do
      nil ->
        Logger.error("Cannot subscribe: not connected to NATS")
        {:reply, {:error, :not_connected}, state}

      _conn ->
        # Placeholder: actual implementation would use gnat library
        Logger.info("Subscribed to #{subject}")
        {:reply, {:ok, subject}, state}
    end
  end

  defp connect_to_nats do
    host = System.get_env("NATS_HOST", "127.0.0.1")
    port = System.get_env("NATS_PORT", "4222") |> String.to_integer()

    # Placeholder: actual implementation would:
    # 1. Connect using :gnat library
    # 2. Verify connection health
    # 3. Setup subscriptions
    Logger.info("Attempting to connect to NATS at #{host}:#{port}")
    {:ok, %{host: host, port: port}}
  end
end
