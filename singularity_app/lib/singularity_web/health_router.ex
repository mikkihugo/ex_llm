defmodule SingularityWeb.HealthRouter do
  @moduledoc """
  Minimal HTTP router for health checks and metrics only.
  
  All business logic goes through NATS - this is just for monitoring.
  """

  use Plug.Router

  plug :match
  plug Plug.RequestId
  plug Plug.Logger
  plug :dispatch

  @doc """
  Basic health check endpoint.
  """
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", timestamp: DateTime.utc_now()}))
  end

  @doc """
  Deep health check with system status.
  """
  get "/health/deep" do
    status = Singularity.Health.deep_health()
    send_resp(conn, status.http_status, Jason.encode!(status.body))
  end

  @doc """
  Prometheus metrics endpoint.
  """
  get "/metrics" do
    metrics = Singularity.PrometheusExporter.render()
    send_resp(conn, 200, metrics)
  end

  @doc """
  NATS connection status.
  """
  get "/status/nats" do
    case Singularity.NatsClient.status() do
      status when is_map(status) ->
        send_resp(conn, 200, Jason.encode!(status))
      _ ->
        send_resp(conn, 503, Jason.encode!(%{error: "NATS not available"}))
    end
  end

  @doc """
  System information.
  """
  get "/status/system" do
    system_info = %{
      node: Node.self(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      memory: :erlang.memory(),
      processes: :erlang.system_info(:process_count),
      version: System.version()
    }
    send_resp(conn, 200, Jason.encode!(system_info))
  end

  # Catch-all for 404s
  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "not_found", message: "Only health/metrics endpoints available"}))
  end
end