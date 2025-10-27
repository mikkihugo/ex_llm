defmodule Nexus.Providers.CodexTest do
  @moduledoc """
  Unit tests for Nexus.Providers.Codex - ChatGPT Pro OAuth2 integration provider.

  ## What This Tests

  - **Model Listing**: Available models and their properties (gpt-5, gpt-5-codex, codex-mini-latest)
  - **Configuration Status**: Whether provider has valid OAuth tokens configured
  - **Error Handling**: Graceful failures when tokens unavailable
  - **Dependency Injection**: HTTP client and token repository are configurable

  ## What This Does NOT Test

  - **Actual HTTP Calls**: Uses MockReq to simulate HTTP (use integration tests for real API)
  - **Token Management**: Token refresh, expiration (use OAuthToken unit tests)
  - **Chat Execution**: Actual LLM API calls (use integration tests)

  ## Test Infrastructure

  **Mocking Strategy**: Simple Elixir module mocks defined in test/test_helper.exs
  - `MockReq`: Simulates Req HTTP client (returns default errors)
  - `MockOAuthToken`: Simulates token storage (returns :not_found by default)

  Configuration via `Application.put_env/3` - no external Mox dependency needed.
  Each test inherits the configured mocks automatically.
  """

  use ExUnit.Case, async: false

  alias Nexus.Providers.Codex

  # ======================================================================
  # Test Setup: Configure dependency injection for all tests in this module
  # ======================================================================

  setup do
    # Replace real HTTP client and token repository with simple mocks
    # This allows tests to run without network or database access
    Application.put_env(:nexus, :http_client, MockReq)
    Application.put_env(:nexus, :token_repository, MockOAuthToken)

    # Clean up test configuration after test completes
    on_exit(fn ->
      Application.delete_env(:nexus, :http_client)
      Application.delete_env(:nexus, :token_repository)
    end)

    :ok
  end

  describe "list_models/0" do
    test "returns non-empty list of models" do
      models = Codex.list_models()

      assert is_list(models)
      assert length(models) >= 3  # At least 3 models: gpt-5, gpt-5-codex, codex-mini-latest
    end

    test "each model has required fields" do
      models = Codex.list_models()

      Enum.each(models, fn model ->
        # Every model MUST have these fields
        assert is_map(model)
        assert Map.has_key?(model, :id), "Model missing :id - #{inspect(model)}"
        assert Map.has_key?(model, :name), "Model missing :name - #{inspect(model)}"
        assert Map.has_key?(model, :context_window), "Model missing :context_window - #{inspect(model)}"
        assert Map.has_key?(model, :max_output_tokens), "Model missing :max_output_tokens - #{inspect(model)}"
        assert Map.has_key?(model, :capabilities), "Model missing :capabilities - #{inspect(model)}"
      end)
    end

    test "model fields have valid types" do
      models = Codex.list_models()

      Enum.each(models, fn model ->
        assert is_binary(model.id), "Model :id must be string"
        assert is_binary(model.name), "Model :name must be string"
        assert is_integer(model.context_window), "Model :context_window must be integer"
        assert is_integer(model.max_output_tokens), "Model :max_output_tokens must be integer"
        assert is_list(model.capabilities), "Model :capabilities must be list"
      end)
    end

    test "model values are reasonable" do
      models = Codex.list_models()

      Enum.each(models, fn model ->
        assert model.context_window > 0, "context_window must be > 0"
        assert model.max_output_tokens > 0, "max_output_tokens must be > 0"
        assert model.max_output_tokens < model.context_window, "max_output_tokens must be < context_window"
        assert Enum.all?(model.capabilities, &is_atom/1), "capabilities must be atoms"
      end)
    end

    test "includes gpt-5 model" do
      models = Codex.list_models()
      ids = Enum.map(models, & &1.id)

      assert "gpt-5" in ids
    end

    test "includes gpt-5-codex model" do
      models = Codex.list_models()
      ids = Enum.map(models, & &1.id)

      assert "gpt-5-codex" in ids
    end

    test "includes codex-mini-latest model" do
      models = Codex.list_models()
      ids = Enum.map(models, & &1.id)

      assert "codex-mini-latest" in ids
    end

    test "gpt-5 model has correct properties" do
      models = Codex.list_models()
      gpt5 = Enum.find(models, fn m -> m.id == "gpt-5" end)

      assert gpt5 != nil, "gpt-5 model not found"
      assert gpt5.name == "GPT-5"
      assert gpt5.context_window == 400_000
      assert gpt5.max_output_tokens == 128_000
      assert is_list(gpt5.capabilities)
      assert Enum.member?(gpt5.capabilities, :chat)
    end

    test "gpt-5-codex model has correct properties" do
      models = Codex.list_models()
      codex = Enum.find(models, fn m -> m.id == "gpt-5-codex" end)

      assert codex != nil, "gpt-5-codex model not found"
      assert codex.name == "GPT-5 Codex"
      assert codex.context_window == 400_000
      assert codex.max_output_tokens == 128_000
      assert Enum.member?(codex.capabilities, :code_generation)
    end

    test "codex-mini-latest model has correct properties" do
      models = Codex.list_models()
      mini = Enum.find(models, fn m -> m.id == "codex-mini-latest" end)

      assert mini != nil, "codex-mini-latest model not found"
      assert mini.name == "Codex Mini Latest"
      assert mini.context_window == 200_000
      assert mini.max_output_tokens == 100_000
    end
  end

  describe "configured?/0" do
    test "returns true when real Codex configuration is available" do
      # This test now checks if real ~/.codex configuration is available
      configured = Codex.configured?()

      # Should be true if ~/.codex/auth.json exists with valid tokens
      assert configured == true
    end
  end

  describe "chat/2 - with mocked dependencies" do
    test "returns error when token not available" do
      messages = [%{role: "user", content: "Hello"}]

      # MockOAuthToken.get returns error by default
      {:error, _reason} = Codex.chat(messages)
    end
  end

  describe "stream/3 - with mocked dependencies" do
    test "returns error when token not available" do
      messages = [%{role: "user", content: "Hello"}]
      callback = fn _chunk -> :ok end

      # stream/3 calls get_valid_token, which fails when token not available
      {:error, _reason} = Codex.stream(messages, callback)
    end
  end
end
