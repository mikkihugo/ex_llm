defmodule Singularity.InfrastructurePatternsTest do
  use ExUnit.Case, async: false

  alias Singularity.Infrastructure.ErrorHandling
  alias Singularity.Infrastructure.ErrorRateTracker
  alias Singularity.Monitoring.AgentTaskTracker

  setup_all do
    # Ensure the ETS-backed tracker is available for the suite.
    unless Process.whereis(ErrorRateTracker) do
      start_supervised!(ErrorRateTracker)
    end

    :ok
  end

  describe "ErrorHandling.safe_operation/2" do
    test "returns result tuple on success" do
      assert {:ok, :fine} = ErrorHandling.safe_operation(fn -> :fine end)
    end

    test "wraps exceptions with structured error data" do
      {:error, error_data} =
        ErrorHandling.safe_operation(fn -> raise "boom" end, context: %{operation: :test})

      assert error_data.error == :internal_error
      assert error_data.operation == :test
      assert error_data.message =~ "boom"
    end
  end

  describe "ErrorRateTracker" do
    test "tracks success and error rates" do
      ErrorRateTracker.record_error(:quantum_flow_job, RuntimeError.exception("oops"))
      ErrorRateTracker.record_success(:quantum_flow_job)

      stats = ErrorRateTracker.get_rate(:quantum_flow_job)

      assert stats.error_count >= 1
      assert stats.total_count >= 1
      assert is_float(stats.error_rate)
    end
  end

  describe "AgentTaskTracker telemetry" do
    test "emits telemetry events for task lifecycles" do
      handler_id = {:agent_task_tracker_test, self()}

      :ok =
        :telemetry.attach(
          handler_id,
          [:singularity, :agent_task, :started],
          fn event, measurements, metadata, _config ->
            send(self(), {:telemetry_event, event, measurements, metadata})
          end,
          nil
        )

      AgentTaskTracker.track_start(%{id: "task-123", agent_type: "integration"})

      assert_receive {:telemetry_event, [:singularity, :agent_task, :started], %{count: 1},
                      %{id: "task-123", agent_type: "integration"}},
                     500
    after
      :telemetry.detach({:agent_task_tracker_test, self()})
    end
  end

  describe "ErrorClassification" do
    test "classifies argument errors as validation" do
      type =
        Singularity.Infrastructure.ErrorClassification.classify_exception(
          ArgumentError.exception("oops")
        )

      assert type == :validation_error
    end
  end

  describe "ProcessRegistry" do
    test "exposes QuantumFlow-focused keyword registry" do
      keywords = Singularity.ProcessRegistry.process_keywords()

      assert Map.has_key?(keywords, "QuantumFlow.WorkflowSupervisor")
      assert Map.has_key?(keywords, "Singularity.Infrastructure.Overseer")
    end
  end

  describe "Resilience helpers" do
    test "with_retry eventually succeeds" do
      counter = :counters.new(1, [:atomics])

      {:ok, :success} =
        Singularity.Infrastructure.Resilience.with_retry(fn ->
          attempt = :counters.get(counter, 1)

          if attempt < 2 do
            :counters.put(counter, 1, attempt + 1)
            raise "transient"
          else
            {:ok, :success}
          end
        end)
    end

    test "with_timeout falls back when operation exceeds limit" do
      result =
        Singularity.Infrastructure.Resilience.with_timeout(
          fn ->
            Process.sleep(10)
            :ok
          end,
          timeout_ms: 1,
          fallback: fn -> :fallback end
        )

      assert {:ok, :fallback} = result
    end
  end
end
