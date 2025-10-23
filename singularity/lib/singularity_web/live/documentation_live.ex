defmodule SingularityWeb.DocumentationLive do
  @moduledoc """
  Documentation System LiveView - Real-time interface for documentation management.

  Provides a live interface to:
  - Monitor documentation system status
  - View quality reports across all languages
  - Trigger documentation upgrades
  - Monitor pipeline progress
  """

  use SingularityWeb, :live_view
  require Logger
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer
  alias Singularity.Startup.DocumentationBootstrap

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Start periodic updates
      Process.send_after(self(), :update_status, 1000)
    end

    socket = socket
    |> assign(:status, :loading)
    |> assign(:pipeline_status, %{})
    |> assign(:quality_report, %{})
    |> assign(:health_status, :unknown)
    |> assign(:upgrade_in_progress, false)
    |> assign(:last_update, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_status, socket) do
    # Update status every 5 seconds
    Process.send_after(self(), :update_status, 5000)

    socket = socket
    |> update_status()
    |> assign(:last_update, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket = update_status(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_full_upgrade", _params, socket) do
    case DocumentationPipeline.run_full_pipeline() do
      {:ok, :pipeline_started} ->
        socket = socket
        |> put_flash(:info, "Full documentation upgrade started")
        |> assign(:upgrade_in_progress, true)
        {:noreply, socket}
      {:error, :pipeline_already_running} ->
        socket = put_flash(socket, :error, "Pipeline is already running")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to start pipeline: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_incremental_upgrade", _params, socket) do
    # Get modified files from last 24 hours
    modified_files = get_modified_files()
    
    case DocumentationPipeline.run_incremental_pipeline(modified_files) do
      {:ok, :incremental_pipeline_started} ->
        socket = socket
        |> put_flash(:info, "Incremental documentation upgrade started for #{length(modified_files)} files")
        |> assign(:upgrade_in_progress, true)
        {:noreply, socket}
      {:error, :pipeline_already_running} ->
        socket = put_flash(socket, :error, "Pipeline is already running")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to start incremental pipeline: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("enable_quality_gates", _params, socket) do
    case QualityEnforcer.enable_quality_gates() do
      :ok ->
        socket = put_flash(socket, :info, "Quality gates enabled")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to enable quality gates: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("disable_quality_gates", _params, socket) do
    case QualityEnforcer.disable_quality_gates() do
      :ok ->
        socket = put_flash(socket, :warning, "Quality gates disabled")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to disable quality gates: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("schedule_automatic_upgrades", %{"interval" => interval}, socket) do
    interval_minutes = String.to_integer(interval)
    
    case DocumentationPipeline.schedule_automatic_upgrades(interval_minutes) do
      :ok ->
        socket = put_flash(socket, :info, "Automatic upgrades scheduled every #{interval_minutes} minutes")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to schedule automatic upgrades: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("run_self_awareness", _params, socket) do
    case Singularity.SelfImprovingAgent.run_self_awareness_pipeline() do
      {:ok, :pipeline_started} ->
        socket = put_flash(socket, :info, "Self-awareness pipeline started - analyzing codebase, detecting issues, and generating fixes (with emergency Claude CLI fallback)")
        {:noreply, socket}
      {:error, :pipeline_already_running} ->
        socket = put_flash(socket, :warning, "Self-awareness pipeline is already running")
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to start self-awareness pipeline: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  ## Private Functions

  defp update_status(socket) do
    health_status = case DocumentationBootstrap.check_documentation_health() do
      :healthy -> :healthy
      {:unhealthy, _reason} -> :unhealthy
    end

    pipeline_status = case DocumentationPipeline.get_pipeline_status() do
      {:ok, status} -> status
      {:error, _reason} -> %{}
    end

    quality_report = case QualityEnforcer.get_quality_report() do
      {:ok, report} -> report
      {:error, _reason} -> %{}
    end

    socket
    |> assign(:health_status, health_status)
    |> assign(:pipeline_status, pipeline_status)
    |> assign(:quality_report, quality_report)
    |> assign(:status, :loaded)
    |> assign(:upgrade_in_progress, pipeline_status.pipeline_running || false)
  end

  defp get_modified_files do
    # Get files modified in the last 24 hours
    cutoff_time = DateTime.utc_now() |> DateTime.add(-24, :hour)
    
    ["./singularity/lib/**/*.ex", "./rust/**/*.rs", "./llm-server/**/*.ts", "./llm-server/**/*.tsx"]
    |> Enum.flat_map(fn pattern ->
      Path.wildcard(pattern)
    end)
    |> Enum.filter(fn file_path ->
      case File.stat(file_path) do
        {:ok, stat} ->
          stat.mtime
          |> DateTime.from_unix!()
          |> DateTime.compare(cutoff_time) == :gt
        {:error, _} -> false
      end
    end)
  end

  defp format_timestamp(nil), do: "Never"
  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  defp format_percentage(nil), do: "N/A"
  defp format_percentage(value) when is_number(value), do: "#{Float.round(value, 1)}%"
  defp format_percentage(_), do: "N/A"

  defp get_health_status_class(:healthy), do: "text-green-600"
  defp get_health_status_class(:unhealthy), do: "text-red-600"
  defp get_health_status_class(_), do: "text-yellow-600"

  defp get_health_status_text(:healthy), do: "Healthy"
  defp get_health_status_text(:unhealthy), do: "Unhealthy"
  defp get_health_status_text(_), do: "Unknown"
end