defmodule SingularityLLM.Providers.Codex.OAuth2 do
  @moduledoc """
  OAuth2 authentication for ChatGPT Pro (Codex).

  Handles the complete OAuth2 flow for Codex integration:
  1. Generate authorization URL
  2. Exchange code for tokens
  3. Refresh expired tokens
  4. Revoke tokens on logout
  """

  require Logger

  @auth_base_url "https://chatgpt.com/oauth"
  @token_url "#{@auth_base_url}/token"
  @revoke_url "#{@auth_base_url}/revoke"

  @doc """
  Generate OAuth2 authorization URL.

  Returns URL to open in browser for user authentication.

  ## Options
  - `:redirect_uri` - Where to redirect after auth (default from config)
  - `:scopes` - Requested scopes (default: ["openai.user.read", "model.request"])
  - `:state` - CSRF protection state (generated if not provided)
  """
  def authorization_url(opts \\ []) do
    client_id = get_config(:client_id) || raise "Missing CODEX_CLIENT_ID"
    redirect_uri = opts[:redirect_uri] || get_config(:redirect_uri)
    scopes = opts[:scopes] || get_config(:scopes) || ["openai.user.read", "model.request"]
    state = opts[:state] || generate_state()

    query =
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: Enum.join(scopes, " "),
        state: state,
        access_type: "offline"
      })

    {:ok, "#{@auth_base_url}/authorize?#{query}"}
  end

  @doc """
  Exchange authorization code for access and refresh tokens.

  Parameters:
  - `code` - Authorization code from OAuth2 callback
  - `opts` - Options including optional redirect_uri

  Returns:
  - `{:ok, %{access_token: "...", refresh_token: "...", expires_at: datetime}}`
  - `{:error, reason}`
  """
  def exchange_code(code, opts \\ []) do
    body = %{
      client_id: get_config(:client_id),
      client_secret: get_config(:client_secret),
      code: code,
      redirect_uri: opts[:redirect_uri] || get_config(:redirect_uri),
      grant_type: "authorization_code"
    }

    case post_token_request(body) do
      {:ok, tokens} ->
        Logger.debug("Codex OAuth2: Successfully exchanged code for tokens")
        {:ok, tokens}

      {:error, reason} ->
        Logger.error("Codex OAuth2: Code exchange failed - #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Refresh an expired access token.

  Parameters:
  - `token` - Token map with refresh_token field or refresh token string

  Returns:
  - `{:ok, %{access_token: "...", refresh_token: "...", expires_at: datetime}}`
  - `{:error, reason}`
  """
  def refresh(token) do
    refresh_token = extract_refresh_token(token)

    body = %{
      client_id: get_config(:client_id),
      client_secret: get_config(:client_secret),
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    }

    case post_token_request(body) do
      {:ok, tokens} ->
        Logger.debug("Codex OAuth2: Successfully refreshed access token")
        {:ok, tokens}

      {:error, reason} ->
        Logger.error("Codex OAuth2: Token refresh failed - #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Revoke an access token.

  Parameters:
  - `token` - Access token string

  Returns:
  - `:ok` (always succeeds, errors are logged)
  """
  def revoke(token) do
    body = %{
      client_id: get_config(:client_id),
      token: token
    }

    case Req.post(@revoke_url, json: body) do
      {:ok, %{status: 200}} ->
        Logger.debug("Codex OAuth2: Token revoked successfully")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("Codex OAuth2: Revoke returned status #{status}, treating as success")
        :ok

      {:error, reason} ->
        Logger.warning("Codex OAuth2: Revoke request failed - #{inspect(reason)}, treating as success")
        :ok
    end
  end

  # Private functions

  defp post_token_request(body) do
    case Req.post(@token_url, json: body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, parse_tokens(response)}

      {:ok, %{status: status, body: error}} ->
        {:error, "OAuth2 token request failed (#{status}): #{inspect(error)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_tokens(response) do
    expires_in = response["expires_in"] || 3600

    %{
      access_token: response["access_token"],
      refresh_token: response["refresh_token"],
      expires_at: DateTime.utc_now() |> DateTime.add(expires_in, :second),
      token_type: response["token_type"] || "Bearer",
      scopes: String.split(response["scope"] || "", " ")
    }
  end

  defp extract_refresh_token(token) when is_binary(token), do: token
  defp extract_refresh_token(%{"refresh_token" => rt}), do: rt
  defp extract_refresh_token(%{refresh_token: rt}), do: rt

  defp generate_state do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp get_config(key) do
    Application.get_env(:singularity_llm, :codex, [])[key] ||
      Application.get_env(:singularity_llm, [:codex, key])
  end
end
