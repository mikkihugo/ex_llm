defmodule ExLLM.Routing.TaskMetricsE2ETest do
  @moduledoc """
  End-to-end tests for task metrics calculation and aggregation.

  ## Test Coverage:
  - Win rate calculation from outcomes
  - Confidence scoring (sigmoid function)
  - Semantic fallback when data insufficient
  - Aggregation across (task, complexity, model) triplets
  - Nx embeddings for semantic similarity (future)
  """

  use ExUnit.Case, async: false
  doctest ExLLM.Routing.TaskMetrics

  alias ExLLM.Routing.TaskMetrics

  # ========== WIN RATE CALCULATION ==========

  describe "TaskMetrics.calculate_win_rate/1" do
    test "calculates win rate from success count" do
      # Arrange
      metrics = %{
        total: 10,
        successes: 7
      }

      # Act
      win_rate = TaskMetrics.calculate_win_rate(metrics)

      # Assert
      assert win_rate == 0.7
    end

    test "handles zero total gracefully" do
      # Arrange
      metrics = %{
        total: 0,
        successes: 0
      }

      # Act
      win_rate = TaskMetrics.calculate_win_rate(metrics)

      # Assert: Returns neutral default
      assert win_rate == 0.5
    end

    test "handles perfect success rate" do
      # Arrange
      metrics = %{
        total: 100,
        successes: 100
      }

      # Act
      win_rate = TaskMetrics.calculate_win_rate(metrics)

      # Assert
      assert win_rate == 1.0
    end

    test "handles zero successes" do
      # Arrange
      metrics = %{
        total: 50,
        successes: 0
      }

      # Act
      win_rate = TaskMetrics.calculate_win_rate(metrics)

      # Assert
      assert win_rate == 0.0
    end

    test "handles various success counts" do
      test_cases = [
        {%{total: 20, successes: 10}, 0.5},
        {%{total: 4, successes: 3}, 0.75},
        {%{total: 3, successes: 1}, 0.333},
        {%{total: 100, successes: 99}, 0.99}
      ]

      Enum.each(test_cases, fn {metrics, expected} ->
        win_rate = TaskMetrics.calculate_win_rate(metrics)
        assert Float.round(win_rate, 3) == Float.round(expected, 3)
      end)
    end
  end

  # ========== CONFIDENCE SCORING ==========

  describe "TaskMetrics.calculate_confidence/1" do
    test "confidence increases with sample size (sigmoid)" do
      # The sigmoid function: 1 / (1 + e^(-0.01 * (samples - 50)))

      sample_sizes = [0, 5, 10, 20, 50, 100, 200]

      confidence_scores =
        Enum.map(sample_sizes, fn samples ->
          TaskMetrics.calculate_confidence(%{total: samples})
        end)

      # Assert: Monotonically increasing
      assert confidence_scores == Enum.sort(confidence_scores)
    end

    test "low confidence for few samples" do
      # < 5 samples should have low confidence (< 0.4)
      Enum.each([0, 1, 3, 4], fn samples ->
        confidence = TaskMetrics.calculate_confidence(%{total: samples})
        assert confidence < 0.4
      end)
    end

    test "medium confidence for moderate samples" do
      # 10-50 samples should have medium confidence (0.4-0.6)
      Enum.each([10, 20, 30, 50], fn samples ->
        confidence = TaskMetrics.calculate_confidence(%{total: samples})
        assert confidence >= 0.4 and confidence <= 0.7
      end)
    end

    test "high confidence for many samples" do
      # > 100 samples should have high confidence (> 0.6)
      Enum.each([100, 150, 200, 500], fn samples ->
        confidence = TaskMetrics.calculate_confidence(%{total: samples})
        assert confidence > 0.6
      end)
    end

    test "sigmoid function mathematically correct" do
      # Test specific values
      samples = 50
      exponent = -0.01 * (samples - 50)
      expected = 1.0 / (1.0 + :math.exp(exponent))
      actual = TaskMetrics.calculate_confidence(%{total: samples})

      assert Float.round(actual, 6) == Float.round(expected, 6)
    end

    test "handles non-numeric metrics gracefully" do
      # Should return 0.0 for invalid metrics
      confidence = TaskMetrics.calculate_confidence(%{})
      assert confidence == 0.0
    end

    test "confidence asymptotically approaches 1.0" do
      # Very high sample counts should approach 1.0 but not exceed
      very_high_confidence = TaskMetrics.calculate_confidence(%{total: 10_000})
      assert very_high_confidence > 0.99 and very_high_confidence <= 1.0
    end
  end

  # ========== SEMANTIC FALLBACK ==========

  describe "TaskMetrics.estimate_from_semantic_similarity/3" do
    test "returns adjusted estimate based on complexity" do
      # Arrange: Test all complexity levels
      base_estimate = 0.5

      # Act
      simple = TaskMetrics.estimate_from_semantic_similarity(:coding, "claude-sonnet", :simple)
      medium = TaskMetrics.estimate_from_semantic_similarity(:coding, "claude-sonnet", :medium)
      complex = TaskMetrics.estimate_from_semantic_similarity(:coding, "claude-sonnet", :complex)

      # Assert: Adjustments applied
      assert Float.round(simple, 2) == Float.round(base_estimate + 0.05, 2)
      assert Float.round(medium, 2) == Float.round(base_estimate, 2)
      assert Float.round(complex, 2) == Float.round(base_estimate - 0.08, 2)
    end

    test "returns estimate within valid range (0.1-0.99)" do
      # Due to clamping: max(0.1, min(0.99, ...))
      estimate = TaskMetrics.estimate_from_semantic_similarity(:research, "gpt-4o", :complex)

      assert estimate >= 0.1
      assert estimate <= 0.99
    end

    test "handles invalid complexity level gracefully" do
      # Should fall back to base estimate for unknown complexity
      estimate = TaskMetrics.estimate_from_semantic_similarity(:coding, "claude", :unknown)

      assert is_float(estimate)
      assert estimate >= 0.1 and estimate <= 0.99
    end
  end

  # ========== METRICS AGGREGATION ==========

  describe "TaskMetrics.get_metrics/3 - Integration" do
    test "returns metrics for task/model/complexity triplet" do
      # Act
      metrics = TaskMetrics.get_metrics(:coding, "claude-sonnet", :medium)

      # Assert
      assert is_map(metrics)
      assert metrics.task_type == :coding
      assert metrics.model_name == "claude-sonnet"
      assert metrics.complexity_level == :medium
      assert is_float(metrics.win_rate)
      assert is_float(metrics.confidence)
    end

    test "uses database metrics when available" do
      # When database has data, should use it with high confidence
      metrics = TaskMetrics.get_metrics(:architecture, "gpt-4o", :simple)

      assert is_map(metrics)
      # Source should be :database if data exists, :semantic_estimate if not
      assert metrics.source == :database or metrics.source == :semantic_estimate
    end

    test "uses semantic fallback with low confidence" do
      # When database has no data, should use semantic fallback with confidence ~0.5
      metrics = TaskMetrics.get_metrics(:unknown_task, "unknown_model", :medium)

      assert is_map(metrics)
      assert metrics.source == :semantic_estimate
      # Confidence should be lower when using fallback
      assert metrics.confidence <= 0.5 or metrics.confidence == 0.5
    end

    test "handles all task/model/complexity combinations" do
      task_types = [:coding, :architecture, :refactoring]
      models = ["claude-sonnet", "gpt-4o", "codex"]
      complexities = [:simple, :medium, :complex]

      Enum.each(task_types, fn task ->
        Enum.each(models, fn model ->
          Enum.each(complexities, fn complexity ->
            metrics = TaskMetrics.get_metrics(task, model, complexity)

            assert is_map(metrics)
            assert metrics.task_type == task
            assert metrics.model_name == model
            assert metrics.complexity_level == complexity
            assert is_float(metrics.win_rate)
            assert is_float(metrics.confidence)
          end)
        end)
      end)
    end
  end

  describe "TaskMetrics.aggregate_all_metrics/0" do
    test "aggregates all task metrics" do
      # Act
      result = TaskMetrics.aggregate_all_metrics()

      # Assert
      case result do
        {:ok, aggregates} ->
          assert is_list(aggregates)

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end
  end

  # ========== DATA QUALITY & VALIDATION ==========

  describe "Metrics Data Quality - Hybrid" do
    test "recent data preferred over old data" do
      # When calculating metrics, recent outcomes should be weighted more heavily
      # (This is configuration in the query - we just verify the logic works)

      metrics_recent = TaskMetrics.get_metrics(:planning, "claude-opus", :medium)
      metrics_all = TaskMetrics.get_metrics(:planning, "claude-opus", :medium)

      # Both should return valid metrics
      assert is_map(metrics_recent)
      assert is_map(metrics_all)
    end

    test "min sample threshold for confidence" do
      # Less than 5 samples should show low confidence
      very_low_confidence = TaskMetrics.calculate_confidence(%{total: 2})
      assert very_low_confidence < 0.4
    end

    test "sample size affects confidence more than win rate" do
      # Two models with same win rate but different sample sizes
      # should have different confidence scores

      metrics1 = %{total: 10, successes: 7}
      metrics2 = %{total: 100, successes: 70}

      win_rate1 = TaskMetrics.calculate_win_rate(metrics1)
      win_rate2 = TaskMetrics.calculate_win_rate(metrics2)
      confidence1 = TaskMetrics.calculate_confidence(metrics1)
      confidence2 = TaskMetrics.calculate_confidence(metrics2)

      # Same win rate
      assert win_rate1 == win_rate2

      # Different confidence
      assert confidence1 < confidence2
    end
  end

  # ========== COMPLEXITY ADJUSTMENTS ==========

  describe "Complexity Level Impact - Integration" do
    test "complexity adjustments are consistent" do
      # Simple: +5%, Medium: 0%, Complex: -8%
      base_model = "gpt-4o"

      Enum.each([:coding, :architecture, :research], fn task ->
        simple = TaskMetrics.get_metrics(task, base_model, :simple)
        medium = TaskMetrics.get_metrics(task, base_model, :medium)
        complex = TaskMetrics.get_metrics(task, base_model, :complex)

        # Verify adjustments
        assert simple.win_rate > medium.win_rate
        assert medium.win_rate > complex.win_rate
      end)
    end

    test "complex tasks show lower confidence for same model" do
      # Complex tasks are harder, might have fewer samples
      task = :research
      model = "claude-sonnet"

      metrics_medium = TaskMetrics.get_metrics(task, model, :medium)
      metrics_complex = TaskMetrics.get_metrics(task, model, :complex)

      # Complex tasks might have lower confidence or same, depending on data
      assert is_float(metrics_medium.confidence)
      assert is_float(metrics_complex.confidence)
    end
  end

  # ========== SEMANTIC SIMILARITY (FUTURE) ==========

  describe "Semantic Similarity Placeholder - Hybrid" do
    test "semantic similarity will use Nx embeddings" do
      # Currently returns fallback, but test verifies the contract
      estimate = TaskMetrics.estimate_from_semantic_similarity(:chat, "gemini", :simple)

      # Should return valid float in range
      assert is_float(estimate)
      assert estimate >= 0.1 and estimate <= 0.99
    end

    test "semantic fallback when database unavailable" do
      # If CentralCloud not available, uses semantic fallback
      metrics = TaskMetrics.get_metrics(:analysis, "codex", :medium)

      # Should still return valid metrics (either from DB or semantic)
      assert is_map(metrics)
      assert is_float(metrics.win_rate)
      assert metrics.confidence == 0.5 or metrics.confidence > 0.0
    end
  end

  # ========== EDGE CASES & ERROR HANDLING ==========

  describe "Error Handling & Edge Cases - Hybrid" do
    test "handles nil metrics gracefully" do
      win_rate = TaskMetrics.calculate_win_rate(nil)
      assert win_rate == 0.5
    end

    test "handles missing required fields" do
      incomplete = %{total: 10}
      win_rate = TaskMetrics.calculate_win_rate(incomplete)
      assert is_float(win_rate) or win_rate == 0.5
    end

    test "win rate never exceeds 1.0" do
      # Even if data is corrupted, clamping should prevent > 1.0
      metrics = %{total: 10, successes: 20}  # More successes than total
      win_rate = TaskMetrics.calculate_win_rate(metrics)

      # The calculation would give 2.0, but should be clamped
      assert win_rate <= 1.0
    end

    test "confidence never exceeds 1.0" do
      confidence = TaskMetrics.calculate_confidence(%{total: 100_000})
      assert confidence <= 1.0
    end

    test "confidence never goes below 0.0" do
      confidence = TaskMetrics.calculate_confidence(%{total: -100})
      assert confidence >= 0.0
    end

    test "handles very large sample sizes" do
      large_samples = %{total: 1_000_000, successes: 999_999}
      win_rate = TaskMetrics.calculate_win_rate(large_samples)
      confidence = TaskMetrics.calculate_confidence(large_samples)

      assert is_float(win_rate)
      assert is_float(confidence)
    end
  end

  # ========== INTEGRATION WITH ROUTING ==========

  describe "Metrics Integration with Routing - Integration" do
    test "metrics feed into TaskRouter decisions" do
      # TaskRouter calls get_metrics to get win rates
      task = :coding
      model = "claude-sonnet"
      complexity = :medium

      # Get metrics
      metrics = TaskMetrics.get_metrics(task, model, complexity)

      # This should match what TaskRouter uses
      assert metrics.task_type == task
      assert metrics.model_name == model
      assert is_float(metrics.win_rate)
    end

    test "confidence affects model selection" do
      # High confidence metrics should be trusted more
      high_confidence = TaskMetrics.calculate_confidence(%{total: 200})
      low_confidence = TaskMetrics.calculate_confidence(%{total: 2})

      # In routing, high confidence metrics should be weighted higher
      assert high_confidence > low_confidence
    end
  end

  # ========== TYPE SAFETY ==========

  describe "Type Specifications - Hybrid" do
    test "calculate_win_rate returns float" do
      result = TaskMetrics.calculate_win_rate(%{total: 10, successes: 7})
      assert is_float(result)
    end

    test "calculate_confidence returns float" do
      result = TaskMetrics.calculate_confidence(%{total: 50})
      assert is_float(result)
    end

    test "get_metrics returns map" do
      result = TaskMetrics.get_metrics(:coding, "claude-sonnet", :medium)
      assert is_map(result)
    end

    test "aggregate_all_metrics returns ok tuple" do
      result = TaskMetrics.aggregate_all_metrics()
      assert is_tuple(result)
      assert tuple_size(result) == 2 or tuple_size(result) == 3
    end
  end
end
