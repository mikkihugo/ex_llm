# Singularity Monorepo Structure

**Moon-based polyglot monorepo** with Elixir, Rust, TypeScript, and Gleam.

## Structure

```
singularity/
├─ .moon/
│  ├─ workspace.yml          # All projects registered
│  └─ toolchain.yml          # Shared tooling (rustc, mix, bun)
│
├─ apps/                     # Applications (runnable)
│  ├─ singularity_app/       # Main Elixir/Phoenix app
│  └─ ai-server/             # AI provider TypeScript server
│
├─ libs/                     # Libraries (reusable)
│  └─ rust/                  # Rust workspace
│     ├─ embedding_engine/   # GPU embeddings (Rustler NIF)
│     ├─ analysis_suite/     # Code analysis
│     ├─ universal_parser/   # Tree-sitter parser
│     ├─ tool_doc_index/     # Template indexer
│     ├─ prompt_engine/      # Prompt templates
│     └─ linting_engine/     # Multi-language linter
│
├─ packages/                 # Data/config packages
│  └─ templates_data/        # Code templates (synced to PostgreSQL)
│
├─ tools/                    # Developer tools
│  ├─ scripts/
│  └─ providers/
│
├─ docs/                     # Documentation
├─ bin/                      # Executable scripts
└─ nix/                      # Nix configuration
```

## Moon Projects

All projects registered in `.moon/workspace.yml`:

| Project | Type | Language | Description |
|---------|------|----------|-------------|
| `singularity_app` | application | elixir | Main Elixir app with Phoenix |
| `ai-server` | application | typescript | AI provider integration server |
| `rust` | library | rust | Rust workspace root |
| `rust/embedding_engine` | library | rust | Qodo-Embed-1 + Jina v3 NIF |
| `rust/analysis_suite` | library | rust | Code quality analysis |
| `rust/universal_parser` | library | rust | Multi-language parser |
| `rust/tool_doc_index` | library | rust | Template collector |
| `rust/prompt_engine` | library | rust | Prompt management |
| `rust/linting_engine` | library | rust | Linting engine |
| `templates_data` | library | data | Template repository |

## Dependencies

### Rust Workspace

All Rust crates share dependencies via `/rust/Cargo.toml`:

```toml
[workspace]
members = [
    "embedding_engine",
    "analysis_suite",
    "universal_parser",
    "tool_doc_index",
    "prompt_engine",
    "linting_engine",
]
```

**Benefits:**
- Shared `target/` directory
- Single `Cargo.lock`
- Unified dependency resolution
- Faster builds (cached across crates)

### Elixir (Future: Umbrella App)

Currently standalone, future: convert to umbrella:

```
singularity_app/
├─ apps/
│  ├─ singularity/       # Core app
│  ├─ singularity_web/   # Phoenix web
│  └─ singularity_api/   # API layer
└─ mix.exs               # Umbrella root
```

### TypeScript (Bun Workspace)

`package.json` can define workspace:

```json
{
  "workspaces": ["ai-server", "tools/*"]
}
```

## Build Artifacts

### Shared (Cached)
- `/shared/_build/` - Shared Elixir builds
- `/shared/deps/` - Shared Elixir deps
- `/shared/target/` - Shared Rust builds
- `/shared/node_modules/` - Shared Node deps

### Project-specific (Not shared)
- `singularity_app/_build/` - Dev builds
- `rust/target/` - Rust workspace target
- `ai-server/node_modules/` - If not using workspaces

## Moon Tasks

### Workspace-level

```bash
# Build everything
moon run :build

# Test everything
moon run :test

# Format all code
moon run :fmt

# Run quality checks (clippy, credo, etc.)
moon run :quality
```

### Project-level

```bash
# Build specific project
moon run rust/embedding_engine:build

# Test Rust crates
moon run rust:test

# Run Elixir app
moon run singularity_app:dev
```

## Removed Projects

- ❌ `litellm` - Removed (not used)

## Development Workflow

### 1. Install Dependencies

```bash
# Enter Nix shell (has all tools)
nix develop

# Install deps for all projects
moon run :install  # If moon has install tasks
```

### 2. Development

```bash
# Start services
./start-all.sh

# Or individually
moon run singularity_app:dev
moon run ai-server:dev
```

### 3. Testing

```bash
# All tests
moon run :test

# Specific project
moon run rust/embedding_engine:test
```

### 4. Building

```bash
# All projects
moon run :build

# Production build
MIX_ENV=prod moon run singularity_app:build
```

## CI/CD

Moon caches task outputs in `.moon/cache/`:

```yaml
# .github/workflows/ci.yml
- name: Cache moon
  uses: actions/cache@v3
  with:
    path: .moon/cache
    key: moon-${{ hashFiles('**/moon.yml') }}
```

## Migration Status

- [x] Removed litellm
- [x] Registered all Rust crates as moon projects
- [x] Registered templates_data as moon project
- [x] Created moon project configs for each crate
- [ ] Convert Elixir to umbrella app
- [ ] Set up shared build artifacts
- [ ] Add TypeScript workspace config
- [ ] Create unified CI/CD pipeline

## Best Practices

1. **Add new projects to `.moon/workspace.yml`**
2. **Create `.moon/project.yml` for each project**
3. **Use moon tasks for all build operations**
4. **Share dependencies via workspaces**
5. **Cache `.moon/cache` in CI**

## References

- [Moon Docs](https://moonrepo.dev/docs)
- [Cargo Workspaces](https://doc.rust-lang.org/book/ch14-03-cargo-workspaces.html)
- [Elixir Umbrella](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html)
- [Bun Workspaces](https://bun.sh/docs/install/workspaces)

## Language Integration

### Gleam via mix_gleam

**NOT a separate moon project!** Gleam code lives in `singularity_app/src/` and compiles with Elixir.

```yaml
# ❌ WRONG - Don't do this
projects:
  - 'singularity_app'
  - 'gleam_libs'  # Separate Gleam project

# ✅ CORRECT - Gleam is part of singularity_app
projects:
  - 'singularity_app'  # Includes both Elixir AND Gleam
```

**Build:**
```bash
cd singularity_app
mix compile  # Compiles both Elixir (.ex) and Gleam (.gleam)
```

**Calling:**
```elixir
# Elixir → Gleam
:singularity@htdag.new("goal-id")

# Gleam → Elixir
@external(erlang, "Elixir.MyModule", "function")
```

See [docs/architecture/GLEAM_INTEGRATION.md](docs/architecture/GLEAM_INTEGRATION.md)

### Rust via Rustler NIFs

Rust crates that produce NIFs (like `embedding_engine`) are loaded by Elixir:

```elixir
# singularity_app/lib/singularity/embedding_engine.ex
use Rustler, otp_app: :singularity, crate: "embedding_engine"
```

**Build:**
```bash
# Rust builds first
moon run rust/embedding_engine:build

# Then Elixir loads the .so
cd singularity_app
mix compile
```

