# Adding New Projects to the Moon Monorepo

This guide explains how to add new Elixir, TypeScript/Bun, or Rust projects to the Singularity monorepo. **No workflow changes needed** - glob patterns automatically detect new projects!

## Overview

Singularity uses Moon for monorepo management with automatic caching:
- **GitHub Actions cache**: Automatically caches all `**/node_modules`, `**/deps`, `**/_build`, `.cargo-build`, `.moon/cache`
- **Cachix**: Nix store artifacts shared across all machines
- **Moon**: Task orchestration and output caching in `.moon/cache/`

## Adding a TypeScript/Bun Project (like ai-server)

### 1. Create the project directory

```bash
cd /home/mhugo/code/singularity
mkdir my-new-service
cd my-new-service
bun init
```

### 2. Create `moon.yml` in the project root

```yaml
$schema: '../.moon/cache/schemas/project.json'

language: 'typescript'
type: 'application'  # or 'library'

tasks:
  deps:
    command: 'nix develop ..#dev --command bun install'
    inputs:
      - 'package.json'
      - 'bun.lock'
    outputs:
      - 'node_modules/'

  build:
    command: 'nix develop ..#dev --command bun build'
    deps:
      - 'deps'
    inputs:
      - 'src/**'
      - 'tsconfig.json'
    outputs:
      - 'dist/'

  test:
    command: 'nix develop ..#dev --command bun test'
    deps:
      - 'deps'
    inputs:
      - 'src/**'
      - 'test/**'

  check:
    deps:
      - 'test'
```

### 3. Add to workspace

Edit `.moon/workspace.yml`:

```yaml
projects:
  - 'ai-server'
  - 'my-new-service'  # Add here
  - 'singularity_app'
  # ... other projects
```

### 4. That's it!

**No workflow changes needed!** The glob patterns automatically include:
- `**/node_modules` - Your new service's dependencies
- `**/bun.lock*` - Cache key includes your lockfile
- `.moon/cache` - Task outputs cached

Run Moon tasks:
```bash
moon run my-new-service:deps
moon run my-new-service:build
moon run my-new-service:test
```

## Adding an Elixir Project (like singularity_app)

### 1. Create the Elixir application

```bash
cd /home/mhugo/code/singularity
mix new my_elixir_service --app my_elixir_service
cd my_elixir_service
```

### 2. Create `moon.yml`

```yaml
$schema: '../.moon/cache/schemas/project.json'

language: 'elixir'
type: 'application'

tasks:
  deps.get:
    command: 'nix develop ..#dev --command mix deps.get'
    inputs:
      - 'mix.exs'
      - 'mix.lock'
    outputs:
      - 'deps/'

  deps.compile:
    command: 'nix develop ..#dev --command mix deps.compile'
    deps:
      - 'deps.get'
    inputs:
      - 'deps/**'
    outputs:
      - '.mix/**'

  compile:
    command: 'nix develop ..#dev --command mix compile'
    deps:
      - 'deps.compile'
    inputs:
      - 'lib/**'
      - 'config/**'
      - 'priv/**'
    outputs:
      - '_build/'

  test:
    command: 'nix develop ..#dev --command mix test'
    deps:
      - 'compile'
    inputs:
      - 'test/**'
      - 'lib/**'

  format:
    command: 'nix develop ..#dev --command mix format'
    inputs:
      - 'lib/**'
      - 'test/**'
      - 'config/**'

  credo:
    command: 'nix develop ..#dev --command mix credo --strict'
    deps:
      - 'compile'
    inputs:
      - 'lib/**'
      - 'test/**'

  check:
    deps:
      - 'test'
      - 'credo'
```

### 3. Add to workspace

Edit `.moon/workspace.yml`:

```yaml
projects:
  - 'singularity_app'
  - 'my_elixir_service'  # Add here
  # ... other projects
```

### 4. That's it!

