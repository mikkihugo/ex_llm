defmodule ObserverWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    # Attach Phoenix LiveView telemetry handlers for SASL logging
    attach_liveview_handlers()
    
    # Attach SASL telemetry handlers for OTP error reports
    attach_sasl_handlers()

    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Note: SASL doesn't emit telemetry events - it writes directly to log files.
  # These handlers capture OTP error_logger events that SASL would normally log.
  # For actual SASL log reading, see Observer.Dashboard.SASLTrace which reads log files.
  defp attach_sasl_handlers do
    # Note: SASL reports are written to log files, not emitted as telemetry.
    # The trace viewer reads from log files directly.
    # These handlers are for any future OTP error_logger integration.
    :ok
  end

  # Attach Phoenix LiveView telemetry handlers for SASL logging
  defp attach_liveview_handlers do
    # LiveView mount events
    :telemetry.attach(
      "observer-liveview-mount",
      [:phoenix, :live_view, :mount, :start],
      &handle_liveview_mount_start/4,
      nil
    )

    :telemetry.attach(
      "observer-liveview-mount-stop",
      [:phoenix, :live_view, :mount, :stop],
      &handle_liveview_mount_stop/4,
      nil
    )

    # LiveView exception events
    :telemetry.attach(
      "observer-liveview-exception",
      [:phoenix, :live_view, :exception],
      &handle_liveview_exception/4,
      nil
    )

    # LiveView update events
    :telemetry.attach(
      "observer-liveview-update",
      [:phoenix, :live_view, :update],
      &handle_liveview_update/4,
      nil
    )

    # LiveView handle_event events
    :telemetry.attach(
      "observer-liveview-handle-event-start",
      [:phoenix, :live_view, :handle_event, :start],
      &handle_liveview_handle_event_start/4,
      nil
    )

    :telemetry.attach(
      "observer-liveview-handle-event-stop",
      [:phoenix, :live_view, :handle_event, :stop],
      &handle_liveview_handle_event_stop/4,
      nil
    )

    # LiveView render events
    :telemetry.attach(
      "observer-liveview-render",
      [:phoenix, :live_view, :render],
      &handle_liveview_render/4,
      nil
    )
  end

  # LiveView telemetry handlers
  defp handle_liveview_mount_start(_event, _measurements, metadata, _config) do
    Logger.debug("LiveView mount started",
      view: metadata.view,
      socket: inspect(metadata.socket.assigns, limit: :infinity),
      params: metadata.params
    )
  end

  defp handle_liveview_mount_stop(_event, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("LiveView mount completed",
      view: metadata.view,
      duration_ms: duration_ms
    )
  end

  defp handle_liveview_exception(_event, _measurements, metadata, _config) do
    Logger.error("LiveView exception",
      view: metadata.view,
      kind: metadata.kind,
      reason: inspect(metadata.reason, limit: :infinity),
      stacktrace: inspect(metadata.stacktrace, limit: 10)
    )
  end

  defp handle_liveview_update(_event, measurements, metadata, _config) do
    Logger.debug("LiveView update",
      view: metadata.view,
      diff_size: measurements.diff_size,
      components: measurements.components
    )
  end

  defp handle_liveview_handle_event_start(_event, _measurements, metadata, _config) do
    Logger.debug("LiveView handle_event started",
      view: metadata.view,
      event: metadata.event,
      params: metadata.params
    )
  end

  defp handle_liveview_handle_event_stop(_event, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("LiveView handle_event completed",
      view: metadata.view,
      event: metadata.event,
      duration_ms: duration_ms
    )
  end

  defp handle_liveview_render(_event, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.debug("LiveView render",
      view: metadata.view,
      duration_ms: duration_ms,
      components: measurements.components
    )
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("observer.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("observer.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("observer.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("observer.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("observer.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {ObserverWeb, :count_users, []}
    ]
  end
end
