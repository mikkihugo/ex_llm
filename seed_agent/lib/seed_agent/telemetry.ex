defmodule SeedAgent.Telemetry do
  @moduledoc false
  use Supervisor

  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      [poller_child()]
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      summary("seed_agent.hot_reload.duration", unit: {:native, :millisecond})
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__.Measurements, :report_vm_stats, []}
    ]
  end

  defp poller_child do
    if Code.ensure_loaded?(Telemetry.Poller) do
      {Telemetry.Poller, measurements: periodic_measurements(), period: 10_000}
    end
  end

  defmodule Measurements do
    @moduledoc false

    def report_vm_stats do
      :telemetry.execute([:vm, :memory, :total], %{total: :erlang.memory(:total)}, %{})
    end
  end
end
