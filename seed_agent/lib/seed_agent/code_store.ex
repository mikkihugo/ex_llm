defmodule SeedAgent.CodeStore do
  @moduledoc """
  Persists generated code artifacts to disk for hot reload and version history.
  """
  use GenServer

  @type state :: %{
          root: String.t(),
          active: String.t(),
          versions: String.t()
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

  ## Server callbacks

  @impl true
  def init(_opts) do
    root = Path.expand(System.get_env("CODE_ROOT", "./code"))
    active = Path.join(root, "active")
    versions = Path.join(root, "versions")

    with :ok <- ensure_dir(active),
         :ok <- ensure_dir(versions) do
      # Schedule first cleanup
      schedule_cleanup()
      {:ok, %{root: root, active: active, versions: versions}}
    else
      {:error, reason} ->
        {:stop, {:code_store_init_failed, reason}}
    end
  end

  @impl true
  def handle_call(:paths, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:stage, agent_id, version, code, metadata}, _from, state) when is_binary(code) and byte_size(code) > 0 do
    version_id =
      [agent_id, version, System.system_time(:millisecond)]
      |> Enum.join("-")

    version_file = Path.join(state.versions, "#{version_id}.gleam")
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
    active_file = Path.join(state.active, "#{agent_id}.gleam")

    case File.cp(version_path, active_file) do
      :ok ->
        {:reply, {:ok, active_file}, state}

      {:error, reason} ->
        {:reply, {:error, {:promote_failed, reason}}, state}
    end
  end

  @impl true
  def handle_info(:cleanup_old_versions, state) do
    cleanup_old_versions(state.versions)
    schedule_cleanup()
    {:noreply, state}
  end

  defp ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_versions, @cleanup_interval_ms)
  end

  defp cleanup_old_versions(versions_dir) do
    cutoff_time = System.system_time(:second) - @version_ttl_hours * 3600

    case File.ls(versions_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".gleam"))
        |> Enum.each(fn file ->
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
        end)

      _ ->
        :ok
    end
  end
end
