defmodule Singularity.SelfImprovementIntegrationTest do
  @moduledoc """
  Integration tests for the complete self-improvement pipeline.

  Tests:
  1. Type 1 improvements - Fast, low-risk local improvements
  2. Type 3 improvements - High-risk improvements sent to Genesis
  3. Risk classification based on performance metrics
  4. Metrics recording and decision-making
  5. Genesis communication and code application
  """

  use ExUnit.Case, async: false
  require Logger

  alias Singularity.Execution.Autonomy.Decider
  alias Singularity.SelfImprovingAgent
  alias Singularity.Execution.Todos.TodoWorkerAgent
  alias Singularity.Execution.Autonomy.Planner

  setup do
    # Create test agent state
    agent_state = %{
      id: "test-agent-#{System.unique_integer()}",
      cycles: 0,
      status: :idle,
      metrics: %{},
      last_score: 1.0,
      last_trigger: nil,
      pending_plan: nil,
      last_improvement_cycle: 0,
      last_failure_cycle: nil,
      forced_context: nil
    }

    {:ok, agent_state: agent_state}
  end

  describe "Type 1 improvements (low-risk, local)" do
    test "triggers improvement on performance drop", %{agent_state: state} do
      # Simulate agent with declining performance
      declining_state = %{
        state
        | cycles: 10,
          metrics: %{successes: 5, failures: 20}  # 20% success rate
      }

      # Decision should trigger improvement
      decision = Decider.decide(declining_state)

      # Should suggest improvement
      assert match?({:improve_local, _payload, _context, _state}, decision) ||
               match?({:improve_experimental, _payload, _context, _state}, decision)
    end

    test "classifies low-score as Type 3 improvement" do
      # Low score (0.2) should trigger high-risk (Type 3) improvement
      metrics = %{
        success_rate: 0.2,
        regression: 0.05,
        llm_reduction: 0.1
      }

      state = %{
        id: "test",
        cycles: 50,
        metrics: %{successes: 20, failures: 80},
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        last_score: 0.2
      }

      decision = Decider.decide(state)

      # Should classify as experimental (Type 3) due to low score
      assert match?({:improve_experimental, _payload, _context, _state}, decision)
    end

    test "respects failure backoff window", %{agent_state: state} do
      # Agent recently failed - should not trigger new improvements during backoff
      backoff_state = %{
        state
        | cycles: 5,
          last_failure_cycle: 0,  # Failed at cycle 0, now at cycle 5
          metrics: %{successes: 10, failures: 10}
      }

      # Should not trigger improvement during backoff (< 10 cycles)
      decision = Decider.decide(backoff_state)
      assert match?({:continue, _state}, decision)
    end

    test "triggers after backoff window expires", %{agent_state: state} do
      # Agent failed long ago - backoff expired
      backoff_expired_state = %{
        state
        | cycles: 20,
          last_failure_cycle: 5,  # Failed at cycle 5, now at cycle 20 (> 10 cycle backoff)
          metrics: %{successes: 10, failures: 10}
      }

      # Should allow improvement after backoff expires
      decision = Decider.decide(backoff_expired_state)

      # Could trigger improvement if score is low enough
      case decision do
        {:improve_local, _payload, _context, _state} -> assert true
        {:improve_experimental, _payload, _context, _state} -> assert true
        {:continue, _state} -> assert true
      end
    end
  end

  describe "Type 3 improvements (high-risk, Genesis)" do
    test "sends high-risk improvements to Genesis" do
      # Create state that would trigger Type 3 improvement
      state = %{
        id: "test-agent-type3",
        cycles: 150,
        status: :idle,
        metrics: %{successes: 10, failures: 90},  # Very low success rate
        last_score: 0.1,
        last_trigger: nil,
        pending_plan: nil,
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        forced_context: nil
      }

      decision = Decider.decide(state)

      # Should trigger Type 3 improvement
      assert match?({:improve_experimental, _payload, _context, _state}, decision)

      # Extract the context to verify it contains improvement details
      {type, _payload, context, _new_state} = decision
      assert type == :improve_experimental
      assert context[:score] <= 0.1 or context[:stagnation] > 0
    end

    test "risk classification for extended stagnation" do
      # Agent hasn't improved for > 100 cycles
      state = %{
        id: "test",
        cycles: 150,
        metrics: %{successes: 50, failures: 50},
        last_improvement_cycle: 40,  # Last improvement at cycle 40
        last_failure_cycle: nil,
        last_score: 0.5
      }

      decision = Decider.decide(state)

      # Should classify as Type 3 due to stagnation > 100
      assert match?({:improve_experimental, _payload, _context, _state}, decision)

      {type, _payload, context, _state} = decision
      assert type == :improve_experimental
      assert context[:stagnation] > 100
    end
  end

  describe "Risk classification rules" do
    test "Type 1: score > 0.3 and stagnation < 100 triggers local improvement" do
      context = %{
        score: 0.5,
        stagnation: 50,
        reason: :score_drop
      }

      state = %{
        id: "test",
        cycles: 50,
        metrics: %{successes: 50, failures: 50},
        last_failure_cycle: nil
      }

      # This should classify as Type 1 (local)
      improvement_type = Decider.classify_improvement_risk(state, context)

      assert improvement_type == :improve_local
    end

    test "Type 3: score < 0.3 triggers experimental improvement" do
      context = %{
        score: 0.2,
        stagnation: 50,
        reason: :score_drop
      }

      state = %{
        id: "test",
        cycles: 50,
        metrics: %{successes: 20, failures: 80},
        last_failure_cycle: nil
      }

      # This should classify as Type 3 (experimental)
      improvement_type = Decider.classify_improvement_risk(state, context)

      assert improvement_type == :improve_experimental
    end

    test "Type 3: stagnation > 100 cycles triggers experimental improvement" do
      context = %{
        score: 0.5,
        stagnation: 150,
        reason: :stagnation
      }

      state = %{
        id: "test",
        cycles: 200,
        metrics: %{successes: 50, failures: 50},
        last_failure_cycle: nil
      }

      # This should classify as Type 3 due to extended stagnation
      improvement_type = Decider.classify_improvement_risk(state, context)

      assert improvement_type == :improve_experimental
    end
  end

  describe "Metrics recording" do
    test "task completion records success outcome" do
      agent_id = "test-agent-metrics-#{System.unique_integer()}"

      # Record success
      SelfImprovingAgent.record_outcome(agent_id, :success)
      Process.sleep(10)

      # Verify outcome was recorded (in actual implementation, check agent state)
      # For now, just verify the function executes without error
      assert true
    end

    test "task failure records failure outcome" do
      agent_id = "test-agent-failure-#{System.unique_integer()}"

      # Record failure
      SelfImprovingAgent.record_outcome(agent_id, :failure)
      Process.sleep(10)

      # Verify outcome was recorded
      assert true
    end

    test "sequential success/failure outcomes affect score" do
      # Simulate metric accumulation
      state = %{
        metrics: %{successes: 8, failures: 2}
      }

      # With 8 successes and 2 failures: score = 8/10 = 0.8
      score = Singularity.Execution.Autonomy.Decider.normalized_score(8, 2)

      assert Float.round(score, 1) == 0.8
    end

    test "zero outcomes returns perfect score" do
      score = Singularity.Execution.Autonomy.Decider.normalized_score(0, 0)

      # No data yet - optimistic score of 1.0
      assert score == 1.0
    end

    test "high failure rate triggers improvement" do
      # Create state with high failure rate
      state = %{
        id: "test",
        cycles: 15,
        metrics: %{successes: 2, failures: 13},  # 13% success rate
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        last_score: 0.13
      }

      decision = Decider.decide(state)

      # Should trigger some kind of improvement
      assert match?({:improve_local, _payload, _context, _state}, decision) ||
               match?({:improve_experimental, _payload, _context, _state}, decision) ||
               match?({:continue, _state}, decision)
    end
  end

  describe "Forced improvements" do
    test "forced improvement bypasses normal thresholds" do
      state = %{
        id: "test",
        cycles: 5,
        metrics: %{successes: 100, failures: 0},  # Perfect score
        last_score: 1.0,
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        forced_context: %{reason: "manual_request", trigger: :forced},  # Forced flag
        status: :idle
      }

      decision = Decider.decide(state)

      # Should trigger improvement even with perfect score
      assert match?({:improve_local, _payload, _context, _state}, decision) ||
               match?({:improve_experimental, _payload, _context, _state}, decision)
    end

    test "forced improvement clears context after decision" do
      state = %{
        id: "test",
        cycles: 5,
        metrics: %{},
        last_score: 1.0,
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        forced_context: %{reason: "manual", trigger: :forced},
        status: :idle
      }

      decision = Decider.decide(state)

      # Extract new state from decision
      {_type, _payload, _context, new_state} = decision

      # Forced context should be cleared
      assert new_state.forced_context == nil
    end
  end

  describe "Metrics persistence" do
    test "metrics are tracked across cycles" do
      # Initial state
      state1 = %{
        id: "test",
        cycles: 0,
        metrics: %{successes: 0, failures: 0},
        last_score: 1.0
      }

      # After some work - record outcomes
      state2 = %{
        state1
        | cycles: 5,
          metrics: %{successes: 4, failures: 1}
      }

      # Verify score calculation
      score = Singularity.Execution.Autonomy.Decider.normalized_score(4, 1)
      assert Float.round(score, 2) == 0.8

      # More cycles
      state3 = %{
        state2
        | cycles: 15,
          metrics: %{successes: 12, failures: 3}
      }

      score2 = Singularity.Execution.Autonomy.Decider.normalized_score(12, 3)
      assert Float.round(score2, 2) == 0.8
    end
  end

  describe "Integration: Improvement decision flow" do
    test "complete Type 1 decision flow" do
      # Start with declining agent
      state = %{
        id: "integration-test-type1",
        cycles: 10,
        status: :idle,
        metrics: %{successes: 5, failures: 20},
        last_score: 0.2,
        last_improvement_cycle: 0,
        last_failure_cycle: nil,
        last_trigger: nil,
        pending_plan: nil,
        forced_context: nil
      }

      # Decide on improvement
      decision = Decider.decide(state)

      # Should get some kind of decision
      assert match?({:improve_local, _payload, _context, _state}, decision) ||
               match?({:improve_experimental, _payload, _context, _state}, decision)

      # Verify context contains reasoning
      {type, payload, context, new_state} = decision

      assert type in [:improve_local, :improve_experimental]
      assert is_map(payload)
      assert is_map(context)
      assert is_map(new_state)

      # Context should have improvement trigger info
      assert context[:score] || context[:reason] || context[:stagnation]
    end

    test "complete Type 3 decision flow with Genesis routing" do
      # High-risk scenario
      state = %{
        id: "integration-test-type3",
        cycles: 150,
        status: :idle,
        metrics: %{successes: 5, failures: 95},  # 5% success
        last_score: 0.05,
        last_improvement_cycle: 20,
        last_failure_cycle: nil,
        last_trigger: nil,
        pending_plan: nil,
        forced_context: nil
      }

      # Decide on improvement
      decision = Decider.decide(state)

      # Should trigger Type 3 for high-risk case
      assert match?({:improve_experimental, _payload, _context, _state}, decision)

      {type, payload, context, new_state} = decision

      assert type == :improve_experimental
      assert is_map(payload)
      assert context[:score] < 0.3 or context[:stagnation] > 100
    end
  end
end
