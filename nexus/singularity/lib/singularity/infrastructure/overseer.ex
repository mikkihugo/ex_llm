defmodule Singularity.Infrastructure.Overseer do
  @moduledoc """
  Overseer for the QuantumFlow architecture.

  This GenServer periodically inspects the health of our critical runtime components:

    * PostgreSQL/PGMQ (backbone for queues and storage)
    * QuantumFlow workflow supervisors (architecture + embedding pipelines)
    * HTTP health server used by container orchestration

  The original Overseer in the pre-QuantumFlow branch also managed NATS. Those hooks have been
  replaced with QuantumFlow-oriented checks in this port. The goal is to preserve the pattern –
  a single module that centralises operational visibility – while aligning with the current
  topology.
  """

  use GenServer
  require Logger

  alias Singularity.Infrastructure.PidManager
  alias Singularity.Repo

  @monitor_interval :timer.seconds(5)
  @postgres_port 5432
  @health_server_module Singularity.Health.HttpServer
  @workflow_supervisors [
    architecture: ArchitectureLearningWorkflowSupervisor,
    embedding: EmbeddingTrainingWorkflowSupervisor
  ]

  # ----------------------------------------------------------------------------
  # Client API
  # ----------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ----------------------------------------------------------------------------
  # GenServer callbacks
  # ----------------------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting Overseer (QuantumFlow edition)")

    # Adopt healthy PostgreSQL if it is already running (keeps dev flows fast)
    PidManager.manage_service(:postgres, @postgres_port)

    state = compose_status(%{})
    :timer.send_interval(@monitor_interval, :health_check)

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_info(:health_check, state) do
    new_state = compose_status(state)
    {:noreply, new_state}
  end

  # ----------------------------------------------------------------------------
  # Internal helpers
  # ----------------------------------------------------------------------------

  defp compose_status(previous_state) do
    database = check_database()
    quantum_flow = check_quantum_flow()
    health_server = check_health_server()

    overall =
      cond do
        database.status != :ok -> :critical
        quantum_flow.status == :critical -> :critical
        quantum_flow.status == :degraded || health_server.status != :ok -> :degraded
        true -> :ok
      end

    %{
      database: database,
      quantum_flow: quantum_flow,
      health_server: health_server,
      adopted_postgres: PidManager.get_adopted(:postgres),
      overall: overall,
      last_check_at: DateTime.utc_now(),
      previous: Map.take(previous_state, [:database, :quantum_flow, :health_server, :overall])
    }
  end

  defp check_database do
    result =
      try do
        case Repo.query("SELECT 1") do
          {:ok, _} -> {:ok, :connected}
          {:error, reason} -> {:error, {:query_failed, inspect(reason)}}
        end
      rescue
        error -> {:error, {:exception, Exception.message(error)}}
      end

    status = if match?({:ok, _}, result), do: :ok, else: :error

    %{status: status, detail: result}
  end

  defp check_quantum_flow do
    loaded? = Code.ensure_loaded?(QuantumFlow.WorkflowSupervisor)

    supervisors =
      Enum.map(@workflow_supervisors, fn {key, name} ->
        pid = Process.whereis(name)
        status = if is_pid(pid), do: :ok, else: :not_running

        {key, %{status: status, pid: pid}}
      end)
      |> Enum.into(%{})

    status =
      cond do
        not loaded? -> :unknown
        Enum.all?(supervisors, fn {_k, %{status: s}} -> s == :ok end) -> :ok
        Enum.any?(supervisors, fn {_k, %{status: :ok}} -> true; _ -> false end) -> :degraded
        true -> :critical
      end

    %{status: status, supervisors: supervisors, loaded?: loaded?}
  end

  defp check_health_server do
    pid = Process.whereis(@health_server_module)

    status =
      cond do
        is_pid(pid) and Process.alive?(pid) -> :ok
        is_pid(pid) -> :degraded
        true -> :not_running
      end

    %{status: status, pid: pid}
  end
end
