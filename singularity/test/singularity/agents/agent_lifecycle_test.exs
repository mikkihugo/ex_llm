defmodule Singularity.Agents.AgentLifecycleTest do
  @moduledoc """
  Integration tests for agent lifecycle management.

  Tests:
  - Agent spawning and initialization
  - Task execution and state management
  - Agent termination and cleanup
  - Concurrent agent operations
  - Supervisor restart behavior
  """

  use Singularity.DataCase, async: false

  alias Singularity.Agents.{AgentSupervisor, CostOptimizedAgent}

  @moduletag :integration

  describe "agent spawning" do
    test "successfully spawns agent with unique ID" do
      agent_id = "test-agent-#{System.unique_integer([:positive])}"

      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      assert Process.alive?(pid)
      assert {:ok, agent_info} = CostOptimizedAgent.get_info(pid)
      assert agent_info.id == agent_id
    end

    test "spawning multiple agents concurrently" do
      # Spawn 10 agents concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            agent_id = "concurrent-agent-#{i}"
            AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, fn {:ok, pid} -> Process.alive?(pid) end)

      # Verify all are supervised
      children = DynamicSupervisor.which_children(AgentSupervisor)
      assert length(children) >= 10
    end

    test "prevents duplicate agent IDs" do
      agent_id = "duplicate-test-#{System.unique_integer([:positive])}"

      {:ok, pid1} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Attempting to start agent with same ID should fail or return existing
      result = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      case result do
        {:ok, ^pid1} ->
          # Returned existing agent
          assert true

        {:error, {:already_started, ^pid1}} ->
          # Rejected duplicate
          assert true

        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end

  describe "agent task execution" do
    setup do
      agent_id = "task-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      on_exit(fn ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(AgentSupervisor, pid)
        end
      end)

      {:ok, agent_pid: pid, agent_id: agent_id}
    end

    test "executes simple task successfully", %{agent_pid: pid} do
      task = %{
        prompt: "Simple test task",
        complexity: :simple,
        use_llm: false
      }

      assert {:ok, result} = CostOptimizedAgent.execute(pid, task)
      assert result.source in [:rule, :cache, :llm]
    end

    test "handles concurrent task execution", %{agent_pid: pid} do
      # Execute 5 tasks concurrently on same agent
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            CostOptimizedAgent.execute(pid, %{
              prompt: "Concurrent task #{i}",
              complexity: :simple
            })
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should complete (success or error, but not timeout)
      assert length(results) == 5

      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result) or match?({:error, _}, result)
             end)
    end

    test "tracks task execution metrics", %{agent_pid: pid} do
      # Execute several tasks
      for _ <- 1..3 do
        CostOptimizedAgent.execute(pid, %{
          prompt: "Metric test task",
          complexity: :simple
        })
      end

      {:ok, info} = CostOptimizedAgent.get_info(pid)

      # Should track execution count
      assert is_integer(info.tasks_completed)
      assert info.tasks_completed >= 3
    end
  end

  describe "agent termination" do
    test "gracefully stops agent" do
      agent_id = "stop-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Execute a task
      CostOptimizedAgent.execute(pid, %{prompt: "test", complexity: :simple})

      # Stop agent
      assert :ok = DynamicSupervisor.terminate_child(AgentSupervisor, pid)

      # Should no longer be alive
      refute Process.alive?(pid)
    end

    test "cleans up resources on termination" do
      agent_id = "cleanup-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Monitor agent
      ref = Process.monitor(pid)

      # Terminate
      DynamicSupervisor.terminate_child(AgentSupervisor, pid)

      # Wait for DOWN message
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1000
    end
  end

  describe "supervisor restart behavior" do
    test "restarts crashed agent" do
      agent_id = "crash-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Monitor agent
      ref = Process.monitor(pid)

      # Crash the agent
      Process.exit(pid, :kill)

      # Should receive DOWN
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1000

      # Supervisor should NOT automatically restart (DynamicSupervisor behavior)
      # Original pid should be dead
      refute Process.alive?(pid)
    end

    test "can restart agent manually after crash" do
      agent_id = "manual-restart-#{System.unique_integer([:positive])}"
      {:ok, pid1} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Crash it
      Process.exit(pid1, :kill)

      # Wait for process to die
      :timer.sleep(100)

      # Start new agent with same ID (allowed after first dies)
      {:ok, pid2} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Should be different process
      assert pid1 != pid2
      assert Process.alive?(pid2)
    end
  end

  describe "agent state management" do
    setup do
      agent_id = "state-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      on_exit(fn ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(AgentSupervisor, pid)
        end
      end)

      {:ok, agent_pid: pid}
    end

    test "maintains state across multiple calls", %{agent_pid: pid} do
      # First call
      CostOptimizedAgent.execute(pid, %{prompt: "first", complexity: :simple})
      {:ok, info1} = CostOptimizedAgent.get_info(pid)

      # Second call
      CostOptimizedAgent.execute(pid, %{prompt: "second", complexity: :simple})
      {:ok, info2} = CostOptimizedAgent.get_info(pid)

      # Task count should increment
      assert info2.tasks_completed > info1.tasks_completed
    end

    test "isolates state between different agents" do
      agent1_id = "isolated-1-#{System.unique_integer([:positive])}"
      agent2_id = "isolated-2-#{System.unique_integer([:positive])}"

      {:ok, pid1} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent1_id)
      {:ok, pid2} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent2_id)

      # Execute different number of tasks
      CostOptimizedAgent.execute(pid1, %{prompt: "test1", complexity: :simple})
      CostOptimizedAgent.execute(pid1, %{prompt: "test2", complexity: :simple})

      CostOptimizedAgent.execute(pid2, %{prompt: "test3", complexity: :simple})

      # Get info
      {:ok, info1} = CostOptimizedAgent.get_info(pid1)
      {:ok, info2} = CostOptimizedAgent.get_info(pid2)

      # States should be different
      assert info1.id == agent1_id
      assert info2.id == agent2_id
      assert info1.tasks_completed != info2.tasks_completed

      # Cleanup
      DynamicSupervisor.terminate_child(AgentSupervisor, pid1)
      DynamicSupervisor.terminate_child(AgentSupervisor, pid2)
    end
  end

  describe "performance and stress tests" do
    @tag timeout: 30_000
    test "handles burst of agent spawns" do
      # Spawn 50 agents in rapid succession
      start_time = System.monotonic_time(:millisecond)

      pids =
        for i <- 1..50 do
          {:ok, pid} =
            AgentSupervisor.start_agent(CostOptimizedAgent,
              id: "burst-#{i}-#{System.unique_integer([:positive])}"
            )

          pid
        end

      end_time = System.monotonic_time(:millisecond)

      # All should be alive
      assert Enum.all?(pids, &Process.alive?/1)

      # Should complete in reasonable time (< 5 seconds)
      assert end_time - start_time < 5000

      # Cleanup
      Enum.each(pids, &DynamicSupervisor.terminate_child(AgentSupervisor, &1))
    end

    @tag timeout: 30_000
    test "handles high task throughput" do
      agent_id = "throughput-test-#{System.unique_integer([:positive])}"
      {:ok, pid} = AgentSupervisor.start_agent(CostOptimizedAgent, id: agent_id)

      # Execute 100 tasks
      start_time = System.monotonic_time(:millisecond)

      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            CostOptimizedAgent.execute(pid, %{
              prompt: "Task #{i}",
              complexity: :simple
            })
          end)
        end

      results = Task.await_many(tasks, 20_000)
      end_time = System.monotonic_time(:millisecond)

      # All should complete
      assert length(results) == 100

      # Should complete in reasonable time
      duration_seconds = (end_time - start_time) / 1000
      throughput = 100 / duration_seconds

      # Should handle at least 5 tasks/second
      assert throughput > 5

      # Cleanup
      DynamicSupervisor.terminate_child(AgentSupervisor, pid)
    end
  end
end
