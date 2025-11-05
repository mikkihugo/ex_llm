defmodule SingularityLLM.Providers.Jules do
  @moduledoc """
  Google Jules Provider for SingularityLLM.

  Integrates with Google's Jules AI coding agent using the async Task API.

  ## Supported APIs

  ### Task API (Async Code Generation)
  For long-running code generation tasks using the async request-reply pattern.

      iex> {:ok, session_id} = SingularityLLM.Providers.Jules.create_session(
      ...>   prompt: "Add dark mode support to the dashboard"
      ...> )
      iex> {:ok, session} = SingularityLLM.Providers.Jules.poll_session(session_id)

  ## Async Request-Reply Pattern

  Jules uses the standard async pattern for long-running operations:

  1. **Submit Task** → Returns immediately with session_id
  2. **Poll for Status** → Check progress and results
  3. **Extract Results** → Get code changes and metadata

  ## Authentication

  Jules requires an API key from the Jules web app Settings:

  1. Go to https://jules.google/
  2. Click Settings
  3. Generate an API key
  4. Set environment variable: `GOOGLE_JULES_API_KEY`

  ## Available Models

  - `google-jules` (default) - Google's autonomous AI coding agent

  Cost: FREE with Google Cloud account

  ## Requirements

  - Google account
  - Jules API key (from https://julius.googleapis.com)
  - Environment variable: `GOOGLE_JULES_API_KEY`

  ## Session States

  - `initializing` - Session is being set up
  - `planning` - Jules is planning changes
  - `executing` - Jules is executing changes
  - `done` - Session completed successfully
  - `failed` - Session failed with error

  ## Example: Full Workflow

      iex> alias SingularityLLM.Providers.Jules

      # Step 1: Create session (returns immediately)
      iex> {:ok, session_id} = Jules.create_session(
      ...>   prompt: "Add unit tests for auth module"
      ...> )

      # Step 2: Wait for completion
      iex> {:ok, session} = Jules.poll_session(session_id)

      # Step 3: Get activities/changes
      iex> {:ok, activities} = Jules.get_activities(session_id)

      # Step 4: Extract structured data
      iex> extracted = Jules.extract_response(session, activities)
      iex> Enum.map(extracted.code_changes, & &1.file)
      ["app.py", "utils.py"]
  """

  @behaviour SingularityLLM.Provider

  require Logger
  alias SingularityLLM.Providers.Jules.TaskClient
  alias SingularityLLM.Providers.Jules.ResponseExtractor
  alias SingularityLLM.Types

  @impl true
  def chat(_messages, _opts \\ []) do
    # Jules doesn't support direct chat API like Codex
    # Use session-based task API instead
    {:error, "Jules uses async task API, not direct chat. Use create_session/1 instead."}
  end

  @impl true
  def stream_chat(_messages, _opts \\ []) do
    {:error, "Jules uses async task API, not direct chat. Use create_session/1 instead."}
  end

  @impl true
  def configured?(_opts \\ []) do
    case System.get_env("GOOGLE_JULES_API_KEY") do
      nil -> false
      key when is_binary(key) -> String.length(key) > 0
      _ -> false
    end
  end

  @impl true
  def default_model() do
    "google-jules"
  end

  @impl true
  def list_models(_opts \\ []) do
    # Jules only has one model
    {:ok,
     [
       %Types.Model{
         id: "google-jules",
         name: "Google Jules",
         description: "Google's autonomous AI coding agent",
         context_window: 200_000,
         max_output_tokens: 128_000,
         pricing: %{input: 0.0, output: 0.0},
         capabilities: [
           "code_generation",
           "code_analysis",
           "refactoring",
           "testing",
           "documentation"
         ]
       }
     ]}
  end

  # Session API Methods (Async Request-Reply Pattern)

  @doc """
  Create a new Jules session (Async Request-Reply Pattern - Step 1/2).

  **Async Pattern:** This function returns immediately with a session ID.
  Use `poll_session/2` to check completion.

  **HTTP:** `POST /sessions` → Returns session_id

  ## Options

  - `:prompt` (required) - Code generation instruction
  - `:source_context` (optional) - Context (e.g., "web_app")
  - `:automation_mode` (optional) - "AUTO" or "MANUAL" (default: "MANUAL")

  ## Returns

  - `{:ok, session_id}` - Session created successfully ✓
  - `{:error, reason}` - Creation failed

  ## Example

      iex> {:ok, session_id} = create_session(
      ...>   prompt: "Add dark mode support with theme switcher"
      ...> )
  """
  def create_session(opts) when is_list(opts) do
    TaskClient.create_session(opts)
  end

  @doc """
  Create a session and wait for completion (blocking).

  ## Returns

  - `{:ok, session_id, session}` - Session completed with results
  - `{:error, reason}` - Creation or polling failed

  ## Example

      iex> {:ok, session_id, session} = create_session_and_wait(
      ...>   prompt: "Generate unit tests",
      ...>   max_attempts: 60
      ...> )
  """
  def create_session_and_wait(opts) do
    TaskClient.create_session_and_wait(opts)
  end

  @doc """
  Poll a session for completion (Async Request-Reply Pattern - Step 2/2).

  Continuously polls until completion or timeout.

  ## Options

  - `:poll_interval_ms` - Wait between polls (default: 3000ms)
  - `:max_attempts` - Maximum polls (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000ms)

  ## Returns

  - `{:ok, session}` - Session completed
  - `{:error, reason}` - Failed or timed out

  ## Example

      iex> {:ok, session} = poll_session(session_id, max_attempts: 60)
  """
  def poll_session(session_id, opts \\ []) do
    TaskClient.poll_session(session_id, opts)
  end

  @doc """
  Get session status without waiting.

  ## Returns

  - `{:ok, session}` - Current session object
  - `{:error, reason}` - Request failed
  """
  def get_session(session_id) do
    TaskClient.get_session(session_id)
  end

  @doc """
  Get session state (simplified status).

  ## Returns

  - `{:ok, state}` - Current state ("initializing", "planning", "executing", "done", "failed")
  - `{:error, reason}` - Request failed
  """
  def get_session_state(session_id) do
    TaskClient.get_session_state(session_id)
  end

  @doc """
  Get session activities (code changes).

  ## Returns

  - `{:ok, activities}` - List of activities
  - `{:error, reason}` - Request failed
  """
  def get_activities(session_id) do
    TaskClient.get_activities(session_id)
  end

  @doc """
  Extract structured data from a session and its activities.

  ## Returns

  Map with extracted session state, code changes, activities.

  ## Example

      iex> {:ok, session} = get_session(session_id)
      iex> {:ok, activities} = get_activities(session_id)
      iex> extracted = extract_response(session, activities)
      iex> extracted.code_changes |> Enum.count()
      3
  """
  def extract_response(session, activities) do
    ResponseExtractor.extract(session, activities)
  end

  @doc """
  List user's sessions.

  ## Options

  - `:page_size` - Number of sessions (default: 10)
  - `:page_token` - Pagination token (default: nil)

  ## Returns

  - `{:ok, sessions}` - List of session summaries
  - `{:error, reason}` - Request failed
  """
  def list_sessions(opts \\ []) do
    TaskClient.list_sessions(opts)
  end

  @doc """
  Approve a session's generated plan.

  Required when automation_mode is "MANUAL".

  ## Returns

  - `{:ok, session}` - Plan approved, execution continues
  - `{:error, reason}` - Request failed
  """
  def approve_plan(session_id) do
    TaskClient.approve_plan(session_id)
  end
end
