defmodule Singularity.Telemetry do
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
      # VM Metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),

      # LLM Metrics
      counter("singularity.llm.request.count", tags: [:complexity, :task_type, :model]),
      counter("singularity.llm.request.cost_usd",
        event_name: [:singularity, :llm, :request, :stop],
        measurement: :cost_usd,
        tags: [:complexity, :task_type, :model]
      ),
      summary("singularity.llm.request.duration",
        event_name: [:singularity, :llm, :request, :stop],
        measurement: :duration,
        tags: [:complexity, :task_type, :model],
        unit: {:native, :millisecond}
      ),
      counter("singularity.llm.cache.hit", tags: [:type]),
      counter("singularity.llm.cache.miss", tags: [:type]),

      # Agent Metrics
      counter("singularity.agent.spawn.count", tags: [:agent_type]),
      counter("singularity.agent.task.count", tags: [:agent_type, :status]),
      summary("singularity.agent.task.duration",
        event_name: [:singularity, :agent, :task, :stop],
        measurement: :duration,
        tags: [:agent_type, :status],
        unit: {:native, :millisecond}
      ),
      last_value("singularity.agent.active.count", tags: [:agent_type]),

      # NATS Metrics
      counter("singularity.nats.message.count", tags: [:subject, :direction]),
      summary("singularity.nats.message.size",
        event_name: [:singularity, :nats, :message, :stop],
        measurement: :size_bytes,
        tags: [:subject, :direction],
        unit: :byte
      ),

      # Tool Execution Metrics
      counter("singularity.tool.execution.count", tags: [:tool, :codebase_id, :result]),
      summary("singularity.tool.execution.duration",
        event_name: [:singularity, :tool, :execution, :stop],
        measurement: :duration_ms,
        tags: [:tool, :codebase_id, :result],
        unit: :millisecond
      ),
      counter("singularity.tool.error.count", tags: [:tool, :error_type]),

      # Existing metrics
      summary("singularity.hot_reload.duration", unit: {:native, :millisecond}),
      summary("singularity.code_generator.generate.duration",
        event_name: [:singularity, :code_generator, :generate, :stop],
        measurement: :duration,
        tags: [:operation, :model, :status],
        unit: {:native, :millisecond}
      ),
      counter("singularity.code_generator.generate.count",
        event_name: [:singularity, :code_generator, :generate, :stop],
        measurement: fn _ -> 1 end,
        tags: [:operation, :model, :status]
      ),
      summary("singularity.code_synthesis_pipeline.generate.duration",
        event_name: [:singularity, :code_synthesis_pipeline, :generate, :stop],
        measurement: :duration,
        tags: [:language, :repo, :fast_mode, :status],
        unit: {:native, :millisecond}
      ),
      counter("singularity.code_synthesis_pipeline.generate.count",
        event_name: [:singularity, :code_synthesis_pipeline, :generate, :stop],
        measurement: fn _ -> 1 end,
        tags: [:language, :repo, :fast_mode, :status]
      ),
      counter("singularity.improvement.attempt.count", tags: [:agent_id, :source]),
      counter("singularity.improvement.queued.count", tags: [:agent_id]),
      counter("singularity.improvement.rate_limited.count", tags: [:agent_id]),
      counter("singularity.improvement.success.count", tags: [:agent_id]),
      counter("singularity.improvement.failure.count", tags: [:agent_id]),
      counter("singularity.improvement.duplicate.count", tags: [:agent_id]),
      counter("singularity.improvement.invalid.count", tags: [:agent_id]),
      counter("singularity.improvement.validation.success.count", tags: [:agent_id]),
      counter("singularity.improvement.validation.failure.count", tags: [:agent_id]),
      counter("singularity.improvement.rollback.count", tags: [:agent_id]),
      last_value("singularity.improvement.queue_depth", tags: [:agent_id])
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

  @doc """
  Get current metrics for external consumption (health checks, dashboard).

  Returns a map with:
  - VM stats (memory, processes, schedulers)
  - Agent stats (active count, total spawned)
  - LLM stats (total requests, cost, cache hit rate)
  - NATS stats (message throughput)
  """
  @spec get_metrics() :: map()
  def get_metrics do
    %{
      vm: vm_metrics(),
      agents: agent_metrics(),
      llm: llm_metrics(),
      nats: nats_metrics(),
      tools: tool_metrics(),
      timestamp: DateTime.utc_now()
    }
  end

  defp vm_metrics do
    memory = :erlang.memory()

    %{
      memory_total_mb: div(memory[:total], 1_024 * 1_024),
      memory_processes_mb: div(memory[:processes], 1_024 * 1_024),
      memory_ets_mb: div(memory[:ets], 1_024 * 1_024),
      process_count: :erlang.system_info(:process_count),
      scheduler_count: :erlang.system_info(:schedulers_online),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    }
  end

  defp agent_metrics do
    # Count active agents from DynamicSupervisor
    active_count =
      case Process.whereis(Singularity.Agents.AgentSupervisor) do
        nil ->
          0

        pid ->
          pid
          |> DynamicSupervisor.count_children()
          |> Map.get(:active, 0)
      end

    %{
      active_count: active_count,
      total_spawned: get_counter_value([:singularity, :agent, :spawn, :count])
    }
  end

  defp llm_metrics do
    total_requests = get_counter_value([:singularity, :llm, :request, :count])
    cache_hits = get_counter_value([:singularity, :llm, :cache, :hit])
    cache_misses = get_counter_value([:singularity, :llm, :cache, :miss])

    cache_hit_rate =
      if cache_hits + cache_misses > 0 do
        Float.round(cache_hits / (cache_hits + cache_misses), 2)
      else
        0.0
      end

    %{
      total_requests: total_requests,
      cache_hit_rate: cache_hit_rate,
      cache_hits: cache_hits,
      cache_misses: cache_misses,
      total_cost_usd: get_counter_value([:singularity, :llm, :request, :cost_usd])
    }
  end

  defp nats_metrics do
    %{
      messages_sent: get_counter_value([:singularity, :nats, :message, :count], %{direction: :send}),
      messages_received:
        get_counter_value([:singularity, :nats, :message, :count], %{direction: :receive})
    }
  end

  @doc """
  Log tool execution for auditing and metrics.

  Records:
  - Tool execution count and result (success/error)
  - Execution duration
  - Codebase accessed
  - Error types for failed executions

  ## Examples

      Telemetry.log_tool_execution(%{
        subject: "tools.code.get",
        codebase_id: "singularity",
        result: :success,
        duration_ms: 45
      })
  """
  @spec log_tool_execution(map()) :: :ok
  def log_tool_execution(%{subject: subject, codebase_id: codebase_id, result: result, duration_ms: duration_ms} = params) do
    # Extract tool name from subject (e.g., "tools.code.get" -> "code.get")
    tool = subject |> String.split(".") |> Enum.drop(1) |> Enum.join(".")

    # Emit telemetry events
    :telemetry.execute(
      [:singularity, :tool, :execution, :count],
      %{count: 1},
      %{tool: tool, codebase_id: codebase_id, result: result}
    )

    :telemetry.execute(
      [:singularity, :tool, :execution, :stop],
      %{duration_ms: duration_ms},
      %{tool: tool, codebase_id: codebase_id, result: result}
    )

    # Log errors separately for better tracking
    if result == :error do
      error_type = Map.get(params, :error_type, "unknown")

      :telemetry.execute(
        [:singularity, :tool, :error, :count],
        %{count: 1},
        %{tool: tool, error_type: error_type}
      )
    end

    :ok
  end

  defp tool_metrics do
    total_executions = get_counter_value([:singularity, :tool, :execution, :count])
    total_errors = get_counter_value([:singularity, :tool, :error, :count])

    success_rate =
      if total_executions > 0 do
        Float.round((total_executions - total_errors) / total_executions, 2)
      else
        0.0
      end

    %{
      total_executions: total_executions,
      total_errors: total_errors,
      success_rate: success_rate
    }
  end

  # Helper to get counter values from telemetry
  # Note: This is a simplified version - in production you'd use a proper metrics store
  defp get_counter_value(_event_name, _tags \\ %{}) do
    # TODO: Integrate with proper metrics backend (StatsD, Prometheus, etc.)
    # For now, return 0 as placeholder
    0
  end
end
