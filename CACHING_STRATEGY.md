# Caching Strategy for Singularity

## Overview

Singularity uses a **dual-layer caching strategy** combining Nix binary cache (Cachix) with GitHub Actions cache for optimal build performance.

## Caching Layers

### 1. Moon Cache (Task Orchestration) 🌙

**Purpose**: Caches task outputs and dependencies across projects
**Location**: `.moon/cache/`
**Coverage**: All Moon task outputs, cross-project dependencies

```yaml
# .moon/workspace.yml
projects:
  - 'singularity'      # Elixir app
  - 'centralcloud'     # Elixir service  
  - 'llm-server'       # TypeScript AI server
  - 'rust'             # Rust workspace
  - 'rust/architecture_engine'  # NIF engines
  # ... 12 total projects
```

**Benefits**:
- ✅ **Task-level caching**: Each task caches its outputs
- ✅ **Cross-project dependencies**: Tasks can depend on other projects
- ✅ **Incremental builds**: Only rebuild what changed
- ✅ **Parallel execution**: Run independent tasks in parallel

### 2. Nix Binary Cache (Cachix) 🏗️

**Purpose**: Caches compiled Nix packages and derivations
**Provider**: `mikkihugo.cachix.org`
**Coverage**: All Nix dependencies (Elixir, Rust, Python, system packages)

```nix
# flake.nix
nixConfig = {
  extra-substituters = ["https://mikkihugo.cachix.org"];
  extra-trusted-public-keys = ["mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="];
};
```

**Benefits**:
- ✅ **Cross-platform**: Works on any Nix system (macOS, Linux, WSL2)
- ✅ **Persistent**: Never expires (unless manually deleted)
- ✅ **Fast**: Binary downloads vs compilation
- ✅ **Comprehensive**: Covers entire dependency tree

### 3. GitHub Actions Cache 📦

**Purpose**: Caches build artifacts and intermediate files
**Provider**: GitHub's built-in cache
**Coverage**: Elixir `_build/`, Cargo `target/`, Bun `node_modules/`, Moon `.moon/cache/`

```yaml
# .github/workflows/*.yml
- name: Cache Build Artifacts
  uses: actions/cache@v4
  with:
    path: |
      singularity/_build
      singularity/deps
      .cargo-build
      ~/.cargo/registry
      ~/.cargo/git
    key: ${{ runner.os }}-${{ hashFiles('**/mix.lock', '**/Cargo.lock') }}
```

**Benefits**:
- ✅ **CI-optimized**: Designed for GitHub Actions
- ✅ **Incremental**: Only caches what changed
- ✅ **Free**: No additional cost
- ✅ **Fast**: Local to runner

## Cache Hierarchy

```
1. GitHub Cache (Build Artifacts)
   ├── Elixir: _build/, deps/
   ├── Rust: target/, ~/.cargo/
   ├── Bun: node_modules/, ~/.bun/
   └── Moon: .moon/cache/

2. Moon Cache (Task Orchestration)
   ├── Task outputs per project
   ├── Cross-project dependencies
   └── Incremental build state

3. Cachix (Nix Packages)
   ├── Elixir 1.19, Erlang 28
   ├── Rust toolchain, Cargo
   ├── Python 3.11, PyTorch
   └── System packages (PostgreSQL, NATS, etc.)
```

## Performance Impact

### Without Caching
- **Nix build**: 15-30 minutes (compiling from source)
- **Elixir deps**: 5-10 minutes
- **Rust compilation**: 10-20 minutes
- **Moon tasks**: 5-15 minutes (task orchestration)
- **Total**: 35-75 minutes

### With Caching
- **Nix build**: 2-5 minutes (binary downloads)
- **Elixir deps**: 30 seconds (cached)
- **Rust compilation**: 1-2 minutes (cached)
- **Moon tasks**: 10-30 seconds (task cache hits)
- **Total**: 3-7 minutes

**Speedup**: 10-15x faster builds! 🚀

## Cache Management

### Cachix Management

```bash
# View cache status
cachix list

# Push to cache (after successful build)
nix build .#dev
cachix push mikkihugo

# Check cache hits
nix build .#dev --print-build-logs | grep "copying path"
```

