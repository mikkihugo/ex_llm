defmodule Observer.HITL.QueuePoller do
  @moduledoc """
  Background process that ingests approval requests from pgmq
  and stores them in the Observer database.
  """

  use GenServer
  require Logger

  alias Observer.HITL
  alias Observer.Pgmq

  @request_queue "observer_hitl_requests"
  @poll_interval Application.compile_env(:observer, [:hitl, :poll_interval], 1_000)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Pgmq.ensure_queue(@request_queue)
    schedule_poll(0)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    ingest_requests()
    schedule_poll(@poll_interval)
    {:noreply, state}
  end

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
