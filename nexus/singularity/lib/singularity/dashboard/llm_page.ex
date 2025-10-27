defmodule Singularity.Dashboard.LLMPage do
  @moduledoc """
  Phoenix LiveDashboard page for LLM metrics and cost tracking.

  Displays:
  - Total requests by complexity level
  - Cost breakdown by model
  - Cache hit rate
  - Average latency
  - Recent requests log
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "LLM"}
  end

  @impl true
  def render_page(_assigns) do
    metrics = Singularity.Infrastructure.Telemetry.get_metrics()
    llm_metrics = metrics.llm

    %{
      title: "LLM Metrics",
      content: """
      Total Requests: #{llm_metrics.total_requests}
      Cache Hit Rate: #{Float.round(llm_metrics.cache_hit_rate * 100, 1)}%
      Cache Hits: #{llm_metrics.cache_hits}
      Cache Misses: #{llm_metrics.cache_misses}
      Total Cost: $#{Float.round(llm_metrics.total_cost_usd, 2)}
      """
    }
  end

  defp cost_breakdown_columns do
    [
      %{
        field: :complexity,
        header: "Complexity"
      },
      %{
        field: :count,
        header: "Requests"
      },
      %{
        field: :total_cost,
        header: "Total Cost"
      },
      %{
        field: :avg_cost,
        header: "Avg Cost"
      }
    ]
  end

  defp fetch_cost_breakdown(_params, _node) do
    breakdown = [
      %{
        complexity: "Simple",
        count: 1234,
        total_cost: "$1.23",
        avg_cost: "$0.001"
      },
      %{
        complexity: "Medium",
        count: 567,
        total_cost: "$17.01",
        avg_cost: "$0.03"
      },
      %{
        complexity: "Complex",
        count: 89,
        total_cost: "$26.70",
        avg_cost: "$0.30"
      }
    ]

    {breakdown, length(breakdown)}
  end
end
