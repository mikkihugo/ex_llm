#!/usr/bin/env elixir

# Test PGMQ + NOTIFY integration directly
# Run with: elixir test_pgmq_simple.exs

# Start the application
Application.ensure_all_started(:singularity)

# Test sending a message via PGMQ + NOTIFY
alias Singularity.Jobs.PgmqClient

IO.puts("🧪 Testing PGMQ + NOTIFY integration...")

# Test 1: Send a message via PGMQ
IO.puts("\n1. Sending message via PGMQ...")
case PgmqClient.send_message("observer_notifications", %{
  type: "notification",
  message: "Test notification from PGMQ + NOTIFY!",
  timestamp: DateTime.utc_now(),
  test: true
}) do
  {:ok, message_id} ->
    IO.puts("✅ Message sent successfully! Message ID: #{message_id}")
    
    # Test 2: Trigger NOTIFY
    IO.puts("\n2. Triggering NOTIFY...")
    case Singularity.Repo.query("SELECT pg_notify($1, $2)", ["pgmq_observer_notifications", message_id]) do
      {:ok, _} ->
        IO.puts("✅ NOTIFY triggered successfully!")
      {:error, reason} ->
        IO.puts("❌ Failed to trigger NOTIFY: #{inspect(reason)}")
    end
    
  {:error, reason} ->
    IO.puts("❌ Failed to send message: #{inspect(reason)}")
end

IO.puts("\n🎉 PGMQ + NOTIFY test completed!")
IO.puts("\nThe message should now be in the PGMQ queue and NOTIFY should have been triggered!")