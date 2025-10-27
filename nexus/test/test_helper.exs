ExUnit.start()

# ======================================================================
# NEXUS TESTING FRAMEWORK - Shared mocking infrastructure
# ======================================================================
#
# ## What This File Contains
#
# Reusable mock modules used across ALL Nexus unit tests.
# No external dependencies (no Mox, no third-party libraries).
# Pure Elixir mocks with sensible defaults.
#
# ## Why This Approach?
#
# ✅ **Fast**: No network calls, no database access
# ✅ **Reliable**: 100% reproducible, no timing dependencies
# ✅ **Isolated**: Each test independent, no shared state
# ✅ **Simple**: Just Elixir modules, no special syntax
# ✅ **Clear**: Mock behavior obvious from reading the code
#
# ## How It Works
#
# 1. **Define Mock Modules** (in this file - do once, use everywhere)
# 2. **Add Dependency Injection** to your code (3 lines per module):
#      defp http_client do
#        Application.get_env(:nexus, :http_client, Req)
#      end
# 3. **Configure in Tests** (setup block - 11 lines):
#      setup do
#        Application.put_env(:nexus, :http_client, MockReq)
#        on_exit(fn -> Application.delete_env(:nexus, :http_client) end)
#        :ok
#      end
# 4. **Run Tests** with `mix test --no-start` (no database needed)
#
# ## Adding New Mocks
#
# If you need a new mock (e.g., MockDatabase):
# 1. Add the module below (copy structure from existing mocks)
# 2. Define the functions your code calls
# 3. Return sensible defaults (e.g., error tuples)
# 4. Add to docstring which modules use it
# 5. Update all test modules that need it
#
# ======================================================================

# ======================================================================
# MOCK MODULE: MockReq - HTTP client mock
# ======================================================================
# Simulates the Req HTTP client for testing OAuth2 and API calls.
# Used by: Nexus.Providers.ClaudeCode.OAuth2, Nexus.Providers.Codex

defmodule MockReq do
  @moduledoc """
  Mock HTTP client simulating Req (Elixir HTTP library).

  **Purpose**: Test code making HTTP requests without network access.

  **Default Behavior**:
  - All requests return error (no mock configured)
  - Tests stub specific URLs with expected responses

  **Usage in Tests**:
      setup do
        # OAuth2 tests stub this URL
        Application.put_env(:nexus, :http_client, MockReq)
        on_exit(fn -> Application.delete_env(:nexus, :http_client) end)
        :ok
      end

  **Usage in Code**:
      defmodule MyProvider do
        defp http_client do
          Application.get_env(:nexus, :http_client, Req)
        end
        def fetch(url) do
          http_client().post(url, json: %{data: "value"})
        end
      end

  **Functions Implemented**:
  - `post(url, opts)` - Simulates Req.post/2 (OAuth2 token exchange, API calls)
  """

  def post(_url, _opts \\ []) do
    # Default: error (no stubbed response for this URL)
    {:error, :not_configured}
  end
end

# ======================================================================
# MOCK MODULE: MockOAuthToken - Token repository mock
# ======================================================================
# Simulates OAuth token storage and retrieval.
# Used by: Nexus.Providers.ClaudeCode.OAuth2, Nexus.Providers.Codex

defmodule MockOAuthToken do
  @moduledoc """
  Mock OAuth token repository simulating Nexus.OAuthToken.

  **Purpose**: Test code that stores/retrieves tokens without database.

  **Default Behavior**:
  - `get/1` returns not_found (no token stored)
  - `upsert/3` returns success
  - `expired?/1` checks DateTime logic (real implementation)

  **Usage in Tests**:
      setup do
        Application.put_env(:nexus, :token_repository, MockOAuthToken)
        on_exit(fn -> Application.delete_env(:nexus, :token_repository) end)
        :ok
      end

  **Usage in Code**:
      defmodule MyProvider do
        defp token_repository do
          Application.get_env(:nexus, :token_repository, OAuthToken)
        end
        def get_token do
          token_repository().get("provider_name")
        end
      end

  **Functions Implemented**:
  - `get(provider)` - Get token for provider (returns :not_found by default)
  - `upsert(provider, attrs)` - Store/update token (returns success by default)
  - `expired?(token)` - Check if token expired (uses real DateTime logic)
  """

  def get(_provider) do
    # Default: token not found (no token stored)
    {:error, :not_found}
  end

  def upsert(_provider, _attrs) do
    # Default: success (token stored)
    {:ok, %{}}
  end

  def expired?(%{expires_at: expires_at}) do
    # Real logic: use DateTime comparison
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def expired?(_), do: false
end

# ======================================================================
# MOCK MODULE: MockExLLM - LLM provider mock
# ======================================================================
# Simulates the ExLLM LLM provider abstraction.
# Used by: Nexus.Workflows.LLMRequestWorkflow, agent code

defmodule MockExLLM do
  @moduledoc """
  Mock LLM provider simulating ExLLM (LLM abstraction layer).

  **Purpose**: Test code that calls LLMs without API access.

  **Default Behavior**:
  - `chat/3` returns generic success response
  - `list_all/0` returns empty list

  **Usage in Tests**:
      setup do
        Application.put_env(:nexus, :llm_provider, MockExLLM)
        on_exit(fn -> Application.delete_env(:nexus, :llm_provider) end)
        :ok
      end

  **Usage in Code**:
      defmodule MyWorkflow do
        defp llm_provider do
          Application.get_env(:nexus, :llm_provider, ExLLM)
        end
        def call_llm(messages) do
          llm_provider().chat(:claude, messages)
        end
      end

  **Functions Implemented**:
  - `chat(provider, messages, opts)` - Call LLM for completion
  - `list_all()` - List available LLM models
  """

  def chat(_provider, _messages, _opts \\ []) do
    # Default: generic success response
    {:ok, %{"choices" => [%{"message" => %{"content" => "Mock response"}}]}}
  end

  def list_all do
    # Default: empty model list
    {:ok, []}
  end
end

# ======================================================================
# TEST ENVIRONMENT CONFIGURATION
# ======================================================================

# Set flag so modules know they're running in test mode
Application.put_env(:nexus, :test_mode, true)
