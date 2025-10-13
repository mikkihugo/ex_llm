# Test Unified NATS System
# Tests the single unified NATS server architecture

IO.puts("🧪 Testing Unified NATS System...")

# Test 1: Local NIF Detection
IO.puts("\n1️⃣ Testing Local NIF Detection...")
case Singularity.ArchitectureEngine.detect_frameworks(".") do
  {:ok, result} ->
    IO.puts("✅ Local detection working")
    IO.inspect(result, label: "Frameworks detected")
  {:error, reason} ->
    IO.puts("❌ Local detection failed: #{inspect(reason)}")
end

# Test 2: Unified NATS Server
IO.puts("\n2️⃣ Testing Unified NATS Server...")
case Singularity.NatsServer.request(
  :detect_framework,
  %{
    patterns: ["use Phoenix", "defmodule MyAppWeb"],
    context: "elixir phoenix application"
  },
  complexity: :medium
) do
  {:ok, result} ->
    IO.puts("✅ Unified NATS server working")
    IO.inspect(result, label: "NATS response")
  {:error, reason} ->
    IO.puts("❌ Unified NATS server failed: #{inspect(reason)}")
end

# Test 3: Technology Agent (Remote Detection)
IO.puts("\n3️⃣ Testing Technology Agent...")
case Singularity.TechnologyAgent.detect_technologies(".", complexity: :simple) do
  {:ok, result} ->
    IO.puts("✅ Technology agent working")
    IO.inspect(result, label: "Technology detection")
  {:error, reason} ->
    IO.puts("❌ Technology agent failed: #{inspect(reason)}")
end

# Test 4: LLM Auto-discovery
IO.puts("\n4️⃣ Testing LLM Auto-discovery...")
case Singularity.NatsServer.request(
  :detect_framework,
  %{
    patterns: ["unknown_pattern_xyz", "mystery_code"],
    context: "unknown framework detection test"
  },
  complexity: :complex
) do
  {:ok, result} ->
    IO.puts("✅ LLM auto-discovery working")
    IO.inspect(result, label: "LLM detection")
  {:error, reason} ->
    IO.puts("❌ LLM auto-discovery failed: #{inspect(reason)}")
end

IO.puts("\n🎉 Unified NATS System Test Complete!")
IO.puts("\nArchitecture Summary:")
IO.puts("  🏠 Local Detection: NIF (fast, your codebase)")
IO.puts("  🌐 Remote Detection: Unified NATS server (sophisticated, external packages)")
IO.puts("  🤖 LLM Auto-discovery: 5-level detection with AI fallback")
IO.puts("  📡 Single Entry Point: nats.request")