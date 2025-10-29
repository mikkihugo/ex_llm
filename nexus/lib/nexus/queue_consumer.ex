defmodule Nexus.QueueConsumer do
  @moduledoc """
  Queue Consumer - Consumes LLM requests from pgmq and routes to providers.

  Polls the `llm_requests` queue for incoming LLM requests from Singularity agents,
  routes them through the LLM router, and publishes results back to `llm_results` queue.

  ## Queue Message Format

  ### Input (llm_requests):
  ```json
  {
    "request_id": "uuid",
    "agent_id": "self-improving-agent",
    "complexity": "complex",
    "task_type": "architect",
    "messages": [
      {"role": "user", "content": "Design a feature"}
    ],
    "max_tokens": 4000,
    "timestamp": "2025-10-25T22:00:00Z"
  }
  ```

  ### Output (llm_results):
  ```json
  {
    "request_id": "uuid",
    "agent_id": "self-improving-agent",
    "response": "LLM response content",
    "model": "claude-3-5-sonnet-20241022",
    "usage": {"prompt_tokens": 100, "completion_tokens": 200, "total_tokens": 300},
    "cost": 0.015,
    "timestamp": "2025-10-25T22:00:05Z"
  }
  ```
  """

  use GenServer
  require Logger

  @queue_name "ai_requests"
  @results_queue "ai_results"
  @poll_interval_ms 1000
  @batch_size 10

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    db_url = get_database_url(opts)
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)

    Logger.info("Starting Nexus Queue Consumer",
      queue: @queue_name,
      poll_interval: poll_interval
    )

    state = %{
      db_url: db_url,
      poll_interval: poll_interval,
      batch_size: Keyword.get(opts, :batch_size, @batch_size)
    }

    # Start polling immediately
    schedule_poll(0)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case poll_queue(state) do
      {:ok, count} when count > 0 ->
        Logger.debug("Processed #{count} LLM requests")

      {:ok, 0} ->
        # No messages, keep polling
        :ok

      {:error, reason} ->
        Logger.error("Failed to poll queue: #{inspect(reason)}")
    end

    # Schedule next poll
    schedule_poll(state.poll_interval)

    {:noreply, state}
  end

  # Private functions

  defp get_database_url(_opts) do
    # Use shared queue database configured for Nexus
    # This should be the same PostgreSQL instance as Singularity
    System.get_env("SHARED_QUEUE_DB_URL") ||
      System.get_env("DATABASE_URL") ||
      "postgresql://postgres:@localhost:5432/singularity"
  end

  defp schedule_poll(delay_ms) do
    Process.send_after(self(), :poll, delay_ms)
  end

  defp poll_queue(state) do
    # Read messages from pgmq
    case read_messages(state.db_url, @queue_name, state.batch_size) do
      {:ok, messages} ->
        process_messages(messages, state)
        {:ok, length(messages)}

      {:error, _reason} = error ->
        error
    end
  end

  defp read_messages(db_url, queue_name, limit) do
    # Use pgmq to read messages
    # pgmq.read(queue_name, vt: visibility_timeout, limit: limit)
    query = """
    SELECT * FROM pgmq.read('#{queue_name}', #{limit}, 30)
    """

    case run_query(db_url, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        messages = parse_messages(rows, columns)
        {:ok, messages}

      error ->
        error
    end
  end

  defp run_query(_db_url, query) do
    # Use Nexus.Repo for queries to maintain connection pooling
    # and proper transaction handling
    try do
      {:ok, Nexus.Repo.query!(query)}
    rescue
      e -> {:error, e}
    end
  end

  defp parse_messages(rows, columns) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Map.new()
      |> parse_message()
    end)
  end

  defp parse_message(raw) do
    %{
      msg_id: Map.get(raw, "msg_id"),
      msg: Jason.decode!(Map.get(raw, "msg") || "{}")
    }
  end

  defp process_messages(messages, state) do
    Enum.each(messages, fn msg ->
      process_message(msg, state)
    end)
  end

  defp process_message(%{msg_id: msg_id, msg: request}, state) do
    Logger.info("Processing LLM request",
      msg_id: msg_id,
      request_id: Map.get(request, "request_id"),
      agent_id: Map.get(request, "agent_id")
    )

    case route_request(request) do
      {:ok, response} ->
        publish_result(state.db_url, request, response)
        archive_message(state.db_url, @queue_name, msg_id)

      {:error, reason} ->
        Logger.error("Failed to route request",
          msg_id: msg_id,
          error: inspect(reason)
        )

        # Optionally: publish error result or retry
    end
  end

  defp route_request(request) do
    # Convert string keys to atom keys for router
    api_version = Map.get(request, "api_version", "responses")

    router_request =
      %{
        complexity: string_to_atom(Map.get(request, "complexity")),
        messages: Map.get(request, "messages", []),
        task_type: string_to_atom(Map.get(request, "task_type")),
        api_version: api_version,
        max_tokens: Map.get(request, "max_tokens"),
        temperature: Map.get(request, "temperature"),
        previous_response_id: Map.get(request, "previous_response_id"),
        mcp_servers: Map.get(request, "mcp_servers"),
        store: Map.get(request, "store"),
        tools: Map.get(request, "tools")
      }
      # Remove nil values for cleaner request
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    Nexus.LLMRouter.route(router_request)
  end

  defp string_to_atom(nil), do: nil
  defp string_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp string_to_atom(atom) when is_atom(atom), do: atom

  defp publish_result(db_url, request, llm_response) do
    result = %{
      request_id: Map.get(request, "request_id"),
      agent_id: Map.get(request, "agent_id"),
      response: llm_response.content,
      model: llm_response.model,
      usage: llm_response.usage,
      cost: llm_response.cost,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    query = """
    SELECT * FROM pgmq.send('#{@results_queue}', '#{Jason.encode!(result)}')
    """

    case run_query(db_url, query) do
      {:ok, _} ->
        Logger.info("Published LLM result",
          request_id: result.request_id,
          model: result.model
        )

      {:error, reason} ->
        Logger.error("Failed to publish result: #{inspect(reason)}")
    end
  end

  defp archive_message(db_url, queue_name, msg_id) do
    query = """
    SELECT * FROM pgmq.archive('#{queue_name}', #{msg_id})
    """

    run_query(db_url, query)
  end
end
