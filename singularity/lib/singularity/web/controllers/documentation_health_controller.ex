defmodule Singularity.Web.Controllers.DocumentationHealthController do
  @moduledoc """
  Documentation Health Controller - Health check endpoint for documentation system.

  Provides HTTP endpoints to check the status of the documentation system
  and trigger manual documentation upgrades.

  ## Endpoints

  - `GET /api/documentation/health` - Check documentation system health
  - `GET /api/documentation/status` - Get detailed documentation status
  - `POST /api/documentation/upgrade` - Trigger manual documentation upgrade
  """

  use Singularity.Web, :controller
  alias Singularity.Startup.DocumentationBootstrap
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer

  @doc """
  Check documentation system health.
  """
  def health(conn, _params) do
    case DocumentationBootstrap.check_documentation_health() do
      :healthy ->
        json(conn, %{status: "healthy", message: "Documentation system is running"})
      {:unhealthy, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy", message: "Documentation system is not healthy", reason: inspect(reason)})
    end
  end

  @doc """
  Get detailed documentation status.
  """
  def status(conn, _params) do
    with {:ok, pipeline_status} <- DocumentationPipeline.get_pipeline_status(),
         {:ok, quality_report} <- QualityEnforcer.get_quality_report() do
      
      status = %{
        pipeline: pipeline_status,
        quality: quality_report,
        timestamp: DateTime.utc_now()
      }
      
      json(conn, status)
    else
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to get documentation status", reason: inspect(reason)})
    end
  end

  @doc """
  Trigger manual documentation upgrade.
  """
  def upgrade(conn, %{"type" => "full"}) do
    case DocumentationPipeline.run_full_pipeline() do
      {:ok, :pipeline_started} ->
        json(conn, %{message: "Full documentation upgrade started"})
      {:error, :pipeline_already_running} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Pipeline is already running"})
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to start pipeline", reason: inspect(reason)})
    end
  end

  def upgrade(conn, %{"type" => "incremental", "files" => files}) when is_list(files) do
    case DocumentationPipeline.run_incremental_pipeline(files) do
      {:ok, :incremental_pipeline_started} ->
        json(conn, %{message: "Incremental documentation upgrade started", files: files})
      {:error, :pipeline_already_running} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Pipeline is already running"})
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to start incremental pipeline", reason: inspect(reason)})
    end
  end

  def upgrade(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid upgrade type. Use 'full' or 'incremental' with 'files' parameter"})
  end
end