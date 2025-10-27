defmodule Genesis.SandboxMaintenance do
  @moduledoc """
  Genesis Sandbox Maintenance

  Handles sandbox cleanup, archival, and integrity verification.

  ## Cleanup Strategy

  - Remove sandboxes older than 7 days
  - Archive high-value sandboxes (successful experiments)
  - Clean up failed experiment sandboxes immediately
  - Track all cleanup in sandbox_history table
  """

  require Logger

  @cleanup_age_days 7
  @sandbox_base_path "~/.genesis/sandboxes"

  @doc """
  Clean up old sandbox directories.
  """
  def cleanup_old_sandboxes do
    Logger.info("Starting sandbox cleanup")

    sandbox_dir = expand_path(@sandbox_base_path)

    try do
      case File.ls(sandbox_dir) do
        {:ok, sandbox_ids} ->
          sandbox_ids
          |> Enum.map(fn sandbox_id ->
            sandbox_path = Path.join(sandbox_dir, sandbox_id)
            should_cleanup(sandbox_path, sandbox_id)
          end)
          |> Enum.filter(fn result -> result != :skip end)
          |> length()
          |> then(fn count ->
            Logger.info("Cleaned up #{count} sandboxes")
          end)

        {:error, reason} ->
          Logger.error("Failed to list sandbox directory: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception during sandbox cleanup: #{inspect(e)}")
    end
  end

  @doc """
  Verify sandbox integrity and health.
  """
  def verify_integrity do
    Logger.info("Verifying sandbox integrity")

    sandbox_dir = expand_path(@sandbox_base_path)

    try do
      case File.ls(sandbox_dir) do
        {:ok, sandbox_ids} ->
          results =
            sandbox_ids
            |> Enum.map(fn sandbox_id ->
              sandbox_path = Path.join(sandbox_dir, sandbox_id)
              check_sandbox_health(sandbox_path, sandbox_id)
            end)

          healthy = Enum.count(results, fn {_, status} -> status == :healthy end)
          unhealthy = Enum.count(results, fn {_, status} -> status == :unhealthy end)

          Logger.info(
            "Sandbox integrity check: #{healthy} healthy, #{unhealthy} unhealthy"
          )

        {:error, reason} ->
          Logger.error("Failed to verify sandboxes: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception during integrity check: #{inspect(e)}")
    end
  end

  defp should_cleanup(sandbox_path, sandbox_id) do
    # Check if sandbox is old enough to cleanup
    case File.stat(sandbox_path) do
      {:ok, stat} ->
        age_days = age_in_days(stat.mtime)

        if age_days >= @cleanup_age_days do
          Logger.info("Cleaning up old sandbox #{sandbox_id} (#{age_days} days old)")
          cleanup_sandbox(sandbox_path, sandbox_id)
          :cleaned
        else
          :skip
        end

      {:error, reason} ->
        Logger.warn("Cannot stat sandbox #{sandbox_id}: #{inspect(reason)}")
        :skip
    end
  end

  defp cleanup_sandbox(sandbox_path, sandbox_id) do
    try do
      # Calculate sandbox size before deletion
      size_mb = calculate_directory_size(sandbox_path)

      # Try to get final metrics from experiment record
      final_metrics = fetch_experiment_metrics(sandbox_id)

      # Delete sandbox directory
      case File.rm_rf(sandbox_path) do
        {:ok, _files} ->
          Logger.info("Deleted sandbox directory: #{sandbox_path}")

          # Record cleanup in sandbox_history
          record_sandbox_action(sandbox_id, sandbox_path, "cleaned_up", size_mb, final_metrics)

        {:error, reason} ->
          Logger.error("Failed to delete sandbox #{sandbox_id}: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception during sandbox cleanup: #{inspect(e)}")
    end
  end

  defp check_sandbox_health(sandbox_path, sandbox_id) do
    try do
      # Check if sandbox directory exists
      case File.exists?(sandbox_path) do
        true ->
          # Check if Git repository is healthy
          case check_git_health(sandbox_path) do
            :ok -> {sandbox_id, :healthy}
            {:error, reason} -> {sandbox_id, :unhealthy}
          end

        false ->
          {sandbox_id, :missing}
      end
    rescue
      e ->
        Logger.warn("Exception checking sandbox health: #{inspect(e)}")
        {sandbox_id, :error}
    end
  end

  defp check_git_health(sandbox_path) do
    try do
      # Check if Git repository is accessible and not corrupted
      case System.cmd("bash", [
        "-c",
        "cd #{Path.quote(sandbox_path)} && git status --porcelain > /dev/null 2>&1"
      ]) do
        {_output, 0} -> :ok
        {_output, _code} -> {:error, "git status failed"}
      end
    rescue
      e ->
        {:error, inspect(e)}
    end
  end

  defp age_in_days(mtime) do
    # mtime is in microseconds since Unix epoch
    now = System.os_time(:microsecond)
    diff_us = now - mtime
    diff_seconds = div(diff_us, 1_000_000)
    div(diff_seconds, 86400)
  end

  defp calculate_directory_size(path) do
    try do
      case System.cmd("bash", ["-c", "du -sh #{Path.quote(path)} | cut -f1"]) do
        {size_str, 0} ->
          case parse_size_to_mb(String.trim(size_str)) do
            {:ok, mb} -> mb
            :error -> 0.0
          end

        _error ->
          0.0
      end
    rescue
      _e -> 0.0
    end
  end

  defp parse_size_to_mb(size_str) do
    case String.downcase(size_str) do
      "0" <> _rest -> {:ok, 0.0}
      <<value::binary-size(1), "m">> -> {:ok, String.to_float(value) || 0.0}
      <<value::binary-size(2), "m">> -> {:ok, String.to_float(value) || 0.0}
      <<value::binary-size(1), "g">> -> {:ok, (String.to_float(value) || 0.0) * 1024}
      <<value::binary-size(2), "g">> -> {:ok, (String.to_float(value) || 0.0) * 1024}
      _other -> :error
    end
  end

  defp fetch_experiment_metrics(sandbox_id) do
    # Fetch final metrics from database
    try do
      case Genesis.Repo.get(Genesis.Schemas.ExperimentMetrics, sandbox_id) do
        nil -> %{}
        metrics -> %{success_rate: metrics.success_rate, regression: metrics.regression}
      end
    rescue
      _e -> %{}
    end
  end

  defp record_sandbox_action(experiment_id, sandbox_path, action, size_mb, metrics) do
    # Record action in sandbox_history table
    try do
      attrs = %{
        experiment_id: experiment_id,
        sandbox_path: sandbox_path,
        action: action,
        sandbox_size_mb: size_mb,
        final_metrics: metrics
      }

      %Genesis.Schemas.SandboxHistory{}
      |> Genesis.Schemas.SandboxHistory.changeset(attrs)
      |> Genesis.Repo.insert()

      Logger.debug("Recorded sandbox action: #{action} for #{experiment_id}")
    rescue
      e ->
        Logger.warn("Failed to record sandbox action: #{inspect(e)}")
    end
  end

  defp expand_path(path) do
    path
    |> String.replace("~", System.get_env("HOME", "/tmp"))
  end
end
