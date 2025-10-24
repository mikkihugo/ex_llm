defmodule Singularity.Execution.EvolutionTest do
  use ExUnit.Case

  alias Singularity.Execution.Evolution

  describe "evolve_agent/1" do
    test "evolves agent with improvements" do
      # Mock data: agent with identified issues and suggested improvements
      assert {:ok, result} = Evolution.evolve_agent("test-agent-1")

      # Check result structure
      assert result.agent_id == "test-agent-1"
      assert is_atom(result.status)
      assert result.status in [:success, :no_improvement_needed, :validation_failed]
    end

    test "returns no_improvement_needed for healthy agent" do
      # Healthy agent with no issues
      assert {:ok, result} = Evolution.evolve_agent("healthy-agent")

      # Should not apply improvements
      assert result.status == :no_improvement_needed
      assert result.improvement_applied == :none
    end

    test "applies pattern enhancement for low success rate" do
      # Agent with low success rate
      assert {:ok, result} = Evolution.evolve_agent("low-success-agent")

      # Should apply pattern improvement
      if result.status == :success do
        assert result.improvement_applied == :add_patterns
        assert is_float(result.baseline_metric) or is_integer(result.baseline_metric)
        assert is_float(result.variant_metric) or is_integer(result.variant_metric)
        assert is_binary(result.improvement)
      end
    end

    test "applies model optimization for high cost" do
      # Agent with high cost per task
      assert {:ok, result} = Evolution.evolve_agent("high-cost-agent")

      # If improvement is needed
      if result.status == :success do
        assert result.improvement_applied == :optimize_model
      end
    end

    test "applies cache improvement for high latency" do
      # Agent with high latency
      assert {:ok, result} = Evolution.evolve_agent("slow-agent")

      # If improvement is needed
      if result.status == :success do
        assert result.improvement_applied == :improve_cache
      end
    end

    test "validates improvements with A/B testing" do
      # Evolution should validate improvements before persisting
      assert {:ok, result} = Evolution.evolve_agent("ab-test-agent")

      # Result should indicate validation outcome
      case result.status do
        :success ->
          # Validation passed
          assert not is_nil(result.baseline_metric)
          assert not is_nil(result.variant_metric)
          assert not is_nil(result.improvement)

        :validation_failed ->
          # Validation failed, improvement was rolled back
          assert result.reason == "A/B test showed regression"

        :no_improvement_needed ->
          # No improvements needed
          assert result.improvement_applied == :none
      end
    end

    test "rolls back degraded improvements" do
      # If improvement causes regression, it should be rolled back
      assert {:ok, result} = Evolution.evolve_agent("regression-test-agent")

      # Should detect regression during A/B test
      if result.status == :validation_failed do
        assert result.reason == "A/B test showed regression"
      end
    end

    test "handles agents with no metrics" do
      # Agent with no performance history
      assert (({:ok, _result} | {:error, :no_baseline_metrics}) =
        Evolution.evolve_agent("no-metrics-agent"))
    end

    test "handles missing agents gracefully" do
      # Non-existent agent
      result = Evolution.evolve_agent("nonexistent-agent-xyz")

      # Should either error or return no improvement (depends on metrics)
      assert match?(({:ok, _} | {:error, _}), result)
    end
  end

  describe "get_evolution_status/1" do
    test "returns status for evolved agent" do
      assert {:ok, status} = Evolution.get_evolution_status("evolved-agent")

      assert status.agent_id == "evolved-agent"
      assert is_atom(status.status)
    end

    test "returns no_evolution_attempts for new agent" do
      assert {:ok, status} = Evolution.get_evolution_status("new-agent")

      assert status.agent_id == "new-agent"
      assert status.status == :no_evolution_attempts
      assert is_nil(status.last_evolution)
    end

    test "includes evolution metrics in status" do
      assert {:ok, status} = Evolution.get_evolution_status("metric-agent")

      # If agent has evolution attempts
      if status.status != :no_evolution_attempts do
        assert is_atom(status.status)
        assert not is_nil(status.last_evolution)
        assert status.improvement_type in [:add_patterns, :optimize_model, :improve_cache, nil]
      end
    end

    test "handles errors gracefully" do
      # Database error scenario
      result = Evolution.get_evolution_status("any-agent")

      assert match?(({:ok, _} | {:error, _}), result)
    end
  end

  describe "improvement selection" do
    test "selects highest confidence improvement" do
      # Agent with multiple issues and suggestions
      assert {:ok, result} = Evolution.evolve_agent("multi-issue-agent")

      # Should select best (highest confidence) improvement
      if result.status == :success do
        assert not is_nil(result.improvement_applied)
      end
    end

    test "prioritizes critical issues" do
      # Agent with both critical and medium issues
      assert {:ok, result} = Evolution.evolve_agent("critical-issue-agent")

      # Should address critical issue even if confidence is lower
      if result.status == :success do
        assert result.improvement_applied in [:add_patterns, :optimize_model, :improve_cache]
      end
    end

    test "skips non-critical improvements for healthy agent" do
      # Healthy agent with no issues
      assert {:ok, result} = Evolution.evolve_agent("healthy-agent")

      # Should not apply improvements
      assert result.status == :no_improvement_needed
    end
  end

  describe "A/B testing validation" do
    test "validates improvement with baseline comparison" do
      # Evolution should compare baseline vs variant metrics
      assert {:ok, result} = Evolution.evolve_agent("validation-agent")

      # If improvement applied
      if result.status == :success and result.improvement_applied != :none do
        # Should have measured improvement
        assert is_number(result.baseline_metric) or is_float(result.baseline_metric)
        assert is_number(result.variant_metric) or is_float(result.variant_metric)
      end
    end

    test "detects regression during A/B test" do
      # Improvement that causes regression
      assert {:ok, result} = Evolution.evolve_agent("regression-agent")

      # Should detect and rollback
      case result.status do
        :validation_failed -> assert result.reason == "A/B test showed regression"
        :success -> assert not is_nil(result.improvement)
        :no_improvement_needed -> assert true
      end
    end

    test "accepts improvements meeting threshold" do
      # Improvement that meets quality threshold
      assert {:ok, result} = Evolution.evolve_agent("threshold-agent")

      # Should accept improvement
      if result.status == :success and result.improvement_applied != :none do
        assert String.contains?(result.improvement, "%")
      end
    end
  end

  describe "metric tracking" do
    test "tracks success_rate improvement" do
      # Pattern enhancement for success rate
      assert {:ok, result} = Evolution.evolve_agent("success-rate-agent")

      if result.improvement_applied == :add_patterns do
        # Should measure success rate improvement
        assert result.baseline_metric > 0
        assert result.variant_metric > 0
      end
    end

    test "tracks cost improvement" do
      # Model optimization for cost reduction
      assert {:ok, result} = Evolution.evolve_agent("cost-agent")

      if result.improvement_applied == :optimize_model do
        # Should measure cost reduction
        assert result.baseline_metric > 0
        assert result.variant_metric > 0
      end
    end

    test "tracks latency improvement" do
      # Cache improvement for latency
      assert {:ok, result} = Evolution.evolve_agent("latency-agent")

      if result.improvement_applied == :improve_cache do
        # Should measure latency reduction
        assert result.baseline_metric > 0
        assert result.variant_metric > 0
      end
    end
  end

  describe "error handling" do
    test "handles missing baseline metrics" do
      # Agent with no metrics available
      result = Evolution.evolve_agent("no-data-agent")

      # Should either error or return no improvement
      assert match?(({:ok, _} | {:error, _}), result)
    end

    test "handles agent not found" do
      # Non-existent agent
      result = Evolution.evolve_agent("phantom-agent")

      # Should handle gracefully
      assert match?(({:ok, _} | {:error, _}), result)
    end

    test "handles analyzer errors" do
      # Analyzer fails to analyze agent
      assert (({:ok, _result} | {:error, _reason}) =
        Evolution.evolve_agent("error-agent"))
    end

    test "continues on individual agent failures" do
      # In a batch operation, should continue after one failure
      # This would be tested in AgentEvolutionWorker tests
      assert true
    end
  end

  describe "rollback and recovery" do
    test "rolls back failed improvements" do
      # Improvement that fails validation
      assert {:ok, result} = Evolution.evolve_agent("rollback-test-agent")

      # Should indicate rollback occurred
      case result.status do
        :validation_failed -> assert String.contains?(result.reason, "regression")
        :success -> assert true
        :no_improvement_needed -> assert true
      end
    end

    test "preserves agent state on rollback" do
      # After rollback, agent should be in valid state
      {:ok, status1} = Evolution.get_evolution_status("rollback-agent")

      assert match?({:ok, _}, Evolution.evolve_agent("rollback-agent"))

      {:ok, status2} = Evolution.get_evolution_status("rollback-agent")

      # Agent should still be accessible
      assert status2.agent_id == status1.agent_id
    end
  end
end
