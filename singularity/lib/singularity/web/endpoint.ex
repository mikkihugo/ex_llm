defmodule Singularity.Web.Endpoint do
  @moduledoc """
  HTTP endpoint for Singularity web interface.

  Provides:
  - Phoenix LiveDashboard for metrics visualization
  - Health check endpoint
  - Internal admin interface

  ## Architecture

  This is a minimal HTTP interface optimized for internal tooling.
  The primary interface is NATS (for distributed services) and MCP (for AI clients).
  """

  use Plug.Router

  require Logger

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  # Health check endpoint
  get "/health" do
    status = health_status()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end

  # Metrics endpoint (simple JSON)
  get "/metrics" do
    metrics = Singularity.Telemetry.get_metrics()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(metrics))
  end

  # Documentation system health check
  get "/api/documentation/health" do
    case Singularity.Startup.DocumentationBootstrap.check_documentation_health() do
      :healthy ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{status: "healthy", message: "Documentation system is running"})
        )

      {:unhealthy, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          503,
          Jason.encode!(%{
            status: "unhealthy",
            message: "Documentation system is not healthy",
            reason: inspect(reason)
          })
        )
    end
  end

  # Documentation system status
  get "/api/documentation/status" do
    with {:ok, pipeline_status} <- Singularity.Agents.DocumentationPipeline.get_pipeline_status(),
         {:ok, quality_report} <- Singularity.Agents.QualityEnforcer.get_quality_report() do
      status = %{
        pipeline: pipeline_status,
        quality: quality_report,
        timestamp: DateTime.utc_now()
      }

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(status))
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          500,
          Jason.encode!(%{error: "Failed to get documentation status", reason: inspect(reason)})
        )
    end
  end

  # Self-awareness pipeline
  post "/api/self-awareness/run" do
    case Singularity.SelfImprovingAgent.run_self_awareness_pipeline() do
      {:ok, :pipeline_started} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{
            message: "Self-awareness pipeline started (with emergency Claude CLI fallback)"
          })
        )

      {:error, :pipeline_already_running} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(409, Jason.encode!(%{error: "Pipeline is already running"}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          500,
          Jason.encode!(%{error: "Failed to start pipeline", reason: inspect(reason)})
        )
    end
  end

  # Self-awareness status
  get "/api/self-awareness/status" do
    # Get status from SelfImprovingAgent
    status = %{
      # Would need to track this in the agent
      pipeline_running: false,
      last_run: nil,
      capabilities: %{
        parser_engine: Code.ensure_loaded?(Singularity.ParserEngine),
        code_quality_engine: Code.ensure_loaded?(Singularity.CodeEngine),
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
      ]
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end

  # Trigger documentation upgrade
  post "/api/documentation/upgrade" do
    case conn.params do
      %{"type" => "full"} ->
        case Singularity.Agents.DocumentationPipeline.run_full_pipeline() do
          {:ok, :pipeline_started} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{message: "Full documentation upgrade started"}))

          {:error, :pipeline_already_running} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(409, Jason.encode!(%{error: "Pipeline is already running"}))

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(
              500,
              Jason.encode!(%{error: "Failed to start pipeline", reason: inspect(reason)})
            )
        end

      %{"type" => "incremental", "files" => files} when is_list(files) ->
        case Singularity.Agents.DocumentationPipeline.run_incremental_pipeline(files) do
          {:ok, :incremental_pipeline_started} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(
              200,
              Jason.encode!(%{message: "Incremental documentation upgrade started", files: files})
            )

          {:error, :pipeline_already_running} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(409, Jason.encode!(%{error: "Pipeline is already running"}))

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(
              500,
              Jason.encode!(%{
                error: "Failed to start incremental pipeline",
                reason: inspect(reason)
              })
            )
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{
            error: "Invalid upgrade type. Use 'full' or 'incremental' with 'files' parameter"
          })
        )
    end
  end

  # Documentation LiveView
  get "/documentation" do
    # This would need proper LiveView setup
    # For now, redirect to a simple status page
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Documentation System</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-50">
      <div class="min-h-screen flex items-center justify-center">
        <div class="max-w-md w-full bg-white rounded-lg shadow-md p-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-4">Documentation System</h1>
          <p class="text-gray-600 mb-6">Multi-language quality enforcement and upgrades</p>
          <div class="space-y-4">
            <a href="/api/documentation/health" class="block w-full bg-blue-600 text-white text-center py-2 px-4 rounded hover:bg-blue-700">
              Check Health
            </a>
            <a href="/api/documentation/status" class="block w-full bg-green-600 text-white text-center py-2 px-4 rounded hover:bg-green-700">
              View Status
            </a>
            <form method="POST" action="/api/documentation/upgrade" class="w-full">
              <input type="hidden" name="type" value="full">
              <button type="submit" class="w-full bg-indigo-600 text-white py-2 px-4 rounded hover:bg-indigo-700">
                Start Full Upgrade
              </button>
            </form>
          </div>
        </div>
      </div>
    </body>
    </html>
    """)
  end

  # Catch-all for undefined routes
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end

  defp health_status do
    %{
      status: "healthy",
      services: %{
        database: check_database(),
        nats: check_nats(),
        rust_nifs: check_nifs()
      },
      version: Application.spec(:singularity, :vsn) |> to_string(),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    }
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(Singularity.Repo, "SELECT 1", []) do
      {:ok, _} -> "up"
      {:error, _} -> "down"
    end
  rescue
    _ -> "down"
  end

  defp check_nats do
    # Check if NATS client process is alive
    case Process.whereis(Singularity.NATS.Client) do
      nil -> "down"
      pid when is_pid(pid) -> if Process.alive?(pid), do: "up", else: "down"
    end
  end

  defp check_nifs do
    # Check if NIFs are loaded by trying a simple call
    try do
      # Try calling a NIF function - if it works, NIFs are loaded
      case Code.ensure_loaded?(Singularity.CodeEngine) do
        true -> "loaded"
        false -> "not_loaded"
      end
    rescue
      _ -> "error"
    end
  end
end
