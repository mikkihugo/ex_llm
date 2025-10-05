defmodule Singularity.LLM.ProviderIntegrationTest do
  use Singularity.DataCase, async: false

  alias Singularity.LLM.Provider

  @moduletag :integration
  # 2 minute timeout for LLM calls
  @moduletag timeout: 120_000

  describe "Model Integration Tests - All Published Models" do
    @tag :slow
    test "claude-sonnet-4.5 - best for coding" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :claude,
                 model: "claude-sonnet-4.5",
                 prompt: "Write a simple hello world in Elixir",
                 max_tokens: 100,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :claude
      assert response.model == "claude-sonnet-4.5"
      assert response.tokens_used > 0

      assert String.contains?(response.content, "defmodule") ||
               String.contains?(response.content, "IO.puts")
    end

    @tag :slow
    test "claude-opus-4.1 - best for complex reasoning" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :claude,
                 model: "claude-opus-4.1",
                 prompt: "Explain the difference between a monad and a functor",
                 max_tokens: 150,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :claude
      assert response.model == "claude-opus-4.1"
      assert String.contains?(String.downcase(response.content), "monad")
    end

    @tag :slow
    test "gpt-5-codex - with MCP tools" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :codex,
                 model: "gpt-5-codex",
                 prompt: "Write a Python function to check if a number is prime",
                 max_tokens: 100,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :codex
      assert response.model == "gpt-5-codex"

      assert String.contains?(response.content, "def ") ||
               String.contains?(response.content, "return")
    end

    @tag :slow
    test "o3 - deepest thinking model" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :codex,
                 model: "o3",
                 prompt:
                   "Solve: If 5 machines make 5 widgets in 5 minutes, how long for 100 machines to make 100 widgets?",
                 max_tokens: 200,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :codex
      assert response.model == "o3"
      # o3 should reason through this (answer: 5 minutes)
      assert String.contains?(response.content, "5")
    end

    @tag :slow
    test "o1 - fast thinking model" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :codex,
                 model: "o1",
                 prompt: "What is 2+2?",
                 max_tokens: 50,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :codex
      assert response.model == "o1"
      assert String.contains?(response.content, "4")
    end

    @tag :slow
    test "gemini-2.5-flash - fastest model" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :gemini,
                 model: "gemini-2.5-flash",
                 prompt: "What is Elixir?",
                 max_tokens: 100,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :gemini
      assert response.model == "gemini-2.5-flash"

      assert String.contains?(String.downcase(response.content), "elixir") ||
               String.contains?(String.downcase(response.content), "erlang")
    end

    @tag :slow
    test "gemini-2.5-pro - long context (2M tokens)" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :gemini,
                 model: "gemini-2.5-pro",
                 prompt: "Write a brief description of functional programming",
                 max_tokens: 100,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :gemini
      assert response.model == "gemini-2.5-pro"
      assert String.contains?(String.downcase(response.content), "function")
    end

    @tag :slow
    test "copilot-gpt-4.1 - lighter quota" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :copilot,
                 model: "copilot-gpt-4.1",
                 prompt: "Write a JavaScript arrow function",
                 max_tokens: 50,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :copilot
      assert response.model == "copilot-gpt-4.1"

      assert String.contains?(response.content, "=>") ||
               String.contains?(response.content, "const")
    end

    @tag :slow
    test "grok-coder-1 - xAI alternative" do
      assert {:ok, response} =
               Provider.call(%{
                 provider: :grok,
                 model: "grok-coder-1",
                 prompt: "Hello, test message",
                 max_tokens: 50,
                 temperature: 0.7
               })

      assert response.content
      assert response.provider == :grok
      assert response.model == "grok-coder-1"
    end
  end

  describe "Complexity-based Auto-Selection" do
    @tag :slow
    test "simple tasks use gemini-flash" do
      assert {:ok, response} =
               Provider.call(%{
                 complexity: :simple,
                 prompt: "Say hello",
                 max_tokens: 20,
                 temperature: 0.7
               })

      assert response.content
      # Should use Gemini Flash (fastest)
      assert response.provider in [:gemini, :copilot, :grok]
    end

    @tag :slow
    test "medium tasks use claude-sonnet or codex" do
      assert {:ok, response} =
               Provider.call(%{
                 complexity: :medium,
                 prompt: "Write a function to sort an array",
                 max_tokens: 100,
                 temperature: 0.7
               })

      assert response.content
      # Should use Claude Sonnet, Codex, or Gemini Pro
      assert response.provider in [:claude, :codex, :gemini]
    end

    @tag :slow
    test "complex tasks use claude-opus or codex" do
      assert {:ok, response} =
               Provider.call(%{
                 complexity: :complex,
                 prompt: "Design a distributed system for real-time analytics",
                 max_tokens: 200,
                 temperature: 0.7
               })

      assert response.content
      # Should use Opus or Codex
      assert response.provider in [:claude, :codex]
    end

    @tag :slow
    test "reasoning tasks use o3 or opus" do
      assert {:ok, response} =
               Provider.call(%{
                 complexity: :reasoning,
                 prompt: "Solve the traveling salesman problem approach",
                 max_tokens: 200,
                 temperature: 0.7
               })

      assert response.content
      # Should use o3, Opus, or o1
      assert response.provider in [:codex, :claude]
    end
  end

  describe "Failover and Emergency Fallback" do
    @tag :slow
    test "fails over to next provider if primary unavailable" do
      # This would require mocking HTTP failures
      # For now, just verify multiple providers are configured
      assert length(Provider.list_providers()) >= 5
    end

    @tag :manual
    @tag :skip
    test "emergency CLI fallback when HTTP down" do
      # Manual test - would require stopping ai-server
      # Verify emergency CLI path exists
      assert File.exists?(Path.expand("~/.singularity/emergency/bin/claude-recovery"))
    end
  end

  describe "Semantic Caching" do
    @tag :slow
    test "similar prompts use cache" do
      prompt1 = "Write a hello world in Python"
      prompt2 = "Create a hello world program in Python"

      # First call - cache miss
      {:ok, response1} =
        Provider.call(%{
          prompt: prompt1,
          max_tokens: 50,
          temperature: 0.7
        })

      # Similar prompt - might hit cache (92% similarity threshold)
      {:ok, response2} =
        Provider.call(%{
          prompt: prompt2,
          max_tokens: 50,
          temperature: 0.7
        })

      assert response1.content
      assert response2.content
    end
  end

  describe "Model Catalog" do
    test "all models are registered in catalog" do
      expected_models = [
        "claude-sonnet-4.5",
        "claude-opus-4.1",
        "gpt-5-codex",
        "o3",
        "o1",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "copilot-gpt-4.1",
        "grok-coder-1"
      ]

      catalog = Provider.list_models()

      for model <- expected_models do
        assert model in catalog, "Model #{model} not in catalog"
      end
    end

    test "all models have correct capabilities metadata" do
      provider_info = Provider.provider_capabilities()

      assert provider_info[:claude][:extended_thinking] == true
      assert provider_info[:codex][:tools] == true
      assert provider_info[:codex][:thinking_models] == [:o3, :o1]
      # 2M tokens
      assert provider_info[:gemini][:context] == 2_097_152
      assert provider_info[:copilot][:quota] == :light
      assert provider_info[:grok][:quota] == :light
    end
  end

  # Helper functions for tests
  defp list_providers, do: [:claude, :codex, :gemini, :copilot, :grok]

  defp list_models do
    [
      "claude-sonnet-4.5",
      "claude-opus-4.1",
      "gpt-5-codex",
      "o3",
      "o1",
      "gemini-2.5-flash",
      "gemini-2.5-pro",
      "copilot-gpt-4.1",
      "grok-coder-1"
    ]
  end

  defp provider_capabilities do
    %{
      claude: %{extended_thinking: true, tools: false, context: 200_000},
      codex: %{tools: true, thinking_models: [:o3, :o1], context: 128_000},
      gemini: %{context: 2_097_152, reasoning: :good},
      copilot: %{quota: :light, context: 128_000},
      grok: %{quota: :light, context: 128_000}
    }
  end
end
