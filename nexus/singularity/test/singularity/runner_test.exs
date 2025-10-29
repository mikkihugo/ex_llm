defmodule Singularity.RunnerTest do
  @moduledoc """
  Tests for the Runner module with integrated functionality.
  """

  use ExUnit.Case, async: false
  require Logger

  alias Singularity.Execution.Runners.Runner

  @moduletag :integration

  describe "Runner integration" do
    setup do
      # Start the runner if not already running
      case GenServer.whereis(Runner) do
        nil ->
          {:ok, _pid} = Runner.start_link()

        _pid ->
          :ok
      end

      :ok
    end

    test "executes simple analysis task" do
      task = %{
        type: :analysis,
        args: %{
          path: "/tmp/test-codebase",
          options: %{depth: "shallow"}
        }
      }

      # Execute task
      result = Runner.execute_task(task)

      # Verify result structure
      assert {:ok, analysis_result} = result
      assert analysis_result.type == :analysis
      assert analysis_result.completed_at != nil
      assert Map.has_key?(analysis_result, :discovery)
      assert Map.has_key?(analysis_result, :structural)
      assert Map.has_key?(analysis_result, :semantic)
      assert Map.has_key?(analysis_result, :ai_insights)
    end

    test "executes tool task" do
      task = %{
        type: :tool,
        args: %{
          tool: "file_system",
          args: %{path: "/tmp", recursive: true}
        }
      }

      # Execute task
      result = Runner.execute_task(task)

      # Verify result structure
      assert {:ok, tool_result} = result
      assert tool_result.type == :tool
      assert tool_result.tool == "file_system"
      assert tool_result.completed_at != nil
    end

    test "executes concurrent tasks" do
      tasks = [
        %{
          type: :analysis,
          args: %{path: "/tmp/test1"}
        },
        %{
          type: :tool,
          args: %{tool: "file_system", args: %{path: "/tmp"}}
        }
      ]

      # Execute concurrent tasks
      result = Runner.execute_concurrent(tasks, max_concurrency: 2)

      # Verify results
      assert {:ok, results} = result
      assert length(results) == 2

      # Check each result
      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end

    test "streams execution with backpressure" do
      tasks = [
        %{
          type: :analysis,
          args: %{path: "/tmp/test1"}
        },
        %{
          type: :analysis,
          args: %{path: "/tmp/test2"}
        },
        %{
          type: :analysis,
          args: %{path: "/tmp/test3"}
        }
      ]

      # Stream execution
      stream = Runner.stream_execution(tasks, max_concurrency: 2)
      results = Enum.to_list(stream)

      # Verify results
      assert length(results) == 3

      # Check each result
      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end

    test "gets execution statistics" do
      stats = Runner.get_stats()

      # Verify stats structure
      assert is_map(stats)
      assert Map.has_key?(stats, :active_executions)
      assert Map.has_key?(stats, :total_executions)
      assert Map.has_key?(stats, :metrics)
      assert Map.has_key?(stats, :circuit_breakers)
      assert Map.has_key?(stats, :supervisor_children)
      assert Map.has_key?(stats, :nats_connected)
      assert Map.has_key?(stats, :execution_history_count)
    end

    test "gets circuit breaker status" do
      status = Runner.get_circuit_status()

      # Verify circuit breaker status
      assert is_map(status)
      assert Map.has_key?(status, :llm_service)
      assert Map.has_key?(status, :database)
      assert Map.has_key?(status, :external_apis)
    end

    test "gets execution history" do
      history = Runner.get_execution_history(limit: 10)

      # Verify history structure
      assert is_list(history)

      # Check history items if any exist
      if length(history) > 0 do
        first_item = List.first(history)
        assert Map.has_key?(first_item, :id)
        assert Map.has_key?(first_item, :task_type)
        assert Map.has_key?(first_item, :status)
        assert Map.has_key?(first_item, :started_at)
      end
    end

    test "publishes NATS events" do
      # Test NATS event publishing
      result = Runner.publish_event("test.event", %{message: "test"})

      # Should succeed even if NATS is not available
      assert result == :ok
    end

    test "handles task failures gracefully" do
      task = %{
        type: :unknown_type,
        args: %{}
      }

      # Execute invalid task
      result = Runner.execute_task(task)

      # Verify error handling
      assert {:error, :unknown_task_type} = result
    end

    test "persists execution history" do
      task = %{
        type: :analysis,
        args: %{path: "/tmp/test-persistence"}
      }

      # Execute task
      {:ok, _result} = Runner.execute_task(task)

      # Wait a moment for persistence
      Process.sleep(100)

      # Check execution history
      history = Runner.get_execution_history(limit: 1)

      # Should have at least one record
      assert length(history) >= 1

      # Check the most recent record
      recent = List.first(history)
      assert recent.task_type == "analysis"
      assert recent.status in ["completed", "running", "failed"]
    end
  end
end
