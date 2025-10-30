defmodule Singularity.RCA.SessionManagerTest do
  @moduledoc """
  Tests for RCA SessionManager - Verifies complete session lifecycle and integration

  Tests cover:
  - Session creation and completion
  - Metric recording
  - Session retrieval with relations
  - Query integration
  """

  use Singularity.DataCase

  alias Singularity.RCA.SessionManager
  alias Singularity.Schemas.RCA.{GenerationSession, RefinementStep, TestExecution}
  alias Singularity.Repo

  describe "session lifecycle" do
    test "creates new session with initial state" do
      attrs = %{
        initial_prompt: "Generate a REST API endpoint",
        agent_id: "code-gen-v2",
        template_id: Ecto.UUID.generate(),
        agent_version: "v2.1.0"
      }

      {:ok, session} = SessionManager.start_session(attrs)

      assert session.id
      assert session.initial_prompt == attrs.initial_prompt
      assert session.agent_id == "code-gen-v2"
      assert session.status == "in_progress"
      assert session.started_at
    end

    test "completes session with outcome metrics" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      session_id = session.id

      {:ok, completed} =
        SessionManager.complete_session(session_id, %{
          final_outcome: "success",
          success_metrics: %{
            "code_quality" => 95,
            "test_pass_rate" => 100,
            "complexity" => "medium"
          },
          generation_cost_tokens: 2500,
          total_validation_cost_tokens: 500
        })

      assert completed.id == session_id
      assert completed.status == "completed"
      assert completed.final_outcome == "success"
      assert completed.generation_cost_tokens == 2500
      assert completed.total_validation_cost_tokens == 500
      assert completed.success_metrics["code_quality"] == 95
    end

    test "fails to complete non-existent session" do
      fake_id = Ecto.UUID.generate()

      result =
        SessionManager.complete_session(fake_id, %{
          final_outcome: "success"
        })

      assert result == {:error, :not_found}
    end
  end

  describe "metric recording" do
    test "records generation metrics from LLM response" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      llm_response = %{
        text: "generated code",
        model: "claude-sonnet-4.5",
        tokens_used: 2000,
        cost_cents: 10,
        metrics: %{
          "quality_score" => 92,
          "maintainability" => "high"
        }
      }

      {:ok, updated} = SessionManager.record_generation_metrics(session.id, llm_response)

      assert updated.generation_cost_tokens == 2000
      assert updated.success_metrics["quality_score"] == 92
    end

    test "records LLM call link" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      llm_call_id = Ecto.UUID.generate()

      {:ok, updated} = SessionManager.record_llm_call(session.id, llm_call_id)

      assert updated.initial_llm_call_id == llm_call_id
    end
  end

  describe "session retrieval" do
    test "gets session with preloaded relations" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      # Add a refinement step
      {:ok, step} =
        Repo.insert(%RefinementStep{
          generation_session_id: session.id,
          step_number: 1,
          agent_action: "initial_gen",
          tokens_used: 1000
        })

      # Add a test execution
      {:ok, test_exec} =
        Repo.insert(%TestExecution{
          triggered_by_session_id: session.id,
          test_pass_rate: Decimal.new("95.0"),
          test_coverage_line: Decimal.new("85.0"),
          failed_test_count: 1
        })

      # Retrieve with relations
      {:ok, loaded} = SessionManager.get_session_full(session.id)

      assert loaded.id == session.id
      assert length(loaded.refinement_steps) == 1
      assert hd(loaded.refinement_steps).agent_action == "initial_gen"
      assert length(loaded.test_executions) == 1
      assert hd(loaded.test_executions).failed_test_count == 1
    end

    test "returns not_found for non-existent session" do
      fake_id = Ecto.UUID.generate()

      result = SessionManager.get_session_full(fake_id)

      assert result == {:error, :not_found}
    end
  end

  describe "session helpers" do
    test "checks if session was successful" do
      {:ok, success_session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      {:ok, _} =
        SessionManager.complete_session(success_session.id, %{
          final_outcome: "success"
        })

      assert SessionManager.successful?(success_session.id)

      {:ok, failed_session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      {:ok, _} =
        SessionManager.complete_session(failed_session.id, %{
          final_outcome: "failure_validation"
        })

      refute SessionManager.successful?(failed_session.id)
    end

    test "calculates total cost tokens" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      {:ok, _} =
        SessionManager.complete_session(session.id, %{
          final_outcome: "success",
          generation_cost_tokens: 2000,
          total_validation_cost_tokens: 800
        })

      total_cost = SessionManager.total_cost_tokens(session.id)

      assert total_cost == 2800
    end

    test "returns 0 for non-existent session cost" do
      fake_id = Ecto.UUID.generate()

      total_cost = SessionManager.total_cost_tokens(fake_id)

      assert total_cost == 0
    end
  end

  describe "get_or_create_session" do
    test "creates new session when not provided" do
      session_attrs = %{
        initial_prompt: "Generate code",
        agent_id: "test-agent"
      }

      {:ok, session_id} = SessionManager.get_or_create_session([], session_attrs)

      assert session_id
      # Verify it was actually created
      {:ok, session} = SessionManager.get_session_full(session_id)
      assert session.id == session_id
    end

    test "uses existing session when provided in opts" do
      # Create initial session
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      existing_id = session.id

      # Use get_or_create with existing ID
      {:ok, returned_id} =
        SessionManager.get_or_create_session(
          [generation_session_id: existing_id],
          %{initial_prompt: "Different prompt"}
        )

      assert returned_id == existing_id
    end
  end

  describe "refinement step tracking" do
    test "creates refinement step chain" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      # First refinement step
      {:ok, step1} =
        Repo.insert(%RefinementStep{
          generation_session_id: session.id,
          step_number: 1,
          agent_action: "initial_gen",
          feedback_received: nil,
          validation_result: "fail",
          tokens_used: 1000
        })

      # Second refinement step (depends on first)
      {:ok, step2} =
        Repo.insert(%RefinementStep{
          generation_session_id: session.id,
          step_number: 2,
          agent_action: "re_gen_on_error",
          feedback_received: "Failed validation tests",
          previous_step_id: step1.id,
          validation_result: "pass",
          tokens_used: 800
        })

      # Verify chain
      loaded_step2 =
        RefinementStep
        |> where(id: ^step2.id)
        |> Repo.one()

      assert loaded_step2.previous_step_id == step1.id

      # Verify next_steps relation
      loaded_step1 = Repo.preload(step1, :next_steps)

      assert length(loaded_step1.next_steps) == 1
      assert hd(loaded_step1.next_steps).id == step2.id
    end
  end

  describe "test execution tracking" do
    test "tracks test execution metrics" do
      {:ok, session} =
        SessionManager.start_session(%{
          initial_prompt: "Generate code",
          agent_id: "test-agent"
        })

      {:ok, test_exec} =
        Repo.insert(%TestExecution{
          triggered_by_session_id: session.id,
          test_pass_rate: Decimal.new("97.5"),
          test_coverage_line: Decimal.new("92.0"),
          test_coverage_branch: Decimal.new("85.5"),
          failed_test_count: 2,
          execution_time_ms: 5432,
          peak_memory_mb: 512,
          status: "completed",
          all_failures: %{
            "test_edge_case_1" => "Expected 42, got 41",
            "test_edge_case_2" => "Timeout after 5000ms"
          }
        })

      assert test_exec.test_pass_rate == Decimal.new("97.5")
      assert test_exec.failed_test_count == 2
      assert Map.get(test_exec.all_failures, "test_edge_case_1") == "Expected 42, got 41"
    end
  end
end
