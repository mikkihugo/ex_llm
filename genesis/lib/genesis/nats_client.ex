defmodule Genesis.NatsClient do
  @moduledoc """
  Genesis NATS Client

  Manages NATS messaging for Genesis:
  - Subscribes to experiment requests from Singularity instances
  - Publishes experiment results back to requesting instances
  - Handles connection management and error recovery

  ## NATS Subjects

  **Incoming:**
  - `agent.events.experiment.request.{instance_id}` - Experiment requests
  - `agent.control.shutdown` - Control messages

  **Outgoing:**
  - `agent.events.experiment.completed.{experiment_id}` - Successful completion
  - `agent.events.experiment.failed.{experiment_id}` - Failure with details
  - `system.health.genesis` - Health check responses
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Genesis.NatsClient starting...")

    # Try to connect with retry logic
    case connect_with_retry(0) do
      {:ok, conn} ->
        Logger.info("Connected to NATS successfully")
        {:ok, %{
          connection: conn,
          connection_failures: 0,
          last_connection_failure: nil
        }}

      {:error, reason} ->
        Logger.error("Failed to connect to NATS after retries: #{inspect(reason)}")
        # Start with failed state, will attempt reconnect after delay
        schedule_reconnect(1000)
        {:ok, %{
          connection: nil,
          connection_failures: 1,
          last_connection_failure: DateTime.utc_now()
        }}
    end
  end

  # Retry logic with exponential backoff
  defp connect_with_retry(attempt) do
    max_attempts = 3

    case connect_to_nats() do
      {:ok, conn} ->
        {:ok, conn}

      {:error, reason} when attempt < max_attempts ->
        wait_ms = Integer.pow(2, attempt) * 500
        Logger.warn("NATS connection failed (attempt #{attempt + 1}/#{max_attempts}), retrying in #{wait_ms}ms: #{inspect(reason)}")
        Process.sleep(wait_ms)
        connect_with_retry(attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Schedule a reconnection attempt after delay
  defp schedule_reconnect(delay_ms) do
    Process.send_after(self(), :reconnect_nats, delay_ms)
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
  def handle_info(:reconnect_nats, state) do
    Logger.info("Attempting to reconnect to NATS...")

    case connect_to_nats() do
      {:ok, conn} ->
        Logger.info("Reconnected to NATS successfully")
        {:noreply, %{
          state |
          connection: conn,
          connection_failures: 0,
          last_connection_failure: nil
        }}

      {:error, reason} ->
        Logger.error("Reconnection failed: #{inspect(reason)}")
        # Exponential backoff: increase delay each retry (max 30 seconds)
        next_delay = min(state.connection_failures * 2000, 30_000)
        schedule_reconnect(next_delay)
        {:noreply, %{
          state |
          connection: nil,
          connection_failures: state.connection_failures + 1,
          last_connection_failure: DateTime.utc_now()
        }}
    end
  end

  @impl true
  def handle_call({:publish, subject, message}, _from, state) do
    case state.connection do
      nil ->
        Logger.error("Cannot publish: NATS not connected (failures: #{state.connection_failures}, last: #{state.last_connection_failure})")
        # Try reconnect
        schedule_reconnect(500)
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
