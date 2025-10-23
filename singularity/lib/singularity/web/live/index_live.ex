defmodule Singularity.Web.IndexLive do
  @moduledoc """
  Index LiveView - Welcome page with navigation to all Singularity pages.

  Displays links to:
  - Custom LiveView pages (Approvals, Documentation)
  - Phoenix LiveDashboard (System monitoring)
  - API documentation

  ## Features

  - Quick navigation to all available interfaces
  - System status overview
  - Links to API endpoints
  """

  use Singularity.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Singularity - Home")
     |> assign(:system_status, get_system_status())}
  end

  defp get_system_status do
    case Ecto.Adapters.SQL.query(Singularity.Repo, "SELECT 1", []) do
      {:ok, _} -> :up
      {:error, _} -> :down
    end
  rescue
    _ -> :down
  end
end
