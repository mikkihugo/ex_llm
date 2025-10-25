defmodule Nexus.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will send measurements to the registered handlers
      {:telemetry_poller, [measurements: periodic_measurements(), period: 10_000]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Endpoint Metrics
      counter("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.exceptions.duration",
        tags: [:kind, :reason],
        unit: {:native, :millisecond}
      ),

      # Phoenix LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.cpu", unit: :integer),
      summary("vm.total_run_queue_lengths.io", unit: :integer)
    ]
  end

  defp periodic_measurements do
    [
      # vm metrics
      {:vm, :memory, []},
      {:vm, :total_run_queue_lengths, []}
    ]
  end
end
