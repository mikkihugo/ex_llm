defmodule Nexus.Integration.ClaudeIntegrationTest do
  @moduledoc """
  Integration tests for Claude provider with real database.

  Tests the complete Claude provider functionality including:
  - OAuth token storage and retrieval
  - Token refresh logic
  - Model listing and configuration
  - Error handling with real database

  ## What This Tests

  - **Database Integration**: Real PostgreSQL operations with OAuth tokens
  - **Token Management**: Store, retrieve, refresh, and expire tokens
  - **Provider Configuration**: Check if Claude is properly configured
  - **Model Operations**: List models and check capabilities
  - **Error Handling**: Graceful failures when tokens unavailable

  ## What This Does NOT Test

  - **Actual HTTP Calls**: No real API calls to Claude (use manual testing)
  - **OAuth2 Flow**: No browser-based authentication (use manual setup)
  - **Token Refresh**: Mocked refresh responses (real refresh needs valid tokens)

  ## Test Infrastructure

  Uses real database operations for integration testing.
  Each test cleans up after itself by deleting test tokens.
  """

  use ExUnit.Case, async: false
  @moduletag :integration

  alias Nexus.OAuthToken
  alias Nexus.Providers.Claude
  alias Nexus.Providers.ClaudeCode.OAuth2

  # ======================================================================
  # Test Setup: Real database operations
  # ======================================================================

  setup do
    # Clean up any existing tokens
    OAuthToken.delete("claude_code")

    :ok
  end

  describe "OAuth Token Management" do
    test "stores and retrieves OAuth tokens" do
      # Create a test token
      token_attrs = %{
        access_token: "test_access_token_123",
        refresh_token: "test_refresh_token_456",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["org:create_api_key", "user:profile", "user:inference"],
        token_type: "Bearer",
        metadata: %{"test" => true}
      }

      # Store token
      {:ok, stored_token} = OAuthToken.upsert("claude_code", token_attrs)
      assert stored_token.provider == "claude_code"
      assert stored_token.access_token == "test_access_token_123"
      assert stored_token.refresh_token == "test_refresh_token_456"
      assert stored_token.scopes == ["org:create_api_key", "user:profile", "user:inference"]

      # Retrieve token
      {:ok, retrieved_token} = OAuthToken.get("claude_code")
      assert retrieved_token.id == stored_token.id
      assert retrieved_token.access_token == "test_access_token_123"
    end

    test "handles token expiration correctly" do
      # Create expired token
      expired_token = %{
        access_token: "expired_token",
        refresh_token: "refresh_token",
        # 1 hour ago
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
        scopes: ["user:inference"]
      }

      {:ok, token} = OAuthToken.upsert("claude_code", expired_token)
      assert OAuthToken.expired?(token) == true

      # Create valid token
      valid_token = %{
        access_token: "valid_token",
        refresh_token: "refresh_token",
        # 1 hour from now
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["user:inference"]
      }

      {:ok, token} = OAuthToken.upsert("claude_code", valid_token)
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

      {:ok, token} = OAuthToken.upsert("claude_code", token_attrs)

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

  describe "Claude Provider with Real Database" do
    test "configured? returns false when no token exists" do
      # Ensure no token exists
      OAuthToken.delete("claude_code")

      assert Claude.configured?() == false
    end

    test "configured? returns true when valid token exists" do
      # Create valid token
      token_attrs = %{
        access_token: "valid_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["user:inference"]
      }

      {:ok, _token} = OAuthToken.upsert("claude_code", token_attrs)

      assert Claude.configured?() == true
    end

    test "list_models works with real database" do
      models = Claude.list_models()

      assert is_list(models)
      assert length(models) == 3

      # Check all required models exist
      ids = Enum.map(models, & &1.id)
      assert "claude-3-5-sonnet-20241022" in ids
      assert "claude-3-5-haiku-20241022" in ids
      assert "claude-3-opus-20240229" in ids
    end

    test "provider_name and default_model work" do
      assert Claude.provider_name() == "claude"
      assert Claude.default_model() == "claude-3-5-sonnet-20241022"
    end

    test "chat returns error when no token available" do
      # Ensure no token exists
      OAuthToken.delete("claude_code")

      messages = [%{role: "user", content: "Hello"}]

      {:error, reason} = Claude.chat(messages)
      assert reason == :not_found
    end

    test "chat returns error when token expired" do
      # Create expired token
      token_attrs = %{
        access_token: "expired_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
        scopes: ["user:inference"]
      }

      {:ok, _token} = OAuthToken.upsert("claude_code", token_attrs)

      # Should attempt refresh but fail (no real refresh token)
      messages = [%{role: "user", content: "Hello"}]
      {:error, reason} = Claude.chat(messages)
      assert reason in [:not_found, :refresh_failed]
    end
  end

  describe "OAuth2 Module Integration" do
    test "OAuth2 module is loaded and functional" do
      # Test that OAuth2 module exists and has expected functions
      assert Code.ensure_loaded?(OAuth2)

      # Test authorization URL generation (should work without config)
      {:ok, url} = OAuth2.authorization_url()
      assert String.starts_with?(url, "https://claude.ai/oauth/authorize")
      assert String.contains?(url, "client_id=")
      assert String.contains?(url, "response_type=code")
    end

    test "OAuth2 exchange_code fails without real credentials" do
      # This should fail because we don't have real OAuth credentials
      {:error, reason} = OAuth2.exchange_code("fake_code")
      assert reason in [:not_configured, :exchange_failed, :not_found]
    end

    test "OAuth2 refresh fails without real refresh token" do
      # Create token with fake refresh token
      token_attrs = %{
        access_token: "access_token",
        refresh_token: "fake_refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["user:inference"]
      }

      {:ok, token} = OAuthToken.upsert("claude_code", token_attrs)

      # Refresh should fail with fake token
      {:error, reason} = OAuth2.refresh(token)
      assert reason in [:refresh_failed, :not_found, :not_configured]
    end
  end

  describe "Model Capabilities and Properties" do
    test "claude-3-5-sonnet model has correct properties" do
      models = Claude.list_models()
      sonnet = Enum.find(models, fn m -> m.id == "claude-3-5-sonnet-20241022" end)

      assert sonnet != nil
      assert sonnet.name == "Claude 3.5 Sonnet"
      assert sonnet.context_window == 200_000
      assert sonnet.max_output_tokens == 8_192
      assert :thinking in sonnet.capabilities
      assert sonnet.thinking_levels == [:low, :medium, :high]
      assert sonnet.cost == :free
      assert sonnet.pricing == "Free with Claude Pro subscription"
      assert sonnet.quota_usage == %{low: 1.0, medium: 2.0, high: 4.0}
    end

    test "claude-3-5-haiku model has correct properties" do
      models = Claude.list_models()
      haiku = Enum.find(models, fn m -> m.id == "claude-3-5-haiku-20241022" end)

      assert haiku != nil
      assert haiku.name == "Claude 3.5 Haiku"
      assert haiku.context_window == 200_000
      assert haiku.max_output_tokens == 8_192
      assert :thinking not in haiku.capabilities
      assert haiku.thinking_levels == nil
      assert haiku.cost == :free
      assert haiku.pricing == "Free with Claude Pro subscription"
      assert haiku.quota_usage == %{default: 1.0}
    end

    test "claude-3-opus model has correct properties" do
      models = Claude.list_models()
      opus = Enum.find(models, fn m -> m.id == "claude-3-opus-20240229" end)

      assert opus != nil
      assert opus.name == "Claude 3 Opus"
      assert opus.context_window == 200_000
      assert opus.max_output_tokens == 4_096
      assert :thinking not in opus.capabilities
      assert opus.thinking_levels == nil
      assert opus.cost == :free
      assert opus.pricing == "Free with Claude Pro subscription"
      assert opus.quota_usage == %{default: 1.0}
    end
  end
end
