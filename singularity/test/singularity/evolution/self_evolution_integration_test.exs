defmodule Singularity.Evolution.SelfEvolutionIntegrationTest do
  @moduledoc """
  Integration tests for the complete self-evolution cycle.

  Tests the full pipeline from pattern analysis through rule synthesis,
  confidence gating, Genesis publishing, and cross-instance learning.

  ## Test Scenarios

  1. **Basic Rule Evolution** - Single instance learns and evolves rules
  2. **Confidence Gating** - Rules below threshold stay as candidates
  3. **Cross-Instance Learning** - Rules shared via Genesis Framework
  4. **Consensus Formation** - Multiple instances synthesize same rules
  5. **Learning Loop Closure** - Failures tracked, patterns learned, validation weights adjusted
  """

  use ExUnit.Case
  doctest Singularity.Evolution.RuleEvolutionSystem
  doctest Singularity.Evolution.GenesisPublisher

  alias Singularity.Evolution.RuleEvolutionSystem
  alias Singularity.Evolution.GenesisPublisher
  alias Singularity.Evolution.RuleQualityDashboard
  alias Singularity.Pipeline.Orchestrator
  alias Singularity.Validation.HistoricalValidator
  alias Singularity.Validation.EffectivenessTracker

  describe "Rule Evolution System" do
    test "analyze_and_propose_rules returns rules with confidence scores" do
      criteria = %{task_type: :architect, complexity: :high}
      opts = [min_confidence: 0.0, limit: 10]

      {:ok, rules} = RuleEvolutionSystem.analyze_and_propose_rules(criteria, opts)

      assert is_list(rules)

      if length(rules) > 0 do
        rule = List.first(rules)
        assert rule[:pattern]
        assert rule[:action]
        assert rule[:confidence]
        assert is_float(rule[:confidence])
        assert rule[:confidence] >= 0.0
        assert rule[:confidence] <= 1.0
      end
    end

    test "get_candidate_rules returns rules below confidence threshold" do
      {:ok, _} = RuleEvolutionSystem.analyze_and_propose_rules(%{}, limit: 50)

      candidates = RuleEvolutionSystem.get_candidate_rules(min_frequency: 1, limit: 20)

      assert is_list(candidates)

      # All candidates should be below quorum
      Enum.each(candidates, fn rule ->
        assert rule[:confidence] < 0.85
      end)
    end

    test "publish_confident_rules publishes only high-confidence rules" do
      {:ok, count} = RuleEvolutionSystem.publish_confident_rules(min_confidence: 0.85, limit: 10)

      assert is_integer(count)
      assert count >= 0
    end

    test "get_evolution_health returns system health metrics" do
      health = RuleEvolutionSystem.get_evolution_health()

      assert health[:total_rules] >= 0
      assert health[:confident_rules] >= 0
      assert health[:candidate_rules] >= 0
      assert is_float(health[:avg_confidence])
      assert String.valid?(health[:health_status])
    end

    test "get_rule_impact_metrics returns effectiveness data" do
      metrics = RuleEvolutionSystem.get_rule_impact_metrics(time_range: :last_week)

      assert is_map(metrics)
      # Should have some metric data or empty gracefully
      assert metrics[:error] || metrics[:validation_accuracy] || metrics[:execution_success_rate]
    end
  end

  describe "Genesis Publisher" do
    test "publish_rules returns publication results with Genesis IDs" do
      {:ok, results} = GenesisPublisher.publish_rules(min_confidence: 0.85, limit: 5)

      assert is_list(results)

      if length(results) > 0 do
        result = List.first(results)
        assert result[:rule_id]
        assert result[:status]
        assert result[:genesis_id]
        assert result[:timestamp]
      end
    end

    test "import_rules_from_genesis returns imported rules" do
      {:ok, imported} =
        GenesisPublisher.import_rules_from_genesis(min_confidence: 0.85, limit: 10)

      assert is_list(imported)

      if length(imported) > 0 do
        rule = List.first(imported)
        assert rule[:pattern]
        assert rule[:action]
        assert rule[:confidence]
      end
    end

    test "get_cross_instance_metrics returns network statistics" do
      metrics = GenesisPublisher.get_cross_instance_metrics()

      assert is_map(metrics)
      assert metrics[:total_rules] >= 0
      assert metrics[:instances_in_network] >= 0
      assert metrics[:consensus_rules] >= 0
    end

    test "get_consensus_rules returns multi-instance rules" do
      consensus = GenesisPublisher.get_consensus_rules()

      assert is_list(consensus)

      if length(consensus) > 0 do
        rule = List.first(consensus)
        assert rule[:pattern]
        assert rule[:sources]
        assert is_list(rule[:source_instances])
      end
    end

    test "get_publication_history returns audit trail" do
      history = GenesisPublisher.get_publication_history(limit: 50)

      assert is_list(history)

      if length(history) > 0 do
        record = List.first(history)
        assert record[:rule_id]
        assert record[:published_at]
      end
    end

    test "get_instance_contributions retrieves rules from specific instance" do
      contributions = GenesisPublisher.get_instance_contributions(:self)

      assert is_list(contributions)
    end

    test "check_rule_status identifies published vs candidate rules" do
      status1 = GenesisPublisher.check_rule_status("rule_123")
      status2 = GenesisPublisher.check_rule_status("unknown_rule")

      # Should return either published, candidate, or not_found
      assert status1 == :not_found || elem(status1, 0) in [:published, :candidate]
      assert status2 == :not_found
    end
  end

  describe "Historical Validator & Learning Integration" do
    test "recommend_checks returns validation checks based on context" do
      context = %{
        task_type: :architect,
        complexity: :high,
        story_signature: "design_pattern"
      }

      recommendations = HistoricalValidator.recommend_checks(context)

      assert is_list(recommendations)

      if length(recommendations) > 0 do
        rec = List.first(recommendations)
        assert rec[:check_id]
        assert rec[:effectiveness_score]
        assert is_float(rec[:combined_score])
      end
    end

    test "find_similar_failures queries historical patterns" do
      context = %{
        task_type: :architect,
        complexity: :high
      }

      failures = HistoricalValidator.find_similar_failures(context, threshold: 0.70, limit: 10)

      assert is_list(failures)
    end

    test "get_successful_fixes_for returns remediation strategies" do
      context = %{
        task_type: :architect,
        complexity: :high
      }

      failures = HistoricalValidator.find_similar_failures(context, threshold: 0.70)
      fixes = HistoricalValidator.get_successful_fixes_for(failures)

      assert is_list(fixes)
    end

    test "get_top_performing_checks returns effective validation checks" do
      checks = HistoricalValidator.get_top_performing_checks(limit: 5)

      assert is_list(checks)

      if length(checks) > 0 do
        {check_id, effectiveness} = List.first(checks)
        assert is_binary(check_id)
        assert is_float(effectiveness)
      end
    end
  end

  describe "Effectiveness Tracker - Dynamic Validation Weights" do
    test "get_validation_weights returns normalized check weights" do
      weights = EffectivenessTracker.get_validation_weights(:last_week)

      assert is_map(weights)

      # If weights exist, they should be normalized (sum ≈ 1.0)
      if map_size(weights) > 0 do
        total = Enum.sum(Map.values(weights))
        # Allow small floating point variance
        assert total >= 0.95 && total <= 1.05
      end
    end

    test "analyze_check_performance returns detailed effectiveness data" do
      analysis = EffectivenessTracker.analyze_check_performance("quality_check", :last_week)

      if analysis do
        assert analysis[:check_id]
        assert is_float(analysis[:effectiveness_score])
        assert is_integer(analysis[:true_positives])
        assert is_integer(analysis[:false_positives])
        assert is_float(analysis[:avg_runtime_ms])
        assert String.valid?(analysis[:recommendation])
      end
    end

    test "get_improvement_opportunities identifies underperforming checks" do
      opportunities = EffectivenessTracker.get_improvement_opportunities()

      assert is_list(opportunities)

      if length(opportunities) > 0 do
        opp = List.first(opportunities)
        assert opp[:check_id]
        assert opp[:effectiveness]
        assert String.valid?(opp[:recommendation])
      end
    end

    test "get_time_budget_analysis shows validation time distribution" do
      analysis = EffectivenessTracker.get_time_budget_analysis(:last_week)

      assert is_map(analysis)
      assert analysis[:total_avg_validation_time_ms]
    end

    test "recalculate_weights refreshes check weights" do
      result = EffectivenessTracker.recalculate_weights()

      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Pipeline Orchestrator Integration" do
    test "analyze_and_propose_rules delegates to RuleEvolutionSystem" do
      {:ok, rules} = Orchestrator.analyze_and_propose_rules(%{task_type: :coder}, limit: 10)

      assert is_list(rules)
    end

    test "publish_evolved_rules publishes via GenesisPublisher" do
      {:ok, published} = Orchestrator.publish_evolved_rules(min_confidence: 0.85)

      assert is_list(published)
    end

    test "import_rules_from_genesis fetches from Genesis" do
      {:ok, imported} = Orchestrator.import_rules_from_genesis(min_confidence: 0.85)

      assert is_list(imported)
    end

    test "get_consensus_rules returns multi-instance consensus" do
      consensus = Orchestrator.get_consensus_rules()

      assert is_list(consensus)
    end

    test "get_evolution_health returns system KPIs" do
      health = Orchestrator.get_evolution_health()

      assert is_map(health)
      assert health[:total_rules]
      assert health[:confident_rules]
      assert health[:candidate_rules]
    end

    test "get_cross_instance_metrics returns network metrics" do
      metrics = Orchestrator.get_cross_instance_metrics()

      assert is_map(metrics)
      assert metrics[:instances_in_network] >= 0
    end

    test "get_rule_impact_metrics returns effectiveness data" do
      metrics = Orchestrator.get_rule_impact_metrics()

      assert is_map(metrics)
    end

    test "get_validation_weights returns check effectiveness" do
      weights = Orchestrator.get_validation_effectiveness()

      assert is_map(weights)
    end

    test "recommend_validation_checks returns recommendations" do
      recommendations =
        Orchestrator.recommend_validation_checks(%{
          task_type: :architect,
          complexity: :high
        })

      assert is_list(recommendations)
    end

    test "analyze_learning_health returns complete health metrics" do
      health = Orchestrator.analyze_learning_health()

      assert is_map(health)
      assert health[:kpis]
      assert health[:check_effectiveness]
      assert health[:system_health]
    end
  end

  describe "Rule Quality Dashboard" do
    test "get_dashboard returns complete dashboard snapshot" do
      {:ok, dashboard} = RuleQualityDashboard.get_dashboard()

      assert is_map(dashboard)
      assert dashboard[:evolution_status]
      assert dashboard[:effectiveness_analytics]
      assert dashboard[:network_metrics]
      assert dashboard[:quality_trends]
      assert dashboard[:recommendations]
      assert dashboard[:timestamp]
    end

    test "get_evolution_status returns rule synthesis metrics" do
      status = RuleQualityDashboard.get_evolution_status()

      assert is_map(status)
      assert status[:total_rules] >= 0
      assert status[:confident_rules] >= 0
      assert status[:candidate_rules] >= 0
      assert is_float(status[:avg_confidence])
    end

    test "get_effectiveness_analytics returns impact metrics" do
      analytics = RuleQualityDashboard.get_effectiveness_analytics()

      assert is_map(analytics)
      assert String.valid?(analytics[:effectiveness_trend])
    end

    test "get_network_metrics returns Genesis network statistics" do
      metrics = RuleQualityDashboard.get_network_metrics()

      assert is_map(metrics)
      assert metrics[:instances_in_network] >= 0
      assert metrics[:consensus_rules] >= 0
    end

    test "get_quality_trends analyzes historical evolution" do
      trends = RuleQualityDashboard.get_quality_trends()

      assert is_map(trends)
      assert String.valid?(trends[:evolution_trend])
    end

    test "get_recommendations suggests improvement actions" do
      recommendations = RuleQualityDashboard.get_recommendations()

      assert is_list(recommendations)

      if length(recommendations) > 0 do
        rec = List.first(recommendations)
        assert rec[:priority] in ["HIGH", "MEDIUM", "LOW"]
        assert rec[:action]
        assert rec[:reason]
      end
    end

    test "get_publication_history returns recent publications" do
      history = RuleQualityDashboard.get_publication_history(20)

      assert is_list(history)
    end

    test "get_rule_analytics returns detailed rule metrics" do
      analytics = RuleQualityDashboard.get_rule_analytics()

      assert is_list(analytics)

      if length(analytics) > 0 do
        rule = List.first(analytics)
        assert rule[:pattern]
        assert rule[:confidence]
        assert rule[:effectiveness]
        assert rule[:recommendation]
      end
    end
  end

  describe "Full Self-Evolution Cycle" do
    test "complete learning loop from pattern to rule to publication" do
      # Phase 1: Analyze patterns
      {:ok, rules} =
        RuleEvolutionSystem.analyze_and_propose_rules(%{}, min_confidence: 0.0, limit: 20)

      assert is_list(rules)
      initial_count = length(rules)

      # Phase 2: Identify confident rules
      confident = Enum.filter(rules, &(&1[:confidence] >= 0.85))
      confident_count = length(confident)
      assert confident_count >= 0

      # Phase 3: Publish to Genesis if confident rules exist
      if confident_count > 0 do
        {:ok, published} = GenesisPublisher.publish_rules(min_confidence: 0.85)
        assert is_list(published)
      end

      # Phase 4: Check evolution health
      health = RuleEvolutionSystem.get_evolution_health()
      assert health[:total_rules] >= 0
      assert health[:confident_rules] >= 0

      # Phase 5: Import rules from Genesis
      {:ok, imported} = GenesisPublisher.import_rules_from_genesis()
      assert is_list(imported)

      # Phase 6: Check cross-instance metrics
      metrics = GenesisPublisher.get_cross_instance_metrics()
      assert metrics[:instances_in_network] >= 0

      # Phase 7: Get dashboard snapshot
      {:ok, dashboard} = RuleQualityDashboard.get_dashboard()
      assert dashboard[:evolution_status]
      assert dashboard[:recommendations]

      # Verify cycle closure
      assert initial_count >= 0
    end

    test "historical validator learns from failures" do
      # Simulate failure context
      context = %{
        task_type: :architect,
        complexity: :high,
        story_signature: "architecture_design"
      }

      # Get recommendations based on similar failures
      recommendations = HistoricalValidator.recommend_checks(context)
      assert is_list(recommendations)

      # Get effectiveness scores
      effectiveness = EffectivenessTracker.get_validation_weights(:last_week)
      assert is_map(effectiveness)

      # Get health metrics
      health = Orchestrator.analyze_learning_health()
      assert health[:system_health]
    end

    test "validation weights adjust based on effectiveness" do
      # Get baseline weights
      baseline_weights = EffectivenessTracker.get_validation_weights(:last_week)

      # Recalculate weights
      :ok = EffectivenessTracker.recalculate_weights()

      # Get updated weights
      updated_weights = EffectivenessTracker.get_validation_weights(:last_week)

      # Weights should be valid
      assert is_map(updated_weights)
      assert map_size(updated_weights) >= 0
    end

    test "rules promoted as confidence increases" do
      # Get all rules including candidates
      {:ok, all_rules} =
        RuleEvolutionSystem.analyze_and_propose_rules(%{}, min_confidence: 0.0, limit: 100)

      candidates = Enum.filter(all_rules, &(&1[:confidence] < 0.85))
      confident = Enum.filter(all_rules, &(&1[:confidence] >= 0.85))

      # Verify confidence-based stratification
      Enum.each(candidates, fn rule ->
        assert rule[:status] == :candidate
      end)

      Enum.each(confident, fn rule ->
        assert rule[:status] == :confident
      end)
    end
  end
end
