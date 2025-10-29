defmodule Nexus.Providers.ClaudeTest do
  @moduledoc """
  Unit tests for Claude provider.

  Tests the Claude provider functionality including:
  - Model listing and configuration
  - OAuth token management
  - Error handling with mocked dependencies

  ## What This Tests

  - **Model Operations**: List models and check capabilities
  - **Provider Configuration**: Check if Claude is properly configured
  - **Error Handling**: Graceful failures when tokens unavailable
  - **Dependency Injection**: Uses mocked HTTP client and token repository

  ## What This Does NOT Test

  - **Actual HTTP Calls**: No real API calls to Claude (use integration tests)
  - **OAuth2 Flow**: No browser-based authentication (use manual setup)
  - **Token Refresh**: Mocked refresh responses (real refresh needs valid tokens)
  """

  use ExUnit.Case, async: true

  alias Nexus.Providers.Claude

  # ======================================================================
  # Test Setup: Mock dependencies
  # ======================================================================

  setup do
    # Configure mock dependencies
    Application.put_env(:nexus, :http_client, MockReq)
    Application.put_env(:nexus, :token_repository, MockOAuthToken)

    :ok
  end

  describe "list_models/0" do
    test "returns list of Claude models" do
      models = Claude.list_models()

      assert is_list(models)
      assert length(models) == 3

      # Check all required models exist
      ids = Enum.map(models, & &1.id)
      assert "claude-3-5-sonnet-20241022" in ids
      assert "claude-3-5-haiku-20241022" in ids
      assert "claude-3-opus-20240229" in ids
    end

    test "models have correct structure" do
      models = Claude.list_models()

      Enum.each(models, fn model ->
        assert Map.has_key?(model, :id)
        assert Map.has_key?(model, :name)
        assert Map.has_key?(model, :context_window)
        assert Map.has_key?(model, :max_output_tokens)
        assert Map.has_key?(model, :capabilities)
        assert Map.has_key?(model, :cost)
        assert Map.has_key?(model, :pricing)
        assert Map.has_key?(model, :quota_usage)
      end)
    end

    test "claude-3-5-sonnet has thinking capabilities" do
      models = Claude.list_models()
      sonnet = Enum.find(models, fn m -> m.id == "claude-3-5-sonnet-20241022" end)

      assert sonnet != nil
      assert :thinking in sonnet.capabilities
      assert sonnet.thinking_levels == [:low, :medium, :high]
      assert sonnet.quota_usage == %{low: 1.0, medium: 2.0, high: 4.0}
    end

    test "claude-3-5-haiku has no thinking capabilities" do
      models = Claude.list_models()
      haiku = Enum.find(models, fn m -> m.id == "claude-3-5-haiku-20241022" end)

      assert haiku != nil
      assert :thinking not in haiku.capabilities
      assert haiku.thinking_levels == nil
      assert haiku.quota_usage == %{default: 1.0}
    end
  end

  describe "configured?/0" do
    test "returns false when no token is stored" do
      # MockOAuthToken.get/1 returns {:error, :not_found} by default
      configured = Claude.configured?()

      assert configured == false
    end

    test "returns true when token is stored" do
      # Create a custom mock that returns a token
      defmodule MockOAuthTokenWithToken do
        def get("claude_code") do
          token = %Nexus.OAuthToken{
            provider: "claude_code",
            access_token: "test_access_token",
            refresh_token: "test_refresh_token",
            expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
            scopes: ["user:profile", "user:inference"],
            token_type: "Bearer",
            metadata: %{},
            user_identifier: nil,
            id: 1,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }

          {:ok, token}
        end

        def get(_), do: {:error, :not_found}
        def upsert(_, _), do: {:ok, %{}}

        def expired?(%{expires_at: expires_at}),
          do: DateTime.compare(DateTime.utc_now(), expires_at) == :gt

        def expired?(_), do: false
      end

      Application.put_env(:nexus, :token_repository, MockOAuthTokenWithToken)

      configured = Claude.configured?()
      assert configured == true
    end
  end

  describe "provider_name/0 and default_model/0" do
    test "returns correct provider name" do
      assert Claude.provider_name() == "claude"
    end

    test "returns correct default model" do
      assert Claude.default_model() == "claude-3-5-sonnet-20241022"
    end
  end

  describe "chat/2 - with mocked dependencies" do
    test "returns error when token not available" do
      messages = [%{role: "user", content: "Hello"}]

      {:error, reason} = Claude.chat(messages)
      assert reason == :not_found
    end

    test "returns error when API call fails" do
      # Create a custom mock that returns a valid token
      defmodule MockOAuthTokenWithValidToken do
        def get("claude_code") do
          token = %Nexus.OAuthToken{
            provider: "claude_code",
            access_token: "valid_token",
            refresh_token: "refresh_token",
            expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
            scopes: ["user:inference"],
            token_type: "Bearer",
            metadata: %{},
            user_identifier: nil,
            id: 1,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }

          {:ok, token}
        end

        def get(_), do: {:error, :not_found}
        def upsert(_, _), do: {:ok, %{}}

        def expired?(%Nexus.OAuthToken{expires_at: expires_at}),
          do: DateTime.compare(DateTime.utc_now(), expires_at) == :gt

        def expired?(_), do: false
      end

      # Create a custom mock that returns network error
      defmodule MockReqWithError do
        def post(_, _, _) do
          {:error, :network_error}
        end
      end

      Application.put_env(:nexus, :token_repository, MockOAuthTokenWithValidToken)
      Application.put_env(:nexus, :http_client, MockReqWithError)

      messages = [%{role: "user", content: "Hello"}]

      {:error, reason} = Claude.chat(messages)
      assert reason == {:request_failed, :network_error}
    end

    test "returns success when API call succeeds" do
      # Create a custom mock that returns a valid token
      defmodule MockOAuthTokenWithValidToken do
        def get("claude_code") do
          token = %Nexus.OAuthToken{
            provider: "claude_code",
            access_token: "valid_token",
            refresh_token: "refresh_token",
            expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
            scopes: ["user:inference"],
            token_type: "Bearer",
            metadata: %{},
            user_identifier: nil,
            id: 1,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }

          {:ok, token}
        end

        def get(_), do: {:error, :not_found}
        def upsert(_, _), do: {:ok, %{}}

        def expired?(%Nexus.OAuthToken{expires_at: expires_at}),
          do: DateTime.compare(DateTime.utc_now(), expires_at) == :gt

        def expired?(_), do: false
      end

      # Create a custom mock that returns successful API response
      defmodule MockReqWithSuccess do
        def post(_, _, _) do
          api_response = %{
            "content" => [
              %{"type" => "text", "text" => "Hello! How can I help you today?"}
            ]
          }

          {:ok, %{status: 200, body: api_response}}
        end
      end

      Application.put_env(:nexus, :token_repository, MockOAuthTokenWithValidToken)
      Application.put_env(:nexus, :http_client, MockReqWithSuccess)

      messages = [%{role: "user", content: "Hello"}]

      {:ok, response} = Claude.chat(messages)
      assert response.content == "Hello! How can I help you today?"
      assert response.model == "claude-3-5-sonnet-20241022"
    end
  end

  describe "stream/3" do
    test "returns error when no token available" do
      messages = [%{role: "user", content: "Hello"}]
      callback = fn _ -> :ok end

      {:error, reason} = Claude.stream(messages, callback)
      assert reason == :not_found
    end
  end
end
