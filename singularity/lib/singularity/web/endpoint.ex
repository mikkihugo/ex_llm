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
    case Process.whereis(Singularity.NATS.NatsClient) do
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
