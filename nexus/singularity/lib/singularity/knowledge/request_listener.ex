defmodule Singularity.Knowledge.RequestListener do
  @moduledoc """
  Listens for PostgreSQL NOTIFY events on the `knowledge_requests` channel
  and falls back to periodic polling to guarantee delivery.
  """

  use GenServer
  require Logger

  alias Singularity.Knowledge.Requests
  alias Singularity.Repo
  alias Singularity.Infrastructure.QuantumFlow.Queue

  @channel "knowledge_requests"
  @default_poll_ms 60_000
  @poll_window_seconds 300

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    poll_interval_ms =
      opts
      |> Keyword.get(:poll_interval_ms)
      |> case do
        nil ->
          Application.get_env(:singularity, :knowledge_requests, %{})[:poll_interval_ms] ||
            @default_poll_ms

        value ->
          value
      end

    state = %{
      listener: nil,
      poll_interval_ms: poll_interval_ms
    }

    case Queue.listen(@channel, Repo) do
      {:ok, listener_pid} ->
        Logger.info("KnowledgeRequestListener subscribed to #{@channel}")
        Process.monitor(listener_pid)
        schedule_poll(poll_interval_ms)
        {:ok, %{state | listener: listener_pid}}

      {:error, reason} ->
        Logger.error("Failed to subscribe to #{@channel}", reason: inspect(reason))
        schedule_poll(poll_interval_ms)
        {:ok, state}
    end
  end

  @impl true
  def handle_info({:notification, listener, @channel, payload}, %{listener: listener} = state) do
    Requests.handle_notification(payload)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notification, _pid, _channel, _payload}, state) do
    # Ignore notifications from other listeners/channels
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{listener: pid} = state) do
    Logger.warning(
      "KnowledgeRequestListener lost NOTIFY subscription, reason: #{inspect(reason)}"
    )

    case Queue.listen(@channel, Repo) do
      {:ok, listener_pid} ->
        Logger.info("KnowledgeRequestListener re-subscribed to #{@channel}")
        Process.monitor(listener_pid)
        {:noreply, %{state | listener: listener_pid}}

      {:error, error} ->
        Logger.error("Failed to re-subscribe to #{@channel}", reason: inspect(error))
        {:noreply, %{state | listener: nil}}
    end
  end

  @impl true
  def handle_info(:poll, %{poll_interval_ms: poll_ms} = state) do
    run_poll_cycle()
    schedule_poll(poll_ms)
    {:noreply, state}
  end

  defp schedule_poll(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    Process.send_after(self(), :poll, interval_ms)
  end

  defp run_poll_cycle do
    now = DateTime.utc_now()

    pending = Requests.due_for_processing()

    pending
    |> Enum.each(fn request ->
      Logger.debug("Knowledge request still pending",
        id: request.id,
        status: request.status,
        external_key: request.external_key
      )
    end)

    since = DateTime.add(now, -@poll_window_seconds, :second)

    resolved = Requests.recently_resolved(since)

    resolved
    |> Enum.each(fn request ->
      # Replay resolved events in case NOTIFY was missed
      request
      |> Requests.build_event()
      |> Requests.dispatch_event()
    end)

    :telemetry.execute(
      [:singularity, :knowledge_request, :poll_completed],
      %{pending: length(pending), resolved: length(resolved)},
      %{since: since}
    )
  rescue
    e ->
      Logger.error("KnowledgeRequestListener poll failed", error: inspect(e))
  end
end
