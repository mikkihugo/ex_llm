defmodule Singularity.Infrastructure.ErrorRateTracker do
  @moduledoc """
  Tracks error rates for monitoring and alerting.

  Uses ETS for fast, concurrent access to error statistics.
  Automatically calculates error rates over sliding time windows.

  ## Usage

      ErrorRateTracker.record_error(:database_query, %DBConnection.ConnectionError{})
      ErrorRateTracker.get_rate(:database_query)
      # => %{error_count: 5, total_count: 100, error_rate: 0.05, window_seconds: 60}
  """

  use GenServer
  require Logger

  @table_name :singularity_error_rates
  @window_seconds 60
  @cleanup_interval_ms 30_000
  # 5% error rate triggers alert
  @alert_threshold 0.05

  defstruct [
    :cleanup_timer
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record an error occurrence for an operation.
  """
  def record_error(operation, error) do
    timestamp = System.system_time(:second)
    error_type = extract_error_type(error)

    # Insert into ETS
    :ets.insert(@table_name, {
      {operation, :error, timestamp},
      error_type
    })

    # Check if we should alert
    check_alert_threshold(operation)

    :ok
  end

  @doc """
  Record a successful operation.
  """
  def record_success(operation) do
    timestamp = System.system_time(:second)

    :ets.insert(@table_name, {
      {operation, :success, timestamp},
      :success
    })

    :ok
  end

  @doc """
  Get error rate for an operation.

  Returns statistics over the sliding window:
  - `error_count` - Number of errors in window
  - `success_count` - Number of successes in window
  - `total_count` - Total operations in window
  - `error_rate` - Percentage of operations that failed (0.0 - 1.0)
  - `window_seconds` - Size of the time window
  """
  def get_rate(operation) do
    now = System.system_time(:second)
    window_start = now - @window_seconds

    # Get all operations in the window
    error_count = count_operations(operation, :error, window_start, now)
    success_count = count_operations(operation, :success, window_start, now)
    total_count = error_count + success_count

    error_rate =
      if total_count > 0 do
        error_count / total_count
      else
        0.0
      end

    %{
      operation: operation,
      error_count: error_count,
      success_count: success_count,
      total_count: total_count,
      error_rate: error_rate,
      window_seconds: @window_seconds
    }
  end

  @doc """
  Get all operations being tracked.
  """
  def list_operations do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {{operation, _type, _timestamp}, _} -> operation end)
    |> Enum.uniq()
  end

  @doc """
  Get error rates for all operations.
  """
  def get_all_rates do
    list_operations()
    |> Enum.map(&{&1, get_rate(&1)})
    |> Enum.into(%{})
  end

  @doc """
  Clear all statistics.
  """
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Configure ETS table options
    read_concurrency = Keyword.get(opts, :read_concurrency, true)
    write_concurrency = Keyword.get(opts, :write_concurrency, true)
    compressed = Keyword.get(opts, :compressed, false)

    # Create ETS table
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: read_concurrency,
      write_concurrency: write_concurrency,
      compressed: compressed
    ])

    # Schedule periodic cleanup
    timer = Process.send_after(self(), :cleanup, @cleanup_interval_ms)

    Logger.info("Error rate tracker initialized", window_seconds: @window_seconds)

    {:ok, %__MODULE__{cleanup_timer: timer}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove old entries outside the window
    now = System.system_time(:second)
    # Keep 2x window for safety
    cutoff = now - @window_seconds * 2

    # Delete old entries
    :ets.select_delete(@table_name, [
      {{{:_, :_, :"$1"}, :_}, [{:<, :"$1", cutoff}], [true]}
    ])

    # Schedule next cleanup
    timer = Process.send_after(self(), :cleanup, @cleanup_interval_ms)

    {:noreply, %{state | cleanup_timer: timer}}
  end

  ## Private Helpers

  defp count_operations(operation, type, window_start, window_end) do
    :ets.select_count(@table_name, [
      {
        {{operation, type, :"$1"}, :_},
        [{:andalso, {:>=, :"$1", window_start}, {:"=<", :"$1", window_end}}],
        [true]
      }
    ])
  end

  defp extract_error_type(error) when is_exception(error) do
    error.__struct__
  end

  defp extract_error_type(error) when is_atom(error) do
    error
  end

  defp extract_error_type(%{type: type}) do
    type
  end

  defp extract_error_type(_error) do
    :unknown
  end

  defp check_alert_threshold(operation) do
    rate_info = get_rate(operation)

    if rate_info.total_count >= 10 && rate_info.error_rate >= @alert_threshold do
      SASL.critical_failure(
        :high_error_rate_alert,
        "High error rate detected for operation",
        operation: operation,
        error_rate: Float.round(rate_info.error_rate * 100, 2),
        error_count: rate_info.error_count,
        total_count: rate_info.total_count
      )

      # Send alert to Google Chat webhook
      send_alert(operation, rate_info)
    end
  end

  defp send_alert(operation, rate_info) do
    webhook_url = Application.get_env(:singularity, :google_chat_webhook_url)

    if webhook_url do
      send_google_chat_alert(webhook_url, operation, rate_info)
    else
      Logger.warning(
        "Google Chat webhook not configured - would send alert for high error rate",
        operation: operation,
        error_rate: rate_info.error_rate
      )
    end
  end

  defp send_google_chat_alert(webhook_url, operation, rate_info) do
    message = %{
      text: "🚨 High Error Rate Alert",
      cards: [
        %{
          header: %{
            title: "Singularity Error Alert",
            subtitle: "High error rate detected"
          },
          sections: [
            %{
              widgets: [
                %{
                  keyValue: %{
                    topLabel: "Operation",
                    content: to_string(operation)
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Error Rate",
                    content: "#{Float.round(rate_info.error_rate * 100, 2)}%"
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Error Count",
                    content: "#{rate_info.error_count}/#{rate_info.total_count}"
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Time Window",
                    content: "#{@window_seconds} seconds"
                  }
                }
              ]
            }
          ]
        }
      ]
    }

    case Req.post(webhook_url, json: message) do
      {:ok, %{status: 200}} ->
        Logger.info("Error alert sent to Google Chat", operation: operation)

      {:ok, %{status: status}} ->
        Logger.warning("Failed to send Google Chat alert", status: status)

      {:error, reason} ->
        Logger.error("Error sending Google Chat alert", reason: reason)
    end
  end
end
