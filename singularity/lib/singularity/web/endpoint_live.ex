defmodule Singularity.Web.EndpointLive do
  @moduledoc """
  Phoenix LiveView Endpoint for Singularity web interface.

  Provides:
  - Phoenix LiveView support with WebSocket
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
  """

  use Phoenix.Endpoint, otp_app: :singularity

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  @session_options [
    store: :cookie,
    key: "_singularity_live_key",
    signing_salt: "AAAAAAAAAAAAAAAA"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :singularity,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug :put_secure_browser_headers

  plug Plug.Session, @session_options
  plug Singularity.Web.Router

  # Put secure browser headers
  defp put_secure_browser_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("content-security-policy", "default-src 'self'")
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Conn.put_resp_header("x-frame-options", "SAMEORIGIN")
    |> Plug.Conn.put_resp_header("x-xss-protection", "1; mode=block")
  end

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
end
