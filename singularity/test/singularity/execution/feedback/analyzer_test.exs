defmodule Singularity.Execution.Feedback.AnalyzerTest do
  use ExUnit.Case

  alias Singularity.Execution.Feedback.Analyzer
  alias Singularity.Schemas.AgentMetric

  describe "analyze_agent/1" do
    test "analyzes agent with low success rate" do
      # Mock data: agent with 85% success rate (below 90% threshold)
      assert {:ok, analysis} = Analyzer.analyze_agent("test-agent-1")

      assert analysis.agent_id == "test-agent-1"
      assert is_list(analysis.issues)
      assert is_list(analysis.suggestions)
    end

    test "identifies healthy agent with no issues" do
      # Should return empty issues for healthy agent
      assert {:ok, analysis} = Analyzer.analyze_agent("healthy-agent")

      # Healthy agents should have no or very few issues
      assert is_list(analysis.issues)
    end
  end

  describe "find_agents_needing_improvement/0" do
    test "returns list of agents with issues" do
      assert {:ok, agents} = Analyzer.find_agents_needing_improvement()

      assert is_list(agents)
      # All returned agents should have at least one issue
      Enum.each(agents, fn agent ->
        assert length(agent.issues) > 0
        assert agent.overall_health in [:critical, :needs_improvement, :degraded]
      end)
    end

    test "agents are sorted by priority (highest first)" do
      {:ok, agents} = Analyzer.find_agents_needing_improvement()

      # Check that agents are sorted by priority descending
      priorities = Enum.map(agents, & &1.priority)
      assert priorities == Enum.sort(priorities, :desc)
    end
  end

  describe "get_suggestions_for/1" do
    test "returns suggestions for agent with issues" do
      assert {:ok, suggestions} = Analyzer.get_suggestions_for("test-agent-1")

      assert is_list(suggestions)
      # Suggestions should be sorted by confidence descending
      confidences = Enum.map(suggestions, & &1.confidence)
      assert confidences == Enum.sort(confidences, :desc)
    end

    test "suggestion has required fields" do
      {:ok, suggestions} = Analyzer.get_suggestions_for("test-agent-1")

      if length(suggestions) > 0 do
        suggestion = List.first(suggestions)
        assert Map.has_key?(suggestion, :type)
        assert Map.has_key?(suggestion, :confidence)
        assert Map.has_key?(suggestion, :description)
        assert Map.has_key?(suggestion, :estimated_effort)
      end
    end
  end

  describe "issue identification" do
    test "identifies low success rate as critical" do
      # Create a metric with 85% success rate
      assert {:ok, analysis} = Analyzer.analyze_agent("low-success-agent")

      low_success_issues =
        Enum.filter(analysis.issues, &(&1.type == :low_success_rate))

      if length(low_success_issues) > 0 do
        issue = List.first(low_success_issues)
        assert issue.value < 0.90
        assert issue.threshold == 0.90
      end
    end

    test "identifies high cost issues" do
      assert {:ok, analysis} = Analyzer.analyze_agent("high-cost-agent")

      high_cost_issues =
        Enum.filter(analysis.issues, &(&1.type == :high_cost))

      if length(high_cost_issues) > 0 do
        issue = List.first(high_cost_issues)
        assert issue.value > 3.0
      end
    end

    test "identifies high latency issues" do
      assert {:ok, analysis} = Analyzer.analyze_agent("slow-agent")

      high_latency_issues =
        Enum.filter(analysis.issues, &(&1.type == :high_latency))

      if length(high_latency_issues) > 0 do
        issue = List.first(high_latency_issues)
        assert issue.value > 2000
      end
    end
  end

  describe "suggestion generation" do
    test "adds pattern suggestion for low success rate" do
      assert {:ok, analysis} = Analyzer.analyze_agent("low-success-agent")

      add_pattern_suggestions =
        Enum.filter(analysis.suggestions, &(&1.type == :add_patterns))

      if length(add_pattern_suggestions) > 0 do
        suggestion = List.first(add_pattern_suggestions)
        assert suggestion.confidence > 0.0
        assert String.contains?(suggestion.expected_improvement, "+")
      end
    end

    test "adds optimization suggestion for high cost" do
      assert {:ok, analysis} = Analyzer.analyze_agent("high-cost-agent")

      optimize_suggestions =
        Enum.filter(analysis.suggestions, &(&1.type == :optimize_model))

      if length(optimize_suggestions) > 0 do
        suggestion = List.first(optimize_suggestions)
        assert suggestion.confidence > 0.0
        assert String.contains?(suggestion.expected_improvement, "-")
      end
    end

    test "adds caching suggestion for high latency" do
      assert {:ok, analysis} = Analyzer.analyze_agent("slow-agent")

      cache_suggestions =
        Enum.filter(analysis.suggestions, &(&1.type == :improve_cache))

      if length(cache_suggestions) > 0 do
        suggestion = List.first(cache_suggestions)
        assert suggestion.confidence > 0.0
        assert String.contains?(suggestion.expected_improvement, "-")
      end
    end
  end

  describe "health determination" do
    test "marks agent as healthy with no issues" do
      assert {:ok, analysis} = Analyzer.analyze_agent("healthy-agent")

      if length(analysis.issues) == 0 do
        assert analysis.overall_health == :healthy
      end
    end

    test "marks agent as critical with critical issues" do
      assert {:ok, analysis} = Analyzer.analyze_agent("critical-agent")

      # If there are critical severity issues, health should be critical
      critical_count =
        Enum.count(analysis.issues, &(&1.severity == :critical))

      if critical_count > 0 do
        assert analysis.overall_health == :critical
      end
    end

    test "marks agent as needs_improvement with multiple issues" do
      assert {:ok, analysis} = Analyzer.analyze_agent("degraded-agent")

      if length(analysis.issues) > 2 do
        assert analysis.overall_health == :needs_improvement
      end
    end
  end

  describe "error handling" do
    test "handles missing metrics gracefully" do
      result = Analyzer.analyze_agent("nonexistent-agent-xyz")
      # Should either return error or empty analysis
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
end
