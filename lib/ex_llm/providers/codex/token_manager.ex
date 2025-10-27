defmodule ExLLM.Providers.Codex.TokenManager do
  @moduledoc """
  Codex Token Manager - Handles OAuth2 token lifecycle.

  Responsibilities:
  - Cache OAuth2 access tokens with expiration
  - Auto-refresh tokens before expiration
  - Provide valid tokens for API calls

  This is a GenServer that maintains token state and schedules auto-refresh.
  """

  require Logger
  use GenServer
  alias ExLLM.Providers.Codex.OAuth2

  @codex_token_file ".codex_oauth_token"

  defmodule State do
    defstruct [:access_token, :refresh_token, :expires_at, :refresh_task]
  end

  @doc """
  Start the Codex token manager.

  Options:
  - `:initial_token` - Initial access token (optional, will load from cache if not provided)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current valid access token.

  Returns:
  - `{:ok, token_string}`
  - `{:error, reason}`
  """
  def get_token() do
    GenServer.call(__MODULE__, :get_token)
  end

  @doc """
  Refresh the token immediately.

  Returns:
  - `{:ok, token_string}`
  - `{:error, reason}`
  """
  def refresh_token() do
    GenServer.call(__MODULE__, :refresh_token)
  end

  @doc """
  Store new tokens from OAuth2 exchange.

  Called after successful OAuth2 code exchange.
  """
  def store_tokens(tokens) do
    GenServer.call(__MODULE__, {:store_tokens, tokens})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    Logger.debug("Initializing Codex TokenManager")

    case get_or_load_token(opts) do
      {:ok, token, refresh_token, expires_at} ->
        refresh_task = schedule_refresh(expires_at)

        {:ok,
         %State{
           access_token: token,
           refresh_token: refresh_token,
           expires_at: expires_at,
           refresh_task: refresh_task
         }}

      {:error, reason} ->
        Logger.warning("Failed to initialize Codex tokens: #{inspect(reason)}")
        {:ok, %State{}}
    end
  end

  @impl true
  def handle_call(:get_token, _from, %State{access_token: nil} = state) do
    {:reply, {:error, "No token available"}, state}
  end

  def handle_call(:get_token, _from, %State{access_token: token} = state) do
    {:reply, {:ok, token}, state}
  end

  @impl true
  def handle_call(:refresh_token, _from, %State{refresh_token: refresh_token} = state) do
    case OAuth2.refresh(refresh_token) do
      {:ok, tokens} ->
        # Cancel old refresh task
        if state.refresh_task, do: Process.cancel_timer(state.refresh_task)

        # Schedule new refresh
        refresh_task = schedule_refresh(tokens.expires_at)

        # Save tokens
        save_tokens(tokens)

        new_state = %State{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: tokens.expires_at,
          refresh_task: refresh_task
        }

        Logger.debug("Codex token refreshed successfully")
        {:reply, {:ok, tokens.access_token}, new_state}

      {:error, reason} ->
        Logger.error("Failed to refresh Codex token: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:store_tokens, tokens}, _from, state) do
    # Cancel old refresh task
    if state.refresh_task, do: Process.cancel_timer(state.refresh_task)

    # Schedule new refresh
    refresh_task = schedule_refresh(tokens.expires_at)

    # Save tokens to file
    save_tokens(tokens)

    new_state = %State{
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: tokens.expires_at,
      refresh_task: refresh_task
    }

    Logger.debug("Codex tokens stored and refresh scheduled")
    {:reply, {:ok, tokens.access_token}, new_state}
  end

  @impl true
  def handle_info(:refresh_codex_token, %State{} = state) do
    Logger.debug("Auto-refreshing Codex token")

    case OAuth2.refresh(state.refresh_token) do
      {:ok, tokens} ->
        refresh_task = schedule_refresh(tokens.expires_at)
        save_tokens(tokens)

        new_state = %State{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: tokens.expires_at,
          refresh_task: refresh_task
        }

        Logger.debug("Codex token auto-refreshed")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Codex auto-refresh failed: #{inspect(reason)}")
        # Retry in 1 minute
        Process.send_after(self(), :refresh_codex_token, 60_000)
        {:noreply, state}
    end
  end

  # Private helpers

  defp get_or_load_token(opts) do
    case Keyword.get(opts, :initial_token) do
      token when is_binary(token) ->
        {:ok, token, nil, nil}

      nil ->
        # Try to load from cache
        case get_cached_tokens() do
          {:ok, access_token, refresh_token, expires_at} ->
            # Check if still valid (with 5 min buffer)
            if DateTime.utc_now() |> DateTime.to_unix() < expires_at - 300 do
              Logger.debug("Using cached Codex token")
              {:ok, access_token, refresh_token, expires_at}
            else
              Logger.debug("Cached Codex token expired")
              {:error, :token_expired}
            end

          {:error, _} ->
            Logger.debug("No cached Codex token found")
            {:error, :no_token}
        end

      token ->
        {:ok, token, nil, nil}
    end
  end

  defp get_cached_tokens() do
    case File.read(@codex_token_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token, "expires_at" => expires_at}} ->
            {:ok, access_token, refresh_token, expires_at}

          {:error, reason} ->
            {:error, "Invalid cached token format: #{inspect(reason)}"}
        end

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_tokens(tokens) do
    content =
      Jason.encode!(%{
        "access_token" => tokens.access_token,
        "refresh_token" => tokens.refresh_token,
        "expires_at" => DateTime.to_unix(tokens.expires_at)
      })

    File.write(@codex_token_file, content)
  end

  defp schedule_refresh(expires_at) do
    # Schedule refresh 60 seconds before expiration
    now = DateTime.utc_now() |> DateTime.to_unix()
    expires_unix = DateTime.to_unix(expires_at)
    delay_ms = max(0, (expires_unix - now - 60) * 1000)

    Logger.debug("Scheduling Codex token refresh in #{delay_ms}ms")
    Process.send_after(self(), :refresh_codex_token, delay_ms)
  end
end
