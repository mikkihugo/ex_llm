defmodule Nexus.Integration.CodexIntegrationTest do
  @moduledoc """
  Integration tests for Codex provider with real database.

  Tests the complete Codex provider functionality including:
  - OAuth token storage and retrieval
  - Token refresh logic
  - Model listing and configuration
  - Error handling with real database

  ## What This Tests

  - **Database Integration**: Real PostgreSQL operations with OAuth tokens
  - **Token Management**: Store, retrieve, refresh, and expire tokens
  - **Provider Configuration**: Check if Codex is properly configured
  - **Model Operations**: List models and check capabilities
  - **Error Handling**: Graceful failures when tokens unavailable

  ## What This Does NOT Test

  - **Actual HTTP Calls**: No real API calls to ChatGPT Pro (use manual testing)
  - **OAuth2 Flow**: No browser-based authentication (use manual setup)
  - **Token Refresh**: Mocked refresh responses (real refresh needs valid tokens)

  ## Test Infrastructure

  Uses real database operations for integration testing.
  Each test cleans up after itself by deleting test tokens.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias Nexus.OAuthToken
  alias Nexus.Providers.Codex

  # ======================================================================
  # Test Setup: Real database with sandbox isolation
  # ======================================================================

  setup do
    # Clean up any existing tokens
    OAuthToken.delete("codex")
    
    :ok
  end

  describe "OAuth Token Management" do
    test "stores and retrieves OAuth tokens" do
      # Create a test token
      token_attrs = %{
        access_token: "test_access_token_123",
        refresh_token: "test_refresh_token_456",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["openai.user.read", "model.request"],
        token_type: "Bearer",
        metadata: %{"test" => true}
      }

      # Store token
      {:ok, stored_token} = OAuthToken.upsert("codex", token_attrs)
      assert stored_token.provider == "codex"
      assert stored_token.access_token == "test_access_token_123"
      assert stored_token.refresh_token == "test_refresh_token_456"
      assert stored_token.scopes == ["openai.user.read", "model.request"]

      # Retrieve token
      {:ok, retrieved_token} = OAuthToken.get("codex")
      assert retrieved_token.id == stored_token.id
      assert retrieved_token.access_token == "test_access_token_123"
    end

    test "handles token expiration correctly" do
      # Create expired token
      expired_token = %{
        access_token: "expired_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second), # 1 hour ago
        scopes: ["openai.user.read"]
      }

      {:ok, token} = OAuthToken.upsert("codex", expired_token)
      assert OAuthToken.expired?(token) == true

      # Create valid token
      valid_token = %{
        access_token: "valid_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second), # 1 hour from now
        scopes: ["openai.user.read"]
      }

      {:ok, token} = OAuthToken.upsert("codex", valid_token)
      assert OAuthToken.expired?(token) == false
    end

    test "converts between OAuthToken and ex_llm formats" do
      # Create token
      token_attrs = %{
        access_token: "access_123",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["scope1", "scope2"],
        token_type: "Bearer"
      }

      {:ok, token} = OAuthToken.upsert("codex", token_attrs)

      # Convert to ex_llm format
      ex_llm_format = OAuthToken.to_ex_llm_format(token)
      assert ex_llm_format.access_token == "access_123"
      assert ex_llm_format.refresh_token == "refresh_456"
      assert ex_llm_format.token_type == "Bearer"
      assert ex_llm_format.scope == "scope1 scope2"

      # Convert back from ex_llm format
      converted_attrs = OAuthToken.from_ex_llm_format(ex_llm_format)
      assert converted_attrs.access_token == "access_123"
      assert converted_attrs.refresh_token == "refresh_456"
      assert converted_attrs.token_type == "Bearer"
      assert converted_attrs.scopes == ["scope1", "scope2"]
    end
  end

  describe "Codex Provider with Real Database" do
    test "configured? returns false when no token exists" do
      # Ensure no token exists
      OAuthToken.delete("codex")
      
      assert Codex.configured?() == false
    end

    test "configured? returns true when valid token exists" do
      # Create valid token
      token_attrs = %{
        access_token: "valid_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["openai.user.read"]
      }

      {:ok, _token} = OAuthToken.upsert("codex", token_attrs)
      
      assert Codex.configured?() == true
    end

    test "list_models works with real database" do
      models = Codex.list_models()
      
      assert is_list(models)
      assert length(models) == 3
      
      # Check all required models exist
      ids = Enum.map(models, & &1.id)
      assert "gpt-5" in ids
      assert "gpt-5-codex" in ids
      assert "codex-mini-latest" in ids
    end

    test "provider_name and default_model work" do
      assert Codex.provider_name() == "codex"
      assert Codex.default_model() == "gpt-5"
    end

    test "chat returns error when no token available" do
      # Ensure no token exists
      OAuthToken.delete("codex")
      
      messages = [%{role: "user", content: "Hello"}]
      
      {:error, reason} = Codex.chat(messages)
      assert reason == :not_found
    end
  end

  describe "Model Capabilities and Properties" do
    test "gpt-5 model has correct properties" do
      models = Codex.list_models()
      gpt5 = Enum.find(models, fn m -> m.id == "gpt-5" end)
      
      assert gpt5 != nil
      assert gpt5.name == "GPT-5"
      assert gpt5.context_window == 400_000
      assert gpt5.max_output_tokens == 128_000
      assert :thinking in gpt5.capabilities
      assert gpt5.thinking_levels == [:low, :medium, :high]
      assert gpt5.cost == :free
      assert gpt5.pricing == "Free with volume limits"
      assert gpt5.quota_usage == %{low: 1.0, medium: 3.0, high: 5.0}
    end

    test "gpt-5-codex model has correct properties" do
      models = Codex.list_models()
      codex = Enum.find(models, fn m -> m.id == "gpt-5-codex" end)
      
      assert codex != nil
      assert codex.name == "GPT-5 Codex"
      assert codex.context_window == 400_000
      assert codex.max_output_tokens == 128_000
      assert :code_generation in codex.capabilities
      assert :thinking in codex.capabilities
      assert codex.thinking_levels == [:low, :medium, :high]
      assert codex.cost == :free
      assert codex.pricing == "Free with volume limits"
      assert codex.quota_usage == %{low: 1.0, medium: 3.0, high: 5.0}
    end

    test "codex-mini-latest model has correct properties" do
      models = Codex.list_models()
      mini = Enum.find(models, fn m -> m.id == "codex-mini-latest" end)
      
      assert mini != nil
      assert mini.name == "Codex Mini Latest"
      assert mini.context_window == 200_000
      assert mini.max_output_tokens == 100_000
      assert :code_generation in mini.capabilities
      assert mini.thinking_levels == nil  # No thinking capability
      assert mini.cost == :free
      assert mini.pricing == "Free with volume limits"
      assert mini.quota_usage == %{default: 1.0}
    end
  end
end
