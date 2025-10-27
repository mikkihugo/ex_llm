defmodule Singularity.Health.HttpServer do
  @moduledoc """
  Supervises the HTTP listener that serves health endpoints.

  Starts a `Plug.Cowboy` child using `Singularity.Health.Endpoint` when
  HTTP health checks are enabled via configuration or environment
  (see `HTTP_SERVER_ENABLED`). Returns `:ignore` if disabled so the
  supervisor tree can skip the process cleanly.
  """

  use Supervisor

  require Logger

  def start_link(opts \\ []) do
    if enabled?() do
      Logger.info("Starting health HTTP server", port: port())
      Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Health HTTP server disabled; set HTTP_SERVER_ENABLED=true to enable")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    cowboy_opts = [
      port: port(),
      num_acceptors: acceptors()
    ]

    child =
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Singularity.Health.Endpoint,
        options: cowboy_opts
      )

    Supervisor.init([child], strategy: :one_for_one)
  end

  defp enabled? do
    config = Application.get_env(:singularity, :http_server, [])
    Keyword.get(config, :enabled, false)
  end

  defp port do
    config = Application.get_env(:singularity, :http_server, [])
    Keyword.get(config, :port, 4000)
  end

  defp acceptors do
    config = Application.get_env(:singularity, :http_server, [])
    Keyword.get(config, :acceptors, 4)
  end
end