### GitHub Cache Management

```bash
# Cache is automatic in CI
# Manual cache clearing via GitHub UI:
# Settings → Actions → Caches → Delete
```

## Cache Keys Strategy

### Nix Cache Keys
- **Automatic**: Nix handles derivation hashing
- **Based on**: Source code, dependencies, system architecture
- **Collision-free**: Cryptographic hashes

### GitHub Cache Keys
- **Primary**: `${{ runner.os }}-${{ hashFiles('**/mix.lock', '**/Cargo.lock') }}`
- **Fallback**: `${{ runner.os }}-` (partial match)
- **Scope**: Per-workflow, per-runner OS

## Troubleshooting

### Cache Misses

**Nix Cache Miss**:
```bash
# Check if package exists in cache
nix-store --query --references $(nix-instantiate '<nixpkgs>' -A elixir)

# Force rebuild and push
nix build .#dev --rebuild
cachix push mikkihugo
```

**GitHub Cache Miss**:
```yaml
# Check cache hit status
- name: Show cache status
  run: |
    echo "Cache hit? ${{ steps.cache-build.outputs.cache-hit }}"
```

### Cache Corruption

**Clear Nix Cache**:
```bash
# Clear local Nix store
nix-collect-garbage -d

# Rebuild from Cachix
nix build .#dev
```

**Clear GitHub Cache**:
- GitHub UI: Settings → Actions → Caches
- Or wait for automatic expiration (7 days)

## Best Practices

### 1. Cache Key Design
- ✅ Include file hashes: `hashFiles('**/mix.lock')`
- ✅ Include OS: `${{ runner.os }}`
- ✅ Use restore-keys for fallback
- ❌ Don't use timestamps (causes cache misses)

### 2. Cache Paths
- ✅ Cache build outputs: `_build/`, `target/`
- ✅ Cache dependencies: `deps/`, `node_modules/`
- ✅ Cache registries: `~/.cargo/registry`
- ❌ Don't cache source code (changes frequently)

### 3. Cache Size Management
- **GitHub Cache**: 10GB limit per repository
- **Cachix**: No limit (but costs storage)
- **Monitor**: Check cache usage regularly

## Monitoring

### Cache Hit Rates
```bash
# Nix cache hits (look for "copying path" in build logs)
nix build .#dev --print-build-logs | grep -c "copying path"

# GitHub cache hits (in workflow logs)
echo "Cache hit? ${{ steps.cache-build.outputs.cache-hit }}"
```

### Cache Performance
- **Target**: >80% cache hit rate
- **Nix**: Should see mostly "copying path" vs "building"
- **GitHub**: Should see "Cache hit: true" most of the time

## Cost Analysis

### Cachix Costs
- **Free tier**: 5GB storage
- **Paid**: $0.10/GB/month
- **Current usage**: ~2GB (estimated)
- **Status**: Within free tier ✅

### GitHub Cache Costs
- **Free**: 10GB per repository
- **Current usage**: ~1GB (estimated)
- **Status**: Well within limits ✅

## Moon Integration Benefits

### Task-Level Caching
```yaml
# Example: singularity/moon.yml
compile:
  command: 'nix develop ..#dev --command just compile'
  deps: ['deps.compile', 'rust.build']  # Dependencies
  inputs: ['lib/**', 'config/**']       # Input files  
  outputs: ['_build/']                  # Cached outputs
```

### Cross-Project Dependencies
- **singularity** depends on **rust** NIF builds
- **centralcloud** depends on **rust/package_intelligence**
- **llm-server** can depend on **singularity** for types

### Parallel Execution
```bash
# Run all tasks in parallel
moon run build --parallel

# Run specific project tasks
moon run singularity:compile
moon run rust:build
```

## Conclusion

**All three caching layers are essential** for optimal performance:

- **Moon Cache**: Handles task orchestration and cross-project dependencies
- **Cachix**: Handles Nix package compilation (biggest time saver)  
- **GitHub Cache**: Handles build artifacts (incremental builds)

**Recommendation**: Keep all three, optimize cache keys, monitor hit rates, and enjoy 10-15x faster builds! 🚀