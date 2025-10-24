defmodule Singularity.Learning.GenesisIntegrationTest do
  @moduledoc """
  Integration tests for Genesis ↔ Singularity experiment flow.

  Tests the complete flow:
  1. Singularity requests an experiment via ExperimentRequester
  2. Genesis completes the experiment (simulated)
  3. Genesis publishes result to NATS
  4. ExperimentResultConsumer receives and stores result
  5. ExperimentRequester retrieves result and returns to caller
  """

  use Singularity.DataCase

  alias Singularity.Learning.{ExperimentResult, ExperimentRequester}

  describe "ExperimentResult.record/2" do
    test "stores Genesis experiment result in database" do
      experiment_id = "exp-test-#{System.unique_integer()}"

      genesis_result = %{
        "status" => "success",
        "metrics" => %{
          "success_rate" => 0.95,
          "llm_reduction" => 0.38,
          "regression" => 0.02,
          "runtime_ms" => 3600000
        },
        "recommendation" => "merge_with_adaptations",
        "risk_level" => "medium",
        "timestamp" => DateTime.utc_now()
      }

      # Record the result
      assert {:ok, recorded_result} = ExperimentResult.record(experiment_id, genesis_result)

      # Verify fields
      assert recorded_result.experiment_id == experiment_id
      assert recorded_result.status == "success"
      assert recorded_result.recommendation == "merge_with_adaptations"
      assert recorded_result.metrics["success_rate"] == 0.95
      assert recorded_result.risk_level == "medium"
    end

    test "enforces unique constraint on experiment_id" do
      experiment_id = "exp-unique-#{System.unique_integer()}"

      genesis_result = %{
        "status" => "success",
        "metrics" => %{},
        "recommendation" => "merge",
        "timestamp" => DateTime.utc_now()
      }

      # First record should succeed
      assert {:ok, _} = ExperimentResult.record(experiment_id, genesis_result)

      # Second record with same ID should fail
      assert {:error, changeset} = ExperimentResult.record(experiment_id, genesis_result)
      assert changeset.errors[:experiment_id]
    end

    test "defaults recommendation to rollback if missing" do
      experiment_id = "exp-default-#{System.unique_integer()}"

      genesis_result = %{
        "status" => "success",
        "metrics" => %{},
        "timestamp" => DateTime.utc_now()
        # No recommendation field
      }

      assert {:ok, result} = ExperimentResult.record(experiment_id, genesis_result)
      assert result.recommendation == "rollback"
    end

    test "validates status values" do
      experiment_id = "exp-invalid-#{System.unique_integer()}"

      genesis_result = %{
        "status" => "invalid_status",  # Invalid status
        "metrics" => %{},
        "recommendation" => "merge",
        "timestamp" => DateTime.utc_now()
      }

      assert {:error, changeset} = ExperimentResult.record(experiment_id, genesis_result)
      assert changeset.errors[:status]
    end

    test "validates recommendation values" do
      experiment_id = "exp-invalid-rec-#{System.unique_integer()}"

      genesis_result = %{
        "status" => "success",
        "metrics" => %{},
        "recommendation" => "invalid_recommendation",  # Invalid recommendation
        "timestamp" => DateTime.utc_now()
      }

      assert {:error, changeset} = ExperimentResult.record(experiment_id, genesis_result)
      assert changeset.errors[:recommendation]
    end
  end

  describe "ExperimentResult.get_by_type/2" do
    test "queries results by experiment type" do
      # Create multiple results with different descriptions
      for i <- 1..3 do
        experiment_id = "exp-pattern-#{i}-#{System.unique_integer()}"

        ExperimentResult.record(experiment_id, %{
          "status" => "success",
          "metrics" => %{},
          "recommendation" => "merge",
          "changes_description" => "Add pattern cache to pattern miner",
          "timestamp" => DateTime.utc_now()
        })
      end

      # Query by type
      results = ExperimentResult.get_by_type("pattern cache", limit: 10)

      # Should find at least one result
      assert length(results) >= 1

      # All should have matching description
      assert Enum.all?(results, fn r ->
        String.contains?(r.changes_description || "", "pattern cache") or
          String.contains?(r.changes_description || "", "pattern miner")
      end)
    end
  end

  describe "ExperimentResult.get_success_rate/1" do
    test "calculates success rate for experiment type" do
      experiment_type = "async worker #{System.unique_integer()}"

      # Create 10 results: 8 successful, 2 failed
      for i <- 1..10 do
        experiment_id = "exp-rate-#{i}-#{System.unique_integer()}"

        status = if i <= 8, do: "success", else: "failed"

        ExperimentResult.record(experiment_id, %{
          "status" => status,
          "metrics" => %{},
          "recommendation" => "merge",
          "changes_description" => experiment_type,
          "timestamp" => DateTime.utc_now()
        })
      end

      # Get success rate
      rate_info = ExperimentResult.get_success_rate(experiment_type)

      # Should have statistics
      assert rate_info != nil
      assert rate_info.successful >= 0
      assert rate_info.total >= 0
      assert is_float(rate_info.rate)
    end
  end

  describe "ExperimentResult.get_insights/1" do
    test "provides insights for learning" do
      experiment_type = "learning insights #{System.unique_integer()}"

      # Create 20 results with various outcomes
      for i <- 1..20 do
        experiment_id = "exp-insight-#{i}-#{System.unique_integer()}"

        # 15 successful with low regression, 5 with high regression
        regression = if i <= 15, do: 0.01, else: 0.08

        ExperimentResult.record(experiment_id, %{
          "status" => "success",
          "metrics" => %{
            "success_rate" => 0.95,
            "regression" => regression,
            "llm_reduction" => 0.35
          },
          "recommendation" => if(i <= 15, do: "merge", else: "rollback"),
          "changes_description" => experiment_type,
          "timestamp" => DateTime.utc_now()
        })
      end

      # Get insights
      assert {:ok, insights} = ExperimentResult.get_insights(experiment_type)

      # Should have learning data
      assert is_map(insights)
      assert Map.has_key?(insights, :success_rate)
      assert Map.has_key?(insights, :total_experiments)
      assert Map.has_key?(insights, :avg_metrics)
      assert Map.has_key?(insights, :failure_patterns)
      assert Map.has_key?(insights, :recommendation)
    end

    test "returns error when no results exist" do
      nonexistent_type = "nonexistent-#{System.unique_integer()}"
      assert {:error, :no_results} = ExperimentResult.get_insights(nonexistent_type)
    end
  end

  describe "ExperimentRequester.request_improvement/1" do
    test "generates valid experiment request" do
      {:ok, experiment_id} =
        ExperimentRequester.request_improvement(
          changes_description: "Test improvement",
          risk_level: "low",
          estimated_impact: 0.25,
          test_plan: "Run test suite"
        )

      # Should return an experiment ID
      assert is_binary(experiment_id)
      assert String.starts_with?(experiment_id, "exp-")
    end

    test "uses defaults when options not provided" do
      {:ok, experiment_id} = ExperimentRequester.request_improvement()

      assert is_binary(experiment_id)
      assert String.starts_with?(experiment_id, "exp-")
    end
  end

  describe "ExperimentRequester.wait_for_result/2" do
    test "times out when result not found" do
      experiment_id = "exp-notfound-#{System.unique_integer()}"

      # Wait with short timeout
      result = ExperimentRequester.wait_for_result(experiment_id, timeout: 100)

      assert {:error, :timeout} = result
    end

    test "returns result when found in database" do
      experiment_id = "exp-found-#{System.unique_integer()}"

      # Pre-populate database
      genesis_result = %{
        "status" => "success",
        "metrics" => %{"success_rate" => 0.95},
        "recommendation" => "merge",
        "timestamp" => DateTime.utc_now()
      }

      {:ok, _} = ExperimentResult.record(experiment_id, genesis_result)

      # Wait for result (should find immediately)
      assert {:ok, result} = ExperimentRequester.wait_for_result(experiment_id, timeout: 5000)
      assert result.experiment_id == experiment_id
      assert result.status == "success"
    end
  end
end
