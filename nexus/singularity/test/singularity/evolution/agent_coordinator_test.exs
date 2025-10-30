defmodule Singularity.Evolution.AgentCoordinatorTest do
  use Singularity.DataCase, async: false

  alias Singularity.Evolution.{AgentCoordinator, SafetyProfiles, MetricsReporter}
  alias Singularity.Database.MessageQueue

  @moduletag :integration

  setup do
    # Start required services
    {:ok, coordinator_pid} = start_supervised({AgentCoordinator, instance_id: "test_instance"})
    {:ok, profiles_pid} = start_supervised(SafetyProfiles)
    {:ok, reporter_pid} = start_supervised(MetricsReporter)

    # Clean up test queues
    clean_test_queues()

    %{
      coordinator: coordinator_pid,
      profiles: profiles_pid,
      reporter: reporter_pid
    }
  end

  describe "propose_change/3" do
    test "proposes change to CentralCloud Guardian successfully" do
      change = %{
        type: :refactor,
        files: ["lib/test_module.ex"],
        description: "Extract function for better readability"
      }

      metadata = %{
        confidence: 0.95,
        blast_radius: :low
      }

      assert {:ok, change_record} =
               AgentCoordinator.propose_change(
                 TestAgent,
                 change,
                 metadata
               )

      assert change_record.id =~ "change-test_instance"
      assert change_record.status == :pending
      assert change_record.agent_type == TestAgent
      assert change_record.change == change
    end

    test "validates change before proposal" do
      invalid_change = %{description: "Missing type field"}

      assert {:error, :invalid_change} =
               AgentCoordinator.propose_change(
                 TestAgent,
                 invalid_change,
                 %{}
               )
    end

    test "includes safety profile in change proposal" do
      # Register custom profile
      SafetyProfiles.register_profile(TestAgent, %{
        error_threshold: 0.02,
        needs_consensus: true,
        max_blast_radius: :medium
      })

      change = %{type: :optimize, files: ["lib/performance.ex"]}

      {:ok, change_record} = AgentCoordinator.propose_change(TestAgent, change, %{})

      assert change_record.safety_profile.error_threshold == 0.02
      assert change_record.safety_profile.needs_consensus == true
      assert change_record.safety_profile.max_blast_radius == :medium
    end
  end

  describe "record_pattern/3" do
    test "records pattern to CentralCloud Aggregator successfully" do
      pattern = %{
        name: "extract_function",
        code: "def extracted_fn...",
        success_rate: 0.98,
        applicability: [:elixir, :refactoring]
      }

      assert {:ok, :recorded} =
               AgentCoordinator.record_pattern(
                 TestAgent,
                 :refactoring,
                 pattern
               )
    end

    test "validates pattern before recording" do
      valid_pattern = %{name: "test_pattern"}

      assert {:ok, :recorded} =
               AgentCoordinator.record_pattern(
                 TestAgent,
                 :architecture,
                 valid_pattern
               )
    end
  end

  describe "await_consensus/1" do
    test "waits for consensus approval" do
      change = %{type: :refactor, files: ["lib/test.ex"]}

      {:ok, change_record} = AgentCoordinator.propose_change(TestAgent, change, %{})

      # Simulate consensus response in background
      Task.start(fn ->
        Process.sleep(100)
        simulate_consensus_response(change_record.id, "approved")
      end)

      assert {:ok, :approved} = AgentCoordinator.await_consensus(change_record.id, 5_000)
    end

    test "returns rejected when consensus rejects" do
      change = %{type: :risky_change, files: ["lib/critical.ex"]}

      {:ok, change_record} = AgentCoordinator.propose_change(TestAgent, change, %{})

      # Simulate rejection
      Task.start(fn ->
        Process.sleep(100)
        simulate_consensus_response(change_record.id, "rejected")
      end)

      assert {:ok, :rejected} = AgentCoordinator.await_consensus(change_record.id, 5_000)
    end

    test "returns error for non-existent change" do
      assert {:error, :not_found} = AgentCoordinator.await_consensus("nonexistent-change-123")
    end
  end

  describe "handle_rollback/1" do
    test "handles rollback request from CentralCloud Guardian" do
      change = %{type: :refactor, files: ["lib/test.ex"]}

      {:ok, change_record} = AgentCoordinator.propose_change(TestAgent, change, %{})

      # Simulate rollback
      assert {:ok, :rolled_back} = AgentCoordinator.handle_rollback(change_record.id)

      # Verify status updated
      assert {:ok, :rolled_back} = AgentCoordinator.get_change_status(change_record.id)
    end

    test "returns error for non-existent change rollback" do
      assert {:error, :not_found} = AgentCoordinator.handle_rollback("nonexistent-123")
    end
  end

  describe "get_change_status/1" do
    test "returns current status of proposed change" do
      change = %{type: :refactor, files: ["lib/test.ex"]}

      {:ok, change_record} = AgentCoordinator.propose_change(TestAgent, change, %{})

      assert {:ok, :pending} = AgentCoordinator.get_change_status(change_record.id)
    end

    test "returns not_found for unknown change" do
      assert {:error, :not_found} = AgentCoordinator.get_change_status("unknown-change")
    end
  end

  describe "MetricsReporter integration" do
    test "records single metric successfully" do
      assert :ok =
               MetricsReporter.record_metric(
                 TestAgent,
                 :execution_time,
                 125.5
               )

      # Allow time for cache update
      Process.sleep(50)

      assert {:ok, metrics} = MetricsReporter.get_metrics(TestAgent)
      assert metrics[:execution_time] == [125.5]
    end

    test "records multiple metrics at once" do
      metrics = %{
        execution_time: 98.3,
        success_rate: 0.97,
        error_count: 2
      }

      assert :ok = MetricsReporter.record_metrics(TestAgent, metrics)

      Process.sleep(50)

      assert {:ok, cached} = MetricsReporter.get_metrics(TestAgent)
      assert cached[:execution_time] == [98.3]
      assert cached[:success_rate] == [0.97]
      assert cached[:error_count] == [2]
    end

    test "flushes metrics to CentralCloud" do
      MetricsReporter.record_metric(TestAgent, :execution_time, 100.0)
      MetricsReporter.record_metric(TestAgent, :execution_time, 110.0)

      assert :ok = MetricsReporter.flush()

      # Verify stats updated
      stats = MetricsReporter.get_stats()
      assert stats.total_batches_sent > 0
      assert stats.total_metrics_recorded >= 2
    end

    test "calculates aggregate statistics" do
      # Record multiple values for averaging
      MetricsReporter.record_metric(TestAgent, :latency, 100)
      MetricsReporter.record_metric(TestAgent, :latency, 150)
      MetricsReporter.record_metric(TestAgent, :latency, 125)

      Process.sleep(50)

      {:ok, cached} = MetricsReporter.get_metrics(TestAgent)
      assert length(cached[:latency]) == 3
      assert 100 in cached[:latency]
      assert 150 in cached[:latency]
      assert 125 in cached[:latency]
    end
  end

  describe "SafetyProfiles integration" do
    test "retrieves default profile for unregistered agent" do
      {:ok, profile} = SafetyProfiles.get_profile(UnregisteredAgent)

      assert profile.error_threshold == 0.05
      assert profile.needs_consensus == false
      assert profile.max_blast_radius == :low
    end

    test "retrieves predefined profile for registered agent" do
      {:ok, profile} = SafetyProfiles.get_profile(Singularity.Agents.QualityEnforcer)

      assert profile.error_threshold == 0.01
      assert profile.needs_consensus == true
      assert profile.max_blast_radius == :medium
    end

    test "registers and retrieves custom profile" do
      custom_profile = %{
        error_threshold: 0.001,
        needs_consensus: true,
        max_blast_radius: :high,
        auto_rollback: true
      }

      assert :ok = SafetyProfiles.register_profile(CustomAgent, custom_profile)

      {:ok, retrieved} = SafetyProfiles.get_profile(CustomAgent)
      assert retrieved.error_threshold == 0.001
      assert retrieved.needs_consensus == true
      assert retrieved.max_blast_radius == :high
    end

    test "updates existing profile" do
      SafetyProfiles.register_profile(UpdateAgent, %{
        error_threshold: 0.05,
        needs_consensus: false,
        max_blast_radius: :low
      })

      assert :ok = SafetyProfiles.update_profile(UpdateAgent, %{error_threshold: 0.01})

      {:ok, updated} = SafetyProfiles.get_profile(UpdateAgent)
      assert updated.error_threshold == 0.01
      assert updated.needs_consensus == false
    end

    test "validates profile values" do
      invalid_profile = %{
        error_threshold: 2.0,
        needs_consensus: true,
        max_blast_radius: :low
      }

      assert {:error, :error_threshold_out_of_range} =
               SafetyProfiles.register_profile(InvalidAgent, invalid_profile)
    end

    test "lists all profiles" do
      profiles = SafetyProfiles.all_profiles()

      assert is_map(profiles)
      assert Map.has_key?(profiles, Singularity.Agents.QualityEnforcer)
      assert Map.has_key?(profiles, Singularity.Agents.RefactoringAgent)
    end
  end

  describe "full workflow integration" do
    test "complete agent coordination flow with consensus" do
      # 1. Propose change
      change = %{
        type: :refactor,
        files: ["lib/example.ex"],
        description: "Full workflow test"
      }

      {:ok, change_record} =
        AgentCoordinator.propose_change(
          TestAgent,
          change,
          %{confidence: 0.95}
        )

      assert change_record.status == :pending

      # 2. Record metrics during execution
      MetricsReporter.record_metrics(TestAgent, %{
        execution_time: 145.0,
        success_rate: 0.98
      })

      # 3. Simulate consensus approval
      Task.start(fn ->
        Process.sleep(100)
        simulate_consensus_response(change_record.id, "approved")
      end)

      # 4. Wait for consensus
      assert {:ok, :approved} = AgentCoordinator.await_consensus(change_record.id, 5_000)

      # 5. Record pattern learned
      pattern = %{
        name: "workflow_pattern",
        success_rate: 0.98
      }

      assert {:ok, :recorded} =
               AgentCoordinator.record_pattern(TestAgent, :refactoring, pattern)

      # 6. Verify final state
      assert {:ok, :approved} = AgentCoordinator.get_change_status(change_record.id)
    end

    test "rollback workflow when error threshold exceeded" do
      # 1. Propose change with strict profile
      SafetyProfiles.register_profile(StrictAgent, %{
        error_threshold: 0.01,
        needs_consensus: true,
        max_blast_radius: :low
      })

      change = %{type: :risky_refactor, files: ["lib/critical.ex"]}

      {:ok, change_record} =
        AgentCoordinator.propose_change(StrictAgent, change, %{})

      # 2. Simulate high error rate metrics
      MetricsReporter.record_metrics(StrictAgent, %{
        error_count: 15,
        success_rate: 0.85
      })

      # 3. Trigger rollback
      assert {:ok, :rolled_back} = AgentCoordinator.handle_rollback(change_record.id)

      # 4. Verify rollback status
      assert {:ok, :rolled_back} = AgentCoordinator.get_change_status(change_record.id)
    end
  end

  ## Test Helpers

  defp clean_test_queues do
    queues = [
      "centralcloud_changes",
      "centralcloud_patterns",
      "consensus_responses",
      "rollback_events",
      "agent_metrics"
    ]

    Enum.each(queues, fn queue ->
      try do
        MessageQueue.create_queue(queue)

        # Drain existing messages
        drain_queue(queue)
      rescue
        _ -> :ok
      end
    end)
  end

  defp drain_queue(queue_name) do
    case MessageQueue.receive_message(queue_name) do
      {:ok, {msg_id, _message}} ->
        MessageQueue.acknowledge(queue_name, msg_id)
        drain_queue(queue_name)

      :empty ->
        :ok

      {:error, _} ->
        :ok
    end
  end

  defp simulate_consensus_response(change_id, decision) do
    message = %{
      "change_id" => change_id,
      "decision" => decision,
      "consensus_score" => 0.87,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    MessageQueue.send_message("consensus_responses", Jason.encode!(message))
  end

  # Test agent module for testing
  defmodule TestAgent do
    @behaviour Singularity.Agents.AgentBehavior

    @impl true
    def execute_task(_task, _context), do: {:ok, :completed}

    @impl true
    def get_agent_type, do: :test_agent

    @impl true
    def get_safety_profile(_context) do
      %{
        error_threshold: 0.05,
        needs_consensus: false,
        max_blast_radius: :low
      }
    end
  end
end
