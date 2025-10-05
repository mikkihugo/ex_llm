# Coding Standards - Singularity

> Extracted from GitHub Copilot instructions - coding guidelines for Elixir, Gleam, and Rust

## Project Overview

The Singularity project is a polyglot BEAM-based application with:
- **Elixir 1.20-dev** with native Gleam support (custom build)
- **Gleam** for functional BEAM components
- **Rust** for performance-critical tooling and analysis
- **Phoenix** web framework
- **PostgreSQL 17** with pgvector for embeddings
- **NATS** for distributed messaging

## Language-Specific Guidelines

### Elixir

**Version**: Elixir 1.20-dev (custom build with Gleam support)
**OTP**: 28

**Code Style**:
- Use `mix format` for formatting (configured in `.formatter.exs`)
- Follow Elixir naming conventions (snake_case for functions, PascalCase for modules)
- Prefer pattern matching over conditionals
- Use `with` for chaining operations that may fail
- Leverage Phoenix contexts for domain organization

**Key Patterns**:
```elixir
# Use pattern matching in function heads
def process({:ok, data}), do: transform(data)
def process({:error, reason}), do: handle_error(reason)

# Prefer with over nested case statements
with {:ok, user} <- fetch_user(id),
     {:ok, posts} <- fetch_posts(user),
     {:ok, result} <- process_posts(posts) do
  {:ok, result}
end

# Use guards for type checking
def add(a, b) when is_number(a) and is_number(b), do: a + b
```

**Testing**:
- Use ExUnit for testing
- Run tests with `mix test` or `just test-run`
- Follow existing test patterns in `singularity_app/test/`

### Gleam

**Version**: 1.5+

**Code Style**:
- Use `gleam format` for formatting
- Leverage Gleam's type system - avoid `Dynamic` types when possible
- Use Result types for error handling
- Prefer immutability and pure functions

**Key Patterns**:
```gleam
// Use Result for error handling
pub fn parse_user(json: String) -> Result(User, String) {
  case json.decode(json, user_decoder()) {
    Ok(user) -> Ok(user)
    Error(_) -> Error("Invalid user JSON")
  }
}

// Pattern matching with case
pub fn handle_response(result: Result(String, Error)) -> String {
  case result {
    Ok(data) -> data
    Error(err) -> error_to_string(err)
  }
}

// Use pipe operator for clarity
pub fn process_data(input: String) -> String {
  input
  |> string.trim
  |> string.lowercase
  |> string.replace(" ", "_")
}
```

**Integration with Elixir**:
- Gleam modules compile to Erlang bytecode
- Can be called from Elixir using `@external_resource` or directly as Erlang modules
- Use `gleam_stdlib` for common operations

### Rust

**Version**: Latest stable (1.75+)

**Code Style**:
- Use `rustfmt` for formatting (configured in `rustfmt.toml`)
- Follow Rust API guidelines
- Prefer explicit error types over panics
- Use `anyhow` for application errors, `thiserror` for library errors
- Leverage zero-cost abstractions

**Key Patterns**:
```rust
// Use Result for error handling
pub fn fetch_data(id: u64) -> Result<Data, Error> {
    let conn = establish_connection()?;
    conn.query_row("SELECT * FROM data WHERE id = ?", [id])
        .map_err(|e| Error::Database(e))
}

// Prefer iterators over loops
let sum: i32 = values.iter()
    .filter(|&&x| x > 0)
    .map(|&x| x * 2)
    .sum();

// Use pattern matching for clarity
match result {
    Ok(data) => process(data),
    Err(Error::NotFound) => create_new(),
    Err(e) => return Err(e),
}
```

**Async Patterns**:
- Use `tokio` for async runtime
- Prefer `async/await` over manual futures
- Use `Arc<Mutex<T>>` or channels for shared state

## Architecture Patterns

### Messaging & Persistence

- **Database access**: handled directly via Ecto (`Singularity.Repo`) using the consolidated migrations from 2024-01-01.
- **Messaging**: NATS is reserved for cross-service coordination (`llm.analyze`, `packages.registry.*`, execution events, tool federation).
- **Subjects**: consult `NATS_SUBJECTS.md` for the authoritative subject hierarchy.

