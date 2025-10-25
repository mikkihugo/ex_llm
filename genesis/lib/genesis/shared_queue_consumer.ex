defmodule Genesis.SharedQueueConsumer do
  @moduledoc """
  Genesis Consumer - Reads job requests from shared_queue and publishes results.

  Genesis is a code execution service that:
  1. Reads job_requests from shared_queue pgmq
  2. Executes the code (linting, validation, testing)
  3. Publishes job_results back to shared_queue

  ## Message Flow

  ```
  Singularity
      ↓ publishes
  pgmq.job_requests
      ↓
  Genesis.SharedQueueConsumer.consume_jobs()
      ↓
  Executes code (linting, validation, etc.)
      ↓
  pgmq.job_results
      ↓ reads
  Singularity
  ```

  ## Configuration

  ```elixir
  config :genesis, :shared_queue,
    enabled: true,
    database_url: System.get_env("SHARED_QUEUE_DB_URL"),
    poll_interval_ms: 1000,
    batch_size: 10
  ```

  ## Usage

  Start the consumer:
  ```elixir
  {:ok, _pid} = Genesis.SharedQueueConsumer.start_link([])
  ```

  Or add to supervision tree:
  ```elixir
  {Genesis.SharedQueueConsumer, []}
  ```
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Genesis.SharedQueueConsumer] Starting job consumer")

    # Start polling immediately
    schedule_poll()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    consume_job_requests()
    schedule_poll()
    {:noreply, state}
  end

  # --- Job Consumption ---

  @doc """
  Consume job requests from shared_queue and execute them.
  """
  def consume_job_requests do
    batch_size = config()[:batch_size] || 10

    case read_job_requests(batch_size) do
      {:ok, requests} when is_list(requests) and length(requests) > 0 ->
        Logger.info("[Genesis.SharedQueueConsumer] Processing jobs", %{count: length(requests)})

        Enum.each(requests, fn {msg_id, request} ->
          process_job_request(msg_id, request)
        end)

      :empty ->
        # No jobs available
        :ok

      {:error, reason} ->
        Logger.error("[Genesis.SharedQueueConsumer] Failed to read jobs", %{error: reason})
        :ok
    end
  end

  # --- Private Helpers ---

  defp read_job_requests(limit) do
    unless enabled?() do
      :empty
    else
      try do
        db_url = config()[:database_url]
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        case Postgrex.query(
               pid,
               "SELECT msg_id, read_ct, enqueued_at, vt, msg FROM pgmq.read($1, $2)",
               ["code_execution_requests", limit]
             ) do
          {:ok, result} when result.num_rows > 0 ->
            messages =
              Enum.map(result.rows, fn [msg_id, _read_ct, _enqueued_at, _vt, msg] ->
                msg_data = if is_binary(msg), do: Jason.decode!(msg), else: msg
                {msg_id, msg_data}
              end)

            Postgrex.close(pid)
            {:ok, messages}

          {:ok, _} ->
            Postgrex.close(pid)
            :empty

          {:error, reason} ->
            Postgrex.close(pid)
            {:error, reason}
        end
      rescue
        e ->
          Logger.error("[Genesis.SharedQueueConsumer] Exception reading jobs", %{error: inspect(e)})
          :empty
      end
    end
  end

  defp process_job_request(msg_id, request) do
    start_time = System.monotonic_time(:millisecond)

    try do
      Logger.info("[Genesis] Processing job", %{
        msg_id: msg_id,
        job_id: request["id"],
        language: request["language"]
      })

      # Execute the job
      result = execute_job(request)

      # Publish result back to shared_queue
      publish_job_result(request["id"], result)

      # Calculate execution time
      execution_time_ms = System.monotonic_time(:millisecond) - start_time

      # Publish per-job execution stats to CentralCloud
      publish_job_stats(request["id"], request["language"], "success", execution_time_ms)

      # Archive the processed message
      archive_message("code_execution_requests", msg_id)

      Logger.info("[Genesis] Job completed", %{job_id: request["id"], execution_time_ms: execution_time_ms})
    rescue
      e ->
        execution_time_ms = System.monotonic_time(:millisecond) - start_time

        Logger.error("[Genesis] Job execution failed", %{
          job_id: request["id"],
          error: inspect(e),
          execution_time_ms: execution_time_ms
        })

        # Publish failed job stats
        publish_job_stats(request["id"], request["language"], "failed", execution_time_ms)

        # Still archive the message (it was processed, just failed)
        archive_message("code_execution_requests", msg_id)
    end
  end

  defp execute_job(request) do
    code = request["code"]
    language = request["language"]

    # TODO: Implement actual job execution based on language
    # For now, return a placeholder result
    case language do
      "elixir" ->
        # Validate Elixir syntax
        case Code.string_to_quoted(code) do
          {:ok, _ast} -> %{output: "✓ Valid Elixir code", error: nil}
          {:error, reason} -> %{output: nil, error: inspect(reason)}
        end

      "rust" ->
        # Would call rustfmt or similar
        %{output: "Rust validation not yet implemented", error: nil}

      "javascript" ->
        # Would call Node.js or similar
        %{output: "JavaScript validation not yet implemented", error: nil}

      _ ->
        %{output: nil, error: "Unsupported language: #{language}"}
    end
  end

  defp publish_job_result(job_id, result) do
    unless enabled?() do
      :ok
    else
      try do
        db_url = config()[:database_url]
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        msg = %{
          "request_id" => job_id,
          "output" => result[:output],
          "error" => result[:error]
        }

        json_msg = Jason.encode!(msg)

        case Postgrex.query(
               pid,
               "SELECT pgmq.send($1, $2::jsonb)",
               ["code_execution_results", json_msg]
             ) do
          {:ok, _} ->
            Logger.debug("[Genesis] Published job result", %{job_id: job_id})
            Postgrex.close(pid)
            :ok

          {:error, reason} ->
            Logger.error("[Genesis] Failed to publish job result", %{
              job_id: job_id,
              error: inspect(reason)
            })

            Postgrex.close(pid)
            {:error, reason}
        end
      rescue
        e ->
          Logger.error("[Genesis] Exception publishing job result", %{error: inspect(e)})
          :error
      end
    end
  end

  defp publish_job_stats(job_id, language, status, execution_time_ms) do
    unless enabled?() do
      :ok
    else
      try do
        db_url = config()[:database_url]
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        msg = %{
          "type" => "genesis_execution_stats",
          "job_id" => job_id,
          "language" => language,
          "status" => status,
          "execution_time_ms" => execution_time_ms,
          "memory_used_mb" => 0,
          "lines_analyzed" => 0,
          "timestamp" => DateTime.utc_now()
        }

        json_msg = Jason.encode!(msg)

        case Postgrex.query(
               pid,
               "SELECT pgmq.send($1, $2::jsonb)",
               ["execution_statistics_per_job", json_msg]
             ) do
          {:ok, _} ->
            Logger.debug("[Genesis] Published job stats", %{job_id: job_id, status: status})
            Postgrex.close(pid)
            :ok

          {:error, reason} ->
            Logger.error("[Genesis] Failed to publish job stats", %{
              job_id: job_id,
              error: inspect(reason)
            })

            Postgrex.close(pid)
            {:error, reason}
        end
      rescue
        e ->
          Logger.error("[Genesis] Exception publishing job stats", %{error: inspect(e)})
          :error
      end
    end
  end

  defp archive_message(queue_name, msg_id) do
    unless enabled?() do
      :ok
    else
      try do
        db_url = config()[:database_url]
        {:ok, pid} = Postgrex.start_link(parse_connection_string(db_url))

        case Postgrex.query(
               pid,
               "SELECT pgmq.archive($1, $2)",
               [queue_name, msg_id]
             ) do
          {:ok, _} ->
            Postgrex.close(pid)
            :ok

          {:error, reason} ->
            Logger.warn("[Genesis] Failed to archive message", %{
              queue: queue_name,
              msg_id: msg_id,
              error: inspect(reason)
            })

            Postgrex.close(pid)
            :error
        end
      rescue
        e ->
          Logger.error("[Genesis] Exception archiving message", %{error: inspect(e)})
          :error
      end
    end
  end

  defp parse_connection_string(url) do
    case URI.parse(url) do
      %URI{host: host, port: port, userinfo: userinfo, path: path} ->
        [user, password] = if userinfo, do: String.split(userinfo, ":"), else: ["postgres", ""]
        database = String.trim_leading(path, "/")

        [
          hostname: host,
          port: port || 5432,
          username: user,
          password: password,
          database: database
        ]

      _ ->
        raise "Invalid database URL: #{url}"
    end
  end

  defp schedule_poll do
    poll_interval = config()[:poll_interval_ms] || 1000
    Process.send_after(self(), :poll, poll_interval)
  end

  defp enabled? do
    Application.get_env(:genesis, :shared_queue)[:enabled] == true
  end

  defp config do
    Application.get_env(:genesis, :shared_queue, [])
  end
end
