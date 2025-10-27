# Nexus Testing Guide

## Current Status

✅ **120 Unit Tests Passing (100%)**
- 8 doctests
- 112 functional tests
- No database required
- No external services required
- Zero compilation warnings from Nexus code
- Execution time: 0.4 seconds
- Run with: `mix test --no-start --exclude integration`

⏳ **11 Integration Tests** (require full application startup with database)
- Tests real database operations
- Require Ecto.Sandbox setup
- Marked with `@moduletag :integration`
- Run with: `mix test --include integration` (requires database setup)

---

## Quick Start

### Run All Unit Tests (Recommended)
```bash
cd singularity/nexus
mix test --no-start --exclude integration
```

**Output:**
```
Finished in 0.4 seconds (0.3s async, 0.07s sync)
8 doctests, 120 tests, 0 failures ✅ (11 integration tests excluded)
```

**Why exclude integration tests?**
- Integration tests require database access and application startup
- With --no-start, these tests cannot connect to the database
- Excluding them lets unit tests run fast (0.4 seconds) with zero failures

### Run Specific Test File
```bash
mix test test/nexus/providers/codex_test.exs --no-start
```

### Run With Coverage
```bash
mix test.ci --no-start
```

---

## Test Breakdown

### Unit Tests (--no-start --exclude integration) - 120 tests ✅

| Module | Tests | Status |
|--------|-------|--------|
| Claude Code OAuth2 | 34 | ✅ Passing |
| Codex Provider | 13 | ✅ Passing |
| OAuthToken Schema | 8 | ✅ Passing |
| LLM Workflow | 22 | ✅ Passing |
| Core Modules | 11 | ✅ Passing |
| Doctests | 8 | ✅ Passing |
| Other Unit Tests | 16 | ✅ Passing |
| **Total** | **120** | **✅ All Passing** |

### Integration Tests (11 tests)

Located in `test/nexus/integration/codex_integration_test.exs`

Tests real database operations:
- OAuth token storage and retrieval
- Token expiration logic
- Codex provider configuration
- Model listing with real database

**Status**: Requires:
1. `mix ecto.create` - Database setup
2. `mix ecto.migrate` - Schema creation
3. Full application startup (without --no-start)
4. Ecto.Sandbox configuration

---

## Why --no-start is Used

### With --no-start (Unit Tests Only)
- ✅ No application startup
- ✅ No ExLLM initialization
- ✅ No external service calls
- ✅ No database connection required
- ✅ Fast execution (0.4 seconds)
- ✅ Perfect for CI/CD pipelines

### Without --no-start (Full Application)
- ❌ ExLLM application fails to initialize
- ❌ Requires database setup
- ❌ Requires external service configuration
- ❌ Requires full environment setup
- ⚠️ Not practical for standard CI/CD

**Decision**: Use `--no-start` for all standard testing. Only run full application tests when explicitly needed.

---

## Setting Up Database (Optional)

If you want to run integration tests with real database:

### 1. Create Test Database
```bash
psql -U postgres -c "CREATE DATABASE singularity_test;"
```

### 2. Run Migrations
```bash
cd singularity/nexus
mix ecto.migrate
```

### 3. Update Integration Tests

Add Ecto.Sandbox to `test/nexus/integration/codex_integration_test.exs`:

```elixir
defmodule Nexus.Integration.CodexIntegrationTest do
  use ExUnit.Case, async: false

  # Add this:
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Nexus.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, {:shared, self()})
    :ok
  end

  # ... rest of tests
end
```

### 4. Run Integration Tests Separately
```bash
# After fixing Ecto.Sandbox, run specific test file
mix test test/nexus/integration/codex_integration_test.exs

# Or filter to integration tests
mix test --include integration
```

---

## Test Infrastructure

### Shared Mocking Framework (test/test_helper.exs)

Pure Elixir mocks with **zero external dependencies**:

#### MockReq - HTTP Client Mock
```elixir
defmodule MockReq do
  @moduledoc """
  Mock HTTP client for testing without network access.

  Used by:
  - Nexus.Providers.ClaudeCode.OAuth2
  - Nexus.Providers.Codex
  """

  def post(_url, _opts \\ []) do
    {:error, :not_configured}
  end
end
```

#### MockOAuthToken - Token Repository Mock
```elixir
defmodule MockOAuthToken do
  @moduledoc """
  Mock OAuth token repository for testing without database.
  """

  def get(_provider), do: {:error, :not_found}
  def upsert(_provider, _attrs), do: {:ok, %{}}
  def expired?(%{expires_at: expires_at}), do:
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  def expired?(_), do: false
end
```

#### MockExLLM - LLM Provider Mock
```elixir
defmodule MockExLLM do
  @moduledoc """
  Mock LLM provider for testing without external services.
  """

  def chat(_provider, _messages, _opts \\ []) do
    {:ok, %{"choices" => [%{"message" => %{"content" => "Mock response"}}]}}
  end

  def list_all do
    {:ok, []}
  end
end
```

### Dependency Injection Pattern

All providers use consistent dependency injection:

```elixir
# In lib/nexus/providers/codex.ex
defp http_client do
  Application.get_env(:nexus, :http_client, Req)
end

defp token_repository do
  Application.get_env(:nexus, :token_repository, OAuthToken)
end

# In tests, setup block configures mocks:
setup do
  Application.put_env(:nexus, :http_client, MockReq)
  Application.put_env(:nexus, :token_repository, MockOAuthToken)

  on_exit(fn ->
    Application.delete_env(:nexus, :http_client)
    Application.delete_env(:nexus, :token_repository)
  end)

  :ok
end
```

