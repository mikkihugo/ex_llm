# Simple test to verify NATS and LLM are working
IO.puts("Testing NATS connection...")

# Test if we can connect to NATS
case :gnat.start_link(%{host: "localhost", port: 4222}) do
  {:ok, conn} ->
    IO.puts("✅ NATS connection successful")
    :gnat.stop(conn)
  {:error, reason} ->
    IO.puts("❌ NATS connection failed: #{inspect(reason)}")
end

IO.puts("Test complete!")