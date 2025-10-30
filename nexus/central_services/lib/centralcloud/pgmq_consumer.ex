defmodule CentralCloud.PgmqConsumer do
  @moduledoc """
  Base GenServer for consuming pgmq messages.

  ## Architecture

  Uses PostgreSQL pgmq (message queue) to consume messages from shared_queue database.

  Features:
  - Polls pgmq queue periodically
  - Handles message processing with configurable callback
  - Automatic acknowledgment on success
  - Requeue on failure with backoff
  - Statistics tracking (messages consumed, errors, etc.)

  ## Usage

  Create a consumer by implementing handle_message/1 callback in a handler module.

  Then add to supervision tree with configuration options:
  - queue_name: Name of pgmq queue to consume from
  - handler_module: Module with handle_message/1 function
  - poll_interval_ms: How often to poll (milliseconds)
  - batch_size: Number of messages per poll
  """

  use GenServer
  require Logger
  alias Pgmq
  alias Pgmq.Message

  defmodule State do
    @moduledoc """
    Consumer state: configuration + statistics
    """
    defstruct [
      :queue_name,
      :handler_module,
      :repo,
      poll_interval_ms: 1000,
      batch_size: 10,
      messages_consumed: 0,
      messages_failed: 0,
      messages_requeued: 0,
      started_at: nil,
      last_poll_at: nil
    ]
  end

  @doc """
  Start a pgmq consumer with configuration.

  Options:
  - queue_name: Name of pgmq queue to consume from
  - handler_module: Module implementing handle_message/1
  - poll_interval_ms: How often to poll (default: 1000)
  - batch_size: How many messages to consume per poll (default: 10)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    queue_name = Keyword.fetch!(opts, :queue_name)
    handler_module = Keyword.fetch!(opts, :handler_module)

    state = %State{
      queue_name: queue_name,
      handler_module: handler_module,
      repo: CentralCloud.SharedQueueRepo,
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, 1000),
      batch_size: Keyword.get(opts, :batch_size, 10),
      started_at: DateTime.utc_now()
    }

    Logger.info("[#{queue_name}] Consumer starting",
      handler: handler_module,
      poll_interval_ms: state.poll_interval_ms,
      batch_size: state.batch_size
    )

    # Start polling immediately
    send(self(), :poll)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    # Poll for messages
    state = poll_messages(state)

    # Schedule next poll
    Process.send_after(self(), :poll, state.poll_interval_ms)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    uptime_seconds = DateTime.diff(DateTime.utc_now(), state.started_at)

    stats = %{
      queue_name: state.queue_name,
      handler_module: state.handler_module,
      uptime_seconds: uptime_seconds,
      messages_consumed: state.messages_consumed,
      messages_failed: state.messages_failed,
      messages_requeued: state.messages_requeued,
      last_poll_at: state.last_poll_at,
      poll_interval_ms: state.poll_interval_ms,
      batch_size: state.batch_size
    }

    {:reply, stats, state}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp poll_messages(state) do
    case read_messages(state.repo, state.queue_name, state.batch_size) do
      {:ok, messages} when is_list(messages) and length(messages) > 0 ->
        Logger.debug("[#{state.queue_name}] Received #{length(messages)} messages")
        process_messages(state, messages)

      {:ok, []} ->
        # No messages available, just update last_poll_at
        %{state | last_poll_at: DateTime.utc_now()}

      {:error, reason} ->
        Logger.error("[#{state.queue_name}] Poll failed: #{inspect(reason)}")
        state
    end
  end

  defp read_messages(repo, queue_name, batch_size) do
    try do
      messages =
        repo
        |> Pgmq.read_messages(queue_name, 30, batch_size)
        |> Enum.map(&format_message/1)

      {:ok, messages}
    rescue
      e ->
        Logger.error("[#{queue_name}] Query error: #{inspect(e)}")
        {:error, e}
    end
  end

  defp format_message(%Message{id: msg_id, body: body}) do
    %{msg_id: msg_id, msg: body}
  end

  defp format_message(other) do
    Logger.warning("Unexpected message format: #{inspect(other)}")
    %{msg_id: nil, msg: other}
  end

  defp process_messages(state, messages) do
    processed = Enum.reduce(messages, state, &process_single_message/2)
    %{processed | last_poll_at: DateTime.utc_now()}
  end

  defp process_single_message(%{msg_id: msg_id, msg: msg}, state) do
    # Parse JSON message
    try do
      parsed_msg =
        case msg do
          s when is_binary(s) -> Jason.decode!(s)
          m when is_map(m) -> m
          other -> other
        end

      # Call handler
      case state.handler_module.handle_message(parsed_msg) do
        :ok ->
          # Remove message from queue
          ack_message(state.repo, state.queue_name, msg_id)
          Logger.debug("[#{state.queue_name}] ✓ Processed message #{msg_id}")
          %{state | messages_consumed: state.messages_consumed + 1}

        {:error, reason} ->
          Logger.error("[#{state.queue_name}] ✗ Processing failed: #{inspect(reason)}")
          # Requeue with exponential backoff (visibility timeout increases)
          requeue_message(state.repo, state.queue_name, msg_id)
          %{state | messages_failed: state.messages_failed + 1, messages_requeued: state.messages_requeued + 1}

        other ->
          Logger.warning("[#{state.queue_name}] Unexpected handler result: #{inspect(other)}")
          # Requeue on unexpected result
          requeue_message(state.repo, state.queue_name, msg_id)
          %{state | messages_failed: state.messages_failed + 1}
      end
    rescue
      e ->
        Logger.error("[#{state.queue_name}] Exception processing message: #{inspect(e)}")
        requeue_message(state.repo, state.queue_name, msg_id)
        %{state | messages_failed: state.messages_failed + 1}
    end
  end

  defp ack_message(repo, queue_name, msg_id) do
    try do
      :ok = Pgmq.delete_messages(repo, queue_name, [msg_id])
    rescue
      e -> Logger.error("Failed to ack message #{msg_id}: #{inspect(e)}")
    end
  end

  defp requeue_message(repo, queue_name, msg_id) do
    try do
      # Set visibility timeout to 60 seconds (message will be retryable after)
      :ok = Pgmq.set_message_vt(repo, queue_name, msg_id, 60)
    rescue
      e -> Logger.error("Failed to requeue message #{msg_id}: #{inspect(e)}")
    end
  end
end
