defmodule SingularityLLM.Providers.Codex.TaskClient do
  @moduledoc """
  Codex WHAM Task Client - Asynchronous Task-Based API Implementation.

  Implements the standard **Async Request-Reply Pattern** (HTTP 202 Accepted) for long-running
  code generation operations using the WHAM (ChatGPT backend) protocol.

  ## Async Request-Reply Pattern

  This module follows the established async pattern for long-running operations:

  **Step 1: Submit Task**
  ```
  POST /wham/tasks
  → 202 Accepted (or 200 OK with task_id)
  → Returns: task_id
  ```

  **Step 2: Poll for Status**
  ```
  GET /wham/tasks/{task_id}
  → Returns: current_assistant_turn with status
  → Statuses: "queued", "in_progress", "completed", "failed"
  ```

  **Step 3: Extract Results**
  ```
  Response contains:
  - output_items[]: Messages, diffs, PR metadata, files
  ```

  ## SQ/EQ Protocol (Submission Queue / Event Queue)

  - **SQ**: Submit task → Get async job ID immediately
  - **EQ**: Poll endpoint → Get job status and results

  ## Status Codes

  - **200 OK** - Task response retrieved successfully
  - **202 Accepted** - Task submitted (processing started)
  - **401 Unauthorized** - Invalid or expired token
  - **429 Too Many Requests** - Rate limited
  - **500 Internal Server Error** - Server error

  ## Usage

      iex> # Step 1: Submit task (async)
      iex> {:ok, task_id} = TaskClient.create_task(
      ...>   environment_id: "owner/repo",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support"
      ...> )

      iex> # Step 2: Poll for completion
      iex> {:ok, response} = TaskClient.poll_task(task_id, max_attempts: 30)

  ## HTTP Endpoints

  - `POST /wham/tasks` - Submit task (returns task_id)
  - `GET /wham/tasks/{id}` - Poll status and get response
  - `GET /wham/tasks/list` - List user's tasks
  - `GET /wham/usage` - Check rate limits

  ## Implementation Details

  - All endpoints use `https://chatgpt.com/backend-api/wham/`
  - Requires valid OAuth2 token from `~/.codex/auth.json`
  - Token management handled by `TokenManager`
  - Account ID also required (from auth.json)

  ## See Also

  - **AsyncAPI Specification**: https://www.asyncapi.com/
  - **Azure Async Request-Reply Pattern**: https://learn.microsoft.com/azure/architecture/patterns/async-request-reply
  - **RESTful API Design for Long-Running Tasks**: https://restfulapi.net/rest-api-design-for-long-running-tasks/
  """

  require Logger
  alias SingularityLLM.Providers.Codex.TokenManager
  alias SingularityLLM.Providers.Shared.HTTP.Core

  @wham_base_url "https://chatgpt.com/backend-api/wham"
  @default_poll_interval_ms 3000
  @default_max_attempts 30
  @timeout_ms 120_000

  @typedoc """
  Codex task creation options.

  - `:environment_id` (required) - Format: "owner/repository-name"
  - `:branch` (required) - Git branch name (e.g., "main", "develop")
  - `:prompt` (required) - User prompt/instructions for the task
  - `:model` (optional) - Model ID (default: "gpt-5-codex")
  - `:qa_mode` (optional) - Run in QA mode (default: false)
  - `:best_of_n` (optional) - Number of attempts (default: 1)
  - `:poll_interval_ms` (optional) - Polling interval in milliseconds
  - `:max_attempts` (optional) - Maximum polling attempts
  - `:timeout_ms` (optional) - Total timeout for polling
  """
  @type create_opts :: [
          {:environment_id, String.t()}
          | {:branch, String.t()}
          | {:prompt, String.t()}
          | {:model, String.t()}
          | {:qa_mode, boolean()}
          | {:best_of_n, pos_integer()}
          | {:poll_interval_ms, pos_integer()}
          | {:max_attempts, pos_integer()}
          | {:timeout_ms, pos_integer()}
        ]

  @doc """
  Create a new Codex task (Async Request-Reply Pattern - Step 1/2).

  **Async Pattern:** This function returns immediately with a task ID.
  Use `poll_task/2` to check for completion.

  **HTTP:** `POST /wham/tasks` → 202 Accepted (task submitted)

  ## Arguments

  - `opts` - Keyword list with task configuration

  ## Options

  - `:environment_id` (required) - "owner/repository"
  - `:branch` (required) - Git branch name
  - `:prompt` (required) - User instruction
  - `:model` - Model ID (default: "gpt-5-codex")
  - `:qa_mode` - Run in QA mode (default: false)
  - `:best_of_n` - Number of attempts (default: 1)

  ## Returns

  - `{:ok, task_id}` - Task submitted successfully ✓
  - `{:error, reason}` - Submission failed

  ## Examples

      iex> # Step 1: Submit task (returns immediately)
      iex> {:ok, task_id} = create_task(
      ...>   environment_id: "mikkihugo/singularity-incubation",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support"
      ...> )

      iex> # Step 2: Poll for results
      iex> {:ok, response} = poll_task(task_id, max_attempts: 60)
  """
  @spec create_task(create_opts()) :: {:ok, String.t()} | {:error, term()}
  def create_task(opts) when is_list(opts) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, account_id} <- get_account_id(),
         {:ok, task_id} <- do_create_task(token, account_id, opts) do
      {:ok, task_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a task and wait for completion (blocking operation).

  ## Arguments

  - `opts` - Same as `create_task/1` plus `wait_for_completion: true`

  ## Returns

  - `{:ok, task_id, response}` - Task completed with response
  - `{:error, reason}` - Creation or polling failed

  ## Timeout Behavior

  Uses total timeout from `opts[:timeout_ms]` (default 120 seconds).
  """
  @spec create_task_and_wait(create_opts()) ::
          {:ok, String.t(), map()} | {:error, term()}
  def create_task_and_wait(opts) do
    case create_task(opts) do
      {:ok, task_id} ->
        # Remove task creation options, keep polling options
        poll_opts = Keyword.take(opts, [:poll_interval_ms, :max_attempts, :timeout_ms])

        case poll_task(task_id, poll_opts) do
          {:ok, response} -> {:ok, task_id, response}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Poll a task for completion (Async Request-Reply Pattern - Step 2/2).

  **Async Pattern:** Continuously polls the task endpoint until completion or timeout.
  Call after `create_task/1` to wait for results.

  **HTTP:** `GET /wham/tasks/{task_id}` → 200 OK with status

  ## Arguments

  - `task_id` - Task ID from `create_task/1`
  - `opts` - Polling options

  ## Options

  - `:poll_interval_ms` - Wait between polls (default: 3000ms)
  - `:max_attempts` - Maximum polling attempts (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000ms)

  ## Returns

  - `{:ok, response}` - Task completed with response ✓
  - `{:error, reason}` - Polling failed or timed out

  ## Example

      iex> # Poll until completion (blocks)
      iex> {:ok, response} = poll_task("task_e_...", max_attempts: 60)
      iex> response["current_assistant_turn"]["turn_status"]
      "completed"
  """
  @spec poll_task(String.t(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def poll_task(task_id, opts \\ []) when is_binary(task_id) do
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    timeout_ms = Keyword.get(opts, :timeout_ms, @timeout_ms)

    start_time = System.monotonic_time(:millisecond)

    do_poll_task(
      task_id,
      poll_interval_ms,
      max_attempts,
      timeout_ms,
      start_time,
      0
    )
  end

  @doc """
  Get task status without waiting.

  ## Returns

  - `{:ok, status}` - Current task status ("queued", "in_progress", "completed", "failed", etc.)
  - `{:error, reason}` - Request failed
  """
  @spec get_task_status(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_task_status(task_id) when is_binary(task_id) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, account_id} <- get_account_id(),
         {:ok, response} <- fetch_task(token, account_id, task_id) do
      status = get_in(response, ["current_assistant_turn", "turn_status"])
      {:ok, status}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get full task response.

  Fetches the complete task details without polling.

  ## Returns

  - `{:ok, response}` - Full task response
  - `{:error, reason}` - Request failed
  """
  @spec get_task_response(String.t()) :: {:ok, map()} | {:error, term()}
  def get_task_response(task_id) when is_binary(task_id) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, account_id} <- get_account_id(),
         {:ok, response} <- fetch_task(token, account_id, task_id) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List user's tasks with pagination.

  ## Options

  - `:limit` - Number of tasks to return (default: 10)
  - `:offset` - Pagination offset (default: 0)

  ## Returns

  - `{:ok, items}` - List of task summaries
  - `{:error, reason}` - Request failed
  """
  @spec list_tasks(Keyword.t()) :: {:ok, list(map())} | {:error, term()}
  def list_tasks(opts \\ []) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, account_id} <- get_account_id() do
      limit = Keyword.get(opts, :limit, 10)
      offset = Keyword.get(opts, :offset, 0)

      headers = wham_headers(token, account_id)
      url = "#{@wham_base_url}/tasks/list?limit=#{limit}&offset=#{offset}"

      case execute_request(:get, url, nil, headers) do
        {:ok, %{"items" => items}} -> {:ok, items}
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check rate limit usage.

  ## Returns

  - `{:ok, usage}` - Rate limit information
  - `{:error, reason}` - Request failed

  ## Response Format

      %{
        "primary_window" => %{
          "used_percent" => 8,
          "limit_window_seconds" => 17940,
          "reset_at" => 1761548349
        },
        "secondary_window" => %{
          "used_percent" => 15,
          "limit_window_seconds" => 604740,
          "reset_at" => 1761596280
        }
      }
  """
  @spec get_usage() :: {:ok, map()} | {:error, term()}
  def get_usage() do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, account_id} <- get_account_id() do
      headers = wham_headers(token, account_id)
      url = "#{@wham_base_url}/usage"

      case execute_request(:get, url, nil, headers) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private implementation

  defp do_create_task(token, account_id, opts) do
    environment_id = Keyword.fetch!(opts, :environment_id)
    branch = Keyword.fetch!(opts, :branch)
    prompt = Keyword.fetch!(opts, :prompt)
    model = Keyword.get(opts, :model, "gpt-5-codex")
    qa_mode = Keyword.get(opts, :qa_mode, false)
    best_of_n = Keyword.get(opts, :best_of_n, 1)

    # Build the payload according to codex-rs specification
    payload = %{
      "new_task" => %{
        "environment_id" => environment_id,
        "branch" => branch,
        "run_environment_in_qa_mode" => qa_mode
      },
      "input_items" => [
        %{
          "type" => "message",
          "role" => "user",
          "content" => [
            %{
              "content_type" => "text",
              "text" => prompt
            }
          ]
        }
      ]
    }

    # Add metadata if best_of_n > 1
    payload =
      if best_of_n > 1 do
        Map.put(payload, "metadata", %{"best_of_n" => best_of_n})
      else
        payload
      end

    headers = wham_headers(token, account_id)
    url = "#{@wham_base_url}/tasks"

    Logger.debug(
      "Creating Codex task: env=#{environment_id}, branch=#{branch}, model=#{model}"
    )

    case execute_request(:post, url, payload, headers) do
      {:ok, %{"task" => %{"id" => task_id}}} ->
        Logger.info("Codex task created: #{task_id}")
        {:ok, task_id}

      {:ok, response} ->
        Logger.error("Unexpected task creation response: #{inspect(response)}")
        {:error, "Invalid response format"}

      {:error, reason} ->
        Logger.error("Task creation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_poll_task(task_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt)
       when attempt < max_attempts do
    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    if elapsed_ms > timeout_ms do
      Logger.warning("Task polling timeout after #{elapsed_ms}ms")
      {:error, :timeout}
    else
      case get_task_response(task_id) do
        {:ok, response} ->
          status = get_in(response, ["current_assistant_turn", "turn_status"])

          case status do
            "completed" ->
              Logger.info("Task completed: #{task_id}")
              {:ok, response}

            "failed" ->
              Logger.error("Task failed: #{task_id}")
              {:error, :task_failed}

            _ ->
              # Still in progress, wait and retry
              Logger.debug("Task #{task_id} status: #{status}, polling again...")
              Process.sleep(poll_interval_ms)
              do_poll_task(task_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt + 1)
          end

        {:error, reason} ->
          Logger.warning("Error polling task #{task_id}: #{inspect(reason)}")
          Process.sleep(poll_interval_ms)
          do_poll_task(task_id, poll_interval_ms, max_attempts, timeout_ms, start_time, attempt + 1)
      end
    end
  end

  defp do_poll_task(_task_id, _poll_interval_ms, _max_attempts, _timeout_ms, _start_time, _attempt) do
    Logger.warning("Task polling max attempts reached")
    {:error, :max_attempts_exceeded}
  end

  defp fetch_task(token, account_id, task_id) do
    headers = wham_headers(token, account_id)
    url = "#{@wham_base_url}/tasks/#{task_id}"

    case execute_request(:get, url, nil, headers) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_request(method, url, body, headers) do
    client_opts = [
      provider: :codex,
      base_url: @wham_base_url
    ]

    client = Core.client(client_opts)

    case Tesla.request(client, method: method, url: url, body: body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: 401, body: response_body}} ->
        Logger.warning("Codex auth failed (401): #{response_body}")
        {:error, "unauthorized"}

      {:ok, %Tesla.Env{status: 429, body: response_body}} ->
        Logger.warning("Codex rate limit (429): #{response_body}")
        {:error, "rate_limit"}

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        Logger.error("Codex API error (#{code}): #{response_body}")
        {:error, "HTTP #{code}: #{response_body}"}

      {:error, reason} ->
        Logger.error("HTTP request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp wham_headers(token, account_id) do
    [
      {"Authorization", "Bearer #{token}"},
      {"chatgpt-account-id", account_id},
      {"Content-Type", "application/json"},
      {"User-Agent", "SingularityLLM/1.0.0"}
    ]
  end

  defp get_account_id() do
    # Load account_id from ~/.codex/auth.json
    codex_auth_path = Path.expand("~/.codex/auth.json")

    case File.read(codex_auth_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"tokens" => %{"account_id" => account_id}}} when is_binary(account_id) ->
            {:ok, account_id}

          {:ok, _} ->
            Logger.error("Missing account_id in ~/.codex/auth.json")
            {:error, "missing_account_id"}

          {:error, reason} ->
            Logger.error("Failed to parse ~/.codex/auth.json: #{inspect(reason)}")
            {:error, "invalid_auth_json"}
        end

      {:error, reason} ->
        Logger.error("Failed to read ~/.codex/auth.json: #{inspect(reason)}")
        {:error, "auth_file_not_found"}
    end
  end
end
