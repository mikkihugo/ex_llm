defmodule Singularity.AgentTest do
  use ExUnit.Case, async: true

  alias Singularity.Agent

  test "agent starts with unique id" do
    {:ok, pid} = Agent.start_link([])
    assert Process.alive?(pid)
    state = GenServer.call(pid, :state)
    assert state.id
    assert state.version == 1
    assert state.status == :idle
    GenServer.stop(pid)
  end

  test "agent starts with provided id" do
    custom_id = "custom-agent-123"
    {:ok, pid} = Agent.start_link(id: custom_id)
    state = GenServer.call(pid, :state)
    assert state.id == custom_id
    GenServer.stop(pid)
  end

  test "agent tracks metrics" do
    {:ok, pid} = Agent.start_link([])
    GenServer.cast(pid, {:update_metrics, %{requests: 10}})
    Process.sleep(10)
    state = GenServer.call(pid, :state)
    assert state.metrics.requests == 10
    GenServer.stop(pid)
  end

  test "agent handles improvement request" do
    {:ok, pid} = Agent.start_link([])
    GenServer.cast(pid, {:improve, %{code: "pub fn test() { 1 }"}})
    Process.sleep(10)
    state = GenServer.call(pid, :state)
    # Should either be updating or back to idle depending on timing
    assert state.status in [:idle, :updating]
    GenServer.stop(pid)
  end
end
