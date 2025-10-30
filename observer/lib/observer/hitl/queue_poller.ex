defmodule Observer.HITL.QueuePoller do
  @moduledoc """
  Background process that ingests approval requests from pgmq
  and stores them in the Observer database.

  Uses QuantumFlow notifications for real-time message processing instead of polling.
  """

  use GenServer
  require Logger

  alias Observer.HITL
  alias Observer.Pgmq
  alias Observer.Repo

  @request_queue "observer_hitl_requests"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Pgmq.ensure_queue(@request_queue)

    # Start listening for notifications
    case QuantumFlow.Notifications.listen(@request_queue, Repo) do
      {:ok, listener_pid} ->
        Logger.info("HITL QueuePoller: Started listening for notifications",
          queue: @request_queue,
          listener_pid: inspect(listener_pid)
        )
        {:ok, %{listener_pid: listener_pid}}

      {:error, reason} ->
        Logger.error("HITL QueuePoller: Failed to start notification listener, falling back to polling",
          queue: @request_queue,
          error: inspect(reason)
        )
        # Fallback to polling
        schedule_poll(0)
        {:ok, %{polling: true}}
    end
  end

  @impl true
  def handle_info({:notification, _pid, _channel, _payload}, state) do
    # Notification received, process messages
    ingest_requests()
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %{polling: true} = state) do
    ingest_requests()
    schedule_poll(1_000)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{listener_pid: pid} = _state) do
    QuantumFlow.Notifications.unlisten(pid, Repo)
  end

  @impl true
  def terminate(_reason, _state), do: :ok

  defp ingest_requests do
    Pgmq.read_messages(@request_queue, 10)
    |> Enum.each(fn {msg_id, payload} ->
      case handle_request(payload) do
        :ok ->
          Pgmq.ack_message(@request_queue, msg_id)

        {:error, reason} ->
          Logger.error("Failed to ingest HITL request", reason: inspect(reason), payload: payload)
          Pgmq.ack_message(@request_queue, msg_id)
      end
    end)
  end

  defp handle_request(%{"request_id" => request_id} = payload) do
    existing = HITL.get_by_request_id(request_id)

    attrs = %{
      request_id: request_id,
      agent_id: Map.get(payload, "agent_id"),
      task_type: Map.get(payload, "task_type"),
      payload: payload,
      metadata: Map.get(payload, "metadata", %{}),
      response_queue: Map.get(payload, "response_queue")
    }

    case existing do
      nil ->
        case HITL.create_approval(attrs) do
          {:ok, _approval} -> :ok
          {:error, changeset} -> {:error, changeset}
        end

      %{} ->
        :ok
    end
  rescue
    error -> {:error, error}
  end

  defp handle_request(_), do: {:error, :invalid_payload}

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end
end
