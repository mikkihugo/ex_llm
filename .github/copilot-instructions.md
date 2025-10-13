# GitHub Copilot Setup Instructions

## Project Overview

**Singularity** is an internal AI-powered development environment featuring:
- **Autonomous agents** for self-improving code workflows
- **Multi-AI orchestration** (Claude, Gemini, OpenAI, Copilot) via NATS
- **Semantic code search** with GPU acceleration (RTX 4080)
- **Living knowledge base** with Git ↔ PostgreSQL synchronization
- **NATS-first microservices architecture** for inter-service communication

**Development Philosophy**: Internal tooling prioritizing features & learning over production constraints. Maximum experimentation, rapid iteration.

**Key Architectural Principle**: NATS-first microservices with direct PostgreSQL access via Ecto (Elixir) or async-postgres (Rust services).

## Project Languages

This is a **polyglot codebase** using:
- **Elixir** (primary) - Main application in `singularity_app/`
- **Gleam** - BEAM-native functional language, compiles with Elixir
- **Rust** - High-performance NIFs and services in `rust/` (architecture_engine, code_engine, parser_engine, etc.)
- **TypeScript** - AI server in `ai-server/`

This repository uses **Nix** + **direnv** for reproducible development environments.

## Prerequisites

Before opening this project, ensure you have:

1. **Nix** (with flakes enabled)
2. **direnv**
3. **WSL2** (if on Windows, for GPU access)

## Setup Steps

### 1. Install Nix (if not installed)

```bash
# Install Nix with flakes enabled (Determinate Systems installer)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. Install direnv

```bash
# On Ubuntu/Debian (WSL2)
sudo apt install direnv

# On macOS
brew install direnv

# Add to your shell (~/.bashrc or ~/.zshrc)
eval "$(direnv hook bash)"  # or zsh
```

### 3. Enter Development Environment

```bash
cd /path/to/singularity
direnv allow  # Approve .envrc
```

This will:
- Build the Nix development shell
- Install all dependencies (Rust, Elixir, Gleam, Bun, PostgreSQL, NATS, etc.)
- Start PostgreSQL automatically (port 5432 by default)
- Start NATS with JetStream (port 4222)
- Set up unified caching for fast builds

### 4. Verify Setup

```bash
# Check tools are available
rustc --version
elixir --version
gleam --version
bun --version
psql --version
nats-server --version

# Check database is running
psql -d postgres -c "SELECT 1;"

