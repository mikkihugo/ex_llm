defmodule CentralCloud.NatsClient do
  @moduledoc """
  NATS client for Central Cloud services.

  Provides:
  - Request/Response pattern
  - JetStream KV (Key-Value) access for template caching
  - Connection management with automatic reconnection
  """

  use GenServer
  require Logger

  @nats_url System.get_env("NATS_URL", "nats://localhost:4222")
  @reconnect_interval :timer.seconds(5)

  # ===========================
  # Public API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send request and wait for response.

  ## Examples

      # Request templates from knowledge_cache
      {:ok, response} = NatsClient.request("central.template.search", %{
        artifact_type: "framework",
        limit: 100
      })
  """
  def request(subject, payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:request, subject, payload, timeout}, timeout + 1_000)
  end

  @doc """
  Publish message (fire and forget).
  """
  def publish(subject, payload) do
    GenServer.cast(__MODULE__, {:publish, subject, payload})
  end

  @doc """
  Get value from JetStream KV bucket.

  ## Examples

      # Get framework template from KV cache
      {:ok, template} = NatsClient.kv_get("templates", "framework:phoenix")
  """
  def kv_get(bucket, key) do
    GenServer.call(__MODULE__, {:kv_get, bucket, key})
  end

  @doc """
  Put value into JetStream KV bucket.

  ## Examples

      # Cache framework template
      :ok = NatsClient.kv_put("templates", "framework:phoenix", template_data)
  """
  def kv_put(bucket, key, value) do
    GenServer.call(__MODULE__, {:kv_put, bucket, key, value})
  end

  @doc """
  Check if connected to NATS.
  """
  def connected? do
    GenServer.call(__MODULE__, :connected?)
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @impl true
  def init(_opts) do
    Logger.info("Starting NATS client for Central Cloud...")

    # Connect asynchronously
    send(self(), :connect)

    {:ok, %{conn: nil, kv_buckets: %{}}}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect_to_nats() do
      {:ok, conn} ->
        Logger.info("✅ Connected to NATS at #{@nats_url}")
        {:noreply, %{state | conn: conn}}

      {:error, reason} ->
        Logger.warning("Failed to connect to NATS: #{inspect(reason)}, retrying...")
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:request, subject, payload, timeout}, _from, %{conn: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:request, subject, payload, timeout}, _from, %{conn: conn} = state) do
    encoded_payload = Jason.encode!(payload)

    result =
      case :nats_request(conn, subject, encoded_payload, timeout) do
        {:ok, response} ->
          case Jason.decode(response) do
            {:ok, decoded} -> {:ok, decoded}
            {:error, _} -> {:ok, response}
          end

        {:error, :timeout} ->
          {:error, :timeout}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:kv_get, bucket, key}, _from, state) do
    case ensure_kv_bucket(bucket, state) do
      {:ok, new_state} ->
        result = kv_get_internal(bucket, key, new_state)
        {:reply, result, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:kv_put, bucket, key, value}, _from, state) do
    case ensure_kv_bucket(bucket, state) do
      {:ok, new_state} ->
        result = kv_put_internal(bucket, key, value, new_state)
        {:reply, result, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:connected?, _from, %{conn: conn} = state) do
    {:reply, conn != nil, state}
  end

  @impl true
  def handle_cast({:publish, subject, payload}, %{conn: nil} = state) do
    Logger.warning("Cannot publish to #{subject}: not connected")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, subject, payload}, %{conn: conn} = state) do
    encoded_payload = Jason.encode!(payload)
    :nats_publish(conn, subject, encoded_payload)
    {:noreply, state}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp connect_to_nats do
    # TODO: Implement actual async_nats connection
    # For now, return placeholder
    #
    # In real implementation:
    # {:ok, conn} = :async_nats.connect(@nats_url)
    # {:ok, conn}

    Logger.info("NATS connection placeholder - implement async_nats NIFx")
    {:ok, :placeholder_connection}
  end

  defp ensure_kv_bucket(bucket, %{kv_buckets: buckets} = state) do
    if Map.has_key?(buckets, bucket) do
      {:ok, state}
    else
      # Create or bind to KV bucket
      case create_kv_bucket(bucket, state) do
        {:ok, kv} ->
          {:ok, %{state | kv_buckets: Map.put(buckets, bucket, kv)}}

        error ->
          error
      end
    end
  end

  defp create_kv_bucket(bucket, _state) do
    # TODO: Implement JetStream KV bucket creation
    #
    # In real implementation:
    # {:ok, js} = :async_nats.jetstream(state.conn)
    # {:ok, kv} = :async_nats_kv.create_or_bind(js, bucket)
    # {:ok, kv}

    Logger.debug("Creating JetStream KV bucket: #{bucket}")
    {:ok, :placeholder_kv}
  end

  defp kv_get_internal(bucket, key, state) do
    # TODO: Implement actual KV get
    #
    # In real implementation:
    # kv = state.kv_buckets[bucket]
    # case :async_nats_kv.get(kv, key) do
    #   {:ok, value} -> {:ok, Jason.decode!(value)}
    #   {:error, :not_found} -> {:error, :not_found}
    # end

    Logger.debug("KV GET #{bucket}/#{key}")
    {:error, :not_found}
  end

  defp kv_put_internal(bucket, key, value, state) do
    # TODO: Implement actual KV put
    #
    # In real implementation:
    # kv = state.kv_buckets[bucket]
    # encoded = Jason.encode!(value)
    # :async_nats_kv.put(kv, key, encoded)

    Logger.debug("KV PUT #{bucket}/#{key}")
    :ok
  end

  defp :nats_request(conn, subject, payload, timeout) do
    # TODO: Implement actual NATS request
    #
    # In real implementation:
    # case :async_nats.request(conn, subject, payload, timeout) do
    #   {:ok, response} -> {:ok, response.body}
    #   error -> error
    # end

    Logger.debug("NATS REQUEST #{subject}")
    {:error, :not_implemented}
  end

  defp :nats_publish(conn, subject, payload) do
    # TODO: Implement actual NATS publish
    #
    # In real implementation:
    # :async_nats.publish(conn, subject, payload)

    Logger.debug("NATS PUBLISH #{subject}")
    :ok
  end
end
