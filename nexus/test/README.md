# Nexus Test Suite

This directory contains comprehensive tests for the Nexus application, organized following Elixir best practices.

## Test Organization

### Core Modules (`test/nexus/core/`)
Tests for fundamental Nexus modules that provide core functionality:

- **`application_test.exs`** - OTP application startup and configuration
- **`repo_test.exs`** - Ecto repository configuration and database operations
- **`llm_router_test.exs`** - LLM request routing and model selection
- **`oauth_token_test.exs`** - OAuth token storage and management
- **`codex_token_store_test.exs`** - PostgreSQL-backed token storage with file fallback
- **`queue_consumer_test.exs`** - pgmq message processing and queue operations

### Provider Modules (`test/nexus/providers/`)
Tests for AI provider integrations:

- **`codex_test.exs`** - ChatGPT Pro OAuth2 integration
- **`claude_code/oauth2_test.exs`** - Claude Code OAuth2 flow (existing)

### Workflow Modules (`test/nexus/workflows/`)
Tests for workflow execution:

- **`llm_request_workflow_test.exs`** - ex_quantum_flow workflow execution

### Integration Tests (`test/nexus/integration/`)
End-to-end workflow tests:

- **`end_to_end_test.exs`** - Complete workflow integration tests

### Legacy Tests
- **`id_test.exs`** - UUID generation and validation
- **`nexus_test.exs`** - Basic module functionality

## Test Structure

Each test file follows this structure:

```elixir
defmodule ModuleNameTest do
  @moduledoc """
  Brief description of what this module tests.
  
  More detailed explanation of test coverage and approach.
  """

  use ExUnit.Case, async: true  # or false for integration tests

  alias Module.Under.Test

  describe "function_group/arity" do
    test "descriptive test name" do
      # Test implementation
    end
  end
end
```

## Test Categories

### Unit Tests
- Test individual functions in isolation
- Use `async: true` for parallel execution
- Mock external dependencies
- Focus on specific functionality

### Integration Tests
- Test module interactions
- Use `async: false` for sequential execution
- May require test database setup
- Test complete workflows

### End-to-End Tests
- Test complete user workflows
- Require full system setup
- Test external integrations
- Verify system behavior

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/nexus/core/llm_router_test.exs

# Run tests with coverage
mix test --cover

# Run tests in specific directory
mix test test/nexus/core/

# Run integration tests only
mix test test/nexus/integration/
```

## Test Coverage

The test suite aims for 100% coverage of all `nexus.*` modules:

- ✅ **Nexus.Application** - Application startup and configuration
- ✅ **Nexus.Repo** - Database repository operations
- ✅ **Nexus.LLMRouter** - LLM request routing and model selection
- ✅ **Nexus.OAuthToken** - OAuth token storage and management
- ✅ **Nexus.CodexTokenStore** - Token storage with fallback
- ✅ **Nexus.QueueConsumer** - Queue message processing
- ✅ **Nexus.WorkflowWorker** - Workflow execution (via integration tests)
- ✅ **Nexus.Providers.Codex** - ChatGPT Pro integration
- ✅ **Nexus.Providers.Codex.OAuth2** - Codex OAuth2 flow
- ✅ **Nexus.Providers.ClaudeCode.OAuth2** - Claude Code OAuth2 flow
- ✅ **Nexus.Workflows.LLMRequestWorkflow** - Workflow step execution
- ✅ **Nexus.ID** - UUID generation and validation

## Test Dependencies

Some tests require external dependencies:

- **Database** - PostgreSQL with pgmq extension
- **OAuth Providers** - ChatGPT Pro, Claude Code (for integration tests)
- **LLM Providers** - ExLLM with various providers (for integration tests)

## Mocking Strategy

For tests that require external services:

1. **Unit Tests** - Mock all external dependencies
2. **Integration Tests** - Use test doubles or sandboxed services
3. **End-to-End Tests** - Use real services in test environment

## Best Practices

1. **Descriptive Test Names** - Test names should clearly describe what is being tested
2. **Single Responsibility** - Each test should test one specific behavior
3. **Arrange-Act-Assert** - Structure tests with clear setup, execution, and verification
4. **Independent Tests** - Tests should not depend on each other
5. **Fast Tests** - Unit tests should run quickly and in parallel
6. **Clear Documentation** - Use `@moduledoc` and `describe` blocks for organization

## Future Improvements

- Add property-based testing for complex data structures
- Implement test data factories for consistent test data
- Add performance tests for critical paths
- Implement contract testing for external APIs
- Add mutation testing to verify test quality
