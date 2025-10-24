defmodule Singularity.Metrics.EventAggregatorTest do
  use Singularity.DataCase

  alias Singularity.Metrics.{EventAggregator, Event, AggregatedData}
  alias Singularity.Repo

  describe "calculate_statistics/1" do
    test "calculates statistics from measurements" do
      measurements = [1, 2, 3, 4, 5]
      stats = EventAggregator.calculate_statistics(measurements)

      assert stats.count == 5
      assert stats.sum == 15
      assert stats.avg == 3.0
      assert stats.min == 1
      assert stats.max == 5
      assert stats.stddev > 0
    end

    test "handles empty list" do
      stats = EventAggregator.calculate_statistics([])

      assert stats.count == 0
      assert stats.sum == 0
      assert stats.avg == 0
      assert stats.min == nil
      assert stats.max == nil
      assert stats.stddev == nil
    end

    test "handles single measurement" do
      stats = EventAggregator.calculate_statistics([42])

      assert stats.count == 1
      assert stats.sum == 42
      assert stats.avg == 42.0
      assert stats.min == 42
      assert stats.max == 42
      assert stats.stddev == 0.0
    end
  end

  describe "aggregate_by_period/2" do
    test "aggregates all events by period" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Insert test events
      for i <- 1..10 do
        Repo.insert!(%Event{
          event_name: "test.metric",
          measurement: float(i),
          unit: "count",
          tags: %{"type" => "test"},
          recorded_at: DateTime.add(hour_ago, i * 100, :second)
        })
      end

      # Aggregate
      {:ok, aggregations} = EventAggregator.aggregate_by_period(:hour, {hour_ago, now})

      # Verify aggregation
      assert length(aggregations) >= 1

      agg = Enum.find(aggregations, fn a -> a.event_name == "test.metric" end)
      assert agg != nil
      assert agg.count == 10
      assert agg.period == "hour"
    end

    test "aggregation is idempotent" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Insert test event
      Repo.insert!(%Event{
        event_name: "test.idempotent",
        measurement: 42,
        unit: "count",
        tags: %{},
        recorded_at: hour_ago
      })

      # Aggregate twice
      {:ok, agg1} = EventAggregator.aggregate_by_period(:hour, {hour_ago, now})
      {:ok, agg2} = EventAggregator.aggregate_by_period(:hour, {hour_ago, now})

      # Should have same result, no duplicates
      assert length(agg1) == length(agg2)

      # Check database - should only have one aggregation entry
      count = Repo.aggregate(AggregatedData, :count)
      assert count == 1
    end
  end

  describe "aggregate_events_by_name/3" do
    test "aggregates specific event type" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Insert mixed events
      for i <- 1..5 do
        Repo.insert!(%Event{
          event_name: "metric.a",
          measurement: float(i),
          unit: "count",
          tags: %{},
          recorded_at: hour_ago
        })
      end

      for i <- 1..3 do
        Repo.insert!(%Event{
          event_name: "metric.b",
          measurement: float(i),
          unit: "count",
          tags: %{},
          recorded_at: hour_ago
        })
      end

      # Aggregate only metric.a
      {:ok, aggregations} =
        EventAggregator.aggregate_events_by_name("metric.a", :hour, {hour_ago, now})

      agg = List.first(aggregations)
      assert agg.event_name == "metric.a"
      assert agg.count == 5
    end
  end

  describe "aggregate_events_with_tags/3" do
    test "aggregates events matching tag filters" do
      now = DateTime.utc_now()
      hour_ago = DateTime.add(now, -3600, :second)

      # Insert events with different tags
      for i <- 1..5 do
        Repo.insert!(%Event{
          event_name: "api.call",
          measurement: float(i),
          unit: "count",
          tags: %{"service" => "openai"},
          recorded_at: hour_ago
        })
      end

      for i <- 1..3 do
        Repo.insert!(%Event{
          event_name: "api.call",
          measurement: float(i),
          unit: "count",
          tags: %{"service" => "anthropic"},
          recorded_at: hour_ago
        })
      end

      # Aggregate only openai
      {:ok, aggregations} =
        EventAggregator.aggregate_events_with_tags(
          %{"service" => "openai"},
          :hour,
          {hour_ago, now}
        )

      agg = List.first(aggregations)
      assert agg.count == 5
      assert agg.tags["service"] == "openai"
    end
  end

  defp float(i) do
    i * 1.0
  end
end
