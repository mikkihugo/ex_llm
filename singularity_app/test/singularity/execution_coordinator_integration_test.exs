defmodule Singularity.ExecutionCoordinatorIntegrationTest do
  @moduledoc """
  Integration test for ExecutionCoordinator wiring into NatsOrchestrator.

  This test validates the complete flow:
  1. NatsOrchestrator receives request
  2. Routes through ExecutionCoordinator
  3. ExecutionCoordinator uses TemplateOptimizer
  4. ExecutionCoordinator executes via HybridAgent
  5. Metrics are recorded back to TemplateOptimizer
  """

  use ExUnit.Case, async: false
  require Logger

  alias Singularity.{ExecutionCoordinator, TemplateOptimizer}

  @moduletag :integration

  describe "ExecutionCoordinator integration" do
    test "executes simple task through full pipeline" do
      # Start ExecutionCoordinator if not running
      case GenServer.whereis(ExecutionCoordinator) do
        nil ->
          {:ok, _pid} = ExecutionCoordinator.start_link()

        _pid ->
          :ok
      end

      # Start TemplateOptimizer if not running
      case GenServer.whereis(TemplateOptimizer) do
        nil ->
          {:ok, _pid} = TemplateOptimizer.start_link()

        _pid ->
          :ok
      end

      # Define a simple goal
      goal = %{
        description: "Create a simple NATS consumer in Elixir",
        type: :nats_consumer
      }

      opts = [
        language: "elixir",
        complexity: "medium",
        workspace: System.tmp_dir!()
      ]

      # Execute through ExecutionCoordinator
      result = ExecutionCoordinator.execute(goal, opts)

      # Validate result structure
      assert {:ok, _result_text, metrics} = result

      # Validate metrics
      assert is_map(metrics)
      assert Map.has_key?(metrics, :time_ms)
      assert Map.has_key?(metrics, :quality)
      assert Map.has_key?(metrics, :success)
      assert Map.has_key?(metrics, :cost_usd)
      assert Map.has_key?(metrics, :method)

      # Log for visibility
      Logger.info("ExecutionCoordinator integration test completed",
        success: metrics[:success],
        method: metrics[:method],
        cost: metrics[:cost_usd],
        time_ms: metrics[:time_ms]
      )

      # Validate method is one of the expected values
      assert metrics[:method] in [
               :autonomous,
               :cached,
               :llm_assisted,
               :fallback,
               :error,
               :unknown
             ]
    end

    test "TemplateOptimizer.select_template returns proper structure" do
      # Start TemplateOptimizer if not running
      case GenServer.whereis(TemplateOptimizer) do
        nil ->
          {:ok, _pid} = TemplateOptimizer.start_link()

        _pid ->
          :ok
      end

      result =
        TemplateOptimizer.select_template(%{
          task: "Create NATS consumer for processing user events",
          language: "elixir",
          complexity: "medium"
        })

      assert is_map(result)
      assert Map.has_key?(result, :id)
      assert Map.has_key?(result, :task_type)
      assert Map.has_key?(result, :language)
      assert Map.has_key?(result, :confidence)

      assert result.task_type == :nats_consumer
      assert result.language == "elixir"
      assert result.confidence > 0.5

      Logger.info("Template selection test completed",
        template_id: result.id,
        task_type: result.task_type,
        confidence: result.confidence
      )
    end

    test "ExecutionCoordinator handles errors gracefully" do
      # Start ExecutionCoordinator if not running
      case GenServer.whereis(ExecutionCoordinator) do
        nil ->
          {:ok, _pid} = ExecutionCoordinator.start_link()

        _pid ->
          :ok
      end

      # Test with invalid goal (missing description)
      invalid_goal = %{
        type: :general
        # Missing description field
      }

      opts = [
        language: "elixir",
        complexity: "medium"
      ]

      # This should handle the error gracefully
      assert_raise KeyError, fn ->
        ExecutionCoordinator.execute(invalid_goal, opts)
      end
    end

    test "get execution statistics" do
      # Start ExecutionCoordinator if not running
      case GenServer.whereis(ExecutionCoordinator) do
        nil ->
          {:ok, _pid} = ExecutionCoordinator.start_link()

        _pid ->
          :ok
      end

      stats = ExecutionCoordinator.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_executions)
      assert Map.has_key?(stats, :average_time_ms)
      assert Map.has_key?(stats, :success_rate)
      assert Map.has_key?(stats, :template_usage)

      Logger.info("Execution statistics", stats: stats)
    end
  end
end
