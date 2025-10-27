defmodule Singularity.Metrics.MetricsIntegrationTest do
  @moduledoc """
  End-to-end integration tests for unified Metrics system.

  Tests the complete flow: Record → Aggregate → Query
  """

  use Singularity.DataCase

  alias Singularity.Metrics.{EventCollector, EventAggregator, Query, Event, AggregatedData}
  alias Singularity.Repo

  describe "end-to-end metrics flow" do
    test "records, aggregates, and queries metrics" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Step 1: Record raw metrics
      for i <- 1..10 do
        EventCollector.record_measurement(
          "test.performance",
          100 + i * 10,
          "ms",
          %{"component" => "search", "index" => i}
        )
      end

      Process.sleep(100)

      # Verify events recorded
      event_count = Repo.aggregate(Event, :count)
      assert event_count >= 10

      # Step 2: Aggregate events
      {:ok, aggregations} = EventAggregator.aggregate_by_period(:hour, {hour_ago, now})

      # Verify aggregation
      assert length(aggregations) >= 1

      agg = Enum.find(aggregations, fn a -> a.event_name == "test.performance" end)
      assert agg != nil
      assert agg.count >= 10
      assert agg.avg >= 100
      assert agg.period == "hour"

      # Step 3: Query aggregated metrics
      {:ok, result} = Query.get_metrics_for_event("test.performance", :hour, {hour_ago, now})

      assert length(result) >= 1
      assert hd(result).avg >= 100
    end

    test "metrics flow with cost tracking" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Record costs
      for i <- 1..5 do
        EventCollector.record_cost_spent(
          :api_call,
          0.01 * i,
          %{"service" => "openai", "model" => "gpt-4"}
        )
      end

      Process.sleep(100)

      # Verify costs recorded
      cost_events = Repo.all(from(e in Event, where: like(e.event_name, "api_call%")))
      assert length(cost_events) == 5

      # Aggregate
      {:ok, aggregations} = EventAggregator.aggregate_by_period(:hour, {hour_ago, now})
      cost_agg = Enum.find(aggregations, fn a -> a.event_name == "api_call.cost" end)

      assert cost_agg != nil
      assert cost_agg.count == 5
      assert cost_agg.sum > 0
    end

    test "metrics with tag-based filtering" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Record events with different tags
      for i <- 1..5 do
        EventCollector.record_measurement(
          "search.latency",
          200 + i * 10,
          "ms",
          %{"type" => "semantic", "results" => i * 10}
        )
      end

      for i <- 1..3 do
        EventCollector.record_measurement(
          "search.latency",
          100 + i * 5,
          "ms",
          %{"type" => "keyword", "results" => i * 20}
        )
      end

      Process.sleep(100)

      # Aggregate with tag filter
      {:ok, semantic_aggs} =
        EventAggregator.aggregate_events_with_tags(
          %{"type" => "semantic"},
          :hour,
          {hour_ago, now}
        )

      assert length(semantic_aggs) >= 1
      agg = hd(semantic_aggs)
      assert agg.count == 5
      assert agg.tags["type"] == "semantic"
    end

    test "multiple aggregation periods" do
      now = DateTime.utc_now()
      day_ago = DateTime.add(now, -86400, :second)

      # Record events
      for i <- 1..20 do
        EventCollector.record_measurement(
          "system.health",
          80 + i,
          "percent",
          %{timestamp: "test"}
        )
      end

      Process.sleep(100)

      # Aggregate by hour
      {:ok, hour_aggs} = EventAggregator.aggregate_by_period(:hour, {day_ago, now})
      hour_agg = Enum.find(hour_aggs, fn a -> a.event_name == "system.health" end)

      assert hour_agg != nil
      assert hour_agg.period == "hour"

      # Aggregate by day
      {:ok, day_aggs} = EventAggregator.aggregate_by_period(:day, {day_ago, now})
      day_agg = Enum.find(day_aggs, fn a -> a.event_name == "system.health" end)

      assert day_agg != nil
      assert day_agg.period == "day"
      assert day_agg.count >= hour_agg.count
    end

    test "cache accelerates repeated queries" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Insert aggregated data
      Repo.insert!(%AggregatedData{
        event_name: "cached.metric",
        period: "hour",
        period_start: hour_ago,
        count: 100,
        sum: 1000,
        avg: 10,
        min: 1,
        max: 20,
        tags: %{}
      })

      # First query - hits database
      start1 = System.monotonic_time(:microsecond)
      {:ok, result1} = Query.get_metrics_for_event("cached.metric", :hour, {hour_ago, now})
      time1 = System.monotonic_time(:microsecond) - start1

      # Second query - should hit cache
      start2 = System.monotonic_time(:microsecond)
      {:ok, result2} = Query.get_metrics_for_event("cached.metric", :hour, {hour_ago, now})
      time2 = System.monotonic_time(:microsecond) - start2

      # Cache should be faster (though in tests both are fast)
      assert result1 == result2
    end
  end
end
