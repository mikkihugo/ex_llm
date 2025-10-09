# Multi-Tier Rust Binary Caching

**All 3 tiers work together automatically!**

## Tier 1: cargo-quickinstall (Fastest)
Pre-built binaries from community cache.

```bash
# Install a tool (tries quickinstall first)
cargo quickinstall ripgrep

# Falls back to binstall if not in quickinstall cache
```

## Tier 2: cargo-binstall (Fast)
Downloads from GitHub releases.

```bash
# Install from GitHub releases
cargo binstall cargo-watch

# Also works as fallback from quickinstall
```

## Tier 3: sccache (Compilation Cache)
Automatic - caches compiled object files.

```bash
# Just compile normally - sccache works automatically
cargo build

# Check stats
sccache --show-stats
```

## Combined Workflow

```bash
# 1. Try quickinstall first (fastest)
cargo quickinstall tokio-console || \
# 2. Fall back to binstall (fast)
cargo binstall tokio-console || \
# 3. Compile from source (sccache speeds this up)
cargo install tokio-console
```

## Cache Locations

- **cargo-quickinstall**: Downloads to `$CARGO_HOME/bin/`
- **cargo-binstall**: Downloads to `$CARGO_HOME/bin/`
- **sccache**: Caches compilation at `~/.cache/singularity/sccache` (10GB)
- **Cargo deps**: Downloaded crates at `~/.cache/singularity/cargo/`

## Reset Caches

```bash
# Clear sccache
sccache --stop-server
rm -rf ~/.cache/singularity/sccache

# Clear cargo downloads
rm -rf ~/.cache/singularity/cargo/registry
```

## Status Check

```bash
# Show all cache stats
sccache --show-stats
du -sh ~/.cache/singularity/cargo
ls ~/.cache/singularity/cargo/bin/
```
