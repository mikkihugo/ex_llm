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
      summary("seed_agent.hot_reload.duration", unit: {:native, :millisecond}),
      counter("seed_agent.improvement.attempt.count", tags: [:agent_id, :source]),
      counter("seed_agent.improvement.queued.count", tags: [:agent_id]),
      counter("seed_agent.improvement.rate_limited.count", tags: [:agent_id]),
      counter("seed_agent.improvement.success.count", tags: [:agent_id]),
      counter("seed_agent.improvement.failure.count", tags: [:agent_id]),
      counter("seed_agent.improvement.duplicate.count", tags: [:agent_id]),
      counter("seed_agent.improvement.invalid.count", tags: [:agent_id]),
      counter("seed_agent.improvement.validation.success.count", tags: [:agent_id]),
      counter("seed_agent.improvement.validation.failure.count", tags: [:agent_id]),
      counter("seed_agent.improvement.rollback.count", tags: [:agent_id]),
      last_value("seed_agent.improvement.queue_depth", tags: [:agent_id])
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

  @doc "Capture a lightweight snapshot of runtime stats for validation"
  @spec snapshot() :: %{memory: non_neg_integer(), run_queue: non_neg_integer()}
  def snapshot do
    memory = :erlang.memory(:total)

    run_queue =
      case :erlang.statistics(:total_run_queue_lengths) do
        {total, _cpu, _io} -> total
        total when is_integer(total) -> total
        _ -> 0
      end

    %{memory: memory, run_queue: run_queue}
  end
end
