defmodule Singularity.Infrastructure.ErrorHandling do
  @moduledoc """
  Centralized Production-Ready Error Handling Infrastructure

  Provides:
  - Structured error logging with correlation IDs
  - Telemetry events for monitoring
  - Circuit breaker for external services
  - Retry logic with exponential backoff
  - Error rate tracking and alerting
  - Graceful degradation helpers
  - OpenTelemetry/AppSignal integration

  ## Usage

      use Singularity.Infrastructure.ErrorHandling

      # Wrap operations with structured error handling
      safe_operation(fn ->
        dangerous_work()
      end, context: %{operation: :search, user_id: 123})

      # Retry with exponential backoff
      with_retry(fn -> api_call() end, max_attempts: 3)

      # Circuit breaker for external APIs
      with_circuit_breaker(:google_api, fn ->
        Google.API.call()
      end)
  """

  require Logger

  @type error_context :: %{
          optional(:operation) => atom(),
          optional(:module) => module(),
          optional(:correlation_id) => String.t(),
          optional(:user_id) => term(),
          optional(atom()) => term()
        }

  @type retry_opts :: [
          max_attempts: pos_integer(),
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer(),
          exponential_base: number(),
          jitter: boolean()
        ]

  @type circuit_breaker_opts :: [
          failure_threshold: pos_integer(),
          timeout_ms: pos_integer(),
          reset_timeout_ms: pos_integer()
        ]

  defmacro __using__(_opts) do
    quote do
      require Logger
      import Singularity.Infrastructure.ErrorHandling
      alias Singularity.Infrastructure.ErrorHandling
    end
  end

  ## Structured Error Handling

  @doc """
  Wrap an operation with comprehensive error handling.

  Automatically:
  - Sets correlation ID
  - Logs start/completion/errors
  - Emits telemetry events
  - Tracks duration
  - Captures stack traces

  ## Examples

      safe_operation(fn ->
        Database.query("SELECT * FROM users")
      end, context: %{operation: :query_users, module: __MODULE__})

      # Returns: {:ok, result} | {:error, %ErrorHandling.Error{}}
  """
  def safe_operation(fun, opts \\ []) when is_function(fun, 0) do
    context = Keyword.get(opts, :context, %{})
    correlation_id = Map.get(context, :correlation_id, generate_correlation_id())

    full_context = Map.merge(context, %{correlation_id: correlation_id})

    Logger.metadata(
      correlation_id: correlation_id,
      operation: Map.get(full_context, :operation),
      module: Map.get(full_context, :module)
    )

    start_time = System.monotonic_time(:millisecond)

    Logger.debug("Operation started", full_context)

    result =
      try do
        result = fun.()
        {:ok, result}
      rescue
        error ->
          stacktrace = __STACKTRACE__
          handle_error(error, stacktrace, full_context, start_time)
      catch
        :exit, reason ->
          handle_exit(reason, full_context, start_time)

        :throw, value ->
          handle_throw(value, full_context, start_time)
      end

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, value} ->
        Logger.debug(
          "Operation completed successfully",
          Map.merge(full_context, %{duration_ms: duration})
        )

        emit_telemetry(:success, full_context, %{duration: duration})
        {:ok, value}

      {:error, error} ->
        Logger.error(
          "Operation failed",
          Map.merge(full_context, %{
            duration_ms: duration,
            error: inspect(error)
          })
        )

        emit_telemetry(:error, full_context, %{duration: duration})
        {:error, error}
    end
  end

  ## Retry Logic

  @doc """
  Retry an operation with exponential backoff.

  ## Options

  - `max_attempts` - Maximum retry attempts (default: 3)
  - `base_delay_ms` - Initial delay in milliseconds (default: 100)
  - `max_delay_ms` - Maximum delay in milliseconds (default: 10000)
  - `exponential_base` - Exponential backoff multiplier (default: 2)
  - `jitter` - Add random jitter to delays (default: true)
  - `retryable_errors` - List of retryable error types (default: [:timeout, :connection_error])

  ## Examples

      with_retry(fn ->
        HTTPoison.get("https://api.example.com/data")
      end, max_attempts: 5, base_delay_ms: 200)
  """
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 100)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, 10_000)
    exponential_base = Keyword.get(opts, :exponential_base, 2)
    jitter = Keyword.get(opts, :jitter, true)

    retryable_errors =
      Keyword.get(opts, :retryable_errors, [
        :timeout,
        :connection_error,
        :postgrex_connection_error
      ])

    do_retry(
      fun,
      1,
      max_attempts,
      base_delay_ms,
      max_delay_ms,
      exponential_base,
      jitter,
      retryable_errors
    )
  end

  defp do_retry(
         fun,
         attempt,
         max_attempts,
         base_delay,
         max_delay,
         exp_base,
         jitter,
         retryable_errors
       ) do
    case safe_operation(fun, context: %{attempt: attempt, max_attempts: max_attempts}) do
      {:ok, result} ->
        if attempt > 1 do
          Logger.info("Operation succeeded after retry", attempt: attempt)
        end

        {:ok, result}

      {:error, error} when attempt < max_attempts ->
        if is_retryable?(error, retryable_errors) do
          delay = calculate_delay(attempt, base_delay, max_delay, exp_base, jitter)

          Logger.warninging("Operation failed, retrying",
            attempt: attempt,
            max_attempts: max_attempts,
            delay_ms: delay,
            error: inspect(error)
          )

          Process.sleep(delay)

          do_retry(
            fun,
            attempt + 1,
            max_attempts,
            base_delay,
            max_delay,
            exp_base,
            jitter,
            retryable_errors
          )
        else
          Logger.error("Operation failed with non-retryable error", error: inspect(error))
          {:error, error}
        end

      {:error, error} ->
        Logger.error("Operation failed after all retry attempts",
          attempts: max_attempts,
          error: inspect(error)
        )

        {:error, error}
    end
  end

  defp is_retryable?(error, retryable_errors) do
    cond do
      is_atom(error) -> error in retryable_errors
      is_exception(error) -> error.__struct__ in retryable_errors
      is_map(error) && Map.has_key?(error, :type) -> error.type in retryable_errors
      true -> false
    end
  end

  defp calculate_delay(attempt, base_delay, max_delay, exponential_base, jitter) do
    # Exponential backoff: base_delay * (exponential_base ^ (attempt - 1))
    delay = base_delay * :math.pow(exponential_base, attempt - 1)
    delay = min(delay, max_delay)

    if jitter do
      # Add random jitter (±25%)
      jitter_range = delay * 0.25
      delay + :rand.uniform() * jitter_range - jitter_range / 2
    else
      delay
    end
    |> round()
  end

  ## Circuit Breaker

  @doc """
  Execute operation with circuit breaker protection.

  Circuit breaker states:
  - :closed - Normal operation
  - :open - Failing, reject requests immediately
  - :half_open - Testing if service recovered

  ## Options

  - `failure_threshold` - Failures before opening circuit (default: 5)
  - `timeout_ms` - Operation timeout (default: 5000)
  - `reset_timeout_ms` - Time before attempting reset (default: 60000)

  ## Examples

      with_circuit_breaker(:external_api, fn ->
        ExternalAPI.call()
      end, failure_threshold: 3, timeout_ms: 3000)
  """
  def with_circuit_breaker(circuit_name, fun, opts \\ []) when is_function(fun, 0) do
    case Singularity.Infrastructure.CircuitBreaker.call(circuit_name, fun, opts) do
      {:ok, result} -> {:ok, result}
      {:error, :circuit_open} -> {:error, :service_unavailable}
      {:error, reason} -> {:error, reason}
    end
  end

  ## Timeout Handling

  @doc """
  Execute operation with timeout.

  ## Examples

      with_timeout(fn ->
        expensive_computation()
      end, timeout_ms: 5000)
  """
  def with_timeout(fun, opts \\ []) when is_function(fun, 0) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 30_000)

    task = Task.async(fun)

    try do
      result = Task.await(task, timeout_ms)
      {:ok, result}
    catch
      :exit, {:timeout, _} ->
        Logger.warninging("Operation timeout", timeout_ms: timeout_ms)
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  end

  ## Telemetry

  @doc """
  Emit telemetry event.

  Events are emitted as:
  [:singularity, :operation, :complete] with status in metadata.
  """
  def emit_telemetry(status, context, measurements) do
    event_name = [
      :singularity,
      Map.get(context, :module, :unknown) |> module_to_name(),
      Map.get(context, :operation, :execute),
      :complete
    ]

    metadata = Map.merge(context, %{status: status})

    :telemetry.execute(event_name, measurements, metadata)
  end

  defp module_to_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  ## Error Rate Tracking

  @doc """
  Track error rate for monitoring and alerting.

  Stores error counts in ETS for fast access.
  """
  def track_error_rate(operation, error) do
    Singularity.Infrastructure.ErrorRateTracker.record_error(operation, error)
  end

  def get_error_rate(operation) do
    Singularity.Infrastructure.ErrorRateTracker.get_rate(operation)
  end

  ## Graceful Degradation

  @doc """
  Return fallback value on error.

  ## Examples

      with_fallback(fn ->
        fetch_from_cache()
      end, default: [])
  """
  def with_fallback(fun, opts \\ []) when is_function(fun, 0) do
    default = Keyword.get(opts, :default)

    case safe_operation(fun, context: Keyword.get(opts, :context, %{})) do
      {:ok, result} -> result
      {:error, _error} -> default
    end
  end

  ## Health Check

  @doc """
  Health check for GenServer.

  Returns:
  - :healthy - All systems operational
  - {:degraded, reasons} - Partial functionality
  - {:unhealthy, reasons} - Critical failure
  """
  def health_check(_server, checks \\ []) do
    results =
      Enum.map(checks, fn {name, check_fun} ->
        case check_fun.() do
          :ok -> {name, :ok}
          {:ok, _} -> {name, :ok}
          {:error, reason} -> {name, {:error, reason}}
          :error -> {name, {:error, :unknown}}
        end
      end)

    failed = Enum.filter(results, fn {_, status} -> match?({:error, _}, status) end)

    cond do
      Enum.empty?(failed) -> :healthy
      length(failed) < length(checks) -> {:degraded, failed}
      true -> {:unhealthy, failed}
    end
  end

  ## Private Helpers

  defp handle_error(error, stacktrace, context, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time

    error_details = %{
      type: error.__struct__,
      message: Exception.message(error),
      stacktrace: Exception.format_stacktrace(stacktrace),
      duration_ms: duration
    }

    Logger.error(
      "Operation raised exception",
      Map.merge(context, error_details)
    )

    # Track error rate
    track_error_rate(Map.get(context, :operation, :unknown), error)

    # Report to external error tracker (Sentry/Honeybadger)
    report_to_error_tracker(error, stacktrace, context)

    wrapped_error = %{
      type: :exception,
      error: error,
      stacktrace: stacktrace,
      context: context
    }

    {:error, wrapped_error}
  end

  defp handle_exit(reason, context, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.error(
      "Operation exited",
      Map.merge(context, %{
        reason: inspect(reason),
        duration_ms: duration
      })
    )

    wrapped_error = %{
      type: :exit,
      reason: reason,
      context: context
    }

    {:error, wrapped_error}
  end

  defp handle_throw(value, context, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.error(
      "Operation threw value",
      Map.merge(context, %{
        value: inspect(value),
        duration_ms: duration
      })
    )

    wrapped_error = %{
      type: :throw,
      value: value,
      context: context
    }

    {:error, wrapped_error}
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp report_to_error_tracker(error, stacktrace, context) do
    # Report critical errors to Google Chat webhook
    webhook_url = Application.get_env(:singularity, :google_chat_webhook_url)

    if webhook_url do
      send_error_alert_to_google_chat(webhook_url, error, stacktrace, context)
    else
      Logger.debug("Google Chat webhook not configured - would report to error tracker",
        error: inspect(error),
        context: context
      )
    end
  end

  defp send_error_alert_to_google_chat(webhook_url, error, _stacktrace, context) do
    error_summary = extract_error_summary(error)

    message = %{
      text: "🚨 Critical Error Alert",
      cards: [
        %{
          header: %{
            title: "Singularity Error Report",
            subtitle: "Critical error detected"
          },
          sections: [
            %{
              widgets: [
                %{
                  keyValue: %{
                    topLabel: "Error Type",
                    content: error_summary.type
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Module",
                    content: to_string(context[:module] || "Unknown")
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Operation",
                    content: to_string(context[:operation] || "Unknown")
                  }
                },
                %{
                  keyValue: %{
                    topLabel: "Correlation ID",
                    content: context[:correlation_id] || "N/A"
                  }
                },
                %{
                  textParagraph: %{
                    text: "**Error Details:**\n```\n#{error_summary.message}\n```"
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
        Logger.info("Error alert sent to Google Chat",
          error_type: error_summary.type,
          correlation_id: context[:correlation_id]
        )

      {:ok, %{status: status}} ->
        Logger.warninging("Failed to send Google Chat error alert", status: status)

      {:error, reason} ->
        Logger.error("Error sending Google Chat alert", reason: reason)
    end
  end

  defp extract_error_summary(error) do
    case error do
      %{__struct__: struct} ->
        %{
          type: struct |> to_string() |> String.split(".") |> List.last(),
          message: inspect(error, limit: 200)
        }

      other ->
        %{
          type: "Unknown",
          message: inspect(other, limit: 200)
        }
    end
  end
end
