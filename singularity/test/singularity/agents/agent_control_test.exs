defmodule Singularity.Agents.AgentControlTest do
  @moduledoc """
  Tests for agent control operations (pause, resume, improve).

  Tests:
  - Pause individual agents
  - Resume individual agents
  - Pause all agents via supervisor
  - Resume all agents via supervisor
  - Improve specific agents
  - Query pause state
  """

  use Singularity.DataCase, async: false

  alias Singularity.Agents.{Agent, AgentSupervisor, AgentSpawner}

  @moduletag :integration

  describe "individual agent pause/resume" do
    setup do
      # Spawn test agent
      {:ok, agent} =
        AgentSpawner.spawn(%{
          "role" => "test_agent",
          "config" => %{}
        })

      {:ok, agent: agent}
    end

    test "pause individual agent", %{agent: agent} do
      agent_id = agent.id

      # Agent should not be paused initially
      refute Agent.paused?(agent_id) == true

      # Pause the agent
      assert :ok = Agent.pause(agent_id)

      # Agent should now be paused
      assert Agent.paused?(agent_id) == true
    end

    test "resume individual agent", %{agent: agent} do
      agent_id = agent.id

      # First pause it
      :ok = Agent.pause(agent_id)
      assert Agent.paused?(agent_id) == true

      # Resume the agent
      assert :ok = Agent.resume(agent_id)

      # Agent should no longer be paused
      assert Agent.paused?(agent_id) == false
    end

    test "pause returns error for non-existent agent" do
      assert {:error, :not_found} = Agent.pause("non-existent-agent-id")
    end

    test "resume returns error for non-existent agent" do
      assert {:error, :not_found} = Agent.resume("non-existent-agent-id")
    end

    test "paused? returns error for non-existent agent" do
      assert {:error, :not_found} = Agent.paused?("non-existent-agent-id")
    end
  end

  describe "supervisor-level pause/resume" do
    setup do
      # Spawn multiple test agents
      agents =
        for i <- 1..3 do
          {:ok, agent} =
            AgentSpawner.spawn(%{
              "role" => "test_agent_#{i}",
              "config" => %{}
            })

          agent
        end

      {:ok, agents: agents}
    end

    test "pause all agents", %{agents: agents} do
      # All agents should be unpaused initially
      agents
      |> Enum.each(fn agent ->
        refute Agent.paused?(agent.id) == true
      end)

      # Pause all
      assert :ok = AgentSupervisor.pause_all_agents()

      # All should now be paused
      agents
      |> Enum.each(fn agent ->
        assert Agent.paused?(agent.id) == true
      end)
    end

    test "resume all agents", %{agents: agents} do
      # First pause all
      :ok = AgentSupervisor.pause_all_agents()

      agents
      |> Enum.each(fn agent ->
        assert Agent.paused?(agent.id) == true
      end)

      # Resume all
      assert :ok = AgentSupervisor.resume_all_agents()

      # All should now be unpaused
      agents
      |> Enum.each(fn agent ->
        assert Agent.paused?(agent.id) == false
      end)
    end

    test "pause_all_agents with no agents returns ok" do
      # This should handle the case gracefully
      # First resume any paused agents to get a clean state
      :ok = AgentSupervisor.resume_all_agents()

      # Get initial count
      initial_count = AgentSupervisor.get_all_agents() |> length()

      # If there are agents, pause them
      if initial_count > 0 do
        :ok = AgentSupervisor.pause_all_agents()
      end

      # Should still work without error
      assert :ok = AgentSupervisor.pause_all_agents()
    end
  end

  describe "agent improvement" do
    setup do
      # Spawn test agent
      {:ok, agent} =
        AgentSpawner.spawn(%{
          "role" => "test_agent",
          "config" => %{}
        })

      {:ok, agent: agent}
    end

    test "improve specific agent", %{agent: agent} do
      agent_id = agent.id

      # Submit improvement request
      assert :ok =
               AgentSupervisor.improve_agent(agent_id, %{
                 type: :optimization,
                 description: "Test improvement"
               })
    end

    test "improve returns error for non-existent agent" do
      assert {:error, :not_found} =
               AgentSupervisor.improve_agent("non-existent-agent-id", %{
                 type: :optimization
               })
    end

    test "improve with empty payload works" do
      {:ok, agent} =
        AgentSpawner.spawn(%{
          "role" => "test_agent",
          "config" => %{}
        })

      assert :ok = AgentSupervisor.improve_agent(agent.id, %{})
    end
  end

  describe "pause state tracking" do
    setup do
      # Spawn test agent
      {:ok, agent} =
        AgentSpawner.spawn(%{
          "role" => "test_agent",
          "config" => %{}
        })

      {:ok, agent: agent}
    end

    test "pause state persists across operations", %{agent: agent} do
      agent_id = agent.id

      # Pause agent
      :ok = Agent.pause(agent_id)

      # Verify paused
      assert Agent.paused?(agent_id) == true

      # Resume agent
      :ok = Agent.resume(agent_id)

      # Verify unpaused
      assert Agent.paused?(agent_id) == false

      # Pause again
      :ok = Agent.pause(agent_id)

      # Verify paused
      assert Agent.paused?(agent_id) == true
    end

    test "multiple pause calls are idempotent", %{agent: agent} do
      agent_id = agent.id

      # Pause multiple times
      assert :ok = Agent.pause(agent_id)
      assert :ok = Agent.pause(agent_id)
      assert :ok = Agent.pause(agent_id)

      # Should still be paused
      assert Agent.paused?(agent_id) == true
    end

    test "multiple resume calls are idempotent", %{agent: agent} do
      agent_id = agent.id

      # Pause first
      :ok = Agent.pause(agent_id)

      # Resume multiple times
      assert :ok = Agent.resume(agent_id)
      assert :ok = Agent.resume(agent_id)
      assert :ok = Agent.resume(agent_id)

      # Should still be unpaused
      assert Agent.paused?(agent_id) == false
    end
  end

  describe "get all agents" do
    setup do
      # Spawn multiple agents
      agents =
        for i <- 1..5 do
          {:ok, agent} =
            AgentSpawner.spawn(%{
              "role" => "test_agent_#{i}",
              "config" => %{}
            })

          agent
        end

      {:ok, agents: agents}
    end

    test "get_all_agents returns list of PIDs", %{agents: agents} do
      pids = AgentSupervisor.get_all_agents()

      # Should have at least as many as we spawned
      assert length(pids) >= length(agents)

      # All should be valid PIDs
      assert Enum.all?(pids, &is_pid/1)
    end

    test "all returned PIDs are alive" do
      pids = AgentSupervisor.get_all_agents()

      # All PIDs should be for living processes
      assert Enum.all?(pids, &Process.alive?/1)
    end
  end
end
