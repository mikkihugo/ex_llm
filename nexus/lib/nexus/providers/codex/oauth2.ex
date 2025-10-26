defmodule Nexus.Providers.Codex.OAuth2 do
  @moduledoc """
  OAuth2 authentication flow for ChatGPT Pro.

  Handles the complete OAuth2 flow for Codex integration.
  """

  require Logger
  alias Nexus.OAuthToken

  @auth_base_url "https://chatgpt.com/oauth"

  @doc """
  Generate OAuth2 authorization URL.

  Returns URL to open in browser for user authentication.
  """
  def authorization_url(opts \\ []) do
    client_id = config(:client_id) || raise "Missing CODEX_CLIENT_ID"
    redirect_uri = opts[:redirect_uri] || config(:redirect_uri)
    scopes = opts[:scopes] || config(:scopes) || ["openai.user.read", "model.request"]
    state = opts[:state] || generate_state()

    query = URI.encode_query(%{
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
  Exchange authorization code for tokens.
  """
  def exchange_code(code, opts \\ []) do
    body = %{
      client_id: config(:client_id),
      client_secret: config(:client_secret),
      code: code,
      redirect_uri: opts[:redirect_uri] || config(:redirect_uri),
      grant_type: "authorization_code"
    }

    case Req.post("#{@auth_base_url}/token", json: body) do
      {:ok, %{status: 200, body: response}} ->
        tokens = parse_tokens(response)
        save_tokens(tokens)
        {:ok, tokens}

      {:ok, %{status: status, body: error}} ->
        Logger.error("OAuth2 exchange failed: #{status} - #{inspect(error)}")
        {:error, "Exchange failed: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh access token.
  """
  def refresh(token) do
    refresh_token = case token do
      %OAuthToken{} -> token.refresh_token
      %{refresh_token: rt} -> rt
      rt when is_binary(rt) -> rt
    end

    body = %{
      client_id: config(:client_id),
      client_secret: config(:client_secret),
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    }

    case Req.post("#{@auth_base_url}/token", json: body) do
      {:ok, %{status: 200, body: response}} ->
        tokens = parse_tokens(response)
        save_tokens(tokens)
        {:ok, tokens}

      {:ok, %{status: status}} ->
        {:error, "Refresh failed: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Revoke token.
  """
  def revoke(token) do
    body = %{
      client_id: config(:client_id),
      token: token
    }

    case Req.post("#{@auth_base_url}/revoke", json: body) do
      {:ok, %{status: 200}} -> :ok
      {:ok, _} -> :ok  # Consider successful even on error
      {:error, _} -> :ok
    end
  end

  # Private functions

  defp parse_tokens(response) do
    expires_in = response["expires_in"] || 3600
    expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

    %{
      access_token: response["access_token"],
      refresh_token: response["refresh_token"],
      expires_at: expires_at,
      token_type: response["token_type"] || "Bearer",
      scopes: String.split(response["scope"] || "", " ")
    }
  end

  defp save_tokens(tokens) do
    OAuthToken.upsert("codex", tokens)
  end

  defp generate_state do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp config(key) do
    Application.get_env(:nexus, :codex)[key]
  end
end
