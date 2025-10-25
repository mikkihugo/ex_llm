defmodule Singularity.Database.BackupWorker do
  @moduledoc """
  Database Backup Worker - Automated backups via Oban

  Scheduled backups of singularity, centralcloud, and genesis_db databases.

  ## Scheduling

  Hourly backups (keep 6):
    0 * * * * (every hour at :00)

  Daily backups (keep 7):
    0 1 * * * (every day at 1:00 AM)

  ## Backup Storage

  Backups are stored in: .db-backup/{hourly,daily}/backup_YYYYMMDD_HHMMSS/{db}.sql

  ## Example

    # Schedule a job manually
    %{"type" => "hourly"}
    |> Singularity.Database.BackupWorker.new()
    |> Oban.insert()
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @backup_dir ".db-backup"
  @databases ["singularity", "centralcloud", "genesis_db"]
  @db_user System.get_env("DB_USER", "mhugo")

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => backup_type}}) when backup_type in ["hourly", "daily"] do
    Logger.info("Starting #{backup_type} database backup")

    case backup_databases(backup_type) do
      :ok ->
        cleanup_old_backups(backup_type)
        Logger.info("✅ #{backup_type} backup complete")
        :ok

      {:error, reason} ->
        Logger.error("❌ Backup failed: #{reason}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("Invalid backup job args: #{inspect(args)}")
    :discard
  end

  @doc """
  Schedule hourly backup (every hour at :00, keeps 6)
  """
  def schedule_hourly do
    %{"type" => "hourly"}
    |> new(schedule_in: {1, :hour})
    |> Oban.insert()
  end

  @doc """
  Schedule daily backup (every day at 1:00 AM, keeps 7)
  """
  def schedule_daily do
    %{"type" => "daily"}
    |> new(schedule_in: {1, :day})
    |> Oban.insert()
  end

  # Private functions

  defp backup_databases(backup_type) do
    timestamp = DateTime.now!("Etc/UTC") |> Calendar.strftime("%Y%m%d_%H%M%S")
    backup_subdir = Path.join([@backup_dir, backup_type, "backup_#{timestamp}"])

    File.mkdir_p!(backup_subdir)

    @databases
    |> Enum.reduce(:ok, fn db, acc ->
      case backup_database(db, backup_subdir) do
        :ok -> acc
        {:error, _} = error -> error
      end
    end)
    |> then(fn
      :ok -> :ok
      {:error, _} -> {:error, "Backup failed for one or more databases"}
    end)
  end

  defp backup_database(db_name, backup_dir) do
    backup_file = Path.join(backup_dir, "#{db_name}.sql")

    case System.cmd("pg_dump", [
      "-U", @db_user,
      "-h", "localhost",
      db_name
    ]) do
      {output, 0} ->
        File.write!(backup_file, output)
        size = File.stat!(backup_file).size
        Logger.info("  ✅ #{db_name} (#{format_size(size)})")
        :ok

      {error, exit_code} ->
        Logger.error("  ❌ #{db_name} (exit code: #{exit_code})")
        {:error, error}
    end
  rescue
    e ->
      Logger.error("  ❌ #{db_name}: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end

  defp cleanup_old_backups(backup_type) do
    backup_dir = Path.join(@backup_dir, backup_type)
    keep_count = if backup_type == "hourly", do: 6, else: 7

    case File.ls(backup_dir) do
      {:ok, backups} ->
        backups
        |> Enum.filter(&String.starts_with?(&1, "backup_"))
        |> Enum.sort(:desc)
        |> Enum.drop(keep_count)
        |> Enum.each(fn old_backup ->
          old_path = Path.join(backup_dir, old_backup)
          File.rm_rf!(old_path)
          Logger.info("  Deleted old backup: #{old_backup}")
        end)

      {:error, _} ->
        :ok
    end
  end

  defp format_size(bytes) do
    cond do
      bytes >= 1_000_000_000 -> Float.round(bytes / 1_000_000_000, 2) |> to_string() <> " GB"
      bytes >= 1_000_000 -> Float.round(bytes / 1_000_000, 2) |> to_string() <> " MB"
      bytes >= 1_000 -> Float.round(bytes / 1_000, 2) |> to_string() <> " KB"
      true -> "#{bytes} B"
    end
  end
end
