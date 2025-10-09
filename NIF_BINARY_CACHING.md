# NIF Binary Caching with Cachix

**Since NIFs are internal (not on Hex), use Cachix to cache compiled binaries.**

## Current Setup

✅ **Compilation skipped** - `skip_compilation?: true` in modules  
✅ **Cachix configured** - `mikkihugo.cachix.org`  
✅ **sccache enabled** - Speeds up Rust compilation

## Strategy: Cache NIFs in Cachix

### Option 1: Build NIFs with Nix (Recommended)

Create a Nix derivation for each NIF:

```nix
# In flake.nix, add NIF packages:
embeddingEngineNif = pkgs.rustPlatform.buildRustPackage {
  pname = "embedding_engine";
  version = "0.1.0";
  src = ./singularity_app/native/embedding_engine;
  
  cargoLock = {
    lockFile = ./singularity_app/native/embedding_engine/Cargo.lock;
  };
  
  # Build as cdylib (NIF)
  buildPhase = ''
    cargo build --release --lib
  '';
  
  installPhase = ''
    mkdir -p $out/priv
    cp target/release/libembedding_engine.so $out/priv/
  '';
};
```

Then:
```bash
# Build and push to cachix
nix build .#embeddingEngineNif
cachix push mikkihugo result
```

### Option 2: Manual Compile + Cache (Current)

1. **Compile once** (with sccache):
```bash
cd singularity_app
# Remove skip_compilation temporarily
mix compile  # Compiles all NIFs
```

2. **NIFs cached at**:
- Compilation cache: `~/.cache/singularity/sccache/`
- Built binaries: `singularity_app/_build/dev/lib/*/priv/*.so`

3. **Re-enable skip_compilation** - Future compiles skip Rust

4. **Commit `.cargo-build/` to Git** (if small) or use Cachix

### Option 3: Store in Cachix via Nix Store

```bash
# Build NIFs
cd singularity_app/native/embedding_engine
cargo build --release

# Copy to Nix store
nix-store --add-fixed sha256 target/release/libembedding_engine.so

# Push to cachix  
cachix push mikkihugo /nix/store/<hash>-libembedding_engine.so
```

## Recommendation

**Use Option 1** for reproducible builds that auto-cache in Cachix.

**Current setup (skip_compilation)** works well if:
- You compile once manually
- Cache `_build/` or `.cargo-build/` directories
- Use sccache for fast recompilation when needed

## Check Cache

```bash
# Check what's in cachix
cachix use mikkihugo
nix path-info --all | grep embedding_engine

# Check local compiled NIFs
find singularity_app -name "*.so"
```
