defmodule Singularity.Agents.Toolkit do
  @moduledoc """
  Safe file toolkit for agents. Defaults to dry-run mode for writes.

  Provides:
  - list_files(dir, pattern \\ "**/*")
  - read_file(path)
  - write_file(path, content, opts \\ [])
    opts: dry_run: true/false, backup: true/false
  - backup_file(path)
  """

  require Logger

  @default_opts [dry_run: true, backup: true]

  @doc "List files under `dir` matching a glob pattern" 
  def list_files(dir, pattern \\ "**/*") do
    Path.wildcard(Path.join(dir, pattern))
  end

  @doc "Read file contents as binary" 
  def read_file(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Write a file safely. By default uses dry_run and will not persist unless `dry_run: false` passed." 
  def write_file(path, content, opts \\ []) when is_binary(path) and is_binary(content) do
    opts = Keyword.merge(@default_opts, opts)
    if opts[:dry_run] do
      {:ok, %{path: path, dry_run: true, size: byte_size(content)}}
    else
      if opts[:backup] and File.exists?(path) do
        case backup_file(path) do
          :ok -> :ok
          {:error, reason} -> Logger.warning("Failed to backup #{path}: #{inspect(reason)}")
        end
      end

      dir = Path.dirname(path)
      :ok = File.mkdir_p(dir)
      case File.write(path, content) do
        :ok -> {:ok, %{path: path, dry_run: false}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Backup a file to path.bak.TIMESTAMP" 
  def backup_file(path) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace([":","-"], "_")
    backup = "#{path}.bak.#{timestamp}"
    case File.cp(path, backup) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Read a codebase from the project's CodeStore if available. Returns {:ok, codebase} or {:error, reason}."
  def read_codebase(codebase_id) do
    try do
      if function_exported?(Singularity.CodeStore, :fetch_codebase, 1) do
        Singularity.CodeStore.fetch_codebase(codebase_id)
      else
        {:error, :no_codestore}
      end
    rescue
      e -> {:error, {:exception, e}}
    end
  end
end
