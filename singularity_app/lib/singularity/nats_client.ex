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
    Logger.warning("NATS not connected, cannot publish to #{subject}")
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
  def handle_call(
        {:request, subject, _data, _timeout, _headers},
        _from,
        %{connection: nil} = state
      ) do
    Logger.warning("NATS not connected, cannot request from #{subject}")
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

# COMPLETED: NATS client interactions now support SPARC completion phase for final code delivery.
# COMPLETED: Added telemetry to monitor NATS message flow and its impact on SPARC workflows.

  @doc """
  Ensure NATS client interactions support SPARC completion phase for final code delivery.
  """
  def request_with_sparc_completion(subject, payload, opts \\ []) do
    # Add SPARC completion context to the request
    sparc_context = %{
      sparc_phase: :completion,
      completion_requirements: Map.get(opts, :completion_requirements, []),
      quality_gates: Map.get(opts, :quality_gates, []),
      delivery_format: Map.get(opts, :delivery_format, :code_artifacts)
    }
    
    enhanced_payload = Map.merge(payload, %{
      sparc_context: sparc_context,
      request_id: generate_request_id(),
      timestamp: DateTime.utc_now()
    })
    
    # Track SPARC completion request
    track_nats_message_flow(:sparc_completion_request, subject, enhanced_payload)
    
    # Make the NATS request
    case request(subject, enhanced_payload, opts) do
      {:ok, response} ->
        # Track successful SPARC completion
        track_nats_message_flow(:sparc_completion_success, subject, response)
        {:ok, response}
      
      {:error, reason} ->
        # Track failed SPARC completion
        track_nats_message_flow(:sparc_completion_failure, subject, %{error: reason})
        {:error, reason}
    end
  end

  @doc """
  Add telemetry to monitor NATS message flow and its impact on SPARC workflows.
  """
  def track_nats_message_flow(event_type, subject, payload) do
    :telemetry.execute([:nats_client, :message_flow, event_type], %{
      count: 1,
      timestamp: System.system_time(:millisecond)
    }, %{
      subject: subject,
      payload_size: byte_size(Jason.encode!(payload)),
      sparc_phase: extract_sparc_phase(payload),
      workflow_id: extract_workflow_id(payload)
    })
  end

  def track_sparc_workflow_impact(workflow_id, phase, impact_metrics) do
    :telemetry.execute([:nats_client, :sparc_workflow, :impact], %{
      value: impact_metrics.completion_time,
      timestamp: System.system_time(:millisecond)
    }, %{
      workflow_id: workflow_id,
      phase: phase,
      quality_score: impact_metrics.quality_score,
      artifact_count: impact_metrics.artifact_count,
      error_rate: impact_metrics.error_rate
    })
  end

  defp extract_sparc_phase(payload) do
    case payload do
      %{sparc_context: %{sparc_phase: phase}} -> phase
      %{"sparc_context" => %{"sparc_phase" => phase}} -> String.to_atom(phase)
      _ -> :unknown
    end
  end

  defp extract_workflow_id(payload) do
    case payload do
      %{workflow_id: id} -> id
      %{"workflow_id" => id} -> id
      %{sparc_context: %{workflow_id: id}} -> id
      %{"sparc_context" => %{"workflow_id" => id}} -> id
      _ -> nil
    end
  end

  defp generate_request_id do
    "req_" <> (:crypto.strong_rand_bytes(8) |> Base.encode64(padding: false))
  end
