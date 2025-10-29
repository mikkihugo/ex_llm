defmodule Singularity.Conversation.ResponsePoller do
  @moduledoc """
  Response Poller - Handles polling pgmq for approval/question responses.

  Polls a pgmq response queue for decisions made in the Observer web UI,
  allowing agents to wait for human responses asynchronously.

  ## Usage

      # Start polling for a response
      {:ok, poller_pid} = ResponsePoller.start_polling(
        response_queue: "approval_response_req-123",
        timeout_ms: 30_000,
        callback: fn decision -> handle_decision(decision) end
      )

      # The callback will be invoked when a response arrives
      # or when the timeout is reached
  """

  require Logger

  alias Singularity.Database.MessageQueue

  @poll_interval_ms 500
  @max_retries 3

  @doc """
  Start polling for a response from a pgmq queue.

  Returns immediately with {:ok, poller_pid} and begins polling in background.
  The callback will be invoked with the response when available.

  ## Options

    - `:response_queue` (required) - pgmq queue name to poll
    - `:timeout_ms` (required) - Maximum time to wait for response
    - `:callback` (required) - Function to call with response
    - `:agent_pid` (optional) - PID to notify on completion
  """
  @spec start_polling(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_polling(opts) do
    Task.start(fn -> poll_loop(opts) end)
  end

  @doc """
  Wait for response with blocking call.

  Blocks until response arrives or timeout expires.
  """
  @spec wait_for_response(String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def wait_for_response(response_queue, timeout_ms \\ 30_000) do
    start_time = System.monotonic_time(:millisecond)

    poll_until_response(response_queue, start_time, timeout_ms)
  end

  # Private: Poll until response arrives or timeout
  defp poll_until_response(response_queue, start_time, timeout_ms) do
    case read_response(response_queue) do
      {:ok, response} ->
        {:ok, response}

      :empty ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed >= timeout_ms do
          Logger.warning("Response timeout for queue: #{response_queue}")
          {:error, :timeout}
        else
          remaining = timeout_ms - elapsed
          sleep_time = min(@poll_interval_ms, remaining)

          Process.sleep(sleep_time)
          poll_until_response(response_queue, start_time, timeout_ms)
        end

      {:error, reason} ->
        Logger.error("Failed to read response from #{response_queue}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private: Main polling loop (for async polling)
  defp poll_loop(opts) do
    response_queue = Keyword.fetch!(opts, :response_queue)
    timeout_ms = Keyword.fetch!(opts, :timeout_ms)
    callback = Keyword.fetch!(opts, :callback)

    start_time = System.monotonic_time(:millisecond)

    try do
      case poll_until_response(response_queue, start_time, timeout_ms) do
        {:ok, response} ->
          Logger.info("Response received for queue: #{response_queue}")
          callback.(response)
          {:ok, response}

        {:error, :timeout} ->
          Logger.warning("Response polling timed out for queue: #{response_queue}")
          callback.({:error, :timeout})
          {:error, :timeout}

        {:error, reason} ->
          Logger.error("Response polling failed: #{inspect(reason)}")
          callback.({:error, reason})
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Response polling error: #{inspect(error)}")
        callback.({:error, error})
        {:error, error}
    end
  end

  # Private: Try to read a response from pgmq with retries
  defp read_response(queue_name, retry_count \\ 0) do
    try do
      case MessageQueue.receive_message(queue_name) do
        {:ok, {msg_id, response}} ->
          # Acknowledge message
          MessageQueue.acknowledge(queue_name, msg_id)
          {:ok, response}

        :empty ->
          # Queue is empty
          :empty

        {:error, reason} when retry_count < @max_retries ->
          Logger.warning(
            "Failed to read from #{queue_name} (retry #{retry_count + 1}/#{@max_retries}): #{inspect(reason)}"
          )

          Process.sleep(100)
          read_response(queue_name, retry_count + 1)

        {:error, reason} ->
          Logger.error("Failed to read from #{queue_name} after #{@max_retries} retries")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Exception reading from #{queue_name}: #{inspect(error)}")
        {:error, error}
    end
  end
end