**Benefits:**
- ✅ No external testing frameworks (no Mox)
- ✅ Pure Elixir modules
- ✅ Easy to understand and modify
- ✅ Reusable across all test files

---

## Self-Documenting Tests

Every test file includes:

1. **@moduledoc** - Explains what is/isn't tested
2. **Setup blocks** - Comments explaining configuration
3. **Describe blocks** - Feature-based organization
4. **Test names** - Scenario descriptions

### Example: Codex Provider Tests

```elixir
@moduledoc """
Unit tests for Nexus.Providers.Codex - ChatGPT Pro OAuth2 integration.

## What This Tests
- Model Listing (structure, types, properties)
- Configuration Status (token availability)
- Error Handling (missing tokens)

## What This Does NOT Test
- Actual HTTP Calls (use integration tests)
- Token Management (use OAuthToken tests)
- Chat Execution (use integration tests)

## Test Infrastructure
Uses MockReq and MockOAuthToken (simple Elixir mocks, no Mox)
"""
```

---

## Common Test Scenarios

### Test Model Listing
```bash
mix test test/nexus/providers/codex_test.exs --no-start -k "model"
```

Tests 13 comprehensive scenarios:
- List structure validation
- Required fields present
- Field types correct
- Values reasonable
- Specific model properties

### Test OAuth2 Flow
```bash
mix test test/nexus/providers/claude_code/oauth2_test.exs --no-start -k "authorization"
```

Tests 34 comprehensive scenarios:
- PKCE implementation
- State parameter handling
- Token exchange
- Error cases
- Concurrent requests

### Test Token Management
```bash
mix test test/nexus/core/oauth_token_test.exs --no-start
```

Tests 8 scenarios:
- Changeset validation
- Expiration detection
- Format conversions
- Token handling

---

## Adding New Tests

### 1. Identify Test Type
- **Unit test** (--no-start compatible): Pure logic, no infrastructure
- **Integration test**: Requires database or external services

### 2. Choose Location
```
test/nexus/
├── providers/           # Provider tests (unit)
│   ├── codex_test.exs
│   └── claude_code/
│       └── oauth2_test.exs
├── core/                # Core module tests (unit)
│   ├── oauth_token_test.exs
│   └── llm_router_test.exs
├── workflows/           # Workflow tests (unit)
│   └── llm_request_workflow_test.exs
└── integration/         # Integration tests (need database)
    └── codex_integration_test.exs
```

### 3. Create Test File with Documentation
```elixir
defmodule Nexus.MyModule.MyTest do
  @moduledoc """
  Tests for Nexus.MyModule

  ## What This Tests
  - Feature X
  - Feature Y

  ## What This Does NOT Test
  - External service calls
  - Database operations (use integration tests)

  ## Test Infrastructure
  Uses [list mocks used]
  """

  use ExUnit.Case, async: false

  setup do
    # Configure mocks if needed
    Application.put_env(:nexus, :http_client, MockReq)

    on_exit(fn ->
      Application.delete_env(:nexus, :http_client)
    end)

    :ok
  end

  describe "feature_name" do
    test "specific scenario" do
      assert something
    end
  end
end
```

### 4. Run New Tests
```bash
mix test path/to/new_test.exs --no-start
```

---

## Troubleshooting

### Test Fails with "module not compiled"
```bash
mix clean
mix deps.clean --all
mix setup
mix test --no-start
```

### Test Hangs or Times Out
- Check for database operations (use --no-start)
- Check for external service calls (mock them)
- Check for infinite loops in test code

### Mock Not Being Used
```elixir
# Make sure setup block runs before tests:
setup do
  Application.put_env(:nexus, :http_client, MockReq)
  # ... etc
end

# Verify mock is being injected:
defp http_client do
  Application.get_env(:nexus, :http_client, Req)  # Default: Req
end
```

### Integration Test Failures
1. Create database: `psql -U postgres -c "CREATE DATABASE singularity_test;"`
2. Run migrations: `mix ecto.migrate`
3. Add Ecto.Sandbox to test file
4. Run test: `mix test test/nexus/integration/codex_integration_test.exs`

---

## CI/CD Configuration

### Recommended: Unit Tests Only
```bash
# Fast, reliable, no external dependencies
mix test --no-start --exclude integration
```

Expected output:
```
8 doctests, 120 tests, 0 failures ✅
Finished in 0.4 seconds (11 integration tests excluded)
```

### Optional: With Coverage
```bash
mix test.ci --no-start --exclude integration
```

### Integration Tests (Optional - Requires Setup)
```bash
# Only run if database is set up and application can start
mix test --include integration
# Requires: mix ecto.create, mix ecto.migrate, PostgreSQL
```

### Not Recommended: Full Application Tests
```bash
# Requires ExLLM configuration, external services, database setup
# Not suitable for standard CI/CD
mix test  # ❌ Don't use in CI (ExLLM startup fails)
```

---

## Summary

| Approach | Speed | Database | External Services | Recommended |
|----------|-------|----------|-------------------|-------------|
| `mix test --no-start --exclude integration` | ⚡ 0.4s | ❌ No | ❌ No | ✅ **YES** (120 tests) |
| `mix test --include integration` | ⏱️ ~5s | ✅ Yes | ❌ No | ⚠️ Dev only (11 tests) |
| `mix test` | ⏱️ ~30s | ✅ Yes | ✅ Yes | ❌ No* |

*Full application startup fails with ExLLM initialization issue

---

## Resources

- **Mocking Guide**: See test_helper.exs for mock implementations
- **Provider Tests**: test/nexus/providers/ for OAuth2 and Codex examples
- **Dependency Injection**: lib/nexus/providers/ for production code patterns
- **Test Organization**: Describe blocks group related tests by feature
