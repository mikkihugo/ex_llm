alias Singularity.LLM.Service

IO.puts("Testing single model...")

messages = [
  %{role: "system", content: "You are a test assistant."},
  %{role: "user", content: "Reply with exactly: 'OK'"}
]

case Service.call(:simple, messages, task_type: :simple_chat) do
  {:ok, response} ->
    model = Map.get(response, "model", "unknown")
    content = Map.get(response, "content", "")
    IO.puts("✅ SUCCESS!")
    IO.puts("  Model: #{model}")
    IO.puts("  Response: #{String.trim(content)}")
  {:error, reason} ->
    IO.puts("❌ FAILED: #{inspect(reason)}")
end