# Check NATS is running
nats-server --version && pgrep -x nats-server
```

## Environment Details

### Tools Available

- **Rust**: Latest stable with cargo, rust-analyzer, and cargo-watch (additional cargo tools can be installed on-demand)
- **BEAM**: Elixir 1.18-rc + Gleam support, Erlang 28
- **Database**: PostgreSQL 17 with TimescaleDB, PostGIS, pgvector
- **Message Bus**: NATS with JetStream
- **JavaScript**: Bun (fast TypeScript/JavaScript runtime)
- **AI CLIs**: `claude`, `gemini`, `copilot`, `codex` (via bunx shims)

## Language-Specific Guidelines

### Elixir Code (`singularity_app/`)

**File locations**:
- Main app: `singularity_app/lib/singularity/`
- Tests: `singularity_app/test/`
- Migrations: `singularity_app/priv/repo/migrations/`

**Conventions**:
- Use `snake_case` for files and functions
- Use `PascalCase` for modules
- Prefer GenServer/Agent for state management
- Use `with` for error handling chains
- Document with `@moduledoc` and `@doc`

**Example**:
```elixir
defmodule Singularity.MyModule do
  @moduledoc """
  Description of module purpose.
  """

  use GenServer

  @doc """
  Starts the server.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
```

### Gleam Code

**Integration**: Gleam code compiles to BEAM bytecode and runs alongside Elixir.

**Conventions**:
- Use `snake_case` for all identifiers
- Prefer pattern matching over conditionals
- Use `Result` and `Option` types
- Document with `///` comments

**Example**:
```gleam
import gleam/result

pub fn process_data(input: String) -> Result(String, String) {
  case input {
    "" -> Error("Empty input")
    value -> Ok(value)
  }
}
```

### Rust Code (`rust/`)

**File locations**:
- `rust/architecture_engine/` - Architecture analysis and intelligent naming
- `rust/code_engine/` - Code quality analysis and metrics
- `rust/parser_engine/` - Multi-language parsing (30+ languages)
- `rust/embedding_engine/` - GPU-accelerated embeddings (Jina v3, Qodo)
- `rust/prompt_engine/` - DSPy prompt optimization
- `rust/quality_engine/` - Quality checks and standards
- `rust/architecture_engine/package_registry/` - External package analysis (npm, cargo, hex, pypi)

**Conventions**:
- Use `snake_case` for files and functions
- Use `PascalCase` for types/structs
- Prefer `Result` and `Option`
- Document with `///` (doc comments)
- Follow https://rust-lang.github.io/api-guidelines/

**Example**:
```rust
/// Analyzes code for technology patterns.
pub struct TechnologyDetector {
    patterns: Vec<Pattern>,
}

impl TechnologyDetector {
    /// Creates a new detector with default patterns.
    pub fn new() -> Result<Self, Error> {
        Ok(Self { patterns: vec![] })
    }
}
```

### TypeScript Code (`ai-server/`)

**File locations**:
- Source: `ai-server/src/`
- Tests: `ai-server/src/*.test.ts`

**Conventions**:
- Use `camelCase` for variables and functions
- Use `PascalCase` for types/interfaces
- Prefer `async/await` over callbacks
- Use Bun-specific APIs when available
- Document with JSDoc `/** */`

**Example**:
```typescript
/**
 * Handles AI provider requests.
 */
export async function handleRequest(
  provider: string,
  request: ChatRequest
): Promise<ChatResponse> {
  // Implementation
}
```

### Key Environment Variables

Automatically set by `.envrc`:

```bash
DATABASE_URL="postgres://localhost:5432/postgres"
NATS_URL="nats://localhost:4222"
MIX_ENV="dev"
CARGO_HOME="$HOME/.cache/singularity/cargo"
SCCACHE_DIR="$HOME/.cache/singularity/sccache"
```

### Database Setup

PostgreSQL starts automatically with these databases:
- `postgres` (default)
- `singularity_dev` (development)
- `singularity_test` (testing)
- `singularity_embeddings` (vector search)

Extensions enabled:
- `vector` (pgvector for embeddings)
- `timescaledb` (time-series data)
- `postgis` (geospatial)

### NATS Setup

NATS JetStream runs automatically on port 4222. Data stored in `.nats/`.

## Common Tasks

### Run Elixir App

```bash
cd singularity_app
mix deps.get
mix phx.server
```

### Run AI Server (Bun)

```bash
cd ai-server
bun install
bun run src/server.ts
```

### Run Rust Tools

```bash
# Package registry analysis
cd rust/architecture_engine/package_registry
cargo run -- analyze /path/to/project

# Run all Rust tests
cd rust
cargo test
```

### Run Tests

```bash
# Elixir tests
cd singularity_app && mix test

# Rust tests
cd rust && cargo test
```

### Task Runner (Justfile)

```bash
just help           # Show available commands
just test           # Run all tests
just dev            # Start dev servers
just db-reset       # Reset database
```

## GPU Support (WSL2 + RTX 4080)

CUDA is available for EXLA (ML workloads):

```bash
export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
export EXLA_TARGET="cuda"
```

Verify GPU access:
```bash
nvidia-smi  # Should show RTX 4080
```

## Troubleshooting

### `direnv allow` fails

```bash
# Reload direnv
direnv reload

# Debug mode
direnv allow --verbose
```

### PostgreSQL won't start

```bash
# Check logs
cat .dev-db/pg/postgres.log

# Stop and restart
pg_ctl -D .dev-db/pg stop
direnv reload
```

### NATS not running

```bash
# Start manually
nats-server -js -sd .nats -p 4222
```

### Build cache issues

```bash
# Clear Rust cache
rm -rf .cargo-build

# Clear sccache
sccache --stop-server
rm -rf ~/.cache/singularity/sccache
```

## Architecture Overview

This is a **NATS-first microservices architecture**:

```
┌─────────────────────────────────────────┐
│ NATS (Message Bus)                      │
└──────┬──────────────────────────────────┘
       │
   ┌───┴──────────────────────┐
   │                          │
   ▼                          ▼
┌──────────────┐     ┌──────────────┐
│  ai-server   │     │ central_cloud│
│  (Bun/TS)    │     │  (Elixir)    │
│  LLM APIs    │     │  3 Services  │
└──────────────┘     └──────┬───────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       ┌──────────────┐          ┌──────────────┐
       │ singularity_ │          │  PostgreSQL  │
       │ app          │          │  (Direct)    │
       │ (Elixir)     │          │  + pgvector  │
       │ 6 Rust NIFs  │          └──────────────┘
       └──────────────┘
```

**Key Principles**:
- **NATS-first**: Services communicate via NATS message bus
- **Direct DB Access**: Each service connects to PostgreSQL directly (Ecto for Elixir, async-postgres for Rust)
- **6 Rust NIFs**: Loaded into Singularity BEAM VM for high-performance operations
  1. parser_engine - Multi-language parsing (30+ languages)
  2. code_engine - Code quality analysis
  3. architecture_engine - Architecture analysis + intelligent naming
  4. quality_engine - Quality checks and standards
  5. embedding_engine - GPU-accelerated embeddings (Jina v3, Qodo)
  6. prompt_engine - DSPy prompt optimization + ML training

## Nix Benefits

✅ **Reproducible**: Same environment on all machines
✅ **Isolated**: Dependencies don't conflict with system packages
✅ **Fast**: Unified caching (sccache for Rust, bun cache)
✅ **Declarative**: All dependencies in `flake.nix`
✅ **Automated**: PostgreSQL + NATS start automatically

## VSCode / Cursor Integration

If using VSCode/Cursor, ensure direnv VSCode extension is installed:

```bash
code --install-extension mkhl.direnv
```

This will automatically load the Nix environment in the integrated terminal.

## Development Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes incrementally**
   - Write code in small, focused commits
   - Test each change before moving to the next
   - Use `just dev` to run all services during development

3. **Run tests frequently**
   ```bash
   # Elixir tests (fast feedback)
   cd singularity_app && mix test
   
   # Rust tests (for Rust changes)
   cd rust/tool_doc_index && cargo test
   
   # Full test suite
   just test
   ```

4. **Commit with clear messages**
   ```bash
   git add -p  # Review changes interactively
   git commit -m "feat: Add new detection pattern for Vue.js"
   ```

### Adding New Features

#### Adding a New Technology Detector
1. Create JSON template in `rust/architecture_engine/package_registry/templates/`
2. Add detection patterns (file extensions, package names, etc.)
3. Test with `cargo run -- analyze /path/to/sample/project`
4. Add integration test in Elixir

#### Adding a New NATS Subject
1. Document in `NATS_SUBJECTS.md`
2. Add handler in appropriate service
3. Add request/reply or pub/sub pattern
4. Test with `nats sub "your.subject"`

#### Adding a New LLM Provider
1. Create provider module in `ai-server/src/providers/`
2. Implement standard interface (chat, completion)
3. Add to `ai-server/src/server.ts` routing
4. Document authentication in `tools/deploy-credentials.md`

## Testing Strategy

### Test Pyramid

```
        /\
       /  \    E2E Tests (5-10%)
      /____\   - Full system integration
     /      \  Integration Tests (20-30%)
    /        \ - Service-to-service via NATS
   /__________\ Unit Tests (60-70%)
              - Pure functions, modules
```

### Running Tests

**Unit Tests** (fast, run often):
```bash
# Elixir
cd singularity_app && mix test

# Rust
cd rust && cargo test --lib

# TypeScript
cd ai-server && bun test
```

**Integration Tests** (medium speed):
```bash
# Requires NATS + PostgreSQL running
cd singularity_app && mix test --only integration

# Rust integration tests
cd rust && cargo test --test '*'
```

**E2E Tests** (slow, run before commits):
```bash
# Full system test
just test

# Or run specific E2E test
elixir test-unified-system.exs
```

### Writing Good Tests

**Do:**
- ✅ Test business logic thoroughly
- ✅ Mock external dependencies (LLM APIs, external services)
- ✅ Use descriptive test names: `test "detects React from package.json"`
- ✅ Use factories/fixtures for test data
- ✅ Clean up resources (database, NATS subscriptions) after tests

**Don't:**
- ❌ Test implementation details
- ❌ Make real API calls to LLM providers in tests
- ❌ Share state between tests
- ❌ Write tests that depend on execution order
- ❌ Commit tests that are flaky or slow

### Test Coverage Goals

- **New features**: ≥80% coverage
- **Bug fixes**: Add regression test
- **Refactoring**: Maintain or improve coverage

## Common Pitfalls

### NATS Connection Issues

**Problem**: `nats: connection refused`
```
Error: Failed to connect to NATS at localhost:4222
```

**Solution**:
```bash
# Check if NATS is running
pgrep -x nats-server

# If not, start it
nats-server -js -sd .nats -p 4222

# Or use direnv (auto-starts)
direnv allow
```

### PostgreSQL Not Starting

**Problem**: Database connection errors
```
Error: could not connect to server: Connection refused
```

**Solution**:
```bash
# Check PostgreSQL status
pg_ctl status -D .dev-db/pg

# Check logs
tail -f .dev-db/pg/postgres.log

# Clean restart
pg_ctl stop -D .dev-db/pg
rm -rf .dev-db/pg/postmaster.pid
direnv reload
```

### Rust Build Failures

**Problem**: `cargo build` fails with linking errors

**Solution**:
```bash
# Clear build cache
rm -rf target/
cargo clean

# For sccache issues
sccache --stop-server
rm -rf ~/.cache/singularity/sccache
cargo build
```

### Elixir Dependency Issues

**Problem**: `mix deps.get` fails or deps are outdated

**Solution**:
```bash
cd singularity_app

# Clear deps
rm -rf deps _build

# Fetch fresh
mix local.hex --force
mix local.rebar --force
mix deps.get
mix deps.compile

# For Gleam deps
mix gleam.deps.get
```

### Nix Environment Not Loading

**Problem**: Commands not found after `direnv allow`

**Solution**:
```bash
# Reload direnv
direnv reload

# If still broken, rebuild
nix flake update
direnv allow

# Check what's loaded
which elixir gleam cargo
```

### NATS Subject Naming

**Problem**: Messages not routing correctly

**Pitfall**: Using wrong subject naming conventions
```bash
# ❌ Wrong
"database-query"

# ✅ Correct
"db.query"
```

**Solution**: Always use dot-separated hierarchical names. See `NATS_SUBJECTS.md`.

### Database Access Patterns

**Best Practice**: Use Ecto for database access in Elixir services

**Correct approach**:
```elixir
# ✅ Use Ecto queries
Repo.all(User)
Repo.get(User, id)

# ✅ Or Ecto.Query
import Ecto.Query
from(u in User, where: u.active == true) |> Repo.all()
```

**For Rust services**: Use async-postgres or SQLx with connection pooling

### GPU Memory Issues (WSL2)

**Problem**: CUDA out of memory errors

**Solution**:
```bash
# Check GPU memory
nvidia-smi

# If fragmented, restart WSL
wsl --shutdown
wsl
```

## Code Review Guidelines

### What to Look For

**Architecture**:
- ✅ Follows NATS-first principle for service communication
- ✅ Uses Ecto/async-postgres for database access
- ✅ Services are stateless where possible
- ✅ Proper error handling and logging

**Code Quality**:
- ✅ Follows language conventions (see sections above)
- ✅ Has tests for new functionality
- ✅ Documentation for public APIs
- ✅ No hardcoded secrets or credentials

**Performance**:
- ✅ Efficient database queries (use indexes)
- ✅ Async operations for I/O
- ✅ Proper caching strategies
- ✅ Resource cleanup (connections, subscriptions)

### Approval Criteria

- [ ] All tests pass (`just test`)
- [ ] Code follows language conventions
- [ ] Changes are documented
- [ ] No security issues (secrets, SQL injection, etc.)
- [ ] Performance impact is acceptable

## Further Reading

### Project Documentation
- [Repository README](../README.md) - Project overview and quick start
- [NATS Subjects](../NATS_SUBJECTS.md) - Message bus subject conventions
- [Architecture Clarification](../ARCHITECTURE_CLARIFICATION.md) - System architecture details
- [Knowledge Routing Guide](../KNOWLEDGE_ROUTING_GUIDE.md) - How data flows through the system

### External Resources
- [Nix Flakes](https://nixos.wiki/wiki/Flakes) - Reproducible development environments
- [direnv](https://direnv.net/) - Per-directory environment variables
- [NATS Documentation](https://docs.nats.io/) - Message bus documentation
- [Elixir Guides](https://hexdocs.pm/elixir/) - Elixir language reference
- [Gleam Language](https://gleam.run/) - Gleam documentation
- [Rust Book](https://doc.rust-lang.org/book/) - The Rust Programming Language
