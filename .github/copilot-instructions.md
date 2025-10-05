# GitHub Copilot Setup Instructions

## Project Languages

This is a **polyglot codebase** using:
- **Elixir** (primary) - Main application in `singularity_app/`
- **Gleam** - BEAM-native functional language, compiles with Elixir
- **Rust** - High-performance tools in `rust/` (tool_doc_index, db_service)
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

- **Rust**: Latest stable with cargo, rust-analyzer, cargo-watch, cargo-nextest, etc.
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
- `rust/tool_doc_index/` - Technology detection
- `rust/db_service/` - Database gateway (archived)
- `rust/prompt_engine/` - ML-based prompt optimization

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
# Technology detector
cd rust/tool_doc_index
cargo run -- detect /path/to/project

# Database service (NATS → PostgreSQL gateway)
cd rust/db_service
cargo run
```

### Run Tests

```bash
# Elixir tests
cd singularity_app && mix test

# Rust tests
cd rust/tool_doc_index && cargo test
cd rust/db_service && cargo test
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
┌──────────┐         ┌──────────────┐
│ db_service│         │  ai-server   │
│ (Rust)    │         │  (Bun/TS)    │
│ PostgreSQL│         │  Claude API  │
└──────────┘         └──────────────┘
   ▲                          ▲
   │                          │
   └──────────┬───────────────┘
              │
     ┌────────┴─────────┐
     │                  │
┌────────────┐  ┌──────────────┐
│ tool_doc_  │  │ singularity_ │
│ index      │  │ app          │
│ (Rust)     │  │ (Elixir)     │
│ Detection  │  │ Orchestrator │
└────────────┘  └──────────────┘
```

**Key Principle**: All database access goes through `db_service` via NATS. No direct PostgreSQL connections.

## Nix Benefits

✅ **Reproducible**: Same environment on all machines
✅ **Isolated**: Dependencies don't conflict with system packages
✅ **Fast**: Unified caching (sccache for Rust, bun cache)
✅ **Declarative**: All dependencies in `flake.nix`
✅ **Automated**: PostgreSQL + NATS start automatically

## VS Code / Cursor Integration

If using VS Code/Cursor, ensure direnv VSCode extension is installed:

```bash
code --install-extension mkhl.direnv
```

This will automatically load the Nix environment in the integrated terminal.

## Further Reading

- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [direnv](https://direnv.net/)
- [NATS Architecture](./NATS_SUBJECTS.md)
- [Testing Guide](./TEST_GUIDE.md)
- [E2E Tests](./E2E_TEST.md)
