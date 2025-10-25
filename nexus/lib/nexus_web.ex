defmodule NexusWeb do
  @moduledoc """
  NexusWeb - Web interface for the unified control panel

  Provides Phoenix web controllers, views, and templates for:
  - System dashboards (Singularity, Genesis, CentralCloud)
  - Real-time status updates via NATS
  - Backend system management and monitoring
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: {NexusWeb.Layouts, :root}]

      import Plug.Conn

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {NexusWeb.Layouts, :app}
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