**No workflow changes needed!** The glob patterns automatically include:
- `**/.mix` - Your new service's Mix home
- `**/.hex` - Hex cache
- `**/deps` - Elixir dependencies
- `**/_build` - Compiled BEAM bytecode
- `**/mix.lock` - Cache key includes your lockfile

Run Moon tasks:
```bash
moon run my_elixir_service:deps.get
moon run my_elixir_service:compile
moon run my_elixir_service:test
```

## Adding a Rust Project/NIF (in rust-central)

### 1. Create the crate

```bash
cd /home/mhugo/code/singularity/rust-central
cargo new --lib my_engine
```

### 2. Add to workspace

Edit `rust-central/Cargo.toml`:

```toml
[workspace]
members = [
    "architecture_engine",
    "my_engine",  # Add here
    # ... other engines
]
```

### 3. Add Moon project (optional, for task orchestration)

Edit `.moon/workspace.yml`:

```yaml
projects:
  - 'rust-central/my_engine'
  # ... other projects
```

Create `rust-central/my_engine/moon.yml`:

```yaml
$schema: '../../.moon/cache/schemas/project.json'

language: 'rust'
type: 'library'

tasks:
  build:
    command: 'cargo build'
    inputs:
      - 'src/**'
      - 'Cargo.toml'
    outputs:
      - 'target/'

  test:
    command: 'cargo test'
    deps:
      - 'build'
```

### 4. That's it!

**No workflow changes needed!** The `.cargo-build/` directory is shared across ALL Rust crates.

## What Happens Automatically

When you add a new project following these patterns:

✅ **GitHub Actions automatically caches:**
- `**/node_modules` (all TypeScript/Bun projects)
- `**/.mix`, `**/.hex`, `**/deps`, `**/_build` (all Elixir projects)
- `.cargo-build` (shared across all Rust)
- `.moon/cache` (all Moon task outputs)

✅ **Cache keys automatically include:**
- `**/mix.lock` (all Elixir lockfiles)
- `**/bun.lock*` (all Bun lockfiles)
- `**/package-lock.json` (all npm lockfiles)
- `**/moon.yml` (all Moon configs)

✅ **Cachix automatically shares:**
- Nix store derivations (Erlang, Elixir, Rust, Bun toolchains)
- Built Nix packages

## Best Practices

1. **Use consistent task names** across projects:
   - `deps` - Install dependencies
   - `build` - Build the project
   - `test` - Run tests
   - `check` - Run all quality checks

2. **Declare inputs and outputs** in Moon tasks for optimal caching

3. **Use task dependencies** (`deps:` field) to ensure correct build order

4. **Run Moon tasks through Nix** for reproducible builds:
   ```bash
   nix develop -c moon run project:task
   ```

5. **Commit lockfiles** (`mix.lock`, `bun.lock`, `Cargo.lock`) for reproducible builds

## Example: Adding Central Cloud Framework Service

```bash
# Create the service
mkdir central_cloud_framework
cd central_cloud_framework
bun init

# Create moon.yml (copy from ai-server and adapt)
# Add to .moon/workspace.yml

# That's all! No workflow changes needed!
# CI will automatically:
# - Cache central_cloud_framework/node_modules
# - Include central_cloud_framework/bun.lock in cache key
# - Run Moon tasks if defined
```

## Troubleshooting

### Cache not hitting after adding new project

1. Check that lockfiles are committed
2. Verify Moon project is added to `.moon/workspace.yml`
3. GitHub Actions cache updates on first successful run

### Moon task not found

1. Verify `moon.yml` exists in project root
2. Check project is listed in `.moon/workspace.yml`
3. Run `moon sync` to update project graph

### Dependencies not being cached

1. Ensure `outputs:` in Moon task matches actual directory (e.g., `node_modules/` vs `node_modules`)
2. Check glob patterns include the directory (they should - we use `**/`)

## Summary

**Adding new projects is simple:**
1. Create project directory
2. Add `moon.yml` with tasks
3. Add to `.moon/workspace.yml`
4. **Done!** - No workflow changes needed

The glob patterns in GitHub Actions workflows automatically detect and cache all build artifacts for new projects.
