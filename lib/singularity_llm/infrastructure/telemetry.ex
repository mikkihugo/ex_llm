defmodule SingularityLLM.Infrastructure.Telemetry do
  @moduledoc """
  Telemetry instrumentation for SingularityLLM.

  This module provides telemetry event definitions and helpers for instrumenting
  SingularityLLM operations. It follows the standard `:telemetry` conventions and can be
  integrated with various observability backends.

  ## Event Structure

  All events follow the pattern: `[:singularity_llm, :component, :operation, :phase]`

  Where phase is one of: `:start`, `:stop`, `:exception`

  ## Integration Options

  1. **Logging**: Attach handlers to log events
  2. **Metrics**: Use `SingularityLLM.Infrastructure.Telemetry.Metrics` with `telemetry_metrics`
  3. **Tracing**: Use `SingularityLLM.Infrastructure.Telemetry.OpenTelemetry` for distributed tracing

  ## Example

      # Attach a simple logger
      :telemetry.attach(
        "log-llm-requests",
        [:singularity_llm, :chat, :stop],
        &MyApp.handle_event/4,
        nil
      )
  """

  alias SingularityLLM.Infrastructure.Logger

  # Suppress telemetry warnings at compile time
  @compile {:no_warn_undefined, [:telemetry]}

  @doc """
  Safely execute telemetry events, suppressing warnings if telemetry is not started.

  This wrapper prevents the "Failed to lookup telemetry handlers" warning that can
  occur during early application startup or in test environments.
  """
  def safe_execute(event, measurements, metadata) do
    try do
      :telemetry.execute(event, measurements, metadata)
    rescue
      # Suppress the specific ArgumentError about telemetry handlers
      ArgumentError ->
        # Silently ignore if telemetry application is not started
        :ok
    catch
      # Also catch any exit signals related to telemetry
      :exit, _ ->
        :ok
    end
  end

  # Event definitions organized by component
  @chat_events [
    [:singularity_llm, :chat, :start],
    [:singularity_llm, :chat, :stop],
    [:singularity_llm, :chat, :exception]
  ]

  @embedding_events [
    [:singularity_llm, :embedding, :start],
    [:singularity_llm, :embedding, :stop],
    [:singularity_llm, :embedding, :exception]
  ]

  @streaming_events [
    [:singularity_llm, :stream, :start],
    [:singularity_llm, :stream, :chunk],
    [:singularity_llm, :stream, :stop],
    [:singularity_llm, :stream, :exception]
  ]

  @provider_events [
    [:singularity_llm, :provider, :request, :start],
    [:singularity_llm, :provider, :request, :stop],
    [:singularity_llm, :provider, :request, :exception],
    [:singularity_llm, :provider, :auth, :refresh],
    [:singularity_llm, :provider, :rate_limit]
  ]

  @session_events [
    [:singularity_llm, :session, :created],
    [:singularity_llm, :session, :message_added],
    [:singularity_llm, :session, :token_usage_updated],
    [:singularity_llm, :session, :truncated],
    [:singularity_llm, :session, :cleared]
  ]

  @context_events [
    [:singularity_llm, :context, :truncation, :start],
    [:singularity_llm, :context, :truncation, :stop],
    [:singularity_llm, :context, :window_exceeded]
  ]

  @cost_events [
    [:singularity_llm, :cost, :calculated],
    [:singularity_llm, :cost, :threshold_exceeded]
  ]

  @cache_events [
    [:singularity_llm, :cache, :hit],
    [:singularity_llm, :cache, :miss],
    [:singularity_llm, :cache, :put],
    [:singularity_llm, :cache, :evicted]
  ]

  @test_cache_events [
    [:singularity_llm, :test_cache, :hit],
    [:singularity_llm, :test_cache, :miss],
    [:singularity_llm, :test_cache, :save],
    [:singularity_llm, :test_cache, :error]
  ]

  @http_events [
    [:singularity_llm, :http, :request, :start],
    [:singularity_llm, :http, :request, :stop],
    [:singularity_llm, :http, :request, :exception]
  ]

  @doc """
  Returns all telemetry event names.
  """
  def events do
    @chat_events ++
      @embedding_events ++
      @streaming_events ++
      @provider_events ++
      @session_events ++
      @context_events ++
      @cost_events ++
      @cache_events ++
      @test_cache_events ++
      @http_events
  end

  @doc """
  Execute a function and emit telemetry events.

  This is the core instrumentation helper that emits start/stop/exception events
  and measures duration automatically.

  ## Options

  - `:telemetry_metadata` - Additional metadata to include in events
  - `:telemetry_options` - Options like sampling rate

  ## Example

      span([:singularity_llm, :chat], %{model: "gpt-4"}, fn ->
        # Your code here
        {:ok, result}
      end)
  """
  def span(event_prefix, metadata \\ %{}, fun)
      when is_list(event_prefix) and is_function(fun, 0) do
    start_time = System.monotonic_time()
    start_metadata = Map.put(metadata, :system_time, System.system_time())

    safe_execute(event_prefix ++ [:start], %{system_time: start_time}, start_metadata)

    try do
      result = fun.()
      duration = System.monotonic_time() - start_time

      stop_metadata = enrich_metadata(metadata, result, duration)

      safe_execute(
        event_prefix ++ [:stop],
        %{duration: duration},
        stop_metadata
      )

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time
        kind = :error
        reason = exception
        stacktrace = __STACKTRACE__

        exception_metadata =
          metadata
          |> Map.put(:duration, duration)
          |> Map.put(:kind, kind)
          |> Map.put(:reason, reason)
          |> Map.put(:stacktrace, stacktrace)

        safe_execute(
          event_prefix ++ [:exception],
          %{duration: duration},
          exception_metadata
        )

        reraise exception, stacktrace
    catch
      kind, reason ->
        duration = System.monotonic_time() - start_time
        stacktrace = __STACKTRACE__

        exception_metadata =
          metadata
          |> Map.put(:duration, duration)
          |> Map.put(:kind, kind)
          |> Map.put(:reason, reason)
          |> Map.put(:stacktrace, stacktrace)

        safe_execute(
          event_prefix ++ [:exception],
          %{duration: duration},
          exception_metadata
        )

        :erlang.raise(kind, reason, stacktrace)
    end
  end

  @doc """
  Attach a basic logger handler for debugging.

  This is useful during development to see all telemetry events.
  """
  def attach_default_logger(level \\ :debug) do
    # Check if telemetry is available before trying to attach
    if Code.ensure_loaded?(:telemetry) and function_exported?(:telemetry, :attach_many, 4) do
      events = events()

      try do
        :telemetry.attach_many(
          "ex-llm-default-logger",
          events,
          &handle_event/4,
          %{log_level: level}
        )
      rescue
        ArgumentError ->
          # Telemetry application not started yet, ignore
          :ok
      end
    else
      :ok
    end
  end

  @doc """
  Detach the default logger.
  """
  def detach_default_logger do
    :telemetry.detach("ex-llm-default-logger")
  end

  # Private functions

  defp enrich_metadata(metadata, result, duration) do
    metadata
    |> Map.put(:duration_ms, System.convert_time_unit(duration, :native, :millisecond))
    |> maybe_add_usage(result)
    |> maybe_add_cost(result)
  end

  defp maybe_add_usage(metadata, {:ok, %{usage: usage}}) when is_map(usage) do
    Map.merge(metadata, %{
      input_tokens: Map.get(usage, :input_tokens),
      output_tokens: Map.get(usage, :output_tokens),
      total_tokens: Map.get(usage, :total_tokens)
    })
  end

  defp maybe_add_usage(metadata, _), do: metadata

  defp maybe_add_cost(metadata, {:ok, %{cost: cost}}) when is_map(cost) do
    Map.put(metadata, :cost_cents, Map.get(cost, :total_cents))
  end

  defp maybe_add_cost(metadata, _), do: metadata

  defp handle_event(event, measurements, metadata, config) do
    level = Map.get(config, :log_level, :debug)

    event_name = event |> Enum.join(".")

    message =
      case List.last(event) do
        :start ->
          "#{event_name} started"

        :stop ->
          "#{event_name} completed in #{measurements[:duration] |> System.convert_time_unit(:native, :millisecond)}ms"

        :exception ->
          "#{event_name} failed: #{inspect(metadata[:reason])}"

        :chunk ->
          "#{event_name} chunk received"

        _ ->
          "#{event_name}"
      end

    Logger.log(level, message, metadata)
  end

  @doc """
  Helper to emit cache events.
  """
  def emit_cache_hit(key) do
    :telemetry.execute([:singularity_llm, :cache, :hit], %{}, %{key: key})
  end

  def emit_cache_miss(key) do
    :telemetry.execute([:singularity_llm, :cache, :miss], %{}, %{key: key})
  end

  def emit_cache_put(key, size_bytes) do
    :telemetry.execute([:singularity_llm, :cache, :put], %{size_bytes: size_bytes}, %{key: key})
  end

  @doc """
  Helper to emit test cache events.
  """
  def emit_test_cache_hit(cache_key, metadata \\ %{}) do
    :telemetry.execute(
      [:singularity_llm, :test_cache, :hit],
      %{cache_type: :test},
      Map.merge(%{cache_key: cache_key}, metadata)
    )
  end

  def emit_test_cache_miss(cache_key, metadata \\ %{}) do
    :telemetry.execute(
      [:singularity_llm, :test_cache, :miss],
      %{cache_type: :test},
      Map.merge(%{cache_key: cache_key}, metadata)
    )
  end

  def emit_test_cache_save(cache_key, size_bytes, metadata \\ %{}) do
    :telemetry.execute(
      [:singularity_llm, :test_cache, :save],
      %{size_bytes: size_bytes, cache_type: :test},
      Map.merge(%{cache_key: cache_key}, metadata)
    )
  end

  def emit_test_cache_error(cache_key, error, metadata \\ %{}) do
    :telemetry.execute(
      [:singularity_llm, :test_cache, :error],
      %{cache_type: :test},
      Map.merge(%{cache_key: cache_key, error: error}, metadata)
    )
  end

  @doc """
  Helper to emit cost events.
  """
  def emit_cost_calculated(provider, model, cost_cents) do
    :telemetry.execute(
      [:singularity_llm, :cost, :calculated],
      %{cost: cost_cents},
      %{provider: provider, model: model}
    )
  end

  def emit_cost_threshold_exceeded(cost_cents, threshold_cents) do
    :telemetry.execute(
      [:singularity_llm, :cost, :threshold_exceeded],
      %{cost: cost_cents, threshold: threshold_cents},
      %{exceeded_by: cost_cents - threshold_cents}
    )
  end

  @doc """
  Helper for streaming events.
  """
  def emit_stream_start(provider, model) do
    :telemetry.execute(
      [:singularity_llm, :stream, :start],
      %{system_time: System.system_time()},
      %{provider: provider, model: model}
    )
  end

  def emit_stream_chunk(provider, model, chunk_size) do
    :telemetry.execute(
      [:singularity_llm, :stream, :chunk],
      %{size: chunk_size},
      %{provider: provider, model: model}
    )
  end

  def emit_stream_complete(provider, model, total_chunks, duration) do
    :telemetry.execute(
      [:singularity_llm, :stream, :stop],
      %{duration: duration, chunks: total_chunks},
      %{provider: provider, model: model}
    )
  end
end
