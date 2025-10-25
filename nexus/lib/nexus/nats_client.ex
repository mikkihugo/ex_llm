defmodule Nexus.NatsClient do
  @moduledoc """
  NATS Client for Nexus - Connects to backend systems

  Provides request-response and pub-sub communication with:
  - singularity.* (Singularity OTP core)
  - genesis.* (Genesis experimentation engine)
  - centralcloud.* (CentralCloud learning aggregation)
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("🔗 Nexus NATS Client starting...")
    {:ok, %{conn: nil}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case connect_nats() do
      {:ok, conn} ->
        Logger.info("✅ Connected to NATS server")
        {:noreply, Map.put(state, :conn, conn)}

      {:error, reason} ->
        Logger.warning("⚠️  Failed to connect to NATS: #{inspect(reason)}")
        Logger.info("Retrying in 5 seconds...")
        Process.send_after(self(), :retry_connect, 5000)
        {:noreply, state}
    end
  end

  def handle_info(:retry_connect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  defp connect_nats do
    host = Application.get_env(:gnat, :host, ~c"127.0.0.1")
    port = Application.get_env(:gnat, :port, 4222)

    case :gnat.start_link(host: host, port: port) do
      {:ok, conn} -> {:ok, conn}
      error -> error
    end
  end

  @doc """
  Request data from a backend system via NATS
  """
  def request(subject, payload, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:request, subject, payload, timeout}, timeout + 1000)
  end

  @doc """
  Publish a message to a subject
  """
  def publish(subject, payload) do
    GenServer.cast(__MODULE__, {:publish, subject, payload})
  end

  @doc """
  Subscribe to backend system status updates
  """
  def subscribe_to_status do
    GenServer.cast(__MODULE__, {:subscribe, "singularity.status"})
    GenServer.cast(__MODULE__, {:subscribe, "genesis.status"})
    GenServer.cast(__MODULE__, {:subscribe, "centralcloud.status"})
  end

  @impl true
  def handle_call({:request, subject, payload, _timeout}, _from, state) do
    Logger.debug("📤 NATS request", subject: subject, payload: inspect(payload))

    case state.conn do
      nil ->
        {:reply, {:error, "NATS not connected"}, state}

      conn ->
        case request_nats(conn, subject, payload) do
          {:ok, response} -> {:reply, {:ok, response}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_cast({:publish, subject, payload}, state) do
    Logger.debug("📡 NATS publish", subject: subject, payload: inspect(payload))

    case state.conn do
      nil ->
        Logger.warning("Cannot publish: NATS not connected")
        {:noreply, state}

      conn ->
        case publish_nats(conn, subject, payload) do
          :ok -> {:noreply, state}
          {:error, reason} -> Logger.error("Publish error: #{inspect(reason)}"); {:noreply, state}
        end
    end
  end

  @impl true
  def handle_cast({:subscribe, subject}, state) do
    Logger.debug("📬 Subscribing to", subject: subject)

    case state.conn do
      nil ->
        Logger.warning("Cannot subscribe: NATS not connected")
        {:noreply, state}

      conn ->
        case subscribe_nats(conn, subject) do
          :ok -> {:noreply, state}
          {:error, reason} -> Logger.error("Subscribe error: #{inspect(reason)}"); {:noreply, state}
        end
    end
  end

  defp request_nats(_conn, subject, _payload) do
    # TODO: Implement actual NATS request-response with gnat library
    Logger.debug("Request on subject: #{subject}")
    {:ok, %{"status" => "pending"}}
  end

  defp publish_nats(_conn, subject, _payload) do
    # TODO: Implement actual NATS publish with gnat library
    Logger.debug("Publish to subject: #{subject}")
    :ok
  end

  defp subscribe_nats(_conn, subject) do
    # TODO: Implement actual NATS subscribe with gnat library
    Logger.debug("Subscribe to subject: #{subject}")
    :ok
  end
end
