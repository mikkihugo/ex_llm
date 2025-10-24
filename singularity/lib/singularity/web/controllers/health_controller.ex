defmodule Singularity.Web.HealthController do
  @moduledoc """
  Health and Metrics Controller - System health check and monitoring endpoints.

  Provides HTTP endpoints for:
  - General health status
  - System metrics
  - Documentation system health
  - Self-awareness pipeline control

  ## Endpoints

  - `GET /api/health` - Overall system health
  - `GET /api/metrics` - System metrics (JSON)
  - `GET /api/documentation/health` - Documentation system health
  - `GET /api/documentation/status` - Detailed documentation status
  - `POST /api/documentation/upgrade` - Trigger documentation upgrade
  - `POST /api/self-awareness/run` - Run self-awareness pipeline
  - `GET /api/self-awareness/status` - Self-awareness status
  """

  use Singularity.Web, :controller

  require Logger

  alias Singularity.Startup.DocumentationBootstrap
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer
  alias Singularity.SelfImprovingAgent
  alias Singularity.Telemetry

  @doc """
  Check overall system health.
  """
  def health(conn, _params) do
    status = %{
      status: "healthy",
      services: %{
        database: check_database(),
        nats: check_nats(),
        rust_nifs: check_nifs()
      },
      version: Application.spec(:singularity, :vsn) |> to_string(),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      timestamp: DateTime.utc_now()
    }

    json(conn, status)
  end

  @doc """
  Get system metrics.
  """
  def metrics(conn, _params) do
    metrics = Telemetry.get_metrics()
    json(conn, metrics)
  end

  @doc """
  Check documentation system health.
  """
  def documentation_health(conn, _params) do
    case DocumentationBootstrap.check_documentation_health() do
      :healthy ->
        json(conn, %{
          status: "healthy",
          message: "Documentation system is running",
          timestamp: DateTime.utc_now()
        })

      {:unhealthy, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          message: "Documentation system is not healthy",
          reason: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  @doc """
  Get detailed documentation status.
  """
  def documentation_status(conn, _params) do
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
        |> json(%{
          error: "Failed to get documentation status",
          reason: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  @doc """
  Trigger documentation upgrade.

  Accepts `type` parameter:
  - "full" - Full documentation upgrade
  - "incremental" - Incremental upgrade (requires "files" parameter)
  """
  def documentation_upgrade(conn, %{"type" => "full"}) do
    case DocumentationPipeline.run_full_pipeline() do
      {:ok, :pipeline_started} ->
        json(conn, %{
          message: "Full documentation upgrade started",
          timestamp: DateTime.utc_now()
        })

      {:error, :pipeline_already_running} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Pipeline is already running",
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to start pipeline",
          reason: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  def documentation_upgrade(conn, %{"type" => "incremental", "files" => files})
      when is_list(files) do
    case DocumentationPipeline.run_incremental_pipeline(files) do
      {:ok, :incremental_pipeline_started} ->
        json(conn, %{
          message: "Incremental documentation upgrade started",
          files: files,
          timestamp: DateTime.utc_now()
        })

      {:error, :pipeline_already_running} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Pipeline is already running",
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to start incremental pipeline",
          reason: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  def documentation_upgrade(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Invalid upgrade type. Use 'full' or 'incremental' with 'files' parameter",
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Run self-awareness pipeline.
  """
  def self_awareness_run(conn, _params) do
    case SelfImprovingAgent.run_self_awareness_pipeline() do
      {:ok, :pipeline_started} ->
        json(conn, %{
          message: "Self-awareness pipeline started (with emergency Claude CLI fallback)",
          timestamp: DateTime.utc_now()
        })

      {:error, :pipeline_already_running} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Pipeline is already running",
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to start pipeline",
          reason: inspect(reason),
          timestamp: DateTime.utc_now()
        })
    end
  end

  @doc """
  Get self-awareness pipeline status.
  """
  def self_awareness_status(conn, _params) do
    status = %{
      pipeline_running: false,
      last_run: nil,
      capabilities: %{
        parser_engine: Code.ensure_loaded?(Singularity.ParserEngine),
        code_engine: Code.ensure_loaded?(Singularity.CodeEngine),
        quality_enforcer: Code.ensure_loaded?(Singularity.Agents.QualityEnforcer),
        documentation_upgrader: Code.ensure_loaded?(Singularity.Agents.DocumentationUpgrader),
        emergency_claude: Code.ensure_loaded?(Singularity.Integration.Claude)
      },
      existing_systems: [
        "SelfImprovingAgent - Main self-evolution system",
        "ParserEngine - Multi-language parsing",
        "CodeEngine - AST analysis and quality metrics",
        "CodeStore - Codebase analysis and storage",
        "QualityEnforcer - Quality 2.3.0 enforcement",
        "DocumentationUpgrader - Documentation standards",
        "ApprovalService - Human-in-the-loop workflow",
        "HotReload.ModuleReloader - Live system updates",
        "Emergency Claude CLI - Fallback system"
      ],
      timestamp: DateTime.utc_now()
    }

    json(conn, status)
  end

  # Private helper functions

  defp check_database do
    case Ecto.Adapters.SQL.query(Singularity.Repo, "SELECT 1", []) do
      {:ok, _} -> "up"
      {:error, _} -> "down"
    end
  rescue
    _ -> "down"
  end

  defp check_nats do
    case Process.whereis(Singularity.Nats.Client) do
      nil -> "down"
      pid when is_pid(pid) -> if Process.alive?(pid), do: "up", else: "down"
    end
  end

  defp check_nifs do
    try do
      case Code.ensure_loaded?(Singularity.CodeEngine) do
        true -> "loaded"
        false -> "not_loaded"
      end
    rescue
      _ -> "error"
    end
  end
end
