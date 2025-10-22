# Testing Guide - Singularity

## Quick Start

### Prerequisites

**Nix automatically starts all required services:**
```bash
nix develop
# ✅ Starts PostgreSQL with pgvector
# ✅ Starts NATS server with JetStream (port 4222)
# ✅ Starts Singularity Phoenix server (port 4000)
# ✅ Provides all tools (Elixir, Rust, etc.)
```

**See AUTO_START_GUIDE.md for details on auto-start behavior, logs, and troubleshooting.**

### Run All Tests

```bash
cd singularity

# All tests (existing + new integration tests)
mix test

# Only integration tests (new in this PR)
mix test --only integration

# Specific test file
mix test test/singularity/nats_integration_test.exs
```

### Run With Coverage

```bash
# HTML coverage report
mix coveralls.html

# View in browser
open cover/excoveralls.html

# CI-style (with color output)
mix test.ci
```

## New Integration Tests (2025-10-13)

### 1. NATS Integration Tests
**File:** `test/singularity/nats_integration_test.exs`
**Tests:** 20+
**Coverage:**
- Request/response flows
- Pub/sub patterns
- LLM request integration
- Error handling & timeouts
- Large message handling (1MB+)

```bash
mix test test/singularity/nats_integration_test.exs
```

**Example test:**
```elixir
test "successful round-trip message" do
  test_subject = "test.echo.#{System.unique_integer([:positive])}"

  {:ok, subscription} = NatsClient.subscribe(test_subject, fn message ->
    NatsClient.publish(message.reply_to, message.body)
  end)

  {:ok, response} = NatsClient.request(test_subject, "test", timeout: 1000)

  assert response.body == "test"
end
```

### 2. Agent Lifecycle Tests
**File:** `test/singularity/agents/agent_lifecycle_test.exs`
**Tests:** 25+
**Coverage:**
- Agent spawning & concurrency
- Task execution & metrics
- Supervisor restart behavior
- State management & isolation
- Performance (50 agents, 100 tasks, 5+ tasks/sec)

```bash
mix test test/singularity/agents/agent_lifecycle_test.exs
```

**Example test:**
```elixir
test "spawning multiple agents concurrently" do
  tasks = for i <- 1..10 do
    Task.async(fn ->
      AgentSupervisor.start_agent(CostOptimizedAgent, id: "concurrent-#{i}")
    end)
  end

  results = Task.await_many(tasks, 5000)
  assert Enum.all?(results, fn {:ok, pid} -> Process.alive?(pid) end)
end
```

### 3. Semantic Search Integration Tests
**File:** `test/singularity/knowledge/semantic_search_integration_test.exs`
**Tests:** 20+
**Coverage:**
- Full-stack semantic search
- Embedding generation (768-dimensional)
- Usage tracking & learning
- Performance (500 artifacts, < 500ms)
- Concurrency (20 simultaneous operations)

```bash
mix test test/singularity/knowledge/semantic_search_integration_test.exs
```

**Example test:**
```elixir
test "searches artifacts by semantic similarity" do
  {:ok, results} = ArtifactStore.search("asynchronous task execution", top_k: 5)

  assert length(results) > 0
  Enum.each(results, fn result ->
    assert result.similarity >= 0.0 and result.similarity <= 1.0
  end)
end
```

## Test Organization

```
test/
├── singularity/
│   ├── nats_integration_test.exs           # ⭐ New: NATS flows
│   ├── agents/
│   │   ├── agent_lifecycle_test.exs        # ⭐ New: Agent lifecycle
│   │   └── cost_optimized_agent_test.exs   # Existing
│   └── knowledge/
│       └── semantic_search_integration_test.exs  # ⭐ New: Search
└── test_helper.exs
```

## Test Tags

All integration tests are tagged:
```elixir
@moduletag :integration
```

**Run only unit tests:**
```bash
mix test --exclude integration
```

**Run only integration tests:**
```bash
mix test --only integration
```

## Coverage Goals

| Component | Before | After | Change |
|-----------|--------|-------|--------|
| Total Tests | 23 | ~90 | +65 tests |
| NATS | Minimal | 20+ tests | ⭐ New |
| Agents | Unit only | 48+ tests | ⭐ +25 |
| Semantic Search | None | 20+ tests | ⭐ New |

## Troubleshooting

### NATS Connection Error

**Error:**
```
** (EXIT) :econnrefused
```

**Solution:**
Check NATS is running:
```bash
pgrep nats-server  # Should return PID
ps aux | grep nats-server

# If not running, start manually:
nats-server -js -p 4222
```

In Nix shell, it should auto-start. If not:
```bash
exit  # Exit Nix shell
nix develop  # Re-enter to trigger startup
```

### Database Connection Error

**Error:**
```
** (Postgrex.Error) FATAL 3D000 (invalid_catalog_name) database "singularity_test" does not exist
```

**Solution:**
```bash
cd singularity
mix ecto.create
mix ecto.migrate
```

### Rust NIF Not Loaded

**Error:**
```
undefined function Singularity.CodeEngine.analyze_file/1
```

**Solution:**
```bash
cd singularity
mix compile --force  # Recompile NIFs
```

## Performance Benchmarks

From integration tests:

**Agent Performance:**
- Spawn 50 agents: < 5 seconds
- Execute 100 tasks: > 5 tasks/second throughput

**Semantic Search:**
- Bulk insert 100 artifacts: < 10 seconds
- Search 500 artifacts: < 500ms

**NATS Messaging:**
- Large messages (1MB+): Handled successfully
- Concurrent operations (20x): All succeed

## CI/CD Integration

Add to GitHub Actions:

```yaml
- name: Run Integration Tests
  run: |
    nix develop --command bash -c "
      cd singularity &&
      mix test --only integration &&
      mix coveralls.github
    "
  env:
    MIX_ENV: test
```

## Additional Resources

- **Implementation Summary:** `IMPLEMENTATION_SUMMARY.md`
- **Codebase Analysis:** `codebase_analysis.md`
- **NATS Subjects:** `docs/messaging/NATS_SUBJECTS.md`
- **Agent Documentation:** `AGENTS.md`

---

**Last Updated:** 2025-10-13
**Test Count:** ~90 tests (+65 integration tests)
**Status:** ✅ Ready for execution in Nix dev shell
