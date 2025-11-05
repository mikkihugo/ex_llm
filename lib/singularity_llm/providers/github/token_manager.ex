defmodule SingularityLLM.Providers.GitHub.TokenManager do
  @moduledoc """
  GitHub Token Manager - Handles GitHub authentication only.

  Responsibilities:
  - Get GitHub token from `gh auth token` (preferred)
  - Fallback to device OAuth flow if gh CLI not available
  - Cache token locally
  - No Copilot-specific logic

  Does NOT handle Copilot token exchange - that's Copilot.TokenManager's job.
  """

  require Logger

  @github_token_file ".github_token"
  @github_client_id "Iv1.b507a08c87ecfe98"
  @github_scopes "read:user"

  @doc """
  Get GitHub token from `gh auth token` CLI.

  Returns:
  - {:ok, token} - Successfully got token from gh CLI
  - {:error, reason} - gh CLI not available or not authenticated
  """
  def get_from_gh_cli() do
    case System.cmd("gh", ["auth", "token"], stderr_to_stdout: true) do
      {token, 0} ->
        {:ok, String.trim(token)}

      {_error, _code} ->
        {:error, "gh CLI not authenticated or not available"}
    end
  end

  @doc """
  Get cached GitHub token from local file.

  Returns:
  - {:ok, token} - Token found and valid
  - {:error, :not_found} - No cached token
  """
  def get_cached() do
    case File.read(@github_token_file) do
      {:ok, token} ->
        token = String.trim(token)
        if String.length(token) > 0, do: {:ok, token}, else: {:error, :empty}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Save GitHub token to local cache.
  """
  def save_cached(token) do
    File.write(@github_token_file, token)
  end

  @doc """
  Get GitHub token with automatic fallback.

  Strategy:
  1. Try `gh auth token` (fresh, from CLI)
  2. Fall back to cached token
  3. Fall back to device OAuth flow

  Returns:
  - {:ok, token}
  - {:error, reason}
  """
  def get_token() do
    case get_from_gh_cli() do
      {:ok, token} ->
        Logger.debug("Got GitHub token from gh CLI")
        save_cached(token)
        {:ok, token}

      {:error, _} ->
        Logger.debug("gh CLI not available, trying cached token")

        case get_cached() do
          {:ok, token} ->
            Logger.debug("Using cached GitHub token")
            {:ok, token}

          {:error, _} ->
            Logger.debug("No cached token, starting device OAuth flow")
            get_from_device_oauth()
        end
    end
  end

  defp get_from_device_oauth() do
    Logger.info("Starting GitHub device OAuth flow")

    with {:ok, device_response} <- request_device_code(),
         {:ok, token} <- poll_for_access_token(device_response) do
      Logger.debug("Got GitHub token from device OAuth")
      save_cached(token)
      {:ok, token}
    else
      {:error, reason} ->
        Logger.error("Device OAuth failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp request_device_code() do
    url = "https://github.com/login/device/code"

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"accept", "application/json"}
    ]

    body = URI.encode_query(%{
      "client_id" => @github_client_id,
      "scope" => @github_scopes
    })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"device_code" => device_code, "user_code" => user_code, "verification_uri" => uri}} ->
            Logger.info("Device code: #{user_code}")
            Logger.info("Verification URI: #{uri}")
            {:ok, %{device_code: device_code, user_code: user_code, verification_uri: uri}}

          {:error, reason} ->
            {:error, "Failed to parse device code response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "Device code request failed (#{code}): #{body}"}

      {:error, reason} ->
        {:error, "Device code request failed: #{inspect(reason)}"}
    end
  end

  defp poll_for_access_token(%{device_code: device_code} = _device_response) do
    url = "https://github.com/login/oauth/access_token"

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"accept", "application/json"}
    ]

    body = URI.encode_query(%{
      "client_id" => @github_client_id,
      "device_code" => device_code,
      "grant_type" => "urn:ietf:params:oauth:grant-type:device_code"
    })

    # Poll for up to 15 minutes
    poll_with_retries(url, body, headers, 0)
  end

  defp poll_with_retries(_url, _body, _headers, attempt) when attempt > 900 do
    {:error, "Device OAuth timeout"}
  end

  defp poll_with_retries(url, body, headers, attempt) do
    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"access_token" => token}} ->
            {:ok, token}

          {:ok, %{"error" => "authorization_pending"}} ->
            Process.sleep(5000)
            poll_with_retries(url, body, headers, attempt + 5)

          {:ok, %{"error" => error}} ->
            {:error, "OAuth error: #{error}"}

          {:error, reason} ->
            {:error, "Failed to parse token response: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Token request failed: #{inspect(reason)}"}
    end
  end
end
