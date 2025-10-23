defmodule Singularity.Web.EndpointLive do
  @moduledoc """
  Phoenix LiveView Endpoint for Singularity web interface.

  DEPRECATED: This module is not currently used. The active HTTP endpoint is
  Singularity.Web.Endpoint which uses Plug.Router for minimal overhead.

  This module is kept as reference for potential future LiveView integration.

  Provides:
  - Phoenix LiveView support with WebSocket (when enabled)
  - Phoenix LiveDashboard for metrics visualization
  - Real-time UI updates for approvals and documentation systems
  - Health check and metrics endpoints

  ## Architecture

  This is a minimal HTTP interface optimized for internal tooling.
  The primary interface is NATS (for distributed services) and MCP (for AI clients).

  ## WebSocket Configuration

  LiveView uses WebSocket for real-time updates. Configure via:
  - SINGULARITY_LIVE_SOCKET_PATH - Path for LiveView socket (default: "/live")
  - SINGULARITY_LIVE_SOCKET_TIMEOUT - Timeout in ms (default: 45000)

  ## Implementation Note

  To enable this endpoint, uncomment `use Phoenix.Endpoint, otp_app: :singularity` below.
  However, Phoenix.Endpoint causes circular dependencies during compile-time with the
  current project structure. Use Singularity.Web.Endpoint (Plug.Router) instead.
  """

  # NOTE: Phoenix.Endpoint causes circular dependencies during compilation
  # Use Singularity.Web.Endpoint (Plug.Router) instead
  # Uncomment the line below only when Phoenix dependencies are properly initialized
  # use Phoenix.Endpoint, otp_app: :singularity

  # Session configuration (kept for reference)
  @session_options [
    store: :cookie,
    key: "_singularity_live_key",
    signing_salt: "AAAAAAAAAAAAAAAA"
  ]

  @doc """
  Callback used to dynamically configure the endpoint.

  The returned keyword list is merged and forwarded to the transport and adapter respectively.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: String.to_integer(port)])}
    else
      {:ok, config}
    end
  end

  @doc """
  Put secure browser headers on response.

  Kept as utility function for future LiveView integration.
  """
  def put_secure_browser_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("content-security-policy", "default-src 'self'")
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Conn.put_resp_header("x-frame-options", "SAMEORIGIN")
    |> Plug.Conn.put_resp_header("x-xss-protection", "1; mode=block")
  end
end
