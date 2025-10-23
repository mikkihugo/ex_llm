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

      conn ->
        # Publish message using gnat library
        try do
          message_binary =
            case message do
              binary when is_binary(binary) -> binary
              term -> Jason.encode!(term)
            end

          :ok = :gnat.pub(conn, subject, message_binary)

          Logger.debug("Published to #{subject}: #{String.slice(message_binary, 0..100)}")
          {:reply, :ok, state}
        rescue
          e ->
            Logger.error("Failed to publish to #{subject}: #{inspect(e)}")
            {:reply, {:error, e}, state}
        end
    end
  end

  @impl true
  def handle_call({:subscribe, subject}, _from, state) do
    case state.connection do
      nil ->
        Logger.error("Cannot subscribe: not connected to NATS")
        {:reply, {:error, :not_connected}, state}

      conn ->
        try do
          # Subscribe to subject with push model
          {:ok, sub_ref} = :gnat.sub(conn, self(), subject)

          Logger.info("Subscribed to #{subject} with ref #{inspect(sub_ref)}")
          {:reply, {:ok, sub_ref}, state}
        rescue
          e ->
            Logger.error("Failed to subscribe to #{subject}: #{inspect(e)}")
            {:reply, {:error, e}, state}
        end
    end
  end

  @impl true
  def handle_info({:msg, %{subject: subject, data: data}}, state) do
    # Handle incoming NATS messages
    Logger.debug("Received message on #{subject}")

    try do
      case Jason.decode(data) do
        {:ok, decoded_data} ->
          # Route to appropriate handler based on subject
          route_message(subject, decoded_data)

        {:error, reason} ->
          Logger.warn("Failed to decode message on #{subject}: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Error handling message from #{subject}: #{inspect(e)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:down, sub_ref}, state) do
    # Handle subscription down
    Logger.warn("Subscription lost: #{inspect(sub_ref)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(message, state) do
    Logger.debug("NatsClient received unhandled message: #{inspect(message)}")
    {:noreply, state}
  end

  defp route_message("agent.events.experiment.request." <> _instance_id = subject, data) do
    # Route experiment requests to ExperimentRunner
    Logger.info("Routing experiment request from #{subject}")

    case Genesis.ExperimentRunner.handle_experiment_request(data) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Failed to handle experiment request: #{inspect(reason)}")
    end
  end

  defp route_message("agent.control.shutdown", _data) do
    Logger.info("Shutdown signal received")
    System.halt(0)
  end

  defp route_message(subject, _data) do
    Logger.warn("Unknown subject: #{subject}")
  end

  defp connect_to_nats do
    host = System.get_env("NATS_HOST", "127.0.0.1")
    port = System.get_env("NATS_PORT", "4222") |> String.to_integer()

    Logger.info("Attempting to connect to NATS at #{host}:#{port}")

    try do
      {:ok, conn} = :gnat.start_link(%{host: String.to_charlist(host), port: port})

      # Verify connection health
      case :gnat.rtt(conn) do
        {:ok, _rtt} ->
          Logger.info("NATS connection verified with RTT check")
          {:ok, conn}

        {:error, reason} ->
          Logger.error("NATS RTT check failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Failed to connect to NATS: #{inspect(e)}")
        {:error, e}
    end
  end
end
