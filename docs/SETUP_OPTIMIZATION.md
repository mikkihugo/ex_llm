# Optimizing Setup Speed

This document explains how the Singularity development environment is optimized for fast setup and how to leverage caching.

## What's Already Optimized

### 1. Precompiled Binaries via Nixpkgs

All core tools come as precompiled binaries from nixpkgs:
- **Elixir**: Using `beamPackages.elixir` (precompiled, no build needed)
- **Erlang**: Using `beamPackages.erlang` (precompiled)
- **Rust toolchain**: rustc, cargo, clippy, rustfmt (precompiled)
- **Essential tools**: All base tools are precompiled binaries

### 2. Minimal Cargo Tools

The flake.nix includes only essential Rust tools that are actually used:
- `rustc`, `cargo` - Core Rust compiler and build tool
- `Singularity Code Analyzer` (rust-analyzer) - LSP server for IDE support
- `cargo-watch` - File watcher (used in justfile)

**30+ specialized cargo tools were removed** to speed up setup. These tools (cargo-nextest, cargo-audit, cargo-llvm-cov, etc.) often need to be built from source and added significant setup time.

If you need additional cargo tools, install them on-demand:
```bash
cargo install cargo-nextest  # Test runner
cargo install cargo-audit    # Security scanning
cargo install cargo-expand   # Macro expansion
```

### 3. Binary Cache via Cachix

The flake is configured to use the `mikkihugo.cachix.org` binary cache (see `flake.nix` lines 9-16):

```nix
nixConfig = {
  extra-substituters = [
    "https://mikkihugo.cachix.org"
  ];
  extra-trusted-public-keys = [
    "mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="
  ];
};
```

This means:
- First setup downloads precompiled binaries from cachix (fast)
- No need to rebuild anything that's already cached
- Team members share the same cached builds

## Pushing to Cachix

To ensure all team members benefit from cached builds, push your dev shell to cachix:

```bash
# Build the dev shell
nix build .#devShells.x86_64-linux.default

# Push to cachix
nix build .#devShells.x86_64-linux.default --json \
  | jq -r '.[].outputs.out' \
  | cachix push mikkihugo
```

For CI/CD, push all common shells:
```bash
# Push all dev shells
for shell in default dev test ci; do
  nix build .#devShells.x86_64-linux.$shell --json \
    | jq -r '.[].outputs.out' \
    | cachix push mikkihugo
done
```

## What Takes Time During Setup

Even with optimizations, some things take time on first run:

### 1. Nix Store Downloads (First Time Only)
- **What**: Downloading all dependencies from nixpkgs and cachix
- **When**: First `direnv allow` or `nix develop`
- **Duration**: 5-15 minutes depending on network speed
- **Cached**: Yes, subsequent runs are instant

### 2. PostgreSQL Initialization (One-Time)
- **What**: Creating `.dev-db/pg` directory and initializing database
- **When**: First shell activation
- **Duration**: ~10 seconds
- **Cached**: Yes, directory persists

### 3. Mix Dependencies (Per Project)
- **What**: Elixir's package manager downloads dependencies
- **When**: First `mix deps.get` in singularity
- **Duration**: 1-3 minutes
- **Cached**: Via `.mix` and `.hex` directories

### 4. Bun Dependencies (Per Project)
- **What**: JavaScript package manager for llm-server
- **When**: First `bun install`
- **Duration**: 30-60 seconds
- **Cached**: Via `node_modules`

## Troubleshooting Slow Setup

### Check if Cachix is Working

```bash
# Should show mikkihugo.cachix.org in substituters
nix show-config | grep substituters
```

If cachix is not configured:
```bash
# Install cachix
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Use the cache
cachix use mikkihugo
```

### Clear Nix Store if Corrupted

```bash
# Remove old generations
nix-collect-garbage -d

# Rebuild
nix develop
```

### Use Binary Cache Only (Skip Builds)

If something tries to build from source when it shouldn't:

```bash
# Force binary-only mode (will fail if not in cache)
nix develop --option substitute-only true
```

This will error if anything needs to be built, helping identify what's not cached.

## Performance Metrics

Expected setup times:

| Scenario | First Run | Subsequent Runs |
|----------|-----------|-----------------|
| Fresh machine with cachix | 5-15 min | 2-5 seconds |
| Fresh machine without cachix | 20-40 min | 2-5 seconds |
| After `nix-collect-garbage` | 5-15 min | 2-5 seconds |
| Normal `direnv` reload | N/A | 2-5 seconds |

## Recommendations

1. **For team members**: Just use `direnv allow` - cachix will handle everything
2. **For CI/CD**: Pre-build and push dev shells to cachix before running tests
3. **For new tools**: Evaluate if they're essential or can be installed on-demand with `cargo install`
4. **For custom packages**: Push to cachix after building to share with team

## Further Optimization Ideas

If setup is still too slow, consider:

1. **Use devcontainers**: Pre-built Docker images with everything installed
2. **Binary cache on S3**: Faster than public cachix for large teams
3. **Nix flake lock**: Pin exact versions to ensure reproducible builds
4. **Lazy shell hooks**: Defer PostgreSQL/PGFlow services until first use

## Questions?

If setup is slower than expected:
1. Check network speed to cachix
2. Verify cachix is configured (`nix show-config | grep substituters`)
3. Check if something is building that shouldn't be (`nix develop -vvv`)
4. Ask in team chat - someone may have cached the build already
