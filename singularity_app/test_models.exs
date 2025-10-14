alias Singularity.LLM.Service

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("TESTING ALL MODELS")
IO.puts(String.duplicate("=", 70) <> "\n")

# Test configuration: model name and complexity level
tests = [
  %{name: "Gemini 2.5 Flash", complexity: :simple, task_type: :simple_chat},
  %{name: "GPT-4o (Copilot)", complexity: :medium, task_type: :coder},
  %{name: "Sonnet (Claude)", complexity: :medium, task_type: :architect},
  %{name: "Gemini 2.5 Pro", complexity: :complex, task_type: :architect}
]

messages = [
  %{role: "system", content: "You are a test assistant."},
  %{role: "user", content: "Reply with exactly: 'OK'"}
]

Enum.each(tests, fn test ->
  IO.puts("Testing: #{test.name}")
  IO.puts("  Complexity: #{test.complexity}, Task: #{test.task_type}")
  IO.write("  Status: ")

  case Service.call(test.complexity, messages, task_type: test.task_type) do
    {:ok, response} ->
      model = Map.get(response, "model", "unknown")
      content = Map.get(response, "content", "")
      IO.puts("✅ SUCCESS (model: #{model})")

    {:error, reason} ->
      IO.puts("❌ FAILED")
      IO.inspect(reason, label: "  Error")
  end

  IO.puts("")
  :timer.sleep(500) # Small delay between tests
end)

IO.puts(String.duplicate("=", 70))
IO.puts("All tests complete!")
IO.puts(String.duplicate("=", 70))