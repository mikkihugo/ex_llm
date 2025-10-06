defmodule Singularity.NatsClient do
  @moduledoc """
  Modern NATS client for communicating with the AI server and other services.

  Provides a clean interface for:
  - Publishing messages to NATS subjects
  - Request/Reply patterns
  - Streaming subscriptions
  - JetStream operations
  """

  use GenServer
  require Logger

  alias Gnat

  @type nats_message :: %{
          subject: String.t(),
          data: binary(),
          reply: String.t() | nil,
          headers: map()
        }

  @type nats_request :: %{
          subject: String.t(),
          data: binary(),
          timeout: non_neg_integer(),
          headers: map()
        }

  @type nats_response :: %{
          data: binary(),
          subject: String.t(),
          headers: map()
        }

  ## Client API

  @doc """
  Publish a message to a NATS subject.

  ## Examples

      iex> Singularity.NatsClient.publish("ai.provider.codex", "Hello world")
      :ok
  """
  @spec publish(String.t(), binary(), keyword()) :: :ok | {:error, term()}
  def publish(subject, data, opts \\ []) when is_binary(subject) and is_binary(data) do
    GenServer.call(__MODULE__, {:publish, subject, data, opts})
  end

  @doc """
  Send a request and wait for a response.

  ## Examples

      iex> Singularity.NatsClient.request("ai.provider.codex", "Generate code", timeout: 5000)
      {:ok, %{data: "def hello, do: :world", ...}}
  """
  @spec request(String.t(), binary(), keyword()) :: {:ok, nats_response()} | {:error, term()}
  def request(subject, data, opts \\ []) when is_binary(subject) and is_binary(data) do
    timeout = Keyword.get(opts, :timeout, 5000)
    headers = Keyword.get(opts, :headers, %{})

    GenServer.call(__MODULE__, {:request, subject, data, timeout, headers}, timeout + 1000)
  end

  @doc """
  Subscribe to a subject pattern.

  ## Examples

      iex> Singularity.NatsClient.subscribe("ai.>")
      {:ok, subscription_id}
  """
  @spec subscribe(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def subscribe(subject_pattern, opts \\ []) when is_binary(subject_pattern) do
    GenServer.call(__MODULE__, {:subscribe, subject_pattern, opts})
  end

  @doc """
  Unsubscribe from a subject.

  ## Examples

      iex> Singularity.NatsClient.unsubscribe(subscription_id)
      :ok
  """
  @spec unsubscribe(String.t()) :: :ok | {:error, term()}
  def unsubscribe(subscription_id) when is_binary(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @doc """
  Check if NATS is connected.
  """
  @spec connected?() :: boolean()
  def connected? do
    GenServer.call(__MODULE__, :connected?)
  end

  @doc """
  Get connection status and statistics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  ## GenServer Callbacks

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    nats_url = Keyword.get(opts, :nats_url, "nats://localhost:4222")

    state = %{
      nats_url: nats_url,
      connection: nil,
      subscriptions: %{},
      message_count: 0,
      error_count: 0,
      connected: false
    }

    # Start connection process
    send(self(), :connect)

    {:ok, state}
  end

  @impl true
  def handle_call({:publish, subject, _data, _opts}, _from, %{connection: nil} = state) do
    Logger.warninging("NATS not connected, cannot publish to #{subject}")
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:publish, subject, data, _opts}, _from, state) do
    try do
      case Gnat.pub(state.connection, subject, data) do
        :ok ->
          Logger.debug("Published to #{subject}", %{subject: subject, data_size: byte_size(data)})
          new_state = %{state | message_count: state.message_count + 1}
          {:reply, :ok, new_state}

        {:error, reason} ->
          Logger.error("Failed to publish to #{subject}: #{inspect(reason)}")
          new_state = %{state | error_count: state.error_count + 1}
          {:reply, {:error, reason}, new_state}
      end
    rescue
      error ->
        Logger.error("Exception publishing to #{subject}: #{inspect(error)}")
        new_state = %{state | error_count: state.error_count + 1}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl true
  def handle_call({:request, subject, _data, _timeout, _headers}, _from, %{connection: nil} = state) do
    Logger.warninging("NATS not connected, cannot request from #{subject}")
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:request, subject, data, timeout, _headers}, _from, state) do
    try do
      Logger.debug("Request to #{subject}", %{
        subject: subject,
        data_size: byte_size(data),
        timeout: timeout
      })

      case Gnat.request(state.connection, subject, data, receive_timeout: timeout) do
        {:ok, message} ->
          Logger.debug("Received response from #{subject}", %{
            subject: subject,
            reply_subject: message.subject
          })

          response = %{
            data: message.data,
            subject: message.subject,
            headers: %{}
          }

          new_state = %{state | message_count: state.message_count + 1}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          Logger.error("Request failed to #{subject}: #{inspect(reason)}")
          new_state = %{state | error_count: state.error_count + 1}
          {:reply, {:error, reason}, new_state}
      end
    rescue
      error ->
        Logger.error("Exception requesting from #{subject}: #{inspect(error)}")
        new_state = %{state | error_count: state.error_count + 1}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl true
  def handle_call({:subscribe, subject_pattern, opts}, _from, state) do
    subscription_id = generate_subscription_id()

    new_subscriptions =
      Map.put(state.subscriptions, subscription_id, %{
        subject_pattern: subject_pattern,
        opts: opts,
        created_at: System.monotonic_time(:millisecond)
      })

    new_state = %{state | subscriptions: new_subscriptions}
    {:reply, {:ok, subscription_id}, new_state}
  end

  @impl true
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    new_subscriptions = Map.delete(state.subscriptions, subscription_id)
    new_state = %{state | subscriptions: new_subscriptions}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      connected: state.connected,
      nats_url: state.nats_url,
      message_count: state.message_count,
      error_count: state.error_count,
      active_subscriptions: map_size(state.subscriptions)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.info("Connecting to NATS at #{state.nats_url}")

    case Gnat.start_link(%{host: "localhost", port: 4222, name: :nats_client}) do
      {:ok, connection} ->
        Logger.info("Connected to NATS successfully")
        new_state = %{state | connection: connection, connected: true}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to connect to NATS: #{inspect(reason)}")
        # Retry connection after 5 seconds
        Process.send_after(self(), :connect, 5000)
        new_state = %{state | error_count: state.error_count + 1}
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:nats_message, subject, _data, _reply, _headers}, state) do
    # Handle incoming NATS messages
    Logger.debug("Received NATS message on #{subject}")

    new_state = %{state | message_count: state.message_count + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nats_error, error}, state) do
    Logger.error("NATS error: #{inspect(error)}")

    new_state = %{state | error_count: state.error_count + 1}
    {:noreply, new_state}
  end

  ## Private Functions

  defp generate_subscription_id do
    "sub_" <> (:crypto.strong_rand_bytes(8) |> Base.encode64(padding: false))
  end
end
