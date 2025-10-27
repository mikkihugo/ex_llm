defmodule Singularity.Health do
  @moduledoc """
  Public health-check facade.

  Provides the legacy `deep_health/0` API used by tests while exposing
  an HTTP-ready Plug via `PlugCheckup` so deployments can satisfy
  external health specifications without re-implementing checks.
  """

  alias Singularity.Monitoring.Health, as: MonitoringHealth

  @doc """
  Return system health information.

  Delegates to `Singularity.Monitoring.Health` (the source of truth).
  """
  @spec deep_health() :: struct()
  defdelegate deep_health, to: MonitoringHealth

  @doc """
  Plug options used to expose the health endpoint via `PlugCheckup`.
  """
  @spec plug_options() :: PlugCheckup.Options.t()
  def plug_options do
    PlugCheckup.Options.new(
      json_encoder: Jason,
      error_code: 503,
      time_unit: :millisecond,
      checks: [
        %PlugCheckup.Check{name: "system", module: __MODULE__, function: :system_health}
      ]
    )
  end

  @doc """
  Return the module/opts tuple for plugging into a router or endpoint.
  """
  @spec plug_spec() :: {module(), Plug.opts()}
  def plug_spec do
    {Singularity.Health.Plug, plug_options()}
  end

  @doc false
  @spec system_health() :: :ok | {:error, term()}
  def system_health do
    status = MonitoringHealth.deep_health()

    if status.http_status == 200 do
      :ok
    else
      {:error, status.body}
    end
  end
end

defmodule Singularity.Health.Plug do
  @moduledoc """
  Minimal Plug that delegates health reporting to `PlugCheckup`.

  Usage:

      plug Singularity.Health.Plug, Singularity.Health.plug_options()
  """

  use Plug.Builder

  plug PlugCheckup, Singularity.Health.plug_options()
end

defmodule Singularity.Health.Endpoint do
  @moduledoc """
  Standalone Plug endpoint exposing HTTP health routes.

  Routes:
  - `GET /health`   → Lightweight OK response
  - `GET /health/live` → Alias for `/health`
  - `GET /health/deep` → JSON payload via PlugCheckup
  - Fallback 404 for any other path
  """

  use Plug.Router

  import Plug.Conn

  plug :match
  plug :dispatch

  get "/health" do
    send_ok(conn)
  end

  get "/health/live" do
    send_ok(conn)
  end

  get "/health/ping" do
    send_ok(conn)
  end

  get "/health/deep" do
    conn
    |> Singularity.Health.Plug.call(Singularity.Health.plug_options())
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp send_ok(conn) do
    payload = %{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(payload))
  end
end
