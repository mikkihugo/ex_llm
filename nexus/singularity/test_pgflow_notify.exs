#!/usr/bin/env elixir

# Test QuantumFlow.Notifications integration
# Run with: elixir test_quantum_flow_notify.exs

# Start the application
Application.ensure_all_started(:singularity)

# Test QuantumFlow.Notifications
alias QuantumFlow.Notifications

IO.puts("🧪 Testing QuantumFlow.Notifications integration...")

# Test 1: Send a notification with NOTIFY
IO.puts("\n1. Sending notification via QuantumFlow.Notifications...")
case Notifications.send_with_notify("observer_notifications", %{
  type: "notification",
  message: "Test notification from QuantumFlow.Notifications!",
  timestamp: DateTime.utc_now(),
  test: true
}, Singularity.Repo) do
  {:ok, message_id} ->
    IO.puts("✅ Notification sent successfully! Message ID: #{message_id}")
  {:error, reason} ->
    IO.puts("❌ Failed to send notification: #{inspect(reason)}")
end

# Test 2: Send an approval event
IO.puts("\n2. Sending approval event via QuantumFlow.Notifications...")
case Notifications.send_with_notify("observer_approvals", %{
  type: "approval_created",
  approval: %{
    request_id: "test_approval_#{System.unique_integer([:positive])}",
    title: "Test Approval",
    description: "This is a test approval request",
    status: "pending"
  },
  timestamp: DateTime.utc_now()
}, Singularity.Repo) do
  {:ok, message_id} ->
    IO.puts("✅ Approval event sent successfully! Message ID: #{message_id}")
  {:error, reason} ->
    IO.puts("❌ Failed to send approval event: #{inspect(reason)}")
end

IO.puts("\n🎉 QuantumFlow.Notifications test completed!")
IO.puts("\nCheck the logs for detailed NOTIFY event logging!")
IO.puts("All NOTIFY events should be properly logged with structured data.")