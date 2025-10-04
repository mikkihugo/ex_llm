defmodule SeedAgent.CodeStore do
  @moduledoc """
  Persists generated code artifacts to disk for hot reload and version history.
  """
  use GenServer

  @type state :: %{
          root: String.t(),
          active: String.t(),
          versions: String.t(),
          queues: String.t()
        }

  # Keep versions for 7 days
  @version_ttl_hours 24 * 7
  # Run cleanup every 6 hours
  @cleanup_interval_ms :timer.hours(6)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def paths do
    GenServer.call(__MODULE__, :paths)
  end

  def stage(agent_id, version, code, metadata \\ %{}) when is_binary(code) do
    GenServer.call(__MODULE__, {:stage, agent_id, version, code, metadata})
  end

  def promote(agent_id, version_path) do
    GenServer.call(__MODULE__, {:promote, agent_id, version_path})
  end

  def load_queue(agent_id) when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:load_queue, agent_id})
  end

  def save_queue(agent_id, entries) when is_binary(agent_id) and is_list(entries) do
    GenServer.cast(__MODULE__, {:save_queue, agent_id, entries})
  end

  ## Server callbacks

  @impl true
  def init(_opts) do
    root = Path.expand(System.get_env("CODE_ROOT", "./code"))
    active = Path.join(root, "active")
    versions = Path.join(root, "versions")
    queues = Path.join(root, "queues")

    with :ok <- ensure_dir(active),
         :ok <- ensure_dir(versions),
         :ok <- ensure_dir(queues) do
      # Schedule first cleanup
      schedule_cleanup()
      {:ok, %{root: root, active: active, versions: versions, queues: queues}}
    else
      {:error, reason} ->
        {:stop, {:code_store_init_failed, reason}}
    end
  end

  @impl true
  def handle_call(:paths, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:stage, agent_id, version, code, metadata}, _from, state)
      when is_binary(code) and byte_size(code) > 0 do
    version_id =
      [agent_id, version, System.system_time(:millisecond)]
      |> Enum.join("-")

    version_file = Path.join(state.versions, "#{version_id}.exs")
    metadata_file = Path.rootname(version_file) <> ".json"

    with :ok <- File.write(version_file, code),
         {:ok, json} <- Jason.encode(Map.put(metadata, :version_id, version_id)),
         :ok <- File.write(metadata_file, json) do
      {:reply, {:ok, version_file}, state}
    else
      {:error, reason} ->
        # Cleanup partial write
        File.rm(version_file)
        File.rm(metadata_file)
        {:reply, {:error, {:stage_failed, reason}}, state}
    end
  end

  def handle_call({:stage, _agent_id, _version, _code, _metadata}, _from, state) do
    {:reply, {:error, :invalid_code}, state}
  end

  def handle_call({:promote, agent_id, version_path}, _from, state) do
    active_file = Path.join(state.active, "#{agent_id}.exs")

    case File.cp(version_path, active_file) do
      :ok ->
        {:reply, {:ok, active_file}, state}

      {:error, reason} ->
        {:reply, {:error, {:promote_failed, reason}}, state}
    end
  end

  def handle_call({:load_queue, agent_id}, _from, state) do
    queue_path = queue_path(state.queues, agent_id)

    queue =
      case File.read(queue_path) do
        {:ok, contents} ->
          case Jason.decode(contents) do
            {:ok, list} when is_list(list) ->
              list
              |> Enum.map(&map_to_queue_entry/1)
              |> Enum.reject(&is_nil/1)

            _ ->
              []
          end

        _ ->
          []
      end

    {:reply, queue, state}
  end

  @impl true
  def handle_cast({:save_queue, agent_id, entries}, state) when is_list(entries) do
    queue_path = queue_path(state.queues, agent_id)

    if entries == [] do
      File.rm(queue_path)
      {:noreply, state}
    else
      payload =
        entries
        |> Enum.map(&queue_entry_to_map/1)
        |> Enum.reject(&is_nil/1)
        |> Jason.encode!()

      :ok = File.write(queue_path, payload)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:cleanup_old_versions, state) do
    cleanup_old_versions(state.versions)
    schedule_cleanup()
    {:noreply, state}
  end

  defp queue_path(dir, agent_id), do: Path.join(dir, "#{agent_id}.json")

  defp queue_entry_to_map(%{
         payload: payload,
         context: context,
         inserted_at: inserted_at,
         fingerprint: fingerprint
       }) do
    %{
      "payload" => stringify_keys(payload),
      "context" => stringify_keys(context),
      "inserted_at" => inserted_at,
      "fingerprint" => fingerprint
    }
  end

  defp queue_entry_to_map(_), do: nil

  defp map_to_queue_entry(
         %{"payload" => payload, "context" => context, "inserted_at" => ts} = map
       )
       when is_integer(ts) do
    %{
      payload: payload,
      context: context,
      inserted_at: ts,
      fingerprint: Map.get(map, "fingerprint")
    }
  end

  defp map_to_queue_entry(_), do: nil

  defp ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp stringify_keys(%{} = map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
      {key, value} -> {to_string(key), stringify_keys(value)}
    end)
    |> Enum.into(%{})
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_versions, @cleanup_interval_ms)
  end

  defp cleanup_old_versions(versions_dir) do
    cutoff_time = System.system_time(:second) - @version_ttl_hours * 3600

    case File.ls(versions_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".exs"))
        |> Enum.each(&cleanup_file(&1, versions_dir, cutoff_time))

      _ ->
        :ok
    end
  end

  defp cleanup_file(file, versions_dir, cutoff_time) do
    path = Path.join(versions_dir, file)

    case File.stat(path) do
      {:ok, %{mtime: mtime}} ->
        file_time = :calendar.datetime_to_gregorian_seconds(mtime)

        if file_time < cutoff_time do
          File.rm(path)
          File.rm(Path.rootname(path) <> ".json")
        end

      _ ->
        :ok
    end
  end
end
