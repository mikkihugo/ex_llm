defmodule ExLLM.Providers.ClaudeCode do
  @moduledoc """
  Anthropic Claude provider that reuses the Claude Code OAuth token.

  The Claude Code CLI authenticates with OAuth, then exchanges the access token
  for a first-party API key using the undocumented
  `/api/oauth/claude_cli/create_api_key` endpoint. This adapter replicates that
  behaviour so we can call the Anthropic API directly without shelling out to
  the CLI.

  ## Token sources

  1. `CLAUDE_CODE_OAUTH_TOKEN` – overrides everything.
  2. `CLAUDE_CODE_OAUTH_TOKEN_PATH` – path to a JSON file with the same shape
     as `~/.claude/.credentials.json`.
  3. `~/.claude/.credentials.json` (default location used by the CLI).
  """

  @behaviour ExLLM.Provider

  alias ExLLM.Infrastructure.ConfigProvider.Static
  alias __MODULE__.Auth

  @default_model "claude-3-7-sonnet-20250219"
  @grant_scope "org:create_api_key user:profile user:inference"
  @token_endpoint "https://console.anthropic.com/v1/oauth/token"
  @credentials_default_path Path.expand("~/.claude/.credentials.json")
  @credential_cache_key {__MODULE__, :api_key}
  @provider_cache_key {__MODULE__, :provider}

  def credential_cache_key, do: @credential_cache_key
  def provider_cache_key, do: @provider_cache_key
  def token_endpoint, do: @token_endpoint
  def grant_scope, do: @grant_scope
  def credentials_default_path, do: @credentials_default_path

  @impl true
  def chat(messages, options \\ []) do
    with {:ok, api_key} <- Auth.ensure_api_key() do
      provider = ensure_provider(api_key)
      ExLLM.Providers.Anthropic.chat(messages, Keyword.put(options, :config_provider, provider))
    end
  end

  @impl true
  def stream_chat(messages, options \\ []) do
    with {:ok, api_key} <- Auth.ensure_api_key() do
      provider = ensure_provider(api_key)

      ExLLM.Providers.Anthropic.stream_chat(
        messages,
        Keyword.put(options, :config_provider, provider)
      )
    end
  end

  @impl true
  def configured?(_options \\ []) do
    case Auth.load_oauth_credentials() do
      {:ok, %{access_token: token}} when is_binary(token) and token != "" -> true
      _ -> false
    end
  end

  @impl true
  def default_model, do: @default_model

  @impl true
  def list_models(_options \\ []) do
    {:ok,
     [
       %ExLLM.Types.Model{
         id: "claude-3-7-sonnet-20250219",
         name: "Claude 3.7 Sonnet",
         description: "Balanced flagship Claude model",
         context_window: 200_000,
         capabilities: %{completion: true, tools: true, vision: true},
         pricing: nil
       },
       %ExLLM.Types.Model{
         id: "claude-3-5-haiku-20241022",
         name: "Claude 3.5 Haiku",
         description: "Fast Claude model optimised for low latency tasks",
         context_window: 200_000,
         capabilities: %{completion: true, tools: true, vision: true},
         pricing: nil
       }
     ]}
  end

  @impl true
  def embeddings(_inputs, _options \\ []), do: {:error, :embeddings_not_supported}

  @impl true
  def list_embedding_models(_options \\ []), do: {:ok, []}

  defp ensure_provider(api_key) do
    case :persistent_term.get(@provider_cache_key, :undefined) do
      %{api_key: ^api_key, pid: pid} when is_pid(pid) ->
        if Process.alive?(pid) do
          pid
        else
          start_provider(api_key)
        end

      %{pid: old_pid} when is_pid(old_pid) ->
        Process.exit(old_pid, :normal)
        start_provider(api_key)

      _ ->
        start_provider(api_key)
    end
  end

  defp start_provider(api_key) do
    {:ok, pid} = Static.start_link(%{anthropic: %{api_key: api_key}})
    :persistent_term.put(provider_cache_key(), %{pid: pid, api_key: api_key})
    pid
  end

  defmodule Auth do
    @moduledoc false

    def ensure_api_key do
      case cached_api_key() do
        {:ok, key} -> {:ok, key}
        :error -> fetch_and_cache_api_key()
      end
    end

    def load_oauth_credentials do
      cond do
        token = System.get_env("CLAUDE_CODE_OAUTH_TOKEN") ->
          {:ok, %{access_token: String.trim(token)}}

        path = System.get_env("CLAUDE_CODE_OAUTH_TOKEN_PATH") ->
          read_credentials(path)

        true ->
          read_credentials(ExLLM.Providers.ClaudeCode.credentials_default_path())
      end
    end

    defp fetch_and_cache_api_key do
      with {:ok, credentials} <- load_oauth_credentials(),
           {:ok, access_token} <- ensure_fresh_access_token(credentials),
           {:ok, api_key, metadata} <- exchange_token_for_api_key(access_token) do
        :persistent_term.put(
          ExLLM.Providers.ClaudeCode.credential_cache_key(),
          %{api_key: api_key, metadata: metadata}
        )

        {:ok, api_key}
      end
    end

    defp cached_api_key do
      case :persistent_term.get(ExLLM.Providers.ClaudeCode.credential_cache_key(), :undefined) do
        %{api_key: api_key} when is_binary(api_key) and api_key != "" -> {:ok, api_key}
        _ -> :error
      end
    end

    defp ensure_fresh_access_token(%{access_token: token, expires_at: nil}), do: {:ok, token}

    defp ensure_fresh_access_token(%{
           access_token: token,
           expires_at: expires_at,
           refresh_token: refresh
         }) do
      now = System.system_time(:second)

      cond do
        is_nil(expires_at) or expires_at - now > 300 ->
          {:ok, token}

        refresh && refresh != "" ->
          refresh_access_token(refresh)

        true ->
          {:ok, token}
      end
    end

    defp ensure_fresh_access_token(%{access_token: token}), do: {:ok, token}

    defp refresh_access_token(refresh_token) do
      body = %{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token,
        "scope" => ExLLM.Providers.ClaudeCode.grant_scope()
      }

      case Req.post(url: ExLLM.Providers.ClaudeCode.token_endpoint(), json: body) do
        {:ok, %Req.Response{status: 200, body: resp}} ->
          {:ok, resp["access_token"]}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:oauth_error, status, body}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end

    defp exchange_token_for_api_key(token) do
      headers = build_headers(token)

      case Req.post(url: create_api_key_url(), headers: headers, json: %{}) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          api_key = body["api_key"] || body["apiKey"]
          metadata = Map.drop(body, ["api_key", "apiKey"])

          cond do
            is_binary(api_key) and api_key != "" ->
              {:ok, api_key, metadata}

            true ->
              {:error, {:invalid_response, body}}
          end

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end

    defp build_headers(token) do
      base_headers = [
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"},
        {"user-agent", System.get_env("CLAUDE_CODE_USER_AGENT") || "claude-code/2.0.5"},
        {"anthropic-client", System.get_env("CLAUDE_CODE_CLIENT_ID") || "claude-code"},
        {"anthropic-client-version", System.get_env("CLAUDE_CODE_CLIENT_VERSION") || "2.0.5"},
        {"anthropic-version", System.get_env("CLAUDE_CODE_ANTHROPIC_VERSION") || "2023-06-01"}
      ]

      beta_header =
        case System.get_env("CLAUDE_CODE_BETA_FEATURES") do
          nil -> []
          "" -> []
          features -> [{"anthropic-beta", features}]
        end

      extra_headers =
        case System.get_env("CLAUDE_CODE_EXTRA_HEADERS") do
          nil ->
            []

          json ->
            with {:ok, map} <- Jason.decode(json),
                 true <- is_map(map) do
              Enum.map(map, fn {k, v} -> {k, v} end)
            else
              _ -> []
            end
        end

      base_headers ++ beta_header ++ extra_headers
    end

    defp create_api_key_url do
      "#{api_base()}/api/oauth/claude_cli/create_api_key"
    end

    defp api_base do
      System.get_env("CLAUDE_CODE_API_BASE") || "https://api.anthropic.com"
    end

    defp read_credentials(path) do
      with true <- File.exists?(path) || {:error, :credentials_not_found},
           {:ok, contents} <- File.read(path),
           {:ok, json} <- Jason.decode(contents) do
        parse_credentials(json)
      end
    end

    defp parse_credentials(%{"claudeAiOauth" => data}) do
      {:ok,
       %{
         access_token: Map.get(data, "accessToken"),
         refresh_token: Map.get(data, "refreshToken"),
         expires_at: Map.get(data, "expiresAt")
       }}
    end

    defp parse_credentials(%{"accessToken" => _} = data) do
      {:ok,
       %{
         access_token: Map.get(data, "accessToken"),
         refresh_token: Map.get(data, "refreshToken"),
         expires_at: Map.get(data, "expiresAt")
       }}
    end

    defp parse_credentials(%{"access_token" => token} = data) do
      {:ok,
       %{
         access_token: token,
         refresh_token: Map.get(data, "refresh_token"),
         expires_at: Map.get(data, "expires_at")
       }}
    end

    defp parse_credentials(_), do: {:error, :unsupported_credentials_format}
  end
end
