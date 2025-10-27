#!/usr/bin/env elixir

# Test PGMQ + NOTIFY integration
# Run with: elixir test_pgmq_notify.exs

# Start the application
Application.ensure_all_started(:singularity)

# Test sending a notification via PGMQ + NOTIFY
alias Singularity.Conversation.WebChat

IO.puts("🧪 Testing PGMQ + NOTIFY integration...")

# Test 1: Send a notification
IO.puts("\n1. Sending notification...")
case WebChat.notify("Test notification from PGMQ + NOTIFY!", %{
  test: true,
  timestamp: DateTime.utc_now()
}) do
  {:ok, message_id} ->
    IO.puts("✅ Notification sent successfully! Message ID: #{message_id}")
  {:error, reason} ->
    IO.puts("❌ Failed to send notification: #{inspect(reason)}")
end

# Test 2: Send an approval request
IO.puts("\n2. Sending approval request...")
case WebChat.ask_approval(%{
  request_id: "test_approval_#{System.unique_integer([:positive])}",
  title: "Test Approval",
  description: "This is a test approval request via PGMQ + NOTIFY",
  impact: "low",
  confidence: 0.8,
  metadata: %{test: true}
}) do
  {:ok, approval} ->
    IO.puts("✅ Approval request sent successfully!")
    IO.puts("   Request ID: #{approval.request_id}")
    IO.puts("   Response Queue: #{approval.response_queue}")
  {:error, reason} ->
    IO.puts("❌ Failed to send approval request: #{inspect(reason)}")
end

IO.puts("\n🎉 PGMQ + NOTIFY test completed!")
IO.puts("\nCheck the Observer web interface to see if the messages appear in real-time!")