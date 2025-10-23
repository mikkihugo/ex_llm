---
name: generate-tests
description: Analyzes code and generates comprehensive test scaffolds in ExUnit (Elixir) or equivalent. Identifies untested code paths and suggests test patterns.
---

# Generate Test Scaffolds Skill

Automatically analyzes code and generates test stubs for untested paths.

## Scope

This skill runs when you:
- Need comprehensive test coverage
- Want to increase ExUnit test count
- Need test scaffolds for critical modules
- Want to identify untested code paths

## What It Does

For each Elixir module:
1. Identifies public functions
2. Checks for existing ExUnit tests
3. Analyzes function signatures and complexity
4. Identifies critical paths and edge cases
5. Generates test scaffolds with:
   - Setup/teardown
   - Happy path tests
   - Error condition tests
   - Edge case tests
   - Async tests where needed

For Rust code:
- Identifies unit test opportunities
- Suggests integration test patterns
- Generates test scaffolds in Rust test format

## Test Patterns

Generated tests include:
- **Happy path** - Normal operation
- **Error cases** - Invalid inputs, failures
- **Edge cases** - Boundaries, empty inputs
- **Async tests** - For GenServers, Tasks
- **Integration tests** - NATS messaging, Ecto
- **Mock patterns** - For external dependencies (NATS, Repo)

## Output

Returns test scaffolds ready to:
1. Fill in actual assertions
2. Update mocks as needed
3. Run with `mix test`

## When to Use

- Increasing test coverage
- Before refactoring code
- For critical modules (Agent, NatsClient, LLM.Service)
- Preparing for production deployment
