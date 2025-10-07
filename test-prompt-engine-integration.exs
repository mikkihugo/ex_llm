# Test script for prompt engine integration
# Run with: elixir test-prompt-engine-integration.exs

# Test prompt engine client
defmodule PromptEngineTest do
  def run_tests do
    IO.puts("🧪 Testing Prompt Engine Integration...")
    
    # Test 1: Health check
    IO.puts("\n1. Testing health check...")
    case Singularity.LLM.PromptEngineClient.health_check() do
      :ok ->
        IO.puts("✅ Prompt engine is available")
      {:error, reason} ->
        IO.puts("❌ Prompt engine health check failed: #{inspect(reason)}")
        return
    end
    
    # Test 2: Generate framework prompt
    IO.puts("\n2. Testing framework prompt generation...")
    case Singularity.LLM.PromptEngineClient.generate_framework_prompt(
      "Create a REST API controller", 
      "phoenix", 
      "commands"
    ) do
      {:ok, %{prompt: prompt, confidence: confidence}} ->
        IO.puts("✅ Generated Phoenix prompt")
        IO.puts("   Confidence: #{confidence}")
        IO.puts("   Prompt preview: #{String.slice(prompt, 0, 100)}...")
      {:error, reason} ->
        IO.puts("❌ Framework prompt generation failed: #{inspect(reason)}")
    end
    
    # Test 3: Generate language prompt
    IO.puts("\n3. Testing language prompt generation...")
    case Singularity.LLM.PromptEngineClient.generate_language_prompt(
      "Create a function to parse JSON", 
      "elixir", 
      "examples"
    ) do
      {:ok, %{prompt: prompt, confidence: confidence}} ->
        IO.puts("✅ Generated Elixir prompt")
        IO.puts("   Confidence: #{confidence}")
        IO.puts("   Prompt preview: #{String.slice(prompt, 0, 100)}...")
      {:error, reason} ->
        IO.puts("❌ Language prompt generation failed: #{inspect(reason)}")
    end
    
    # Test 4: Optimize prompt
    IO.puts("\n4. Testing prompt optimization...")
    case Singularity.LLM.PromptEngineClient.optimize_prompt(
      "Write a function that does something",
      context: "Create a utility function for data processing",
      language: "elixir"
    ) do
      {:ok, %{optimized_prompt: optimized, optimization_score: score}} ->
        IO.puts("✅ Prompt optimized")
        IO.puts("   Optimization score: #{score}")
        IO.puts("   Optimized preview: #{String.slice(optimized, 0, 100)}...")
      {:error, reason} ->
        IO.puts("❌ Prompt optimization failed: #{inspect(reason)}")
    end
    
    # Test 5: List templates
    IO.puts("\n5. Testing template listing...")
    case Singularity.LLM.PromptEngineClient.list_templates() do
      {:ok, templates} ->
        IO.puts("✅ Retrieved #{length(templates)} templates")
        templates
        |> Enum.take(3)
        |> Enum.each(fn template ->
          IO.puts("   - #{template["template_id"]} (#{template["language"]})")
        end)
      {:error, reason} ->
        IO.puts("❌ Template listing failed: #{inspect(reason)}")
    end
    
    # Test 6: LLM Service with optimization (complexity-based)
    IO.puts("\n6. Testing LLM Service with optimization...")
    case Singularity.LLM.Service.call_optimized(
      :medium,
      "Create a Phoenix controller for user management",
      "elixir"
    ) do
      {:ok, %{text: text, optimized: optimized}} ->
        IO.puts("✅ LLM call successful")
        IO.puts("   Optimized: #{optimized}")
        IO.puts("   Response preview: #{String.slice(text, 0, 100)}...")
      {:error, reason} ->
        IO.puts("❌ LLM call failed: #{inspect(reason)}")
    end
    
    # Test 7: Different complexity levels
    IO.puts("\n7. Testing different complexity levels...")
    
    # Simple complexity
    case Singularity.LLM.Service.call_optimized(
      :simple,
      "Create a simple function",
      "elixir"
    ) do
      {:ok, %{text: text, optimized: optimized}} ->
        IO.puts("✅ Simple complexity call successful (optimized: #{optimized})")
      {:error, reason} ->
        IO.puts("❌ Simple complexity call failed: #{inspect(reason)}")
    end
    
    # Complex complexity
    case Singularity.LLM.Service.call_optimized(
      :complex,
      "Create a distributed microservice architecture",
      "elixir"
    ) do
      {:ok, %{text: text, optimized: optimized}} ->
        IO.puts("✅ Complex complexity call successful (optimized: #{optimized})")
      {:error, reason} ->
        IO.puts("❌ Complex complexity call failed: #{inspect(reason)}")
    end
    
    IO.puts("\n🎉 Prompt Engine Integration Test Complete!")
  end
end

# Run the tests
PromptEngineTest.run_tests()
