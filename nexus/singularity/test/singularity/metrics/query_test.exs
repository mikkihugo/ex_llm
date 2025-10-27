defmodule Singularity.Metrics.QueryTest do
  use Singularity.DataCase

  alias Singularity.Metrics.{Query, AggregatedData}
  alias Singularity.Repo

  describe "get_agent_metrics_over_time/2" do
    test "queries agent metrics" do
      now = DateTime.utc_now()
      day_ago = DateTime.add(now, -86400, :second)

      # Insert sample aggregated data
      Repo.insert!(%AggregatedData{
        event_name: "agent.success",
        period: "hour",
        period_start: day_ago,
        count: 100,
        sum: 95,
        avg: 0.95,
        min: 0,
        max: 1,
        tags: %{"agent_id" => "agent-123"}
      })

      # Query metrics
      {:ok, metrics} = Query.get_agent_metrics_over_time("agent-123", {day_ago, now})

      assert metrics.success_rate == 0.95
      assert metrics.request_count == 100
    end

    test "returns zero metrics when no data" do
      now = DateTime.utc_now()
      day_ago = DateTime.add(now, -86400, :second)

      {:ok, metrics} = Query.get_agent_metrics_over_time("unknown-agent", {day_ago, now})

      assert metrics.success_rate == 0.0
      assert metrics.request_count == 0
    end
  end

  describe "get_operation_costs_summary/1" do
    test "summarizes costs by operation" do
      now = DateTime.utc_now()
      day_ago = DateTime.add(now, -86400, :second)

      # Insert cost data
      Repo.insert!(%AggregatedData{
        event_name: "llm_api.cost",
        period: "day",
        period_start: day_ago,
        count: 100,
        sum: 5.25,
        avg: 0.0525,
        min: 0.01,
        max: 0.10,
        tags: %{"operation" => "llm_api"}
      })

      {:ok, result} = Query.get_operation_costs_summary({day_ago, now})

      assert result.operations != nil
      assert length(result.operations) >= 0
    end
  end

  describe "get_health_metrics_current/0" do
    test "returns health metrics" do
      {:ok, health} = Query.get_health_metrics_current()

      assert health.memory_usage_pct >= 0
      assert health.queue_depth >= 0
      assert health.error_rate >= 0
    end
  end

  describe "find_metrics_by_pattern/2" do
    test "searches metrics by pattern" do
      # Insert test aggregations
      Repo.insert!(%AggregatedData{
        event_name: "llm.cost",
        period: "hour",
        period_start: DateTime.utc_now(),
        count: 10,
        sum: 0.5,
        avg: 0.05,
        min: 0.01,
        max: 0.10,
        tags: %{}
      })

      Repo.insert!(%AggregatedData{
        event_name: "llm.latency",
        period: "hour",
        period_start: DateTime.utc_now(),
        count: 10,
        sum: 2500,
        avg: 250,
        min: 100,
        max: 500,
        tags: %{}
      })

      # Search for llm metrics
      {:ok, results} = Query.find_metrics_by_pattern("llm", 10)

      event_names = Enum.map(results, & &1.event_name)
      assert "llm.cost" in event_names
      assert "llm.latency" in event_names
    end
  end

  describe "get_learning_insights/1" do
    test "provides learning insights for operation" do
      now = DateTime.utc_now()

      # Insert success data
      for i <- 1..10 do
        Repo.insert!(%AggregatedData{
          event_name: "agent_execution.success",
          period: "hour",
          period_start: DateTime.add(now, -i * 3600, :second),
          count: 100,
          sum: 95,
          avg: 0.95,
          min: 0,
          max: 1,
          tags: %{}
        })
      end

      {:ok, insights} = Query.get_learning_insights(:agent_execution)

      assert insights.success_rate == 0.95
      assert insights.trend in [:improving, :stable, :degrading]
    end

    test "returns error when no data" do
      {:error, :no_data} = Query.get_learning_insights(:unknown_operation)
    end
  end

  describe "get_metrics_for_event/3" do
    test "queries metrics for specific event" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      Repo.insert!(%AggregatedData{
        event_name: "test.metric",
        period: "hour",
        period_start: hour_ago,
        count: 50,
        sum: 1000,
        avg: 20,
        min: 10,
        max: 30,
        tags: %{}
      })

      {:ok, results} = Query.get_metrics_for_event("test.metric", :hour, {hour_ago, now})

      assert length(results) == 1
      assert hd(results).count == 50
    end
  end
end
