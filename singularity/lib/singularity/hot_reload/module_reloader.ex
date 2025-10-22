defmodule Singularity.HotReload.ModuleReloader do
  @moduledoc """
  Coordinates validation, staging, and activation of new code artifacts.
  """
  use GenServer

  require Logger

  alias Singularity.{CodeStore, DynamicCompiler}

  @type queue_entry :: %{
          id: reference(),
          agent_id: String.t(),
          payload: map(),
          inserted_at: integer()
        }

  @max_queue_depth 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec enqueue(String.t(), map()) :: :ok | {:error, term()}
  def enqueue(agent_id, payload) when is_map(payload) do
    GenServer.call(__MODULE__, {:enqueue, agent_id, payload})
  end

  def queue_depth do
    GenServer.call(__MODULE__, :queue_depth)
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{queue: :queue.new(), inflight: nil}}
  end

  @impl true
  def handle_call({:enqueue, agent_id, payload}, _from, state) do
    current_depth = :queue.len(state.queue)

    if current_depth >= @max_queue_depth do
      {:reply, {:error, :queue_full}, state}
    else
      entry = %{
        id: make_ref(),
        agent_id: agent_id,
        payload: payload,
        inserted_at: System.system_time(:millisecond)
      }

      queue = :queue.in(entry, state.queue)
      new_state = %{state | queue: queue}
      Process.send(self(), :process, [])
      {:reply, :ok, new_state}
    end
  end

  def handle_call(:queue_depth, _from, state) do
    {:reply, :queue.len(state.queue), state}
  end

  @impl true
  def handle_info(:process, %{inflight: nil, queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, entry}, rest} ->
        :telemetry.execute(
          [:singularity, :hot_reload, :start],
          %{queue_depth: :queue.len(rest)},
          entry
        )

        Task.Supervisor.start_child(Singularity.TaskSupervisor, fn -> run_pipeline(entry) end)
        {:noreply, %{state | queue: rest, inflight: entry}}

      {:empty, _} ->
        {:noreply, state}
    end
  end

  def handle_info(:process, state), do: {:noreply, state}

  def handle_info({:pipeline_complete, entry_id, result}, state) do
    # Only process if this matches the current inflight entry
    if state.inflight && state.inflight.id == entry_id do
      case result do
        {:ok, version} ->
          send_agent(state.inflight.agent_id, {:reload_complete, version})

          :telemetry.execute(
            [:singularity, :hot_reload, :success],
            %{version: version},
            state.inflight
          )

        {:error, reason} ->
          Logger.error("Hot reload failed",
            agent_id: state.inflight.agent_id,
            reason: inspect(reason)
          )

          send_agent(state.inflight.agent_id, {:reload_failed, reason})

          :telemetry.execute(
            [:singularity, :hot_reload, :error],
            %{reason: inspect(reason)},
            state.inflight
          )
      end

      Process.send(self(), :process, [])
      {:noreply, %{state | inflight: nil}}
    else
      # Stale message, ignore
      {:noreply, state}
    end
  end

  defp run_pipeline(entry) do
    payload = Map.new(entry.payload)
    code = payload[:code] || payload["code"]

    {duration, result} =
      :timer.tc(fn ->
        with :ok <- require_code(code),
             :ok <- DynamicCompiler.validate(code),
             {:ok, staged_path} <-
               CodeStore.stage(entry.agent_id, next_version(entry.agent_id), code, payload),
             {:ok, active_path} <- CodeStore.promote(entry.agent_id, staged_path),
             {:ok, version} <- DynamicCompiler.compile_file(active_path) do
          {:ok, version}
        else
          {:error, _reason} = error -> error
          {:error, reason, _meta} -> {:error, reason}
          other -> {:error, other}
        end
      end)

    :telemetry.execute([:singularity, :hot_reload, :duration], %{duration: duration}, entry)

    send(__MODULE__, {:pipeline_complete, entry.id, result})
  end

  defp next_version(agent_id) do
    :erlang.phash2({agent_id, System.system_time()})
  end

  defp require_code(code) when is_binary(code) and byte_size(code) > 0, do: :ok
  defp require_code(_), do: {:error, :missing_code}

  defp send_agent(agent_id, message) do
    case Registry.lookup(Singularity.ProcessRegistry, {:agent, agent_id}) do
      [{pid, _}] -> send(pid, message)
      [] -> :ok
    end
  end
end
