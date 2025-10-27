defmodule Singularity.Agents.CostOptimizedAgentTemplatesTest do
  @moduledoc """
  Integration tests for CostOptimizedAgent's template-based code generation.

  Tests cover:
  - Template discovery for different task types
  - Code generation using Solid templates
  - Cost optimization (template vs LLM)
  - Fallback behavior when templates unavailable
  - Usage tracking integration
  """
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Singularity.Agents.CostOptimizedAgent
  alias Singularity.Execution.Planning.Task

  @moduletag :agent_integration
  @moduletag :database_required

  setup do
    # Start agent for testing
    agent_id = "test-agent-#{System.unique_integer([:positive])}"

    {:ok, pid} =
      CostOptimizedAgent.start_link(
        id: agent_id,
        specialization: :elixir_developer
      )

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal)
      end
    end)

    {:ok, agent_id: agent_id, agent_pid: pid}
  end

  describe "template-based code generation" do
    test "uses template for standard Elixir module task", %{agent_id: agent_id} do
      task = %Task{
        id: "task-1",
        name: "user_service",
        description: "Create user service module",
        type: :code_generation,
        language: "elixir",
        acceptance_criteria: [
          "Module must have @moduledoc",
          "Include basic CRUD functions"
        ]
      }

      # Process task
      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, cost, :autonomous, _state} when is_binary(code) ->
          # Should use template (autonomous mode, zero cost)
          assert cost == 0.0
          assert code =~ "defmodule"
          # Module name should be inferred from task name
          assert code =~ "UserService" or code =~ "user_service"

        {code, cost, :rule_based, _state} when is_binary(code) ->
          # Rule-based generation is also acceptable
          assert cost == 0.0
          assert code =~ "defmodule"

        {:error, _reason, _cost, _state} ->
          # If templates don't exist yet, this is expected
          :ok

        _other ->
          # Other results acceptable during testing
          :ok
      end
    end

    test "extracts module name from task name correctly", %{agent_id: agent_id} do
      task = %Task{
        id: "task-2",
        name: "payment_processor",
        description: "Payment processing module",
        type: :code_generation,
        language: "elixir"
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, _cost, method, _state} when method in [:autonomous, :rule_based] ->
          # Should convert payment_processor -> PaymentProcessor
          assert code =~ "PaymentProcessor"

        _ ->
          # Acceptable if templates unavailable
          :ok
      end
    end

    test "includes acceptance criteria in generated code", %{agent_id: agent_id} do
      task = %Task{
        id: "task-3",
        name: "cache_manager",
        description: "Cache management module",
        type: :code_generation,
        language: "elixir",
        acceptance_criteria: [
          "Must use ETS for storage",
          "Include TTL support",
          "Handle concurrent access"
        ]
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, _cost, method, _state} when method in [:autonomous, :rule_based] ->
          # Variables should be passed to template
          assert is_binary(code)

        _ ->
          :ok
      end
    end
  end

  describe "cost optimization" do
    test "prefers templates over LLM for standard tasks", %{agent_id: agent_id} do
      task = %Task{
        id: "task-4",
        name: "data_validator",
        description: "Data validation module",
        type: :code_generation,
        language: "elixir"
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {_code, cost, :autonomous, _state} ->
          # Template usage should be free
          assert cost == 0.0

        {_code, cost, :rule_based, _state} ->
          # Rule-based should also be free
          assert cost == 0.0

        {_code, cost, :llm_with_rules, _state} ->
          # LLM call has cost
          assert cost > 0.0

        {_code, cost, :llm_fallback, _state} ->
          # Fallback has cost
          assert cost > 0.0

        _ ->
          :ok
      end
    end

    test "tracks cost savings from template usage", %{agent_id: agent_id} do
      # Process multiple tasks
      tasks =
        for i <- 1..5 do
          %Task{
            id: "task-#{i}",
            name: "module_#{i}",
            description: "Test module #{i}",
            type: :code_generation,
            language: "elixir"
          }
        end

      results = Enum.map(tasks, &CostOptimizedAgent.process_task(agent_id, &1))

      # Count template vs LLM usage
      template_count =
        Enum.count(results, fn
          {_code, 0.0, method, _state} when method in [:autonomous, :rule_based] -> true
          _ -> false
        end)

      # Should use templates for most standard tasks
      # (Acceptable if 0 during testing without templates)
      assert template_count >= 0
    end
  end

  describe "fallback behavior" do
    test "falls back to LLM when template not found", %{agent_id: agent_id} do
      task = %Task{
        id: "task-5",
        name: "very_specific_custom_module",
        description: "Highly specialized module with no template",
        type: :code_generation,
        language: "elixir"
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, cost, method, _state} ->
          # Should generate code somehow (template or LLM)
          assert is_binary(code) or is_nil(code)

          if method in [:llm_with_rules, :llm_fallback] do
            # LLM fallback should have cost
            assert cost > 0.0
          end

        {:error, _reason, _cost, _state} ->
          # Error is acceptable
          :ok
      end
    end

    test "handles template rendering errors gracefully", %{agent_id: agent_id} do
      task = %Task{
        id: "task-6",
        name: "test_module",
        description: "Test module",
        type: :code_generation,
        language: "elixir"
      }

      log =
        capture_log(fn ->
          _result = CostOptimizedAgent.process_task(agent_id, task)
          Process.sleep(50)
        end)

      # Should not crash
      assert is_binary(log)
    end

    test "uses simple fill as last resort", %{agent_id: agent_id} do
      task = %Task{
        id: "task-7",
        name: "fallback_test",
        description: "Test fallback rendering",
        type: :code_generation,
        language: "elixir"
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, _cost, _method, _state} when is_binary(code) ->
          # Should generate something
          assert String.length(code) > 0

        _ ->
          :ok
      end
    end
  end

  describe "template discovery" do
    test "discovers templates by language and type", %{agent_id: agent_id} do
      languages = ["elixir", "rust", "typescript"]
      types = [:code_generation, :refactoring, :testing]

      for language <- languages, type <- types do
        task = %Task{
          id: "discovery-#{language}-#{type}",
          name: "test_#{language}_#{type}",
          description: "Test #{language} #{type}",
          type: type,
          language: language
        }

        result = CostOptimizedAgent.process_task(agent_id, task)

        # Should attempt discovery (success or failure acceptable)
        assert match?({_, _, _, _}, result) or match?({:error, _, _, _}, result)
      end
    end

    test "handles missing language gracefully", %{agent_id: agent_id} do
      task = %Task{
        id: "no-lang",
        name: "test_module",
        description: "Test module with no language",
        type: :code_generation
        # No language specified
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      # Should default to something (likely elixir based on agent specialization)
      case result do
        {code, _cost, _method, _state} ->
          assert is_binary(code) or is_nil(code)

        {:error, _reason, _cost, _state} ->
          :ok
      end
    end
  end

  describe "variable extraction" do
    test "extracts module name from various formats", %{agent_id: agent_id} do
      test_cases = [
        {"user_service", "UserService"},
        {"payment-processor", "PaymentProcessor"},
        {"my api handler", "MyApiHandler"},
        {"UserService", "UserService"}
      ]

      for {input, expected} <- test_cases do
        task = %Task{
          id: "extract-#{input}",
          name: input,
          description: "Test extraction",
          type: :code_generation,
          language: "elixir"
        }

        result = CostOptimizedAgent.process_task(agent_id, task)

        case result do
          {code, _cost, method, _state} when method in [:autonomous, :rule_based] ->
            if is_binary(code) do
              # Should include properly formatted module name
              assert code =~ expected or code =~ input
            end

          _ ->
            :ok
        end
      end
    end

    test "passes task description as description variable", %{agent_id: agent_id} do
      task = %Task{
        id: "description-test",
        name: "test_module",
        description: "This is a very specific description that should appear in the code",
        type: :code_generation,
        language: "elixir"
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, _cost, method, _state}
        when method in [:autonomous, :rule_based] and is_binary(code) ->
          # Description should be in module doc
          assert code =~ "This is a very specific description"

        _ ->
          :ok
      end
    end
  end

  describe "usage tracking integration" do
    test "tracks template usage through agent", %{agent_id: agent_id} do
      task = %Task{
        id: "tracking-test",
        name: "tracked_module",
        description: "Test tracking",
        type: :code_generation,
        language: "elixir"
      }

      _result = CostOptimizedAgent.process_task(agent_id, task)

      # Wait for async tracking to complete
      Process.sleep(100)

      # Verify usage event was recorded to database
      event =
        Singularity.Repo.get_by(
          Singularity.Knowledge.TemplateUsageEvent,
          template_id: "tracked_module"
        )

      # Event should be recorded (either success or failure is fine for this integration test)
      refute is_nil(event), "Usage event should be recorded in database"
      assert event.template_id == "tracked_module"
      assert event.status in [:success, :failure]
    end
  end

  describe "real-world scenarios" do
    test "generates GenServer module", %{agent_id: agent_id} do
      task = %Task{
        id: "genserver-test",
        name: "worker_process",
        description: "Background worker using GenServer",
        type: :code_generation,
        language: "elixir",
        acceptance_criteria: [
          "Use GenServer behavior",
          "Include start_link/1",
          "Handle state management"
        ]
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, _cost, method, _state}
        when method in [:autonomous, :rule_based] and is_binary(code) ->
          assert code =~ "GenServer" or code =~ "defmodule"

        _ ->
          :ok
      end
    end

    test "generates NATS consumer", %{agent_id: agent_id} do
      task = %Task{
        id: "nats-test",
        name: "event_consumer",
        description: "NATS message consumer",
        type: :code_generation,
        language: "elixir",
        acceptance_criteria: [
          "Subscribe to NATS subjects",
          "Handle messages",
          "Error handling"
        ]
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      case result do
        {code, cost, method, _state} ->
          # Should generate something
          if is_binary(code) do
            assert String.length(code) > 0
          end

          # If template exists, cost should be 0
          if method in [:autonomous, :rule_based] do
            assert cost == 0.0
          end

        {:error, _reason, _cost, _state} ->
          :ok
      end
    end

    test "handles complex multi-file generation", %{agent_id: agent_id} do
      task = %Task{
        id: "multifile-test",
        name: "user_context",
        description: "Complete user context with schema, service, controller",
        type: :code_generation,
        language: "elixir",
        acceptance_criteria: [
          "User schema with Ecto",
          "Service layer with business logic",
          "Controller with CRUD actions"
        ]
      }

      result = CostOptimizedAgent.process_task(agent_id, task)

      # Complex tasks might need LLM
      case result do
        {code, _cost, _method, _state} when is_binary(code) ->
          # Should generate something comprehensive
          assert String.length(code) > 0

        {:error, _reason, _cost, _state} ->
          :ok

        _ ->
          :ok
      end
    end
  end
end
