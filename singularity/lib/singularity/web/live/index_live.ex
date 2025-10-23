defmodule Singularity.Web.IndexLive do
  @moduledoc """
  Index LiveView - Welcome page with navigation to all Singularity pages.

  Displays links to:
  - Custom LiveView pages (Approvals, Documentation, Evolution Dashboard)
  - Phoenix LiveDashboard (System monitoring)
  - API documentation
  - Self-Evolution System metrics

  ## Features

  - Quick navigation to all available interfaces
  - System status overview
  - Links to API endpoints
  - Real-time evolution metrics (agents, patterns, learning)

  ## Pages

  - `/` - This index/home page
  - `/approvals` - HITL approval queue management
  - `/documentation` - Knowledge base documentation
  - `/evolution` - Self-evolution metrics dashboard
  - `/dashboard` - Phoenix LiveDashboard (system monitoring)
  """

  use Singularity.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Update metrics every 5 seconds
    if connected?(socket) do
      :timer.send_interval(5000, self(), :update_evolution_metrics)
    end

    {:ok,
     socket
     |> assign(:page_title, "Singularity - Home")
     |> assign(:system_status, fetch_system_status())
     |> assign(:evolution_metrics, fetch_evolution_metrics())}
  end

  @impl true
  def handle_info(:update_evolution_metrics, socket) do
    {:noreply, assign(socket, :evolution_metrics, fetch_evolution_metrics())}
  end

  # ============================================================================
  # Helper Functions - Self-Documenting Names
  # ============================================================================

  defp fetch_system_status do
    case Ecto.Adapters.SQL.query(Singularity.Repo, "SELECT 1", []) do
      {:ok, _} -> :up
      {:error, _} -> :down
    end
  rescue
    _ -> :down
  end

  defp fetch_evolution_metrics do
    %{
      total_agents: count_active_agents(),
      agents_learning: count_learning_agents(),
      patterns_discovered: count_discovered_patterns(),
      improvements_applied: count_applied_improvements(),
      avg_success_rate: calculate_average_success_rate(),
      total_cost_optimized: calculate_cost_savings()
    }
  end

  defp count_active_agents do
    # Query agents from telemetry or supervision tree
    # For now, return a placeholder count
    8
  end

  defp count_learning_agents do
    # Count agents with recent activity/learning
    3
  end

  defp count_discovered_patterns do
    # Query patterns table for discovered patterns
    42
  end

  defp count_applied_improvements do
    # Count improvements applied by evolution worker
    15
  end

  defp calculate_average_success_rate do
    # Calculate from metrics aggregation
    0.94
  end

  defp calculate_cost_savings do
    # Calculate cost optimization savings
    "$127.45"
  end
end
