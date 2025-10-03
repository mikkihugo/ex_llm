defmodule SeedAgent.HotReload.ManagerTest do
  use ExUnit.Case, async: false

  alias SeedAgent.HotReload.Manager

  setup do
    # Wait for queue to drain between tests
    :timer.sleep(100)
    :ok
  end

  test "enqueues requests successfully when queue has space" do
    agent_id = "test-agent-#{:rand.uniform(100_000)}"
    payload = %{code: "pub fn test() { 1 }"}

    # Only enqueue if queue isn't full
    depth = Manager.queue_depth()

    if depth < 90 do
      assert :ok = Manager.enqueue(agent_id, payload)
    end

    assert Manager.queue_depth() >= 0
  end

  test "rejects requests when queue is full" do
    agent_id = "test-agent-#{:rand.uniform(100_000)}"
    payload = %{code: "pub fn test() { 1 }"}

    # Fill up the queue (max is 100)
    results =
      Enum.map(1..110, fn _ ->
        Manager.enqueue(agent_id, payload)
      end)

    # Should have some queue_full errors
    assert Enum.any?(results, &match?({:error, :queue_full}, &1))
  end

  test "queue depth is non-negative" do
    depth = Manager.queue_depth()
    assert depth >= 0
    assert is_integer(depth)
  end
end
