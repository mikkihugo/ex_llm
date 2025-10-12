# UNWIRED - No Elixir Wrapper

This Rust NIF crate is **not wired** to any Elixir module.

**Status:** The NIF provides `Elixir.Singularity.PackageEngine` but no corresponding Elixir module exists in `singularity_app/lib/singularity/`.

**Current State:** Partial implementation - has modules but no complete NIF.

## Modules Present

- `package_file_watcher` - Package file monitoring
- `cache` - Package caching
- `engine` - Core engine logic
- `processor` - Package processing

## Options

### Option 1: Create Elixir Wrapper (Recommended if needed)

If package analysis is needed as a separate engine:
```elixir
# singularity_app/lib/singularity/package_engine.ex
defmodule Singularity.PackageEngine do
  use Rustler,
    otp_app: :singularity,
    crate: :package_engine,
    skip_compilation?: true

  @behaviour Singularity.Engine
  # ... implement
end
```

### Option 2: Remove This Crate (Recommended if not needed)

If package functionality is handled elsewhere:
1. Remove `rust/package/` directory
2. Remove from workspace `Cargo.toml`
3. Remove `native/package_engine` symlink
4. Remove from `singularity_app/mix.exs` dependencies

## Investigation Needed

**Question:** Is package analysis needed as a separate engine?

**Current State:** Package functionality might already exist in:
- `singularity_app/lib/singularity/packages/` (Elixir implementation)
- `Singularity.Detection.*` modules
- Other analysis engines

**Recommendation:** Review if this duplicates existing functionality before wiring.

**Complexity:** This crate seems more complete than `framework` but still incomplete.

---
**Date:** 2025-10-10  
**Issue:** Unwired crate discovered during NIF audit
