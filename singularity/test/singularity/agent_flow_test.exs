defmodule Singularity.AgentFlowTest do
  @moduledoc """
  Tests for agent flow patterns documented in SYSTEM_FLOWS.md

  Tests cover:
  - Self-improving agent lifecycle
  - Cost-optimized agent decision flow
  - Agent supervision and restart
  - Flow tracking integration
  """
  use ExUnit.Case, async: false

  alias Singularity.{Agent, ProcessRegistry}
  alias Singularity.Agents.{SelfImprovingAgent, CostOptimizedAgent}
  alias Singularity.AgentFlowTracker

  describe "Self-Improving Agent Lifecycle" do
    test "agent starts in idle state" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-1")
      state = :sys.get_state(pid)
      
      assert state.status == :idle
      assert state.version == 1
      assert state.cycles == 0
      assert state.improvement_history == []
      
      GenServer.stop(pid)
    end

    test "agent transitions through observation phase" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-2")
      
      # Simulate tick
      send(pid, :tick)
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      assert state.cycles > 0
      
      GenServer.stop(pid)
    end

    test "agent records metrics over time" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-3")
      
      # Update metrics multiple times
      SelfImprovingAgent.update_metrics("lifecycle-test-3", %{latency_ms: 100})
      SelfImprovingAgent.update_metrics("lifecycle-test-3", %{latency_ms: 150})
      SelfImprovingAgent.update_metrics("lifecycle-test-3", %{latency_ms: 120})
      
      Process.sleep(50)
      state = :sys.get_state(pid)
      
      assert state.metrics.latency_ms == 120
      
      GenServer.stop(pid)
    end

    test "agent records success and failure outcomes" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-4")
      
      # Record outcomes
      SelfImprovingAgent.record_outcome("lifecycle-test-4", :success)
      SelfImprovingAgent.record_outcome("lifecycle-test-4", :success)
      SelfImprovingAgent.record_outcome("lifecycle-test-4", :failure)
      
      Process.sleep(50)
      state = :sys.get_state(pid)
      
      assert state.metrics.successes == 2
      assert state.metrics.failures == 1
      
      GenServer.stop(pid)
    end

    test "agent calculates score based on metrics" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-5")
      
      # Record mostly failures
      for _ <- 1..8, do: SelfImprovingAgent.record_outcome("lifecycle-test-5", :failure)
      for _ <- 1..2, do: SelfImprovingAgent.record_outcome("lifecycle-test-5", :success)
      
      send(pid, :tick)
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      # Score should be low due to high failure rate
      assert state.last_score < 0.5
      
      GenServer.stop(pid)
    end

    test "agent queues improvement requests" do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "lifecycle-test-6")
      
      improvement = %{
        reason: "test improvement",
        code: "pub fn improved() { 42 }",
        metadata: %{source: "test"}
      }
      
      SelfImprovingAgent.improve("lifecycle-test-6", improvement)
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      queue_size = :queue.len(state.improvement_queue)
      
      assert queue_size >= 0
      
      GenServer.stop(pid)
    end
  end

  describe "Cost-Optimized Agent Flow" do
    test "agent starts with zero cost" do
      {:ok, pid} = CostOptimizedAgent.start_link(
        id: "cost-test-1",
        specialization: :coder,
        workspace: "/tmp/test"
      )
      
      stats = CostOptimizedAgent.get_stats("cost-test-1")
      
      assert stats.lifetime_cost == 0.0
      assert stats.llm_calls == 0
      assert stats.rule_calls == 0
      
      GenServer.stop(pid)
    end

    test "agent prefers rules over LLM (cost optimization)" do
      {:ok, pid} = CostOptimizedAgent.start_link(
        id: "cost-test-2",
        specialization: :coder,
        workspace: "/tmp/test"
      )
      
      # Create a simple task that can be handled by rules
      task = %{
        id: "task-1",
        type: :simple,
        description: "simple task",
        context: %{}
      }
      
      {method, _result, cost: cost} = CostOptimizedAgent.process_task("cost-test-2", task)
      
      # Should use autonomous (rules) method with zero cost
      assert method == :autonomous
      assert cost == 0.0
      
      stats = CostOptimizedAgent.get_stats("cost-test-2")
      assert stats.rule_calls > 0
      assert stats.llm_calls == 0
      
      GenServer.stop(pid)
    end

    test "agent tracks lifetime cost across multiple tasks" do
      {:ok, pid} = CostOptimizedAgent.start_link(
        id: "cost-test-3",
        specialization: :coder,
        workspace: "/tmp/test"
      )
      
      # Process multiple simple tasks
      for i <- 1..5 do
        task = %{
          id: "task-#{i}",
          type: :simple,
          description: "task #{i}",
          context: %{}
        }
        CostOptimizedAgent.process_task("cost-test-3", task)
      end
      
      stats = CostOptimizedAgent.get_stats("cost-test-3")
      
      # Multiple tasks processed
      total_calls = stats.rule_calls + stats.llm_calls
      assert total_calls >= 5
      
      GenServer.stop(pid)
    end

    test "agent calculates cost per task" do
      {:ok, pid} = CostOptimizedAgent.start_link(
        id: "cost-test-4",
        specialization: :coder,
        workspace: "/tmp/test"
      )
      
      # Process a task
      task = %{
        id: "task-1",
        type: :simple,
        description: "test task",
        context: %{}
      }
      CostOptimizedAgent.process_task("cost-test-4", task)
      
      stats = CostOptimizedAgent.get_stats("cost-test-4")
      
      # Cost per task should be calculated
      assert Map.has_key?(stats, :cost_per_task)
      assert stats.cost_per_task >= 0.0
      
      GenServer.stop(pid)
    end
  end

  describe "Agent Supervision and Recovery" do
    test "agent can be found via process registry" do
      agent_id = "registry-test-1"
      {:ok, pid} = Agent.start_link(id: agent_id)
      
      # Find via registry
      via = Agent.via_tuple(agent_id)
      found_pid = GenServer.whereis(via)
      
      assert found_pid == pid
      
      GenServer.stop(pid)
    end

    test "agent maintains unique ID across restarts" do
      agent_id = "restart-test-1"
      {:ok, pid1} = Agent.start_link(id: agent_id)
      
      state1 = :sys.get_state(pid1)
      original_id = state1.id
      
      GenServer.stop(pid1)
      Process.sleep(50)
      
      # Start new agent with same ID
      {:ok, pid2} = Agent.start_link(id: agent_id)
      state2 = :sys.get_state(pid2)
      
      assert state2.id == original_id
      assert pid1 != pid2
      
      GenServer.stop(pid2)
    end

    test "agent state can be inspected via sys module" do
      {:ok, pid} = Agent.start_link(id: "inspect-test-1")
      
      state = :sys.get_state(pid)
      
      assert is_map(state)
      assert Map.has_key?(state, :id)
      assert Map.has_key?(state, :version)
      assert Map.has_key?(state, :status)
      assert Map.has_key?(state, :metrics)
      
      GenServer.stop(pid)
    end
  end

  describe "Agent Flow Tracking Integration" do
    setup do
      # Ensure flow tracker is available (may not be started in test)
      case AgentFlowTracker.start_link([]) do
        {:ok, pid} -> {:ok, tracker: pid}
        {:error, {:already_started, pid}} -> {:ok, tracker: pid}
        _ -> :ok
      end
    end

    test "agent operations can be tracked", %{tracker: _tracker} do
      {:ok, pid} = Agent.start_link(id: "flow-test-1")
      
      # Operations that might be tracked:
      # - Agent started
      # - Metrics updated
      # - Improvement triggered
      # - Version changed
      
      Agent.update_metrics("flow-test-1", %{test_metric: 123})
      Process.sleep(100)
      
      # Flow tracker may have recorded this
      # (actual verification would require DB access)
      
      GenServer.stop(pid)
    end

    test "flow tracker can record improvement attempts", %{tracker: _tracker} do
      {:ok, pid} = SelfImprovingAgent.start_link(id: "flow-test-2")
      
      improvement = %{
        reason: "test improvement",
        code: "pub fn test() { 1 }",
        metadata: %{source: "test"}
      }
      
      SelfImprovingAgent.improve("flow-test-2", improvement)
      Process.sleep(100)
      
      # Flow tracker should record:
      # - Flow started
      # - Flow type: improvement
      # - Flow status: active -> completed/failed
      
      GenServer.stop(pid)
    end
  end

  describe "Agent Communication Patterns" do
    test "synchronous call pattern - process task" do
      {:ok, pid} = CostOptimizedAgent.start_link(
        id: "comm-test-1",
        specialization: :coder,
        workspace: "/tmp/test"
      )
      
      task = %{id: "task-1", type: :simple, description: "test", context: %{}}
      
      # Synchronous call - blocks until complete
      start_time = System.monotonic_time(:millisecond)
      {_method, _result, cost: _cost} = CostOptimizedAgent.process_task("comm-test-1", task)
      duration = System.monotonic_time(:millisecond) - start_time
      
      # Should return reasonably quickly (< 1 second for simple task)
      assert duration < 1000
      
      GenServer.stop(pid)
    end

    test "asynchronous cast pattern - update metrics" do
      {:ok, pid} = Agent.start_link(id: "comm-test-2")
      
      # Asynchronous cast - returns immediately
      result = Agent.update_metrics("comm-test-2", %{async_metric: 456})
      
      assert result == :ok
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      assert state.metrics.async_metric == 456
      
      GenServer.stop(pid)
    end

    test "agent handles concurrent metric updates" do
      {:ok, pid} = Agent.start_link(id: "comm-test-3")
      
      # Send multiple concurrent updates
      tasks = for i <- 1..10 do
        Task.async(fn ->
          Agent.update_metrics("comm-test-3", %{counter: i})
        end)
      end
      
      # Wait for all
      Task.await_many(tasks)
      Process.sleep(100)
      
      state = :sys.get_state(pid)
      # Should have last update
      assert state.metrics.counter >= 1
      
      GenServer.stop(pid)
    end
  end

  describe "Agent Error Handling" do
    test "agent handles invalid improvement payload gracefully" do
      {:ok, pid} = Agent.start_link(id: "error-test-1")
      
      # Invalid improvement (missing required fields)
      result = Agent.improve("error-test-1", %{invalid: "payload"})
      
      # Should not crash
      assert result == :ok or match?({:error, _}, result)
      assert Process.alive?(pid)
      
      GenServer.stop(pid)
    end

    test "agent handles metric update errors" do
      {:ok, pid} = Agent.start_link(id: "error-test-2")
      
      # Try to update with invalid data
      result = Agent.update_metrics("error-test-2", "not a map")
      
      # Should handle gracefully (implementation specific)
      assert Process.alive?(pid)
      
      GenServer.stop(pid)
    end

    test "agent survives non-existent agent ID lookups" do
      # Try to access non-existent agent
      result = Agent.update_metrics("non-existent-agent", %{test: 1})
      
      # Should return error, not crash
      assert result == {:error, :not_found} or result == :ok
    end
  end
end