```elixir
# Trigger the LLM bridge – response is delivered over NATS
:ok = Singularity.PlatformIntegration.NatsConnector.request(
  "llm.analyze",
  %{model: "claude-3-5-sonnet-20241022", messages: [%{role: "user", content: prompt}]}
)

# Persist technology snapshots via Ecto
attrs = %{codebase_id: "core", snapshot_id: 1, summary: %{}, detected_technologies: []}
%Singularity.Schemas.CodebaseSnapshot{}
|> Singularity.Schemas.CodebaseSnapshot.changeset(attrs)
|> Singularity.Repo.insert(on_conflict: :replace_all_except_primary_key)
```

### Layered Detection System

**5-level technology detection**:
1. **File Detection** (0-0.6 confidence) - Check for marker files
2. **Pattern Detection** (fast) - Regex patterns in code
3. **AST Detection** (slower) - Parse code structure
4. **Facts Detection** - Query knowledge base
5. **LLM Detection** (only if confidence < 0.7) - AI analysis via NATS

Early exit when confidence >= 0.85 to minimize cost.

## Testing Standards

### Elixir Tests
- Use ExUnit
- Maintain 85% coverage for baseline releases
- Mock external services (NATS, databases)
- Use `ExMachina` for factories

```elixir
defmodule Singularity.TechnologyDetectorTest do
  use ExUnit.Case, async: true

  test "detects Rust from Cargo.toml" do
    result = TechnologyDetector.detect_technologies("path/with/Cargo.toml")
    assert Enum.any?(result.technologies, &(&1.id == "rust"))
  end
end
```

### Rust Tests
- Use `cargo test`
- Integration tests in `tests/` directory
- Use `#[tokio::test]` for async tests
- Mock NATS with test subjects

```rust
#[tokio::test]
async fn test_detector_works_standalone() -> Result<()> {
    std::env::remove_var("NATS_URL"); // Standalone mode
    let detector = LayeredDetector::new().await?;
    let results = detector.detect(Path::new(".")).await?;
    assert!(results.iter().any(|r| r.technology_id == "rust"));
    Ok(())
}
```

## Git Workflow

### Commit Messages
- Follow conventional commits: `type(scope): description`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Include ticket references if applicable

```
feat(detection): add Python framework detection templates

- Add FastAPI detection template
- Add Django detection template
- Update UNIFIED_SCHEMA.json with Python patterns

Closes #123
```

### Branch Naming
- Feature branches: `feature/description`
- Bugfix branches: `fix/description`
- Copilot branches: `copilot/fix-{uuid}` (auto-generated)

## Code Review Checklist

- [ ] Code follows language-specific style guides
- [ ] Tests added/updated with adequate coverage
- [ ] Documentation updated (README, inline comments)
- [ ] No direct database access (use NATS)
- [ ] Error handling implemented (Result types)
- [ ] Linters pass (`mix format`, `cargo fmt`, `gleam format`)
- [ ] No secrets committed
- [ ] Performance considerations addressed

## Performance Guidelines

### Elixir
- Use GenServers for stateful processes
- Leverage ETS for caching
- Use Task.async for concurrent operations
- Profile with `:observer` and `:fprof`

### Rust
- Use `sccache` for compilation caching
- Prefer stack allocation over heap when possible
- Use `cargo flamegraph` for profiling
- Benchmark with `cargo bench` (criterion.rs)

### Database Queries
- Use indexes for frequently queried columns
- Batch inserts when possible
- Use prepared statements
- Monitor with pgvector's built-in stats

## Security Guidelines

- Never commit secrets (use `.env` with `.gitignore`)
- Use `age` for credential encryption (see `tools/deploy-credentials.md`)
- Validate all user input
- Use parameterized queries (prevent SQL injection)
- Keep dependencies up to date (`mix deps.update`, `cargo update`)
- Run security audits (`cargo audit`, `mix deps.audit`)

## References

- [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [Gleam Language Tour](https://tour.gleam.run/)
- [NATS Architecture](./NATS_SUBJECTS.md)
- [Testing Guide](./TEST_GUIDE.md)
