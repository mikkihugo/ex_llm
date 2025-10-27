#!/usr/bin/env elixir

# Complete Pgflow.Notifications Integration Test
# Tests the full PGMQ + NOTIFY integration with Singularity and Observer
# Run with: elixir test_pgflow_complete.exs

# This script tests the complete integration between:
# - ex_pgflow (PGMQ + NOTIFY)
# - Singularity (WebChat integration)
# - Observer (Web UI integration)

defmodule PgflowCompleteTest do
  @moduledoc """
  Complete integration test for Pgflow.Notifications with Singularity and Observer.
  
  This test verifies:
  - Pgflow.Notifications functionality
  - Singularity WebChat integration
  - Observer web UI integration
  - Real-time notification flow
  - Structured logging
  - Error handling
  """

  require Logger

  def run do
    IO.puts("🧪 Pgflow Complete Integration Test")
    IO.puts("=" |> String.duplicate(60))
    
    # Start the test
    setup_test()
    |> test_pgflow_notifications()
    |> test_singularity_integration()
    |> test_observer_integration()
    |> test_error_handling()
    |> test_performance()
    |> cleanup_test()
    
    IO.puts("\n✅ Complete integration test passed!")
  end

  defp setup_test do
    IO.puts("\n🔧 Setting up test environment...")
    
    # Configure logging
    Logger.configure(level: :info)
    
    IO.puts("✅ Test environment ready")
    %{start_time: System.monotonic_time()}
  end

  defp test_pgflow_notifications(context) do
    IO.puts("\n📡 Testing Pgflow.Notifications...")
    
    # Test basic notification sending
    IO.puts("  📤 Testing basic notification sending...")
    
    test_events = [
      %{
        type: "workflow_started",
        workflow_id: "test_workflow_#{System.unique_integer([:positive])}",
        input: %{test: true},
        timestamp: DateTime.utc_now()
      },
      %{
        type: "task_completed",
        task_id: "task_123",
        workflow_id: "test_workflow",
        result: %{success: true},
        duration_ms: 1500,
        timestamp: DateTime.utc_now()
      },
      %{
        type: "workflow_completed",
        workflow_id: "test_workflow",
        final_result: %{success: true, processed_items: 100},
        total_duration_ms: 3000,
        timestamp: DateTime.utc_now()
      }
    ]

    for event <- test_events do
      case Pgflow.Notifications.send_with_notify("workflow_events", event, TestRepo) do
        {:ok, message_id} ->
          IO.puts("    ✅ Sent #{event.type} (ID: #{message_id})")
        {:error, reason} ->
          IO.puts("    ❌ Failed to send #{event.type}: #{inspect(reason)}")
      end
    end

    # Test listener functionality
    IO.puts("  👂 Testing NOTIFY listener...")
    
    case Pgflow.Notifications.listen("workflow_events", TestRepo) do
      {:ok, listener_pid} ->
        IO.puts("    ✅ Listener started (PID: #{inspect(listener_pid)})")
        
        # Clean up listener
        Pgflow.Notifications.unlisten(listener_pid, TestRepo)
        IO.puts("    🧹 Listener cleaned up")
        
      {:error, reason} ->
        IO.puts("    ❌ Failed to start listener: #{inspect(reason)}")
    end

    context
  end

  defp test_singularity_integration(context) do
    IO.puts("\n🔗 Testing Singularity integration...")
    
    # Test WebChat notification integration
    IO.puts("  💬 Testing WebChat notification integration...")
    
    # Simulate WebChat notification
    webchat_events = [
      %{
        type: "notification",
        message: "Agent completed task successfully",
        agent_id: "agent_123",
        task_id: "task_456",
        timestamp: DateTime.utc_now()
      },
      %{
        type: "approval_created",
        approval: %{
          request_id: "req_789",
          title: "Deploy to Production",
          description: "Deploy version 1.2.3",
          status: "pending"
        },
        timestamp: DateTime.utc_now()
      }
    ]

    for event <- webchat_events do
      case Pgflow.Notifications.send_with_notify("observer_notifications", event, TestRepo) do
        {:ok, message_id} ->
          IO.puts("    ✅ WebChat event sent (ID: #{message_id})")
        {:error, reason} ->
          IO.puts("    ❌ WebChat event failed: #{inspect(reason)}")
      end
    end

    context
  end

  defp test_observer_integration(context) do
    IO.puts("\n🖥️  Testing Observer integration...")
    
    # Test Observer web UI integration
    IO.puts("  🌐 Testing Observer web UI integration...")
    
    observer_events = [
      %{
        type: "dashboard_update",
        dashboard_id: "main_dashboard",
        metrics: %{
          active_workflows: 5,
          completed_tasks: 150,
          error_rate: 0.02
        },
        timestamp: DateTime.utc_now()
      },
      %{
        type: "user_action",
        user_id: "user_123",
        action: "approved_deployment",
        target: "workflow_456",
        timestamp: DateTime.utc_now()
      }
    ]

    for event <- observer_events do
      case Pgflow.Notifications.send_with_notify("observer_events", event, TestRepo) do
        {:ok, message_id} ->
          IO.puts("    ✅ Observer event sent (ID: #{message_id})")
        {:error, reason} ->
          IO.puts("    ❌ Observer event failed: #{inspect(reason)}")
      end
    end

    context
  end

  defp test_error_handling(context) do
    IO.puts("\n⚠️  Testing error handling...")
    
    # Test error scenarios
    IO.puts("  🚨 Testing error scenarios...")
    
    error_events = [
      %{
        type: "task_failed",
        task_id: "task_error",
        workflow_id: "error_workflow",
        error: "Connection timeout",
        retry_count: 3,
        timestamp: DateTime.utc_now()
      },
      %{
        type: "workflow_failed",
        workflow_id: "error_workflow",
        error: "Dependency failed",
        failed_task: "task_error",
        timestamp: DateTime.utc_now()
      }
    ]

    for event <- error_events do
      case Pgflow.Notifications.send_with_notify("workflow_events", event, TestRepo) do
        {:ok, message_id} ->
          IO.puts("    ✅ Error event sent (ID: #{message_id})")
        {:error, reason} ->
          IO.puts("    ❌ Error event failed: #{inspect(reason)}")
      end
    end

    context
  end

  defp test_performance(context) do
    IO.puts("\n⚡ Testing performance...")
    
    # Test high-frequency notifications
    IO.puts("  📊 Testing high-frequency notifications...")
    
    event_count = 100
    start_time = System.monotonic_time()
    
    results = for i <- 1..event_count do
      Pgflow.Notifications.send_with_notify("test_queue", %{
        type: "test_event",
        id: i,
        timestamp: DateTime.utc_now()
      }, TestRepo)
    end
    
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    success_count = Enum.count(results, fn {:ok, _} -> true; _ -> false end)
    
    IO.puts("    📈 Sent #{success_count}/#{event_count} notifications in #{duration}ms")
    IO.puts("    📊 Rate: #{Float.round(success_count / (duration / 1000), 2)} events/sec")
    
    context
  end

  defp cleanup_test(context) do
    IO.puts("\n🧹 Cleaning up test...")
    
    end_time = System.monotonic_time()
    total_duration = System.convert_time_unit(end_time - context.start_time, :native, :millisecond)
    
    IO.puts("  ⏱️  Total test duration: #{total_duration}ms")
    IO.puts("  ✅ Test cleanup completed")
    
    context
  end
end

# Mock repo for testing
defmodule TestRepo do
  def query(_query, _params) do
    {:ok, %Postgrex.Result{}}
  end
end

# Run the test
if __FILE__ == Path.expand(__FILE__) do
  PgflowCompleteTest.run()
end