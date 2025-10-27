defmodule ExLLM.Providers.Copilot.TokenManager do
  @moduledoc """
  Copilot Token Manager - Handles Copilot token lifecycle only.

  Responsibilities:
  - Exchange GitHub token for Copilot token
  - Cache Copilot token with expiration
  - Auto-refresh token before expiration
  - No GitHub authentication logic

  Does NOT handle GitHub token - that's GitHub.TokenManager's job.
  GitHub token is passed in as a dependency.
  """

  require Logger
  use GenServer
  alias ExLLM.Providers.Shared.HTTP.Core

  @copilot_token_file ".copilot_token"
  @github_api_base "https://api.github.com"
  @copilot_token_endpoint "/copilot_internal/v2/token"

  # State: {token, expires_at, refresh_task_pid}
  defmodule State do
    defstruct [:token, :expires_at, :refresh_task, :github_token]
  end

  @doc """
  Start the Copilot token manager.

  This is a GenServer that maintains the Copilot token and handles auto-refresh.

  Options:
  - github_token: The GitHub token to use for exchanging (required)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current valid Copilot token.

  Returns:
  - {:ok, token}
  - {:error, reason}
  """
  def get_token() do
    GenServer.call(__MODULE__, :get_token)
  end

  @doc """
  Refresh the Copilot token immediately (for testing).
  """
  def refresh_token() do
    GenServer.call(__MODULE__, :refresh_token)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    github_token = Keyword.fetch!(opts, :github_token)

    # Try to use cached token first, then fetch new one
    case get_or_refresh_token(github_token) do
      {:ok, token, expires_at} ->
        refresh_task = schedule_refresh(token, expires_at, github_token)

        {:ok,
         %State{
           token: token,
           expires_at: expires_at,
           refresh_task: refresh_task,
           github_token: github_token
         }}

      {:error, reason} ->
        Logger.error("Failed to initialize Copilot token manager: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_token, _from, %State{} = state) do
    {:reply, {:ok, state.token}, state}
  end

  @impl true
  def handle_call(:refresh_token, _from, %State{} = state) do
    case get_or_refresh_token(state.github_token) do
      {:ok, token, expires_at} ->
        # Cancel old refresh task
        if state.refresh_task, do: Process.cancel_timer(state.refresh_task)

        # Schedule new refresh
        refresh_task = schedule_refresh(token, expires_at, state.github_token)

        new_state = %State{
          state
          | token: token,
            expires_at: expires_at,
            refresh_task: refresh_task
        }

        {:reply, {:ok, token}, new_state}

      {:error, reason} ->
        Logger.error("Failed to refresh Copilot token: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:refresh_copilot_token, %State{} = state) do
    Logger.debug("Auto-refreshing Copilot token")

    case get_or_refresh_token(state.github_token) do
      {:ok, token, expires_at} ->
        refresh_task = schedule_refresh(token, expires_at, state.github_token)

        new_state = %State{
          state
          | token: token,
            expires_at: expires_at,
            refresh_task: refresh_task
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Auto-refresh failed: #{inspect(reason)}")
        # Retry in 1 minute
        Process.send_after(self(), :refresh_copilot_token, 60_000)
        {:noreply, state}
    end
  end

  # Private helpers

  defp get_or_refresh_token(github_token) do
    # Try to use cached token if valid
    case get_cached_token() do
      {:ok, token, expires_at} ->
        # Check if still valid (with 5 min buffer)
        if DateTime.utc_now() |> DateTime.to_unix() < expires_at - 300 do
          Logger.debug("Using cached Copilot token")
          {:ok, token, expires_at}
        else
          Logger.debug("Cached Copilot token expired, fetching new one")
          fetch_copilot_token(github_token)
        end

      {:error, _} ->
        Logger.debug("No cached Copilot token, fetching new one")
        fetch_copilot_token(github_token)
    end
  end

  defp fetch_copilot_token(github_token) do
    url = @github_api_base <> @copilot_token_endpoint

    headers = [
      {"authorization", "token #{github_token}"},
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    client_opts = [
      provider: :github,
      base_url: @github_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :get, @copilot_token_endpoint, headers) do
      {:ok, %{"token" => token, "refresh_in" => _refresh_in, "expires_at" => expires_at}} ->
        Logger.debug("Got new Copilot token from GitHub API")
        save_cached_token(token, expires_at)
        {:ok, token, expires_at}

      {:ok, %{"token" => token, "refresh_in" => refresh_in}} ->
        # Calculate expires_at if not provided
        expires_at = DateTime.utc_now() |> DateTime.add(refresh_in) |> DateTime.to_unix()
        Logger.debug("Got new Copilot token from GitHub API")
        save_cached_token(token, expires_at)
        {:ok, token, expires_at}

      {:error, "unauthorized"} ->
        {:error, "GitHub token invalid or expired"}

      {:error, reason} ->
        {:error, "Copilot token request failed: #{inspect(reason)}"}
    end
  end

  defp get_cached_token() do
    case File.read(@copilot_token_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"token" => token, "expires_at" => expires_at}} ->
            {:ok, token, expires_at}

          {:error, reason} ->
            {:error, "Invalid cached token format: #{inspect(reason)}"}
        end

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_cached_token(token, expires_at) do
    content = Jason.encode!(%{"token" => token, "expires_at" => expires_at})
    File.write(@copilot_token_file, content)
  end

  defp schedule_refresh(_token, expires_at, _github_token) do
    # Schedule refresh 60 seconds before expiration
    now = DateTime.utc_now() |> DateTime.to_unix()
    delay_ms = max(0, (expires_at - now - 60) * 1000)

    Logger.debug("Scheduling Copilot token refresh in #{delay_ms}ms")
    Process.send_after(self(), :refresh_copilot_token, delay_ms)
  end

  defp execute_request(client, method, path, headers) do
    case Tesla.request(client, method: method, url: path, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: 401}} ->
        {:error, "unauthorized"}

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        {:error, "GitHub API failed with status #{code}: #{response_body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
