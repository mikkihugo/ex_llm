defmodule Singularity.Web do
  @moduledoc """
  Conveniences for defining Phoenix LiveView and controller modules.

  Provides macros for importing common dependencies and setting up
  LiveView and controller modules with standard configurations.

  ## Usage

      use Singularity.Web, :live_view
      use Singularity.Web, :controller
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  @doc """
  When used, dispatch to the appropriate module
  """
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {Singularity.Web.Layouts, :app}

      unquote(view_helpers())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: Singularity.Web

      import Plug.Conn
    end
  end

  defp view_helpers do
    quote do
      # HTML helpers (Phoenix 4.0 uses imports instead of use)
      import Phoenix.HTML
      import Phoenix.HTML.Form

      # Salad UI components (43 pre-built components)
      use SaladUI
    end
  end
end
