defmodule Singularity.Metrics.EventCollectorTest do
  use Singularity.DataCase

  alias Singularity.Metrics.{EventCollector, Event}
  alias Singularity.Repo

  describe "record_measurement/4" do
    test "records raw measurement event" do
      EventCollector.record_measurement("test.metric", 42.5, "count", %{source: "test"})

      # Give async task time to complete
      Process.sleep(100)

      # Verify event in database
      event = Repo.get_by(Event, event_name: "test.metric")
      assert event != nil
      assert event.measurement == 42.5
      assert event.unit == "count"
      assert event.tags["source"] == "test"
    end

    test "rejects invalid measurements (NaN)" do
      EventCollector.record_measurement("test.nan", :nan, "count", %{})
      Process.sleep(100)

      # Should not create event with NaN
      count = Repo.aggregate(Event, :count)
      assert count == 0
    end

    test "enriches tags with environment and node" do
      EventCollector.record_measurement("test.enriched", 1, "count", %{})
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "test.enriched")
      assert event.tags["environment"] != nil
      assert event.tags["node"] != nil
    end
  end

  describe "record_cost_spent/3" do
    test "records cost with convenience function" do
      EventCollector.record_cost_spent(:api_call, 0.025, %{service: "openai"})
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "api_call.cost")
      assert event != nil
      assert event.measurement == 0.025
      assert event.unit == "usd"
      assert event.tags["service"] == "openai"
    end
  end

  describe "record_latency_ms/3" do
    test "records latency with convenience function" do
      EventCollector.record_latency_ms(:search_query, 245, %{query_type: "semantic"})
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "search_query.latency")
      assert event != nil
      assert event.measurement == 245
      assert event.unit == "ms"
      assert event.tags["query_type"] == "semantic"
    end
  end

  describe "record_agent_success/3" do
    test "records agent success" do
      EventCollector.record_agent_success("agent-123", true, 2500)
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "agent.success")
      assert event != nil
      assert event.measurement == 1
      assert event.unit == "count"
      assert event.tags["agent_id"] == "agent-123"
      assert event.tags["latency_ms"] == 2500
    end

    test "records agent failure" do
      EventCollector.record_agent_success("agent-456", false, 500)
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "agent.failure")
      assert event != nil
      assert event.measurement == 0
      assert event.tags["agent_id"] == "agent-456"
    end
  end

  describe "record_search_completed/3" do
    test "records search metrics" do
      EventCollector.record_search_completed("async patterns", 42, 245)
      Process.sleep(100)

      event = Repo.get_by(Event, event_name: "search.completed")
      assert event != nil
      assert event.measurement == 42
      assert event.unit == "count"
      assert event.tags["query"] == "async patterns"
      assert event.tags["latency_ms"] == 245
    end
  end
end
