defmodule Nexus.Providers.ClaudeCode.OAuth2 do
  @moduledoc """
  OAuth2 authentication flow for Claude Code HTTP provider.

  Handles the complete OAuth2 flow for Claude Code integration using PKCE.

  Claude Code uses OAuth 2.0 with PKCE (Proof Key for Code Exchange) for enhanced security.
  This allows authentication without a client secret.

  ## Testing

  This module uses dependency injection for HTTP client and token repository.
  Configure test environment in test_helper.exs to use mock modules.
  """

  require Logger
  alias Nexus.OAuthToken

  # ======================================================================
  # Configurable Dependencies (for testing)
  # ======================================================================

  defp http_client do
    Application.get_env(:nexus, :http_client, Req)
  end

  defp token_repository do
    Application.get_env(:nexus, :token_repository, OAuthToken)
  end

  @auth_url "https://claude.ai/oauth/authorize"
  @token_url "https://console.anthropic.com/v1/oauth/token"
  @client_id "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
  @redirect_uri "https://console.anthropic.com/oauth/code/callback"
  @default_scopes ["org:create_api_key", "user:profile", "user:inference"]

  @doc """
  Generate OAuth2 authorization URL with PKCE.

  Returns URL to open in browser for user authentication.

  ## Returns

  `{:ok, url}` - Authorization URL to open in browser
  """
  def authorization_url(opts \\ []) do
    scopes = opts[:scopes] || @default_scopes
    state = generate_state()
    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)

    # Save PKCE data for token exchange
    save_pkce_state(state, code_verifier)

    query = URI.encode_query(%{
      client_id: @client_id,
      response_type: "code",
      redirect_uri: @redirect_uri,
      scope: Enum.join(scopes, " "),
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      state: state
    })

    {:ok, "#{@auth_url}?#{query}"}
  end

  @doc """
  Exchange authorization code for tokens.

  Called after user authorizes and is redirected with an authorization code.
  """
  def exchange_code(code, _opts \\ []) do
    # Verify and load PKCE state
    with {:ok, code_verifier} <- load_and_verify_pkce_state() do
      # Clean up the code (remove any fragments or extra params)
      clean_code = code |> String.split("#") |> List.first() |> String.split("&") |> List.first()

      body = %{
        grant_type: "authorization_code",
        client_id: @client_id,
        code: clean_code,
        redirect_uri: @redirect_uri,
        code_verifier: code_verifier
      }

      case http_client().post(@token_url, json: body) do
        {:ok, %{status: 200, body: response}} ->
          tokens = parse_tokens(response)
          save_tokens("claude_code", tokens)
          cleanup_pkce_state()
          {:ok, tokens}

        {:ok, %{status: status, body: error}} ->
          Logger.error("Claude Code OAuth2 exchange failed: #{status} - #{inspect(error)}")
          {:error, "Exchange failed: #{status}"}

        {:error, reason} ->
          Logger.error("Claude Code OAuth2 request error: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Claude Code OAuth2 state verification failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Refresh access token using refresh token.

  Accepts multiple token formats:
  - OAuthToken struct with refresh_token field
  - Map with refresh_token key
  - Binary string (raw refresh token)

  Returns {:error, "No refresh token"} for nil or invalid inputs.
  """
  def refresh(token) do
    refresh_token = case token do
      %OAuthToken{} -> token.refresh_token
      %{refresh_token: rt} -> rt
      rt when is_binary(rt) -> rt
      _ -> nil  # Catch-all for nil, invalid types, etc.
    end

    if !refresh_token do
      Logger.error("No refresh token available for Claude Code")
      {:error, "No refresh token"}
    else
      body = %{
        grant_type: "refresh_token",
        client_id: @client_id,
        refresh_token: refresh_token
      }

      case http_client().post(@token_url, json: body) do
        {:ok, %{status: 200, body: response}} ->
          tokens = parse_tokens(response)
          save_tokens("claude_code", tokens)
          {:ok, tokens}

        {:ok, %{status: status}} ->
          Logger.error("Claude Code token refresh failed: #{status}")
          {:error, "Refresh failed: #{status}"}

        {:error, reason} ->
          Logger.error("Claude Code token refresh error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Get current access token from database.
  """
  def get_token do
    case token_repository().get("claude_code") do
      {:ok, token} ->
        if OAuthToken.expired?(token) do
          # Try to refresh
          case refresh(token) do
            {:ok, refreshed} -> {:ok, refreshed.access_token}
            {:error, _} -> {:error, :token_expired}
          end
        else
          {:ok, token.access_token}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp parse_tokens(response) do
    expires_in = response["expires_in"] || 3600
    expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

    %OAuthToken{
      provider: "claude_code",
      access_token: response["access_token"],
      refresh_token: response["refresh_token"],
      expires_at: expires_at,
      token_type: response["token_type"] || "Bearer",
      scopes: parse_scopes(response["scope"]),
      metadata: %{
        "isMax" => true,
        "originalScope" => response["scope"]
      }
    }
  end

  defp parse_scopes(scope_string) when is_binary(scope_string) do
    scope_string
    |> String.split(" ")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  defp parse_scopes(_), do: @default_scopes

  defp save_tokens(provider, tokens) do
    case token_repository().upsert(provider, %{
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: tokens.expires_at,
      token_type: tokens.token_type,
      scopes: tokens.scopes,
      metadata: tokens.metadata
    }) do
      {:ok, _} ->
        Logger.info("Claude Code tokens saved successfully")
        :ok

      {:error, reason} ->
        Logger.error("Failed to save Claude Code tokens: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # PKCE helpers

  defp generate_state do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp generate_code_verifier do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp generate_code_challenge(code_verifier) do
    code_verifier
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp save_pkce_state(state, code_verifier) do
    state_data = %{
      "state" => state,
      "code_verifier" => code_verifier,
      "timestamp" => System.system_time(:second),
      "expires_at" => System.system_time(:second) + 600  # 10 minutes
    }

    # Store in a temporary file or memory - for now use application env
    Application.put_env(:nexus, :claude_code_pkce_state, state_data)
  end

  defp load_and_verify_pkce_state do
    case Application.get_env(:nexus, :claude_code_pkce_state) do
      nil ->
        {:error, "No PKCE state found - please start OAuth flow again"}

      state_data ->
        current_time = System.system_time(:second)
        expires_at = state_data["expires_at"]

        if current_time > expires_at do
          {:error, "PKCE state expired (older than 10 minutes)"}
        else
          {:ok, state_data["code_verifier"]}
        end
    end
  end

  defp cleanup_pkce_state do
    Application.delete_env(:nexus, :claude_code_pkce_state)
  end
end
