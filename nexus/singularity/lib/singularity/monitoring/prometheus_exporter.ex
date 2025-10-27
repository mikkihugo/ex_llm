defmodule Singularity.Monitoring.PrometheusExporter do
  @moduledoc false

  @doc """
  Render a minimal Prometheus text exposition with a few runtime metrics.
  """
  def render do
    stats = Singularity.Infrastructure.Telemetry.snapshot()

    memory = Map.get(stats, :memory, 0)
    runq = Map.get(stats, :run_queue, 0)

    [
      "# HELP singularity_memory_bytes Total memory used by the BEAM in bytes",
      "# TYPE singularity_memory_bytes gauge",
      "singularity_memory_bytes #{memory}",
      "# HELP singularity_run_queue_total Total scheduler run queue length",
      "# TYPE singularity_run_queue_total gauge",
      "singularity_run_queue_total #{runq}"
    ]
    |> Enum.join("\n")
  end
end
