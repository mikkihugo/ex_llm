defmodule ExLLM.Providers.Jules.TaskClient do
  @moduledoc """
  Google Jules Task Client - Asynchronous Task-Based API Implementation.

  Implements the standard **Async Request-Reply Pattern** (HTTP 202 Accepted) for long-running
  code generation operations using the Google Jules API.

  ## Async Request-Reply Pattern

  This module follows the established async pattern for long-running operations:

  **Step 1: Submit Task (Create Session)**
  ```
  POST /v1alpha/sessions
  → Returns: session_id with session object
  ```

  **Step 2: Poll for Status**
  ```
  GET /v1alpha/sessions/{session_id}
  → Returns: session object with current state
  → States: "initializing", "planning", "executing", "done", "failed"
  ```

  **Step 3: Get Results**
  ```
  GET /v1alpha/sessions/{session_id}/activities
  → Returns: list of activities with code changes
  ```

  ## Google Jules Protocol

  - **API Base**: `https://julius.googleapis.com/v1alpha/`
  - **Auth**: `X-Goog-Api-Key` header
  - **Sessions**: Container for a single task/conversation
  - **Activities**: Individual actions/changes within a session
  - **Plans**: Generated code plan to approve/reject

  ## Status Codes

  - **200 OK** - Session retrieved successfully
  - **400 Bad Request** - Invalid parameters
  - **401 Unauthorized** - Invalid API key
  - **403 Forbidden** - Permission denied
  - **429 Too Many Requests** - Rate limited
  - **500 Internal Server Error** - Server error

  ## Usage

      iex> # Step 1: Submit task (async)
      iex> {:ok, session_id} = TaskClient.create_session(
      ...>   prompt: "Add dark mode support",
      ...>   source_context: "web_app"
      ...> )

      iex> # Step 2: Poll for status
      iex> {:ok, session} = TaskClient.get_session(session_id)

      iex> # Step 3: Get activities
      iex> {:ok, activities} = TaskClient.get_activities(session_id)

  ## HTTP Endpoints

  - `POST /sessions` - Create session (submit task)
  - `GET /sessions` - List sessions
  - `GET /sessions/{id}` - Get session status
  - `GET /sessions/{id}/activities` - Get session activities/results
  - `POST /sessions/{id}:approvePlan` - Approve generated plan

  ## Implementation Details

  - All endpoints use `https://julius.googleapis.com/v1alpha/`
  - Requires valid API key from Google Jules web app Settings
  - API key passed via `X-Goog-Api-Key` header
  - Currently in alpha release (specs may change)

  ## See Also

  - **Jules API Docs**: https://developers.google.com/jules/api
  - **AsyncAPI Specification**: https://www.asyncapi.com/
  - **Azure Async Request-Reply Pattern**: https://learn.microsoft.com/azure/architecture/patterns/async-request-reply
  - **RESTful API Design for Long-Running Tasks**: https://restfulapi.net/rest-api-design-for-long-running-tasks/
  """

  require Logger
  alias ExLLM.Providers.Shared.HTTP.Core

  @jules_base_url "https://julius.googleapis.com/v1alpha"
  @default_poll_interval_ms 3000
  @default_max_attempts 30
  @timeout_ms 120_000

  @typedoc """
  Jules session creation options.

  - `:prompt` (required) - User instruction/code generation request
  - `:source_context` (optional) - Context path (e.g., "web_app", "backend")
  - `:automation_mode` (optional) - Whether to automatically execute ("AUTO" or "MANUAL")
  - `:poll_interval_ms` (optional) - Polling interval in milliseconds
  - `:max_attempts` (optional) - Maximum polling attempts
  - `:timeout_ms` (optional) - Total timeout for polling
  """
  @type create_opts :: [
          {:prompt, String.t()}
          | {:source_context, String.t()}
          | {:automation_mode, String.t()}
          | {:poll_interval_ms, pos_integer()}
          | {:max_attempts, pos_integer()}
          | {:timeout_ms, pos_integer()}
        ]

  @doc """
  Create a new Jules session (Async Request-Reply Pattern - Step 1/2).

  **Async Pattern:** This function returns immediately with a session ID.
  Use `get_session/1` or `poll_session/2` to check completion.

  **HTTP:** `POST /sessions` → Returns session object with session_id

  ## Arguments

  - `opts` - Keyword list with session configuration

  ## Options

  - `:prompt` (required) - Code generation instruction
  - `:source_context` (optional) - Context (e.g., "web_app")
  - `:automation_mode` (optional) - "AUTO" or "MANUAL" (default: "MANUAL")

  ## Returns

  - `{:ok, session_id}` - Session created successfully ✓
  - `{:error, reason}` - Creation failed

  ## Examples

      iex> # Step 1: Submit task (returns immediately)
      iex> {:ok, session_id} = create_session(
      ...>   prompt: "Add dark mode support to the dashboard"
      ...> )

      iex> # Step 2: Check status
      iex> {:ok, session} = get_session(session_id)
  """
  @spec create_session(create_opts()) :: {:ok, String.t()} | {:error, term()}
  def create_session(opts) when is_list(opts) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, session_id} <- do_create_session(api_key, opts) do
      {:ok, session_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a session and wait for completion (blocking operation).

  **Async Pattern:** Creates session and polls until done.

  ## Arguments

  - `opts` - Same as `create_session/1` plus polling options

  ## Returns

  - `{:ok, session_id, session}` - Session completed with results
  - `{:error, reason}` - Creation or polling failed

  ## Example

      iex> {:ok, session_id, session} = create_session_and_wait(
      ...>   prompt: "Generate tests",
      ...>   max_attempts: 60
      ...> )
  """
  @spec create_session_and_wait(create_opts()) ::
          {:ok, String.t(), map()} | {:error, term()}
  def create_session_and_wait(opts) do
    case create_session(opts) do
      {:ok, session_id} ->
        # Remove session creation options, keep polling options
        poll_opts = Keyword.take(opts, [:poll_interval_ms, :max_attempts, :timeout_ms])

        case poll_session(session_id, poll_opts) do
          {:ok, session} -> {:ok, session_id, session}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Poll a session for completion (Async Request-Reply Pattern - Step 2/2).

  **Async Pattern:** Continuously polls the session endpoint until completion or timeout.
  Call after `create_session/1` to wait for results.

  **HTTP:** `GET /sessions/{session_id}` → Returns session object with state

  ## Arguments

  - `session_id` - Session ID from `create_session/1`
  - `opts` - Polling options

  ## Options

  - `:poll_interval_ms` - Wait between polls (default: 3000ms)
  - `:max_attempts` - Maximum polling attempts (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000ms)

  ## Returns

  - `{:ok, session}` - Session completed with results ✓
  - `{:error, reason}` - Polling failed or timed out

  ## Example

      iex> # Poll until completion (blocks)
      iex> {:ok, session} = poll_session(session_id, max_attempts: 60)
      iex> session["state"]
      "done"
  """
  @spec poll_session(String.t(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def poll_session(session_id, opts \\ []) when is_binary(session_id) do
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    timeout_ms = Keyword.get(opts, :timeout_ms, @timeout_ms)

    start_time = System.monotonic_time(:millisecond)

    do_poll_session(
      session_id,
      poll_interval_ms,
      max_attempts,
      timeout_ms,
      start_time,
      0
    )
  end

  @doc """
  Get session status without waiting.

  ## Returns

  - `{:ok, session}` - Current session object
  - `{:error, reason}` - Request failed
  """
  @spec get_session(String.t()) :: {:ok, map()} | {:error, term()}
  def get_session(session_id) when is_binary(session_id) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, session} <- fetch_session(api_key, session_id) do
      {:ok, session}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get session state (simplified status).

  ## Returns

  - `{:ok, state}` - Current state ("initializing", "planning", "executing", "done", "failed", etc.)
  - `{:error, reason}` - Request failed
  """
  @spec get_session_state(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_session_state(session_id) when is_binary(session_id) do
    with {:ok, session} <- get_session(session_id) do
      state = Map.get(session, "state")
      {:ok, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get session activities (code changes).

  ## Returns

  - `{:ok, activities}` - List of activities in the session
  - `{:error, reason}` - Request failed
  """
  @spec get_activities(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_activities(session_id) when is_binary(session_id) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, activities} <- fetch_activities(api_key, session_id) do
      {:ok, activities}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List user's sessions with pagination.

  ## Options

  - `:page_size` - Number of sessions to return (default: 10)
  - `:page_token` - Pagination token (default: nil)

  ## Returns

  - `{:ok, sessions}` - List of session summaries
  - `{:error, reason}` - Request failed
  """
  @spec list_sessions(Keyword.t()) :: {:ok, list(map())} | {:error, term()}
  def list_sessions(opts \\ []) do
    with {:ok, api_key} <- get_api_key() do
      page_size = Keyword.get(opts, :page_size, 10)
      page_token = Keyword.get(opts, :page_token)

      headers = jules_headers(api_key)
      url = build_url("/sessions", %{"pageSize" => page_size})

      url =
        if page_token do
          url <> "&pageToken=#{page_token}"
        else
          url
        end

      case execute_request(:get, url, nil, headers) do
        {:ok, %{"sessions" => sessions}} -> {:ok, sessions}
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Approve a session's generated plan.

  Required when automation_mode is "MANUAL".

  ## Returns

  - `{:ok, session}` - Plan approved, session continues executing
  - `{:error, reason}` - Request failed
  """
  @spec approve_plan(String.t()) :: {:ok, map()} | {:error, term()}
  def approve_plan(session_id) when is_binary(session_id) do
    with {:ok, api_key} <- get_api_key() do
      headers = jules_headers(api_key)
      url = "#{@jules_base_url}/sessions/#{session_id}:approvePlan"

      case execute_request(:post, url, %{}, headers) do
        {:ok, session} -> {:ok, session}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private implementation

  defp do_create_session(api_key, opts) do
    prompt = Keyword.fetch!(opts, :prompt)
    source_context = Keyword.get(opts, :source_context)
    automation_mode = Keyword.get(opts, :automation_mode, "MANUAL")

    # Build request body
    body = %{
      "automationMode" => automation_mode,
      "initialMessage" => %{
        "content" => prompt
      }
    }

    # Add source context if provided
    body =
      if source_context do
        Map.put(body, "sourceContext", %{"sourceContext" => source_context})
      else
        body
      end

    headers = jules_headers(api_key)
    url = "#{@jules_base_url}/sessions"

    Logger.debug("Creating Jules session: prompt=#{String.slice(prompt, 0..50)}")

    case execute_request(:post, url, body, headers) do
      {:ok, %{"name" => name}} ->
        # Extract session ID from name (format: "projects/*/sessions/{sessionId}")
        session_id = extract_session_id(name)
        Logger.info("Jules session created: #{session_id}")
        {:ok, session_id}

      {:ok, response} ->
        Logger.error("Unexpected session creation response: #{inspect(response)}")
        {:error, "Invalid response format"}

      {:error, reason} ->
        Logger.error("Session creation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_poll_session(session_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt)
       when attempt < max_attempts do
    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    if elapsed_ms > timeout_ms do
      Logger.warning("Session polling timeout after #{elapsed_ms}ms")
      {:error, :timeout}
    else
      case get_session(session_id) do
        {:ok, session} ->
          state = Map.get(session, "state")

          case state do
            "done" ->
              Logger.info("Session completed: #{session_id}")
              {:ok, session}

            "failed" ->
              Logger.error("Session failed: #{session_id}")
              {:error, :session_failed}

            _ ->
              # Still in progress, wait and retry
              Logger.debug("Session #{session_id} state: #{state}, polling again...")
              Process.sleep(poll_interval_ms)

              do_poll_session(session_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt + 1)
          end

        {:error, reason} ->
          Logger.warning("Error polling session #{session_id}: #{inspect(reason)}")
          Process.sleep(poll_interval_ms)

          do_poll_session(session_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt + 1)
      end
    end
  end

  defp do_poll_session(_session_id, _poll_interval_ms, _max_attempts, _timeout_ms, _start_time, _attempt) do
    Logger.warning("Session polling max attempts reached")
    {:error, :max_attempts_exceeded}
  end

  defp fetch_session(api_key, session_id) do
    headers = jules_headers(api_key)
    url = "#{@jules_base_url}/sessions/#{session_id}"

    case execute_request(:get, url, nil, headers) do
      {:ok, session} -> {:ok, session}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_activities(api_key, session_id) do
    headers = jules_headers(api_key)
    url = "#{@jules_base_url}/sessions/#{session_id}/activities"

    case execute_request(:get, url, nil, headers) do
      {:ok, %{"activities" => activities}} -> {:ok, activities}
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_request(method, url, body, headers) do
    client_opts = [
      provider: :jules,
      base_url: @jules_base_url
    ]

    client = Core.client(client_opts)

    case Tesla.request(client, method: method, url: url, body: body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: 401, body: response_body}} ->
        Logger.warning("Jules auth failed (401): #{response_body}")
        {:error, "unauthorized"}

      {:ok, %Tesla.Env{status: 403, body: response_body}} ->
        Logger.warning("Jules permission denied (403): #{response_body}")
        {:error, "forbidden"}

      {:ok, %Tesla.Env{status: 429, body: response_body}} ->
        Logger.warning("Jules rate limit (429): #{response_body}")
        {:error, "rate_limit"}

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        Logger.error("Jules API error (#{code}): #{response_body}")
        {:error, "HTTP #{code}: #{response_body}"}

      {:error, reason} ->
        Logger.error("HTTP request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp jules_headers(api_key) do
    [
      {"X-Goog-Api-Key", api_key},
      {"Content-Type", "application/json"},
      {"User-Agent", "ExLLM/1.0.0"}
    ]
  end

  defp get_api_key() do
    case System.get_env("GOOGLE_JULES_API_KEY") do
      nil ->
        Logger.error("GOOGLE_JULES_API_KEY environment variable not set")
        {:error, "missing_api_key"}

      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      _ ->
        Logger.error("GOOGLE_JULES_API_KEY is empty")
        {:error, "empty_api_key"}
    end
  end

  defp build_url(path, params) when is_map(params) do
    query_string =
      params
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    "#{@jules_base_url}#{path}?#{query_string}"
  end

  defp extract_session_id(name) when is_binary(name) do
    # Format: "projects/{projectId}/sessions/{sessionId}"
    case String.split(name, "/") do
      [_, _, _, _, session_id] -> session_id
      _ -> name
    end
  end
end
